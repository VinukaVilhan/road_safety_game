import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';

import '../local/isar_schemas.dart';
import '../local/local_db.dart';
import '../remote/firestore_api.dart';
import 'sync_outbox.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  late final FirestoreApi _firestoreApi;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _initialized = false;
  bool _syncing = false;
  String? _currentUid;

  Future<void> initialize() async {
    if (_initialized) return;
    _firestoreApi = FirestoreApi(FirebaseFirestore.instance);
    _currentUid = _auth.currentUser?.uid;
    _authSub = _auth.authStateChanges().listen((user) {
      _currentUid = user?.uid;
      unawaited(syncNow());
    });
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(syncNow());
    });
    _initialized = true;
    await syncNow();
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _connectivitySub?.cancel();
    _initialized = false;
  }

  Future<void> syncNow() async {
    if (!_initialized || _syncing) return;
    final uid = _currentUid;
    if (uid == null) return;

    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) return;

    _syncing = true;
    try {
      await _flushPending(uid);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _flushPending(String uid) async {
    final isar = LocalDb.instance.isar;
    final outbox = SyncOutbox(isar);
    final items = await outbox.pendingForUser(uid);
    for (final item in items) {
      await isar.writeTxn(() async {
        item.status = SyncOutboxStatus.processing;
        item.updatedAt = DateTime.now().toUtc();
        await isar.syncOutboxItems.put(item);
      });

      try {
        await _firestoreApi.applyOutboxOperation(
          uid: uid,
          entityType: item.entityType,
          entityId: item.entityId,
          opId: item.opId,
          payloadJson: item.payloadJson,
        );
        await _markEntitySynced(isar, uid, item);
        await isar.writeTxn(() async {
          item.status = SyncOutboxStatus.synced;
          item.nextRetryAt = null;
          item.lastError = null;
          item.updatedAt = DateTime.now().toUtc();
          await isar.syncOutboxItems.put(item);
        });
      } catch (e) {
        final retries = item.retryCount + 1;
        final waitSeconds = retries <= 5 ? retries * 4 : 30;
        await isar.writeTxn(() async {
          item.status = SyncOutboxStatus.failed;
          item.retryCount = retries;
          item.lastError = e.toString();
          item.nextRetryAt = DateTime.now().toUtc().add(Duration(seconds: waitSeconds));
          item.updatedAt = DateTime.now().toUtc();
          await isar.syncOutboxItems.put(item);
        });
      }
    }
  }

  Future<void> _markEntitySynced(Isar isar, String uid, SyncOutboxItem item) async {
    await isar.writeTxn(() async {
      switch (item.entityType) {
        case 'level_progress':
          final key = '$uid::${item.entityId}';
          final row = await isar.localLevelProgress.filter().keyEqualTo(key).findFirst();
          if (row != null) {
            row.synced = true;
            await isar.localLevelProgress.put(row);
          }
          return;
        case 'theory_test_progress':
          final key = '$uid::${item.entityId}';
          final row = await isar.localTheoryTestProgress.filter().keyEqualTo(key).findFirst();
          if (row != null) {
            row.synced = true;
            await isar.localTheoryTestProgress.put(row);
          }
          return;
        case 'theory_attempt':
          final row = await isar.localTheoryAttempts.filter().attemptIdEqualTo(item.entityId).findFirst();
          if (row != null) {
            row.synced = true;
            await isar.localTheoryAttempts.put(row);
          }
          return;
        case 'user_setting':
          final key = '$uid::${item.entityId}';
          final row = await isar.localUserSettings.filter().keyEqualTo(key).findFirst();
          if (row != null) {
            row.synced = true;
            await isar.localUserSettings.put(row);
          }
          return;
      }
    });
  }
}
