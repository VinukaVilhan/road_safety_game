part of '../driving_game.dart';

extension RoadCrossingZones on RealisticCarGameBase {
  /// Asset path for the HUD sign shown after [Spawn_Sign] zone entry.
  String get spawnSignAssetPath => _spawnSignAssetPath;

  /// [road-crossing.tmx]: countdown runs only inside a Zig_Zag (grey) wait zone
  /// while the car is **fully stopped** (stay in gear — no Park in zig-zags).
  void _updateRoadCrossingParkCountdown(double dt) {
    if (!_isRoadCrossingMap() || _testFinished || car == null) return;

    int? stepFromZone;
    _DrivingZone? activeWaitZone;
    var allWheelsInWaitZone = false;
    for (final zone in _drivingZones) {
      final zoneKind = _zoneKindForScenario(zone.zoneClass);
      if (zoneKind != 'zig_zag') continue;
      if (!_areAllWheelsInsideRect(zone.rect)) continue;
      allWheelsInWaitZone = true;
      activeWaitZone ??= zone;
      stepFromZone ??= zone.stepId;
    }

    final stoppedInZone = allWheelsInWaitZone &&
        !car!.isInPark &&
        car!.velocity.length < RealisticCarGameBase._zigZagStoppedSpeedThreshold;
    final waitDurationSec =
        activeWaitZone?.waitTimeSec ?? RealisticCarGameBase._roadCrossingStopDurationSec;

    if (stoppedInZone && !_roadCrossingStopSatisfied) {
      if (!_roadCrossingStopActive) {
        _roadCrossingStopActive = true;
        _roadCrossingStopElapsed = 0.0;
        _roadCrossingStopStepId = stepFromZone;
        _activeRoadCrossingWaitZone = activeWaitZone;
        roadCrossingCountdown.value = waitDurationSec.ceil();
        car!.coast();
      }
    } else {
      if (_roadCrossingStopActive) {
        _roadCrossingStopActive = false;
        _roadCrossingStopElapsed = 0.0;
        _activeRoadCrossingWaitZone = null;
        roadCrossingCountdown.value = null;
      }
    }

    if (!_roadCrossingStopActive) return;

    _roadCrossingStopElapsed += dt;
    final activeWaitSec =
        _activeRoadCrossingWaitZone?.waitTimeSec ?? waitDurationSec;
    final remaining = (activeWaitSec - _roadCrossingStopElapsed)
        .clamp(0.0, activeWaitSec);
    final countdown = remaining <= 0 ? 0 : remaining.ceil();
    if (roadCrossingCountdown.value != countdown) {
      roadCrossingCountdown.value = countdown;
    }
    if (_roadCrossingStopElapsed < activeWaitSec) return;

    _roadCrossingStopActive = false;
    _roadCrossingStopSatisfied = true;
    _activeRoadCrossingWaitZone = null;
    roadCrossingCountdown.value = null;
    if (_roadCrossingStopSatisfied) {
      if (_roadCrossingStopStepId != null &&
          _roadCrossingStopStepId! == _lastCompletedStepId + 1) {
        _lastCompletedStepId = _roadCrossingStopStepId!;
      } else if (_lastCompletedStepId == 0) {
        _lastCompletedStepId = 1;
      }
    }
  }

  bool _isRoadCrossingMap() {
    final asset = mapAsset?.toLowerCase() ?? '';
    return asset.contains('road_crossing');
  }

  bool _isSpawnSignLabel(String raw) {
    final v = raw.trim().toLowerCase().replaceAll(' ', '_');
    return v == 'spawn_sign' || v.contains('spawn_sign');
  }

  bool _isRemoveSignLabel(String raw) {
    final v = raw.trim().toLowerCase().replaceAll(' ', '_');
    return v == 'remove_sign' || v.contains('remove_sign');
  }

  void _loadRoadCrossingSignHudZones(TiledComponent tiledMap) {
    _spawnSignRects.clear();
    _removeSignRects.clear();
    _spawnSignAssetPath = MediaAssets.pedestrianCrossingSign;

    for (final layer in tiledMap.tileMap.map.layers.whereType<ObjectGroup>()) {
      final layerClassLower = (layer.class_ ?? '').trim().toLowerCase();
      final layerNameLower = layer.name.trim().toLowerCase();
      final layerIsSpawnSign = _isSpawnSignLabel(layerClassLower) ||
          _isSpawnSignLabel(layerNameLower);
      final layerIsRemoveSign = _isRemoveSignLabel(layerClassLower) ||
          _isRemoveSignLabel(layerNameLower);

      if (layerIsSpawnSign) {
        final customAsset = layer.properties.getValue<String>('sign_asset') ??
            layer.properties.getValue<String>('sign_image');
        if (customAsset != null && customAsset.trim().isNotEmpty) {
          _spawnSignAssetPath = customAsset.trim();
        }
      }

      for (final obj in layer.objects) {
        if (!obj.visible || obj.width <= 0 || obj.height <= 0) continue;
        if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) {
          continue;
        }
        if (obj.rotation != 0) continue;

        final objectClass = obj.class_.trim().toLowerCase();
        final objectType = obj.type.trim().toLowerCase();
        final objectName = obj.name.trim().toLowerCase();
        final rect = Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height);

        final isSpawnObject = layerIsSpawnSign ||
            _isSpawnSignLabel(objectClass) ||
            _isSpawnSignLabel(objectType) ||
            _isSpawnSignLabel(objectName);
        if (isSpawnObject) {
          _spawnSignRects.add(rect);
          continue;
        }

        final isRemoveObject = layerIsRemoveSign ||
            _isRemoveSignLabel(objectClass) ||
            _isRemoveSignLabel(objectType) ||
            _isRemoveSignLabel(objectName);
        if (isRemoveObject) {
          _removeSignRects.add(rect);
        }
      }
    }
    print(
      '[DEBUG] _setupRoad() - Spawn sign rects: ${_spawnSignRects.length} '
      'remove sign rects: ${_removeSignRects.length} asset=$_spawnSignAssetPath',
    );
  }

  void _updatePedestrianCrossingSignHud() {
    if (!_isRoadCrossingMap() || _testFinished || car == null) {
      if (pedestrianCrossingSignVisible.value) {
        pedestrianCrossingSignVisible.value = false;
      }
      if (pedestrianCrossingDistanceMeters.value != null) {
        pedestrianCrossingDistanceMeters.value = null;
      }
      return;
    }

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );

    if (pedestrianCrossingSignVisible.value && _removeSignRects.isNotEmpty) {
      for (final rect in _removeSignRects) {
        if (!carRect.overlaps(rect)) continue;
        pedestrianCrossingSignVisible.value = false;
        pedestrianCrossingDistanceMeters.value = null;
        return;
      }
    }

    if (!pedestrianCrossingSignVisible.value && _spawnSignRects.isNotEmpty) {
      for (final rect in _spawnSignRects) {
        if (!carRect.overlaps(rect)) continue;
        pedestrianCrossingSignVisible.value = true;
        break;
      }
    }

    if (!pedestrianCrossingSignVisible.value) return;

    if (_anyWheelInZigZagZone()) {
      if (pedestrianCrossingDistanceMeters.value != null) {
        pedestrianCrossingDistanceMeters.value = null;
      }
      return;
    }

    final meters = _distanceToPedestrianCrossingMeters();
    if (pedestrianCrossingDistanceMeters.value != meters) {
      pedestrianCrossingDistanceMeters.value = meters;
    }
  }

  int? _distanceToPedestrianCrossingMeters() {
    final c = car;
    if (c == null) return null;

    final carCenter = Offset(c.position.x, c.position.y);
    double? nearestDistance;
    for (final zone in _drivingZones) {
      if (_zoneKindForScenario(zone.zoneClass) != 'zig_zag') continue;
      final d = _distancePointToRect(carCenter, zone.rect);
      if (nearestDistance == null || d < nearestDistance) {
        nearestDistance = d;
      }
    }
    if (nearestDistance == null) return null;
    return (nearestDistance / 10).clamp(1, 999).toInt();
  }

  bool _anyWheelInZigZagZone() {
    for (final zone in _drivingZones) {
      if (_zoneKindForScenario(zone.zoneClass) != 'zig_zag') continue;
      if (_anyWheelInsideRect(zone.rect)) return true;
    }
    return false;
  }

  /// Blocks Park while any wheel is in a zig-zag (road-crossing maps).
  String? roadCrossingGearBlockReason(String gearLabel) {
    if (!_isRoadCrossingMap() || _testFinished || car == null) return null;
    if (!_anyWheelInZigZagZone()) return null;
    if (gearLabel == 'P') {
      return 'No parking in the zig-zag zone — stay in gear and stop fully.';
    }
    return null;
  }

  void _updateZigZagRoadCrossingRules() {
    if (!_isRoadCrossingMap() || _testFinished || car == null) return;
    if (!_anyWheelInZigZagZone()) return;
    if (car!.isInPark) {
      _failTest('No parking in the zig-zag zone.');
    }
  }

  bool _zigZagRowOverlapsY(Rect a, Rect b) {
    return a.top < b.bottom && b.top < a.bottom;
  }

  void _rebuildZigZagRows() {
    _zigZagRowZoneIds = [];
    if (!_isRoadCrossingMap()) return;

    final zigZags = _drivingZones
        .where((z) => _zoneKindForScenario(z.zoneClass) == 'zig_zag')
        .toList();
    final used = <int>{};
    for (var i = 0; i < zigZags.length; i++) {
      final a = zigZags[i];
      if (used.contains(a.objectId)) continue;
      final rowIds = <int>[a.objectId];
      used.add(a.objectId);
      for (var j = i + 1; j < zigZags.length; j++) {
        final b = zigZags[j];
        if (used.contains(b.objectId)) continue;
        if (_zigZagRowOverlapsY(a.rect, b.rect)) {
          rowIds.add(b.objectId);
          used.add(b.objectId);
        }
      }
      if (rowIds.length >= 2) {
        _zigZagRowZoneIds.add(rowIds);
      }
    }
    print('[DEBUG] _setupRoad() - Zig-zag horizontal rows: $_zigZagRowZoneIds');
  }

  void _updateZigZagStraddleFail() {
    if (!_isRoadCrossingMap() || _testFinished || car == null) return;
    if (_zigZagRowZoneIds.isEmpty) return;

    final byId = {for (final z in _drivingZones) z.objectId: z};
    for (final rowIds in _zigZagRowZoneIds) {
      var touched = 0;
      for (final id in rowIds) {
        final zone = byId[id];
        if (zone == null) continue;
        if (_anyWheelInsideRect(zone.rect)) touched++;
      }
      if (touched >= 2) {
        _failTest(
          'Stay in one lane — do not touch both zig-zag zones on the same side of the crossing.',
        );
        return;
      }
    }
  }
}
