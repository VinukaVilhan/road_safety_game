part of '../driving_game.dart';

/// [emergency_ambulance]: CP1–CP4 and CPF from Tiled (`class` CP1…CP4 / CPF, including under [Group]).
class _AmbulanceCheckpoint {
  final String id;
  final Rect rect;
  /// Seconds allowed to reach this checkpoint after the previous timed one; 0 = no limit.
  final double timeLimitSecs;

  const _AmbulanceCheckpoint({
    required this.id,
    required this.rect,
    this.timeLimitSecs = 0,
  });
}

/// `scenarioId: emergency_ambulance` — timed checkpoints, safe-zone pull-over, success layer.
extension _EmergencyAmbulanceScenario on RealisticCarGameBase {
  bool get _isEmergencyAmbulanceScenario =>
      (scenarioId ?? '').trim().toLowerCase() == 'emergency_ambulance';

  void _loadEmergencyAmbulanceCheckpointsFromTiledMap(TiledMap map) {
    _ambCheckpoints.clear();
    final ogs = <ObjectGroup>[];
    _collectObjectGroupsRecursive(map.layers, ogs);
    for (final og in ogs) {
      final cls = (og.class_ ?? '').trim().toLowerCase();
      final name = og.name.trim().toLowerCase();
      final id = cls == 'cp1' ||
              cls == 'cp2' ||
              cls == 'cp3' ||
              cls == 'cp4' ||
              cls == 'cpf'
          ? cls
          : ((name == 'cp1' ||
                  name == 'cp2' ||
                  name == 'cp3' ||
                  name == 'cp4' ||
                  name == 'cpf')
              ? name
              : '');
      if (id.isEmpty) continue;
      Rect? rect;
      double? timeFromProperty;
      for (final obj in og.objects) {
        final r = _checkpointRectFromTiledObject(obj);
        if (r != null) {
          rect = r;
          timeFromProperty = _readNumericPropertyAsDouble(obj.properties, 'timeLimitSecs') ??
              _readNumericPropertyAsDouble(og.properties, 'timeLimitSecs');
          break;
        }
      }
      if (rect == null) continue;
      final limit = timeFromProperty ??
          ((id == 'cp1' || id == 'cp2')
              ? RealisticCarGameBase._ambCpDefaultTimeLimitSecs
              : 0.0);
      _ambCheckpoints.add(
        _AmbulanceCheckpoint(id: id, rect: rect, timeLimitSecs: limit),
      );
    }
    _ambCheckpoints.sort((a, b) => a.id.compareTo(b.id));
    if (_ambCheckpoints.isNotEmpty) {
      debugPrint(
        '[DEBUG] _setupRoad() - Ambulance CP checkpoints: '
        '${_ambCheckpoints.map((c) => '${c.id}(${c.timeLimitSecs}s)').join(', ')}',
      );
    }
  }

  void _resetEmergencyAmbulanceForRestart() {
    _ambulancePullOverComplete = false;
    _ambulanceYieldCompletedLeftSide = null;
    _ambCp1Cleared = false;
    _ambCp2Cleared = false;
    _ambCpElapsed = 0.0;
    _ambTotalElapsed = 0.0;
  }

  /// Safe-zone pull-over: complete when Park + overlap matching zone + correct exclusive
  /// signal. After that, signal may be cancelled while the car stays in P in that zone.
  void _updateAmbulancePullOverState() {
    if (!_isEmergencyAmbulanceScenario || _testFinished || car == null) {
      return;
    }
    final hasZones =
        _safeZoneLeftRects.isNotEmpty || _safeZoneRightRects.isNotEmpty;
    if (!hasZones) return;
    if (turnSignalLeft == null || turnSignalRight == null) return;

    final c = car!;
    final carRect = Rect.fromCenter(
      center: Offset(c.position.x, c.position.y),
      width: c.size.x,
      height: c.size.y,
    );
    final inLeft = _safeZoneLeftRects.any((r) => carRect.overlaps(r));
    final inRight = _safeZoneRightRects.any((r) => carRect.overlaps(r));
    final exclusiveLeft = turnSignalLeft!.value && !turnSignalRight!.value;
    final exclusiveRight = turnSignalRight!.value && !turnSignalLeft!.value;

    if (_ambulancePullOverComplete) {
      final wantLeft = _ambulanceYieldCompletedLeftSide == true;
      final inOkZone = wantLeft ? inLeft : inRight;
      if (!c.isInPark || !inOkZone) {
        _ambulancePullOverComplete = false;
        _ambulanceYieldCompletedLeftSide = null;
      }
      return;
    }

    if (c.isInPark && inLeft && exclusiveLeft) {
      _ambulancePullOverComplete = true;
      _ambulanceYieldCompletedLeftSide = true;
    } else if (c.isInPark && inRight && exclusiveRight) {
      _ambulancePullOverComplete = true;
      _ambulanceYieldCompletedLeftSide = false;
    }
  }

  void _updateAmbulanceCheckpoints(double dt) {
    if (!_isEmergencyAmbulanceScenario || _testFinished || car == null) {
      return;
    }
    if (_ambCheckpoints.isEmpty) return;

    _AmbulanceCheckpoint? cp(String id) {
      for (final c in _ambCheckpoints) {
        if (c.id == id) return c;
      }
      return null;
    }

    final cp1 = cp('cp1');
    final cp2 = cp('cp2');
    final cpf = cp('cpf');
    if (cp1 == null) _ambCp1Cleared = true;
    if (cp2 == null) _ambCp2Cleared = true;

    _ambTotalElapsed += dt;
    if (_ambTotalElapsed > RealisticCarGameBase._ambLevelTimeoutSecs) {
      _failTest('Time limit exceeded.');
      return;
    }

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    bool carOverlaps(Rect r) => carRect.overlaps(r);

    if (!_ambCp1Cleared && cp1 != null) {
      _ambCpElapsed += dt;
      if (carOverlaps(cp1.rect)) {
        _ambCp1Cleared = true;
        _ambCpElapsed = 0;
      } else if (cp1.timeLimitSecs > 0 && _ambCpElapsed > cp1.timeLimitSecs) {
        _failTest('Too slow — missed Checkpoint 1.');
      }
      return;
    }

    if (!_ambCp2Cleared && cp2 != null) {
      _ambCpElapsed += dt;
      if (carOverlaps(cp2.rect)) {
        _ambCp2Cleared = true;
        _ambCpElapsed = 0;
      } else if (cp2.timeLimitSecs > 0 && _ambCpElapsed > cp2.timeLimitSecs) {
        _failTest('Too slow — missed Checkpoint 2.');
      }
      return;
    }

    if (_ambCp2Cleared &&
        !_ambulancePullOverComplete &&
        cpf != null &&
        carOverlaps(cpf.rect)) {
      _failTest(
        'You must park in a safe zone with the correct signal between Checkpoint 2 and the final checkpoint.',
      );
      return;
    }
  }

  /// When the ambulance overlaps [Success_Layer], pass if the player has yielded correctly
  /// (pull-over completed; may have cancelled indicators after parking).
  void _updateAmbulanceLevelSuccess() {
    if (_testFinished || car == null) return;
    if (!_isEmergencyAmbulanceScenario) return;
    if (_successLayerRects.isEmpty) return;
    final deco = _ambulanceDecoration;
    if (deco == null) return;

    if (!playerYieldedForAmbulance()) return;

    final ambRect = Rect.fromCenter(
      center: Offset(deco.position.x, deco.position.y),
      width: deco.size.x,
      height: deco.size.y,
    );
    for (final r in _successLayerRects) {
      if (!ambRect.overlaps(r)) continue;
      _reachedFinishZone = true;
      _testFinished = true;
      car!.coast();
      onTestPassed?.call();
      return;
    }
  }

  AmbulanceAttemptSnapshot? _buildAmbulanceAttemptSnapshot() {
    if (!_isEmergencyAmbulanceScenario) return null;

    _AmbulanceCheckpoint? acp(String id) {
      for (final c in _ambCheckpoints) {
        if (c.id == id) return c;
      }
      return null;
    }

    final cp1 = acp('cp1');
    final cp2 = acp('cp2');
    final cpf = acp('cpf');
    final deco = _ambulanceDecoration;
    return AmbulanceAttemptSnapshot(
      mapHasCp1: cp1 != null,
      mapHasCp2: cp2 != null,
      mapHasCpf: cpf != null,
      cp1Cleared: _ambCp1Cleared,
      cp2Cleared: _ambCp2Cleared,
      pullOverCompleted: _ambulancePullOverComplete,
      yieldLeftSide: _ambulanceYieldCompletedLeftSide,
      elapsedSecs: _ambTotalElapsed,
      levelTimeoutSecs: RealisticCarGameBase._ambLevelTimeoutSecs,
      cp1TimeLimitSecs: cp1?.timeLimitSecs ?? 0,
      cp2TimeLimitSecs: cp2?.timeLimitSecs ?? 0,
      ambulanceRouteCompleted: deco?.routeCompleted ?? false,
      ambulanceAiState: deco == null ? 'none' : deco.state.name,
    );
  }
}
