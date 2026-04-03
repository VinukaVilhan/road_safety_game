import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/repositories/progress_repository.dart';

class LevelProgressService {
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
    } catch (_) {
      // Keep unlock logic resilient when remote fetch fails.
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
    } catch (_) {
      // Ignore migration failures; unlock reads still work via fallback paths.
    }
  }
}
