import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/local/local_db.dart';
import '../data/sync/sync_outbox.dart';
import '../data/sync/sync_service.dart';
import '../game/realistic_car_game.dart';
import '../config/cloudinary_config.dart';
import '../models/game_level.dart';
import '../models/last_driving_report.dart';
import 'cloudinary_upload_service.dart';

/// Persists the latest finished practical driving attempt per level (for level cards).
class LastDrivingReportService {
  LastDrivingReportService._();
  static final LastDrivingReportService instance = LastDrivingReportService._();

  static const _prefsMapKey = 'last_driving_reports_by_level_v1';
  /// Legacy single global report (pre per-level); merged in [_readAllRaw] until a new save runs.
  static const _legacyPrefsKey = 'last_driving_report_v1';

  static ({int correct, int mistakes, int total}) _rubricCounts(
    DrivingAttemptSummary s, {
    required bool roadCrossingLayout,
  }) {
    final List<bool> checks;
    if (roadCrossingLayout) {
      checks = [
        s.enteredApproachZone,
        s.waitedAtRoadCrossing,
        s.reachedFinishZone,
        s.nonCrashBumpCount == 0,
      ];
    } else {
      checks = [
        s.enteredApproachZone,
        s.signaledCorrectlyInApproachZone,
        s.enteredMidTurnZone,
        s.hadCorrectSignalInMidTurnZone,
        s.reachedFinishZone,
        s.nonCrashBumpCount == 0,
      ];
    }
    final correct = checks.where((e) => e).length;
    final total = checks.length;
    return (correct: correct, mistakes: total - correct, total: total);
  }

  static String _signalPhrase(String expected) {
    switch (expected) {
      case 'left':
        return 'left turn signal';
      case 'right':
        return 'right turn signal';
      default:
        return 'no turn signal (straight / no turning manoeuvre)';
    }
  }

  /// One explanatory sentence per failed checklist row (matches in-game rubric).
  static List<String> mistakeDetailLines(
    DrivingAttemptSummary s, {
    required bool roadCrossingLayout,
  }) {
    final lines = <String>[];
    if (roadCrossingLayout) {
      if (!s.enteredApproachZone) {
        lines.add(
          'Approach control — yellow speed-limit zone was not entered as required before the attempt ended.',
        );
      }
      if (!s.waitedAtRoadCrossing) {
        lines.add(
          'Zebra crossing — full stop in Park and the completed wait within the grey zig-zag zone were not satisfied.',
        );
      }
      if (!s.reachedFinishZone) {
        lines.add(
          'Route completion — the vehicle did not reach the green finish zone.',
        );
      }
      if (s.nonCrashBumpCount > 0) {
        lines.add(
          'Obstacle discipline — recorded ${s.nonCrashBumpCount} minor non-crash contact(s); a clean run requires none.',
        );
      }
    } else {
      final sig = _signalPhrase(s.expectedTurnSignal);
      if (!s.enteredApproachZone) {
        lines.add(
          'Approach zone — the yellow marked approach zone was not entered.',
        );
      }
      if (!s.signaledCorrectlyInApproachZone) {
        lines.add(
          'Signalling (approach) — the correct $sig was not shown in the yellow approach zone.',
        );
      }
      if (!s.enteredMidTurnZone) {
        lines.add(
          'Turn execution — the purple turn execution zone was not entered.',
        );
      }
      if (!s.hadCorrectSignalInMidTurnZone) {
        lines.add(
          'Signalling (during turn) — the required $sig was not maintained throughout the purple zone.',
        );
      }
      if (!s.reachedFinishZone) {
        lines.add(
          'Route completion — the green finish zone was not reached.',
        );
      }
      if (s.nonCrashBumpCount > 0) {
        lines.add(
          'Obstacle discipline — recorded ${s.nonCrashBumpCount} minor non-crash contact(s); a clean run requires none.',
        );
      }
    }
    return lines;
  }

  Future<Map<String, dynamic>> _readAllRaw() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> all = {};
    final raw = prefs.getString(_prefsMapKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          all = Map<String, dynamic>.from(decoded);
        } else if (decoded is Map) {
          all = decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
    if (all.isEmpty) {
      final legacy = prefs.getString(_legacyPrefsKey);
      if (legacy != null && legacy.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacy);
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            final id = map['levelId'] as String?;
            if (id != null && id.isNotEmpty) all[id] = map;
          }
        } catch (_) {}
      }
    }
    return all;
  }

  Map<String, dynamic> _normalizeFirestoreDoc(String docId, Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    m['levelId'] = docId;
    final iso = m['recordedAtIso'];
    if (iso is! String || iso.isEmpty) {
      final t = m['recordedAt'];
      if (t is Timestamp) {
        m['recordedAtIso'] = t.toDate().toUtc().toIso8601String();
      }
    }
    m.remove('syncedAt');
    m.remove('opId');
    m.remove('updatedAt');
    return m;
  }

  DateTime? _parseRecordedAtFromMap(Map<String, dynamic> m) {
    final iso = m['recordedAtIso'];
    if (iso is String && iso.isNotEmpty) return DateTime.tryParse(iso)?.toUtc();
    final t = m['recordedAt'];
    if (t is Timestamp) return t.toDate().toUtc();
    return null;
  }

  /// Pulls newer per-level summaries from Firestore into the local SharedPreferences cache.
  Future<void> mergeRemoteSummariesIfSignedIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('driving_last_runs')
          .get();
      if (snap.docs.isEmpty) return;

      final all = await _readAllRaw();
      var changed = false;

      for (final doc in snap.docs) {
        final raw = doc.data();
        final normalized = _normalizeFirestoreDoc(doc.id, raw);
        LastDrivingReport remote;
        try {
          remote = LastDrivingReport.fromJson(normalized);
        } catch (_) {
          continue;
        }
        final remoteAt = remote.recordedAt;

        final existingRaw = all[doc.id];
        DateTime? localAt;
        if (existingRaw is Map) {
          localAt = _parseRecordedAtFromMap(Map<String, dynamic>.from(existingRaw));
        }

        if (localAt == null || remoteAt.isAfter(localAt)) {
          all[doc.id] = remote.toJson();
          changed = true;
        }
      }

      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsMapKey, jsonEncode(all));
      }
    } catch (_) {
      // Offline, rules, or transient errors — keep local cache only.
    }
  }

  /// Persists [report] to SharedPreferences under [level.id].
  Future<void> _persistReportToPrefs(LastDrivingReport report, String levelId) async {
    final all = await _readAllRaw();
    all[levelId] = report.toJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsMapKey, jsonEncode(all));
  }

  /// Firestore payload: never send device-local [screenshotPath].
  Map<String, dynamic> _firestorePayload(LastDrivingReport report, GameLevel level) {
    final j = Map<String, dynamic>.from(report.toJson());
    j.remove('screenshotPath');
    if (level.moduleId != null && level.moduleId!.trim().isNotEmpty) {
      j['moduleId'] = level.moduleId!.trim();
    }
    return j;
  }

  Future<void> _enqueueDrivingLastRun(
    String uid,
    GameLevel level,
    Map<String, dynamic> payload,
  ) async {
    final opId = const Uuid().v4();
    final outbox = SyncOutbox(LocalDb.instance.isar);
    await outbox.enqueue(
      opId: opId,
      uid: uid,
      entityType: 'driving_last_run',
      entityId: level.id,
      payload: payload,
    );
    unawaited(SyncService.instance.syncNow());
  }

  Future<String?> _writeScreenshotToDisk(Uint8List bytes, String objectName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final screenshotsDir = Directory('${dir.path}/driving_screenshots');
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }
      final file = File('${screenshotsDir.path}/$objectName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// After local save, uploads to Cloudinary and updates prefs + Firestore when signed in.
  Future<void> _finalizeCloudinaryUpload({
    required LastDrivingReport baseReport,
    required Uint8List screenshotBytes,
    required String objectName,
    required String safeId,
    required int ts,
    required GameLevel level,
    String? uid,
  }) async {
    await CloudinaryConfig.ensureLoaded();
    String? url;
    if (CloudinaryConfig.isConfigured) {
      final owner = (uid != null && uid.isNotEmpty) ? uid : 'guest';
      url = await CloudinaryUploadService.uploadImageBytes(
        bytes: screenshotBytes,
        fileName: objectName,
        publicId: '${owner}_${safeId}_$ts',
      );
    }
    if (url == null || url.isEmpty) {
      if (uid != null && uid.isNotEmpty) {
        await _enqueueDrivingLastRun(uid, level, _firestorePayload(baseReport, level));
      }
      return;
    }

    final updated = LastDrivingReport(
      levelId: baseReport.levelId,
      levelName: baseReport.levelName,
      passed: baseReport.passed,
      score: baseReport.score,
      correctMoves: baseReport.correctMoves,
      mistakes: baseReport.mistakes,
      mistakeDetails: baseReport.mistakeDetails,
      timeSpentMs: baseReport.timeSpentMs,
      recordedAt: baseReport.recordedAt,
      failureMessage: baseReport.failureMessage,
      roadCrossingLayout: baseReport.roadCrossingLayout,
      screenshotPath: baseReport.screenshotPath,
      screenshotUrl: url,
    );
    await _persistReportToPrefs(updated, level.id);

    if (uid != null && uid.isNotEmpty) {
      await _enqueueDrivingLastRun(uid, level, _firestorePayload(updated, level));
    }
  }

  Future<void> recordAttempt({
    required DrivingAttemptSummary summary,
    required GameLevel level,
    Uint8List? screenshotBytes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final road = LastDrivingReport.isRoadCrossingMap(level.mapAsset);
    final counts = _rubricCounts(summary, roadCrossingLayout: road);
    final mistakeDetails = mistakeDetailLines(summary, roadCrossingLayout: road);
    final recordedAt = DateTime.now().toUtc();

    String? screenshotPath;
    int? uploadTs;
    String? uploadSafeId;
    String? objectName;

    if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
      uploadTs = DateTime.now().millisecondsSinceEpoch;
      uploadSafeId = level.id.replaceAll(RegExp(r'[^\w\-]+'), '_');
      objectName = '${uploadSafeId}_$uploadTs.png';
      screenshotPath = await _writeScreenshotToDisk(screenshotBytes, objectName);
    }

    final report = LastDrivingReport(
      levelId: level.id,
      levelName: level.name,
      passed: summary.passed,
      score: summary.score,
      correctMoves: counts.correct,
      mistakes: counts.mistakes,
      mistakeDetails: mistakeDetails,
      timeSpentMs: summary.timeSpent.inMilliseconds,
      recordedAt: recordedAt,
      failureMessage: summary.failureMessage,
      roadCrossingLayout: road,
      screenshotPath: screenshotPath,
      screenshotUrl: null,
    );

    await _persistReportToPrefs(report, level.id);

    if (screenshotBytes != null &&
        screenshotBytes.isNotEmpty &&
        objectName != null &&
        uploadTs != null &&
        uploadSafeId != null) {
      unawaited(
        _finalizeCloudinaryUpload(
          baseReport: report,
          screenshotBytes: screenshotBytes,
          objectName: objectName,
          safeId: uploadSafeId,
          ts: uploadTs,
          level: level,
          uid: uid,
        ),
      );
      return;
    }

    if (uid != null && uid.isNotEmpty) {
      await _enqueueDrivingLastRun(uid, level, _firestorePayload(report, level));
    }
  }

  Future<LastDrivingReport?> loadReportForLevel(String levelId) async {
    final all = await _readAllRaw();
    final rawEntry = all[levelId];
    if (rawEntry is! Map) return null;
    try {
      return LastDrivingReport.fromJson(Map<String, dynamic>.from(rawEntry));
    } catch (_) {
      return null;
    }
  }

  /// Level IDs that have at least one saved finished attempt.
  Future<Set<String>> levelIdsWithSavedReports() async {
    final all = await _readAllRaw();
    return all.keys.toSet();
  }
}
