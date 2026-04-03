import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreApi {
  FirestoreApi(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> applyOutboxOperation({
    required String uid,
    required String entityType,
    required String entityId,
    required String opId,
    required String payloadJson,
  }) async {
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    final userDoc = _firestore.collection('users').doc(uid);

    switch (entityType) {
      case 'level_progress':
        final moduleId = (payload['moduleId'] as String?)?.trim();
        final levelPayload = {
          ...payload,
          'opId': opId,
          'syncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (moduleId != null && moduleId.isNotEmpty) {
          // New schema: keep T-junction level progress under module scope.
          await userDoc
              .collection('modules')
              .doc(moduleId)
              .collection('level_progress')
              .doc(entityId)
              .set(levelPayload, SetOptions(merge: true));
        }

        // Keep legacy path updated for backward compatibility/migration.
        await userDoc.collection('level_progress').doc(entityId).set(
              levelPayload,
              SetOptions(merge: true),
            );
        return;
      case 'theory_test_progress':
        await userDoc.collection('theory_test_progress').doc(entityId).set({
          ...payload,
          'opId': opId,
          'syncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case 'theory_attempt':
        await userDoc.collection('theory_attempts').doc(entityId).set({
          ...payload,
          'opId': opId,
          'syncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      case 'user_setting':
        await userDoc.collection('settings').doc(entityId).set({
          ...payload,
          'opId': opId,
          'syncedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      default:
        throw UnsupportedError('Unknown entityType: $entityType');
    }
  }
}
