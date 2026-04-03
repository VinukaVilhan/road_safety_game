import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/repositories/progress_repository.dart';
import '../data/sync/sync_service.dart';
import 'driving_levels_service.dart';

class LevelProgressService {
  static const String _logName = 'LevelProgressService';

  static bool _migrationAttempted = false;
  static const Set<String> _tJunctionLevelIds = {
    'junctions_t_left',
    'junctions_t_right',
  };

  static Future<Set<String>> getCompletedLevelIds() async {
    await _migrateLegacyTjunctionProgressIfNeeded();
    final localIds = await ProgressRepository.instance.getCompletedLevelIds();
    final remoteIds = await _getRemoteCompletedLevelIds();
    return {
      ...localIds,
      ...remoteIds,
    };
  }

  static Future<void> markLevelCompleted(String levelId, {String? moduleId}) async {
    await ProgressRepository.instance.markLevelCompleted(levelId, moduleId: moduleId);
  }

  /// Writes all locally completed levels (Isar) to Firestore for the signed-in user.
  /// Uses the same paths as [FirestoreApi]: legacy `level_progress` plus optional
  /// `modules/{moduleId}/level_progress` when the level defines [GameLevel.moduleId].
  static Future<void> uploadLocalCompletedLevelsToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      developer.log(
        'uploadLocalCompletedLevelsToFirestore: skipped (no signed-in user)',
        name: _logName,
      );
      return;
    }

    final localIds = await ProgressRepository.instance.getCompletedLevelIds();
    if (localIds.isEmpty) {
      developer.log(
        'uploadLocalCompletedLevelsToFirestore: skipped (no completed levels in local DB for uid=${user.uid})',
        name: _logName,
      );
      return;
    }

    developer.log(
      'uploadLocalCompletedLevelsToFirestore: uploading ${localIds.length} level(s): ${localIds.join(", ")}',
      name: _logName,
    );

    final idToModule = {
      for (final l in DrivingLevelsService.getAllLevels())
        if (l.moduleId != null && l.moduleId!.trim().isNotEmpty) l.id: l.moduleId!.trim(),
    };

    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(user.uid);

    const maxBatchOps = 450;
    var batch = firestore.batch();
    var ops = 0;

    Future<void> commitIfFull() async {
      if (ops < maxBatchOps) return;
      await batch.commit();
      batch = firestore.batch();
      ops = 0;
    }

    try {
      for (final levelId in localIds) {
        final moduleId = idToModule[levelId];
        final baseData = <String, dynamic>{
          'completed': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'syncedAt': FieldValue.serverTimestamp(),
          'source': 'device_upload',
        };

        if (moduleId != null) {
          final moduleRef = userDoc
              .collection('modules')
              .doc(moduleId)
              .collection('level_progress')
              .doc(levelId);
          batch.set(
            moduleRef,
            {...baseData, 'moduleId': moduleId},
            SetOptions(merge: true),
          );
          ops++;
          await commitIfFull();
        }

        final legacyRef = userDoc.collection('level_progress').doc(levelId);
        batch.set(
          legacyRef,
          {
            ...baseData,
            if (moduleId != null) 'moduleId': moduleId,
          },
          SetOptions(merge: true),
        );
        ops++;
        await commitIfFull();
      }

      if (ops > 0) {
        await batch.commit();
      }

      await SyncService.instance.syncNow();
      developer.log(
        'uploadLocalCompletedLevelsToFirestore: success (batch committed, syncNow called)',
        name: _logName,
      );
    } catch (e, st) {
      developer.log(
        'uploadLocalCompletedLevelsToFirestore: FAILED',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<Set<String>> _getRemoteCompletedLevelIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return <String>{};

    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(user.uid);
    final completed = <String>{};

    try {
      // Legacy schema fallback: users/{uid}/level_progress/{levelId}
      final legacySnapshot =
          await userDoc.collection('level_progress').where('completed', isEqualTo: true).get();
      for (final doc in legacySnapshot.docs) {
        final id = doc.id.trim();
        if (id.isNotEmpty) completed.add(id);
      }

      // Module schema: users/{uid}/modules/{moduleId}/level_progress/{levelId}
      final modulesSnapshot = await userDoc.collection('modules').get();
      for (final moduleDoc in modulesSnapshot.docs) {
        final moduleProgress = await moduleDoc.reference
            .collection('level_progress')
            .where('completed', isEqualTo: true)
            .get();
        for (final doc in moduleProgress.docs) {
          final id = doc.id.trim();
          if (id.isNotEmpty) completed.add(id);
        }
      }
    } catch (e, st) {
      developer.log(
        '_getRemoteCompletedLevelIds: failed (unlock will use local progress only)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }

    return completed;
  }

  static Future<void> _migrateLegacyTjunctionProgressIfNeeded() async {
    if (_migrationAttempted) return;
    _migrationAttempted = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection('users').doc(user.uid);

    try {
      final legacySnapshot =
          await userDoc.collection('level_progress').where('completed', isEqualTo: true).get();

      for (final doc in legacySnapshot.docs) {
        final levelId = doc.id.trim();
        if (!_tJunctionLevelIds.contains(levelId)) continue;

        final moduleRef = userDoc
            .collection('modules')
            .doc('t_junction')
            .collection('level_progress')
            .doc(levelId);

        final existingModuleDoc = await moduleRef.get();
        if (existingModuleDoc.exists) continue;

        final data = Map<String, dynamic>.from(doc.data());
        data['moduleId'] = 't_junction';
        data['migratedFrom'] = 'level_progress';
        data['migratedAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();

        await moduleRef.set(data, SetOptions(merge: true));
      }
    } catch (e, st) {
      developer.log(
        '_migrateLegacyTjunctionProgressIfNeeded: failed',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }
}
