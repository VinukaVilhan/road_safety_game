import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../local/isar_schemas.dart';
import '../local/local_db.dart';
import '../sync/sync_outbox.dart';
import '../sync/sync_service.dart';

class ProgressRepository {
  ProgressRepository._();
  static final ProgressRepository instance = ProgressRepository._();

  static const _passScore = 70;
  /// Isar rows and unlock logic use this when there is no Firebase user so road-signs / theory progress still works offline.
  static const _guestProgressUid = '__local_guest__';
  final _uuid = const Uuid();

  Isar get _isar => LocalDb.instance.isar;
  SyncOutbox get _outbox => SyncOutbox(_isar);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String get _progressUid => _uid ?? _guestProgressUid;

  Future<Set<String>> getCompletedLevelIds() async {
    final uid = _uid;
    if (uid == null) return <String>{};
    final levels =
        await _isar.localLevelProgress.filter().uidEqualTo(uid).and().completedEqualTo(true).findAll();
    return levels.map((e) => e.levelId).toSet();
  }

  Future<void> markLevelCompleted(String levelId, {String? moduleId}) async {
    final uid = _uid;
    final trimmed = levelId.trim();
    if (uid == null || trimmed.isEmpty) return;

    final key = '$uid::$trimmed';
    final opId = _uuid.v4();
    final now = DateTime.now().toUtc();

    final existing = await _isar.localLevelProgress.filter().keyEqualTo(key).findFirst();
    final progress = existing ?? LocalLevelProgress()
      ..key = key
      ..uid = uid
      ..levelId = trimmed;

    progress.completed = true;
    progress.updatedAt = now;
    progress.synced = false;
    progress.lastOpId = opId;

    await _isar.writeTxn(() async {
      await _isar.localLevelProgress.put(progress);
    });

    await _outbox.enqueue(
      opId: opId,
      uid: uid,
      entityType: 'level_progress',
      entityId: trimmed,
      payload: {
        if (moduleId != null && moduleId.trim().isNotEmpty) 'moduleId': moduleId.trim(),
        'completed': true,
        'updatedAt': now.toIso8601String(),
      },
    );

    unawaited(SyncService.instance.syncNow());
  }

  Future<Set<String>> getCompletedTestIds() async {
    final uid = _progressUid;
    final tests =
        await _isar.localTheoryTestProgress.filter().uidEqualTo(uid).and().passedEqualTo(true).findAll();
    return tests.map((e) => e.testId).toSet();
  }

  Future<void> recordTheoryAttempt({
    required String testId,
    required int totalQuestions,
    required int correctCount,
    required int score,
  }) async {
    final trimmed = testId.trim();
    if (trimmed.isEmpty) return;

    final uid = _progressUid;
    final syncUid = _uid;
    final now = DateTime.now().toUtc();
    final attemptOpId = _uuid.v4();
    final progressOpId = _uuid.v4();
    final attemptId = _uuid.v4();
    final passed = score >= _passScore;
    final key = '$uid::$trimmed';

    final existing = await _isar.localTheoryTestProgress.filter().keyEqualTo(key).findFirst();
    final progress = existing ?? LocalTheoryTestProgress()
      ..key = key
      ..uid = uid
      ..testId = trimmed;

    progress.attempts += 1;
    progress.bestScore = score > progress.bestScore ? score : progress.bestScore;
    progress.passed = progress.passed || passed;
    progress.updatedAt = now;
    progress.synced = false;
    progress.lastOpId = progressOpId;

    final attempt = LocalTheoryAttempt()
      ..attemptId = attemptId
      ..uid = uid
      ..testId = trimmed
      ..score = score
      ..totalQuestions = totalQuestions
      ..correctCount = correctCount
      ..createdAt = now
      ..updatedAt = now
      ..synced = false
      ..lastOpId = attemptOpId;

    await _isar.writeTxn(() async {
      await _isar.localTheoryTestProgress.put(progress);
      await _isar.localTheoryAttempts.put(attempt);
    });

    if (syncUid != null) {
      await _outbox.enqueue(
        opId: progressOpId,
        uid: syncUid,
        entityType: 'theory_test_progress',
        entityId: trimmed,
        payload: {
          'attempts': progress.attempts,
          'bestScore': progress.bestScore,
          'passed': progress.passed,
          'updatedAt': now.toIso8601String(),
        },
      );

      await _outbox.enqueue(
        opId: attemptOpId,
        uid: syncUid,
        entityType: 'theory_attempt',
        entityId: attemptId,
        payload: {
          'testId': trimmed,
          'score': score,
          'totalQuestions': totalQuestions,
          'correctCount': correctCount,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
    }

    if (syncUid != null) {
      unawaited(SyncService.instance.syncNow());
    }
  }

  /// Module ids for which the user completed the non-MCQ (e.g. study) flow.
  Future<Set<String>> getRoadSignsLearnViewedModuleIds() async {
    final uid = _progressUid;
    final rows = await _isar.localRoadSignsModuleProgress
        .filter()
        .uidEqualTo(uid)
        .and()
        .contentViewedEqualTo(true)
        .findAll();
    return rows.map((e) => e.moduleId).toSet();
  }

  Future<void> markRoadSignsLearnModuleViewed(String moduleId) async {
    final uid = _progressUid;
    final syncUid = _uid;
    final mid = moduleId.trim();
    if (mid.isEmpty) return;
    final key = '$uid::$mid';
    final now = DateTime.now().toUtc();
    final opId = _uuid.v4();
    final existing = await _isar.localRoadSignsModuleProgress.filter().keyEqualTo(key).findFirst();
    final row = existing ?? LocalRoadSignsModuleProgress()
      ..key = key
      ..uid = uid
      ..moduleId = mid;
    row.contentViewed = true;
    row.updatedAt = now;
    row.synced = false;
    row.lastOpId = opId;
    await _isar.writeTxn(() async {
      await _isar.localRoadSignsModuleProgress.put(row);
    });

    if (syncUid != null) {
      await _outbox.enqueue(
        opId: opId,
        uid: syncUid,
        entityType: 'road_signs_module_progress',
        entityId: mid,
        payload: {
          'moduleId': mid,
          'contentViewed': true,
          'updatedAt': now.toIso8601String(),
        },
      );

      unawaited(SyncService.instance.syncNow());
    }
  }

  /// Returns the stored value for [settingKey] for the current user, or null.
  Future<String?> readSetting(String settingKey) async {
    final uid = _uid;
    final keyName = settingKey.trim();
    if (uid == null || keyName.isEmpty) return null;
    final key = '$uid::$keyName';
    final row = await _isar.localUserSettings.filter().keyEqualTo(key).findFirst();
    return row?.value;
  }

  Future<void> saveSetting({
    required String settingKey,
    required String value,
  }) async {
    final uid = _uid;
    final keyName = settingKey.trim();
    if (uid == null || keyName.isEmpty) return;

    final key = '$uid::$keyName';
    final opId = _uuid.v4();
    final now = DateTime.now().toUtc();

    final existing = await _isar.localUserSettings.filter().keyEqualTo(key).findFirst();
    final setting = existing ?? LocalUserSetting()
      ..key = key
      ..uid = uid
      ..settingKey = keyName;

    setting.value = value;
    setting.updatedAt = now;
    setting.synced = false;
    setting.lastOpId = opId;

    await _isar.writeTxn(() async {
      await _isar.localUserSettings.put(setting);
    });

    await _outbox.enqueue(
      opId: opId,
      uid: uid,
      entityType: 'user_setting',
      entityId: keyName,
      payload: {
        'value': value,
        'updatedAt': now.toIso8601String(),
      },
    );
  }
}
