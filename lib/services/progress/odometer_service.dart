import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/local_db.dart';
import '../../data/sync/sync_outbox.dart';
import '../../data/sync/sync_service.dart';

/// Tracks cumulative driving distance (approximate miles), persisted locally and
/// synced to Firestore via the outbox (`users/{uid}/stats/driving.totalMeters`).
class OdometerService {
  OdometerService._();
  static final OdometerService instance = OdometerService._();

  static const _prefsKeyPrefix = 'total_driven_meters_v2_';
  static const _metersPerMile = 1609.344;

  /// In-memory session delta not yet written to prefs / outbox.
  double _sessionPendingMeters = 0;

  /// Updated after merge, flush, or [refreshDisplayMiles].
  final ValueNotifier<double> totalMiles = ValueNotifier<double>(0);

  String _prefsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return '$_prefsKeyPrefix${uid ?? 'guest'}';
  }

  Future<double> _readLocalMeters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_prefsKey()) ?? 0.0;
  }

  Future<void> _writeLocalMeters(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey(), value);
  }

  /// Call when the car moves in-game ([deltaMeters] from world travel scale).
  void recordSessionDelta(double deltaMeters) {
    if (deltaMeters <= 0 || deltaMeters.isNaN || deltaMeters.isInfinite) return;
    _sessionPendingMeters += deltaMeters;
  }

  /// Writes pending session distance to disk and enqueues a Firestore increment when signed in.
  Future<void> flushPendingToPersistence() async {
    final delta = _sessionPendingMeters;
    if (delta <= 0) return;
    _sessionPendingMeters = 0;

    final cur = await _readLocalMeters();
    final next = cur + delta;
    await _writeLocalMeters(next);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      final opId = const Uuid().v4();
      await SyncOutbox(LocalDb.instance.isar).enqueue(
        opId: opId,
        uid: uid,
        entityType: 'odometer_increment',
        entityId: 'driving',
        payload: {'deltaMeters': delta},
      );
      unawaited(SyncService.instance.syncNow());
    }

    totalMiles.value = next / _metersPerMile;
  }

  /// If the server total is higher (e.g. another device), adopt it locally.
  Future<void> mergeFromFirestoreIfSignedIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stats')
          .doc('driving')
          .get();
      if (!doc.exists) return;
      final remote = (doc.data()?['totalMeters'] as num?)?.toDouble();
      if (remote == null || remote.isNaN) return;
      final local = await _readLocalMeters();
      if (remote > local) {
        await _writeLocalMeters(remote);
      }
    } catch (_) {
      // Offline / rules
    }
  }

  /// Loads local (+ optional remote merge), folds guest distance into the signed-in key once,
  /// and updates [totalMiles].
  Future<void> refreshDisplayMiles() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      final guestKey = '${_prefsKeyPrefix}guest';
      final userKey = '${_prefsKeyPrefix}$uid';
      final guestM = prefs.getDouble(guestKey) ?? 0.0;
      if (guestM > 0) {
        final userM = prefs.getDouble(userKey) ?? 0.0;
        await prefs.setDouble(userKey, userM + guestM);
        await prefs.remove(guestKey);
        final opId = const Uuid().v4();
        await SyncOutbox(LocalDb.instance.isar).enqueue(
          opId: opId,
          uid: uid,
          entityType: 'odometer_increment',
          entityId: 'driving',
          payload: {'deltaMeters': guestM},
        );
        unawaited(SyncService.instance.syncNow());
      }
    }
    await mergeFromFirestoreIfSignedIn();
    final m = await _readLocalMeters();
    totalMiles.value = m / _metersPerMile;
  }
}
