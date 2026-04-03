import 'dart:convert';

import 'package:isar/isar.dart';

import '../local/isar_schemas.dart';

class SyncOutbox {
  SyncOutbox(this._isar);

  final Isar _isar;

  Future<void> enqueue({
    required String opId,
    required String uid,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final item = SyncOutboxItem()
      ..opId = opId
      ..uid = uid
      ..entityType = entityType
      ..entityId = entityId
      ..payloadJson = jsonEncode(payload)
      ..createdAt = DateTime.now().toUtc()
      ..updatedAt = DateTime.now().toUtc()
      ..status = SyncOutboxStatus.pending
      ..retryCount = 0
      ..nextRetryAt = null
      ..lastError = null;

    await _isar.writeTxn(() async {
      await _isar.syncOutboxItems.put(item);
    });
  }

  Future<List<SyncOutboxItem>> pendingForUser(String uid, {int limit = 50}) async {
    final now = DateTime.now().toUtc();
    final all = await _isar.syncOutboxItems
        .filter()
        .uidEqualTo(uid)
        .and()
        .group((q) => q
            .statusEqualTo(SyncOutboxStatus.pending)
            .or()
            .statusEqualTo(SyncOutboxStatus.failed))
        .sortByCreatedAt()
        .findAll();
    return all
        .where((item) => item.nextRetryAt == null || !item.nextRetryAt!.isAfter(now))
        .take(limit)
        .toList();
  }
}
