part of '../driving_game.dart';

/// Maps with `Ambulance_Spawn` / `Ambulance_Route` (e.g. [ambulance-reaction.tmx]):
/// decoration AI, siren audio, and yield rules for the [Ambulance] entity.
extension _AmbulanceDecorationScenario on RealisticCarGameBase {
  /// Layer name `Ambulance_Route` and/or class `AmbulanceRoute`.
  void _loadAmbulanceRouteFromTmx(TiledComponent tiledMap) {
    _ambulanceRouteWaypoints.clear();
    for (final layer in tiledMap.tileMap.map.layers.whereType<ObjectGroup>()) {
      final nameNorm = layer.name.replaceAll(' ', '_').toLowerCase();
      final classNorm = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase();
      if (nameNorm != 'ambulance_route' && classNorm != 'ambulanceroute') {
        continue;
      }
      for (final obj in layer.objects) {
        if (!obj.visible) continue;
        final origin = Vector2(obj.x, obj.y);
        if (obj.isPolygon && obj.polygon.isNotEmpty) {
          final pts = obj.polygon;
          // Closed polygon in TMX: first 5 vertices trace the forward drive path.
          final n = pts.length >= 5 ? 5 : pts.length;
          for (var i = 0; i < n; i++) {
            final p = pts[i];
            _ambulanceRouteWaypoints.add(origin + Vector2(p.x, p.y));
          }
        } else if (obj.isPolyline && obj.polyline.isNotEmpty) {
          for (final p in obj.polyline) {
            _ambulanceRouteWaypoints.add(origin + Vector2(p.x, p.y));
          }
        }
      }
    }
    if (_ambulanceRouteWaypoints.isNotEmpty) {
      print(
        '[DEBUG] _setupRoad() - Ambulance route waypoints: ${_ambulanceRouteWaypoints.length}',
      );
    }
  }

  void _loadAmbulanceDecorationMapData(Iterable<ObjectGroup> objectGroupLayers) {
    _collectSirenTriggerRects(objectGroupLayers, _sirenTriggerRects);
    if (_sirenTriggerRects.isNotEmpty) {
      print(
        '[DEBUG] _setupRoad() - Siren_Layer: ${_sirenTriggerRects.length} trigger rect(s); '
        'ambulance will appear when the player enters one.',
      );
    }
    _collectEmergencyScenarioRects(
      objectGroupLayers,
      outLeft: _safeZoneLeftRects,
      outRight: _safeZoneRightRects,
      outSuccess: _successLayerRects,
    );
    if (_safeZoneLeftRects.isNotEmpty ||
        _safeZoneRightRects.isNotEmpty ||
        _successLayerRects.isNotEmpty) {
      print(
        '[DEBUG] _setupRoad() - Emergency pull-over / success rects: '
        'left=${_safeZoneLeftRects.length} right=${_safeZoneRightRects.length} '
        'success=${_successLayerRects.length}',
      );
    }
  }

  /// Draws an ambulance at `Ambulance_Spawn`. If the map has [Siren_Layer] trigger rects,
  /// the sprite (and siren) appear only after the player's car overlaps a trigger.
  Future<void> _setupAmbulanceDecorationFromTmx(
    Iterable<ObjectGroup> objectLayers,
  ) async {
    _ambulanceSpawnConfig = _readAmbulanceSpawnConfig(objectLayers);
    if (_ambulanceSpawnConfig == null) return;

    if (_sirenTriggerRects.isNotEmpty) {
      print(
        '[DEBUG] _setupRoad() - Ambulance spawn deferred until Siren_Layer overlap '
        'at ${_ambulanceSpawnConfig!.position}',
      );
      return;
    }

    print(
      '[DEBUG] _setupRoad() - Ambulance will spawn when player car is ready '
      '(no Siren_Layer).',
    );
  }

  Future<void> _placeAmbulanceDecoration(
    ({Vector2 position, double angle, double sirenVolume}) cfg,
  ) async {
    if (_ambulanceDecoration != null) return;
    final player = car;
    if (player == null) return;

    final sprite = await _loadAmbulanceSpriteForLevel();

    _ambulanceDecoration?.removeFromParent();
    final deco = Ambulance(
      sprite: sprite,
      player: player,
      routeWaypoints: List<Vector2>.from(_ambulanceRouteWaypoints),
      position: cfg.position,
      size: Vector2(52, 78),
      anchor: Anchor.center,
      angle: cfg.angle,
      priority: 0,
    );
    if (_ambulanceRouteWaypoints.isNotEmpty) {
      final toFirstWP = _ambulanceRouteWaypoints.first - cfg.position;
      if (toFirstWP.length > 1) {
        deco.angle = math.atan2(toFirstWP.y, toFirstWP.x) + math.pi / 2;
      }
    }
    _ambulanceDecoration = deco;
    world.add(deco);
    print(
      '[DEBUG] Ambulance AI at ${cfg.position} '
      'angle=${deco.angle * 180 / math.pi}° waypoints=${_ambulanceRouteWaypoints.length}',
    );
    await _startAmbulanceSiren(cfg.sirenVolume);
  }

  /// [_setupRoad] runs before [car] exists on first load; place ambulance when both are ready.
  void _maybePlaceDeferredAmbulanceDecoration() {
    if (_testFinished) return;
    if (_ambulanceDecoration != null || _ambulanceSpawnConfig == null || car == null) {
      return;
    }
    if (_sirenTriggerRects.isNotEmpty) return;
    unawaited(_placeAmbulanceDecoration(_ambulanceSpawnConfig!));
  }

  Future<void> _stopAmbulanceSiren() async {
    final p = _ambulanceSirenPlayer;
    _ambulanceSirenPlayer = null;
    if (p == null) return;
    try {
      await p.stop();
    } catch (_) {}
    try {
      await p.dispose();
    } catch (_) {}
  }

  Future<void> _startAmbulanceSiren(double volume) async {
    await _stopAmbulanceSiren();
    try {
      final v = (volume * RealisticCarGameBase._ambulanceSirenMasterGain).clamp(0.0, 1.0);
      _ambulanceSirenPlayer = await FlameAudio.loop(
        MediaAssets.ambulanceSiren,
        volume: v,
      );
    } catch (e, st) {
      debugPrint(
        'Ambulance loop failed (add assets/audio/${MediaAssets.ambulanceSiren}): $e\n$st',
      );
    }
  }

  void _updateAmbulanceSirenTrigger() {
    if (_testFinished || car == null) return;
    if (_ambulanceSirenRevealDone) return;
    if (_ambulanceSpawnConfig == null || _sirenTriggerRects.isEmpty) return;
    if (_ambulanceDecoration != null) return;

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    for (final r in _sirenTriggerRects) {
      if (!carRect.overlaps(r)) continue;
      _ambulanceSirenRevealDone = true;
      unawaited(_revealAmbulanceAndPlaySiren(_ambulanceSpawnConfig!));
      break;
    }
  }

  Future<void> _revealAmbulanceAndPlaySiren(
    ({Vector2 position, double angle, double sirenVolume}) cfg,
  ) async {
    await _placeAmbulanceDecoration(cfg);
  }

  void _resetAmbulanceDecorationForRestart() {
    _ambulanceDecoration?.removeFromParent();
    _ambulanceDecoration = null;
    _ambulanceSirenRevealDone = false;
    unawaited(_stopAmbulanceSiren());
    if (_ambulanceSpawnConfig != null && _sirenTriggerRects.isEmpty) {
      unawaited(_placeAmbulanceDecoration(_ambulanceSpawnConfig!));
    }
  }

  void _disposeAmbulanceDecoration() {
    _ambulanceDecoration?.removeFromParent();
    _ambulanceDecoration = null;
    unawaited(_stopAmbulanceSiren());
  }

  void _resumeAmbulanceSirenIfPaused() {
    final siren = _ambulanceSirenPlayer;
    if (siren != null && siren.state == PlayerState.paused) {
      unawaited(siren.resume());
    }
  }

  /// True when the car's axis-aligned bounds overlap any of [rects] (ignores rotation).
  bool _isCarAabbInsideAnyRect(Iterable<Rect> rects) {
    final c = car;
    if (c == null) return false;
    final carRect = Rect.fromCenter(
      center: Offset(c.position.x, c.position.y),
      width: c.size.x,
      height: c.size.y,
    );
    for (final r in rects) {
      if (carRect.overlaps(r)) return true;
    }
    return false;
  }

  /// Ambulance may pass when the player is slow enough and has yielded: either a valid
  /// pull-over (see [_updateAmbulancePullOverState]) with signal optional after parking,
  /// or—if the map has no safe zones—the legacy rule (correct signal on only).
  bool playerYieldedForAmbulance() {
    final c = car;
    if (c == null || turnSignalLeft == null || turnSignalRight == null) {
      return false;
    }
    if (c.velocity.length >= 10) return false;
    final hasZones =
        _safeZoneLeftRects.isNotEmpty || _safeZoneRightRects.isNotEmpty;
    if (!hasZones) {
      final leftOn = turnSignalLeft!.value;
      final rightOn = turnSignalRight!.value;
      return (leftOn && !rightOn) || (rightOn && !leftOn);
    }
    if (!_ambulancePullOverComplete) return false;
    if (!c.isInPark) return false;
    if (_ambulanceYieldCompletedLeftSide == true) {
      return _isCarAabbInsideAnyRect(_safeZoneLeftRects);
    }
    if (_ambulanceYieldCompletedLeftSide == false) {
      return _isCarAabbInsideAnyRect(_safeZoneRightRects);
    }
    return false;
  }
}
