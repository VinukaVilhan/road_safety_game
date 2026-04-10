import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Path;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// True if this object layer should supply axis-aligned collision rectangles.
bool _isTiledCollisionObjectLayer(ObjectGroup layer) {
  final nameNorm = layer.name.replaceAll(' ', '_').toLowerCase();
  if (nameNorm == 'obstacles_layer') return true;
  final cls = layer.class_?.trim().toLowerCase();
  return cls == 'collision_box';
}

double? _readNumericPropertyAsDouble(CustomProperties properties, String name) {
  try {
    final intValue = properties.getValue<int>(name);
    if (intValue != null) return intValue.toDouble();
  } catch (_) {
    // Property exists but is not int; fall through to double read.
  }
  try {
    return properties.getValue<double>(name);
  } catch (_) {
    return null;
  }
}

class _DrivingZone {
  final int objectId;
  final Rect rect;
  final String zoneClass;
  final int? stepId;
  final String? failMessage;
  final double? maxSpeed;
  final double? waitTimeSec;

  const _DrivingZone({
    required this.objectId,
    required this.rect,
    required this.zoneClass,
    this.stepId,
    this.failMessage,
    this.maxSpeed,
    this.waitTimeSec,
  });
}

/// Junction "brown" validation: [expectedSignal] is `left`, `right`, or `none`.
class _MidTurnZone {
  final int objectId;
  final Path hitPath;
  final String expectedSignal;

  const _MidTurnZone({
    required this.objectId,
    required this.hitPath,
    required this.expectedSignal,
  });
}

class DrivingAttemptSummary {
  final bool passed;
  final String? failureMessage;
  final Duration timeSpent;
  final String expectedTurnSignal;
  final bool waitedAtRoadCrossing;
  final bool enteredApproachZone;
  final bool signaledCorrectlyInApproachZone;
  final bool enteredMidTurnZone;
  final bool hadCorrectSignalInMidTurnZone;
  final bool reachedFinishZone;
  final int nonCrashBumpCount;
  final int score;

  const DrivingAttemptSummary({
    required this.passed,
    required this.failureMessage,
    required this.timeSpent,
    required this.expectedTurnSignal,
    required this.waitedAtRoadCrossing,
    required this.enteredApproachZone,
    required this.signaledCorrectlyInApproachZone,
    required this.enteredMidTurnZone,
    required this.hadCorrectSignalInMidTurnZone,
    required this.reachedFinishZone,
    required this.nonCrashBumpCount,
    required this.score,
  });
}

/// Tiled: rotation in degrees clockwise around ([ox], [oy]) (pixel space, Y down).
Offset _tiledRotateLocal(double lx, double ly, double rotationDeg) {
  if (rotationDeg == 0) return Offset(lx, ly);
  final rad = rotationDeg * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  final rx = lx * c + ly * s;
  final ry = lx * s + ly * c;
  return Offset(rx, ry);
}

Path? _midTurnHitPathFromObject(TiledObject obj) {
  if (!obj.visible) return null;

  if (obj.isPolygon && obj.polygon.length >= 3) {
    final pts = <Offset>[];
    for (final p in obj.polygon) {
      final r = _tiledRotateLocal(p.x, p.y, obj.rotation);
      pts.add(Offset(obj.x + r.dx, obj.y + r.dy));
    }
    return Path()..addPolygon(pts, true);
  }

  if (obj.isRectangle && obj.width > 0 && obj.height > 0) {
    final w = obj.width;
    final h = obj.height;
    final corners = [
      Offset(0, 0),
      Offset(w, 0),
      Offset(w, h),
      Offset(0, h),
    ];
    final pts = corners
        .map((c) {
          final r = _tiledRotateLocal(c.dx, c.dy, obj.rotation);
          return Offset(obj.x + r.dx, obj.y + r.dy);
        })
        .toList();
    return Path()..addPolygon(pts, true);
  }

  return null;
}

bool _isMidTurnValidationObject(TiledObject obj, ObjectGroup layer) {
  final ot = obj.type.trim().toLowerCase();
  if (ot == 'zone_midturn') return true;
  final lc = (layer.class_ ?? '').trim().toLowerCase();
  if (lc == 'zone_midturn') return true;
  final ln = layer.name.replaceAll(' ', '_').toLowerCase();
  if (ln.contains('junction_validation')) return true;
  return false;
}

/// Tile layer used to mark junction-box hatched area (UK: do not stop inside).
bool _isJunctionBoxTileLayer(TileLayer layer) {
  if (!layer.visible) return false;
  final cls = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase().trim();
  if (cls == 'zone_junctionbox' || cls.contains('junctionbox')) return true;
  final nm = layer.name.replaceAll(' ', '_').toLowerCase();
  return nm == 'junction_box' || nm.contains('junction_box');
}

class RealisticCarGame extends FlameGame with KeyboardHandler {
  Car? car; // Make car accessible - nullable to handle initialization order
  late SpriteComponent roadBackground;
  double roadSpeed = 200.0;
  List<TiledComponent> roadTiles = [];
  bool _roadInitialized = false;
  double? _mapWidth;
  double? _mapHeight;
  double _baseLayerFriction = 400.0; // default fallback friction
  final List<Rect> _wallRects = [];
  Vector2? _spawnPoint;

  /// Preferred camera zoom level (> 1 = zoom in, < 1 = zoom out).
  /// Final zoom is clamped so camera never shows outside-map void.
  static const double preferredCameraZoom = 1.4;

  /// Impact speed (world units/sec, same scale as [Car.maxSpeed]) at or above which
  /// hitting a Collision_Box / Obstacles_Layer wall fails the test as a crash.
  static const double wallHighSpeedCrashThreshold = 125.0;

  /// Optional TMX map path (e.g. 'assets/tiles/T-junction-left.tmx'). If null, default map is used.
  final String? mapAsset;
  /// Optional scenario key to alter objective routing on a shared map.
  final String? scenarioId;
  final void Function(String message)? onTestFailed;
  final VoidCallback? onTestPassed;

  /// Synced from [GameScreen] turn-signal UI; required for [Zone_MidTurn] checks.
  final ValueNotifier<bool>? turnSignalLeft;
  final ValueNotifier<bool>? turnSignalRight;

  final List<_DrivingZone> _drivingZones = [];
  final Set<int> _zonesInsidePreviousFrame = <int>{};
  final List<_MidTurnZone> _midTurnZones = [];
  int _lastCompletedStepId = 0;
  bool _testFinished = false;
  DateTime? _attemptStartedAt;
  bool _enteredApproachZone = false;
  bool _signalOkInApproachZone = false;
  bool _enteredMidTurnZone = false;
  bool _midTurnSignalWasCorrect = false;
  bool _reachedFinishZone = false;
  String? _latestFailureMessage;
  int _nonCrashBumpCount = 0;
  DateTime? _lastNonCrashBumpAt;
  final ValueNotifier<int?> roadCrossingCountdown = ValueNotifier<int?>(null);
  final ValueNotifier<String?> roadCrossingApproachHint =
      ValueNotifier<String?>(null);
  bool _roadCrossingStopActive = false;
  bool _roadCrossingStopSatisfied = false;
  int? _roadCrossingStopStepId;
  double _roadCrossingStopElapsed = 0.0;
  static const double _roadCrossingStopDurationSec = 3.0;
  _DrivingZone? _activeRoadCrossingWaitZone;

  /// Filled from a tile layer (class [Zone_JunctionBox] or name `Junction_Box`).
  List<bool>? _junctionBoxTileMask;
  int? _junctionBoxMaskWidthTiles;
  int? _junctionBoxMaskHeightTiles;
  double _junctionBoxStoppedElapsedSec = 0.0;
  static const double _junctionBoxTileWorldSize = 16.0;
  static const double _junctionBoxStoppedSpeedThreshold = 18.0;
  static const double _junctionBoxStoppedSecondsToFail = 0.28;

  final VehicleSfx _vehicleSfx = VehicleSfx();

  RealisticCarGame({
    this.mapAsset,
    this.scenarioId,
    this.onTestFailed,
    this.onTestPassed,
    this.turnSignalLeft,
    this.turnSignalRight,
  });

  /// True while the zebra-crossing wait countdown is running (car in zone + Park).
  bool get isRoadCrossingStopActive => _roadCrossingStopActive;
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    _attemptStartedAt = DateTime.now();

    // Only preload assets that exist under assets/audio/ (see pubspec assets).
    try {
      await FlameAudio.audioCache.loadAll([
        'Reverse_Sound.m4a',
      ]);
    } catch (e, st) {
      debugPrint('Vehicle SFX preload failed: $e\n$st');
    }
    
    print('[DEBUG] onLoad() - Game size: ${size.x} x ${size.y}');
    
    // Use MaxViewport to fill screen - road will stretch to fill
    camera.viewport = MaxViewport();
    
    // Set camera to center on target (car) and apply zoom
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = preferredCameraZoom;
    print('[DEBUG] onLoad() - Camera viewfinder anchor set to center, zoom: $preferredCameraZoom');
    
    // Try to setup road if size is already available
    if (size.x > 0 && size.y > 0) {
      await _setupRoad();
    }
    // Otherwise, onGameResize will handle it
    
    // Add the car after road so it renders on top
    final newCar = Car();
    await newCar.onLoad();
    newCar.priority = 1; // Higher priority - renders on top of road
    world.add(newCar);  // Add to world, not game
    car = newCar; // Assign after adding to ensure it's not null
    print('[DEBUG] onLoad() - Car added to WORLD at position: ${car!.position}');
    
    // Wait for next frame to ensure car's onMount() is called
    await Future.delayed(Duration.zero);
  }
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    print('[DEBUG] onGameResize() - New size: ${size.x} x ${size.y}');
    
    // Initialize road tiles when size is known
    if (!_roadInitialized && size.x > 0 && size.y > 0) {
      _setupRoad();
    }
    // Re-apply bounds after resize/orientation changes to avoid clipped camera limits.
    if (_roadInitialized) {
      _applyCameraZoomForViewport();
      _applyCameraBounds();
    }
  }
  
  Future<void> _setupRoad() async {
    if (_roadInitialized) return;
    
    // Remove existing tiles if any
    for (var tile in roadTiles) {
      remove(tile);
    }
    roadTiles.clear();
    
    final tmxPath = mapAsset ?? 'town_tiles_2.tmx';
    // Load the Tiled map
    final tiledMap = await TiledComponent.load(
      tmxPath,
      Vector2.all(16), // Tile size from TMX file (16x16)
    );
    
    // Calculate and store map dimensions
    _mapWidth = tiledMap.tileMap.map.width * 16.0; // 16 is tile width
    _mapHeight = tiledMap.tileMap.map.height * 16.0; // 16 is tile height
    print('[DEBUG] _setupRoad() - Map dimensions: ${_mapWidth} x ${_mapHeight}');
    print('[DEBUG] _setupRoad() - Map tiles: ${tiledMap.tileMap.map.width} x ${tiledMap.tileMap.map.height}');

    // Read spawn point from object groups (layer/object class, type, or name can mark spawn).
    _spawnPoint = null;
    for (final layer in tiledMap.tileMap.map.layers.whereType<ObjectGroup>()) {
      final layerTag = layer.name.replaceAll(' ', '_').toLowerCase();
      final layerClassTag = (layer.class_ ?? '').replaceAll(' ', '_').toLowerCase();
      final isSpawnLayer = layerTag.contains('spawn') || layerClassTag.contains('spawn');
      for (final obj in layer.objects) {
        final objectClassTag =
            obj.class_.replaceAll(' ', '_').toLowerCase();
        final objectTypeTag = obj.type.replaceAll(' ', '_').toLowerCase();
        final objectNameTag = obj.name.replaceAll(' ', '_').toLowerCase();
        final isSpawnObject = objectClassTag.contains('spawn') ||
            objectTypeTag.contains('spawn') ||
            objectNameTag.contains('spawn');
        if (!isSpawnLayer && !isSpawnObject) continue;

        final spawnX = obj.isPoint ? obj.x : obj.x + (obj.width / 2);
        final spawnY = obj.isPoint ? obj.y : obj.y + (obj.height / 2);
        _spawnPoint = Vector2(spawnX, spawnY);
        print('[DEBUG] _setupRoad() - Spawn point loaded: $_spawnPoint');
        break;
      }
      if (_spawnPoint != null) break;
    }

    // Read friction from the "Base" layer if available (Tiled layer property)
    TileLayer? baseLayer;
    for (final layer in tiledMap.tileMap.map.layers.whereType<TileLayer>()) {
      if (layer.name == 'Base') {
        baseLayer = layer;
        break;
      }
    }
    if (baseLayer != null) {
      final frictionProp =
          _readNumericPropertyAsDouble(baseLayer.properties, 'friction');
      if (frictionProp != null) {
        _baseLayerFriction = frictionProp * 400.0; // scale tile friction into force
        print('[DEBUG] _setupRoad() - Base layer friction from TMX: $frictionProp -> $_baseLayerFriction');
      } else {
        print('[DEBUG] _setupRoad() - Base layer has no friction property, using default: $_baseLayerFriction');
      }
    } else {
      print('[DEBUG] _setupRoad() - No Base layer found, using default friction: $_baseLayerFriction');
    }

    // Junction box tiles: fail the level if the player stops inside (see [_updateJunctionBoxStopFail]).
    _junctionBoxTileMask = null;
    _junctionBoxMaskWidthTiles = null;
    _junctionBoxMaskHeightTiles = null;
    for (final layer in tiledMap.tileMap.map.layers.whereType<TileLayer>()) {
      if (!_isJunctionBoxTileLayer(layer)) continue;
      final data = layer.data;
      if (data == null || data.length != layer.width * layer.height) {
        print(
          '[DEBUG] _setupRoad() - Junction box layer "${layer.name}" has missing/invalid tile data',
        );
        continue;
      }
      _junctionBoxMaskWidthTiles = layer.width;
      _junctionBoxMaskHeightTiles = layer.height;
      const gidMask = 0x1FFFFFFF; // strip Tiled flip flags from GID
      _junctionBoxTileMask = List<bool>.generate(
        data.length,
        (i) => (data[i] & gidMask) != 0,
      );
      final marked =
          _junctionBoxTileMask!.where((cell) => cell).length;
      print(
        '[DEBUG] _setupRoad() - Junction box tile layer "${layer.name}" ($marked tiles)',
      );
      break;
    }

    // Read collision rectangles from Tiled object layers:
    // - Layer name "Obstacles_Layer" / "Obstacles Layer", OR
    // - Layer class "Collision_Box" (Tiled 1.9+ <objectgroup class="...">).
    // - Skip hidden objects (visible="0") so old placeholder walls don't block the road.
    // - Use every visible axis-aligned rectangle unless type is a known non-solid (spawn, trigger, …).
    // - Plain rectangles without a class/type still collide (Tiled defaults type to "").
    _wallRects.clear();
    final collisionLayers = tiledMap.tileMap.map.layers
        .whereType<ObjectGroup>()
        .where(_isTiledCollisionObjectLayer)
        .toList();
    const ignoredCollisionTypes = {
      'spawn',
      'player',
      'trigger',
      'sensor',
      'ignore',
      'nocollision',
    };
    if (collisionLayers.isNotEmpty) {
      for (final obstaclesLayer in collisionLayers) {
        print(
          '[DEBUG] _setupRoad() - Collision layer "${obstaclesLayer.name}" class="${obstaclesLayer.class_ ?? ""}"',
        );
        for (final obj in obstaclesLayer.objects) {
          if (!obj.visible) continue;
          if (obj.width <= 0 || obj.height <= 0) continue;
          if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) {
            continue;
          }
          if (obj.rotation != 0) {
            print(
              '[DEBUG] _setupRoad() - Skipping rotated object id=${obj.id} (rotation=${obj.rotation}); use axis-aligned rects for collision',
            );
            continue;
          }
          final typeLower = obj.type.trim().toLowerCase();
          if (ignoredCollisionTypes.contains(typeLower)) continue;

          final rect = Rect.fromLTWH(
            obj.x,
            obj.y,
            obj.width,
            obj.height,
          );
          _wallRects.add(rect);
          print(
            '[DEBUG] _setupRoad() - Obstacle rect id=${obj.id} type="${obj.type}": $rect',
          );
        }
      }
      print('[DEBUG] _setupRoad() - Total obstacle rects: ${_wallRects.length}');
    } else {
      print(
        '[DEBUG] _setupRoad() - No collision object layer (name Obstacles_Layer or class Collision_Box), no walls added',
      );
    }

    // Read rule zones (checkpoint, finish, fail) from object layers or objects.
    _drivingZones.clear();
    for (final layer in tiledMap.tileMap.map.layers.whereType<ObjectGroup>()) {
      final layerClass = (layer.class_ ?? '').trim();
      final layerClassLower = layerClass.toLowerCase();
      final layerNameLower = layer.name.trim().toLowerCase();
      final layerStepId = layer.properties.getValue<int>('step_id');
      final layerFailMessage = layer.properties.getValue<String>('fail_message');

      for (final obj in layer.objects) {
        if (!obj.visible || obj.width <= 0 || obj.height <= 0) continue;
        if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) continue;
        if (obj.rotation != 0) continue;

        final objectClass = obj.class_.trim();
        final objectType = obj.type.trim();
        final objectName = obj.name.trim();
        final zoneClass = objectClass.isNotEmpty
            ? objectClass
            : (objectType.isNotEmpty
                ? objectType
                : (objectName.isNotEmpty
                    ? objectName
                    : (layerClass.isNotEmpty ? layerClass : layer.name)));
        final zoneClassLower = zoneClass.toLowerCase();

        if (!_isSupportedDrivingZoneLabel(zoneClassLower) &&
            !_isSupportedDrivingZoneLabel(layerClassLower) &&
            !_isSupportedDrivingZoneLabel(layerNameLower)) {
          continue;
        }

        final effectiveZoneClass =
            zoneClassLower.isNotEmpty ? zoneClass : layerClass;
        final stepId = obj.properties.getValue<int>('step_id') ?? layerStepId;
        final failMessage =
            obj.properties.getValue<String>('fail_message') ?? layerFailMessage;
        final maxSpeed = _readNumericPropertyAsDouble(obj.properties, 'max_speed') ??
            _readNumericPropertyAsDouble(layer.properties, 'max_speed');
        final waitTimeSec =
            _readNumericPropertyAsDouble(obj.properties, 'wait_time') ??
                _readNumericPropertyAsDouble(layer.properties, 'wait_time');

        _drivingZones.add(
          _DrivingZone(
            objectId: obj.id,
            rect: Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height),
            zoneClass: effectiveZoneClass.toLowerCase(),
            stepId: stepId,
            failMessage: _sanitizeFailMessage(failMessage),
            maxSpeed: maxSpeed,
            waitTimeSec: waitTimeSec,
          ),
        );
      }
    }
    print('[DEBUG] _setupRoad() - Loaded driving zones: ${_drivingZones.length}');

    // Junction_Validation_Layer / Zone_MidTurn + expected_signal (polygon or rect).
    _midTurnZones.clear();
    for (final layer in tiledMap.tileMap.map.layers.whereType<ObjectGroup>()) {
      for (final obj in layer.objects) {
        if (!_isMidTurnValidationObject(obj, layer)) continue;
        final raw =
            (obj.properties.getValue<String>('expected_signal') ?? 'none').trim();
        final expected = raw.toLowerCase();
        final path = _midTurnHitPathFromObject(obj);
        if (path == null) continue;
        _midTurnZones.add(
          _MidTurnZone(
            objectId: obj.id,
            hitPath: path,
            expectedSignal: expected,
          ),
        );
        print(
          '[DEBUG] _setupRoad() - MidTurn zone id=${obj.id} expected=$expected',
        );
      }
    }
    print('[DEBUG] _setupRoad() - MidTurn validation zones: ${_midTurnZones.length}');
    
    // Create a single static map instance at (0, 0) covering the entire world
    final mapInstance = await TiledComponent.load(
      tmxPath,
      Vector2.all(16),
    );
    
    // Position map at world origin (0, 0) - covers entire world space
    mapInstance.position = Vector2(0, 0);
    mapInstance.priority = 0; // Lower priority - renders behind
    
    roadTiles.add(mapInstance);
    world.add(mapInstance);  // Add to world, not game
    
    _roadInitialized = true;
    
    // Set camera bounds so the view never shows past the map edges (no black void).
    // considerViewport: true ensures the visible area (viewport + zoom) stays inside the map.
    _applyCameraZoomForViewport();
    _applyCameraBounds();
    
    // Follow the car (if already in world); otherwise Car.onMount will call follow
    if (car != null && car!.isMounted) {
      if (_spawnPoint != null) {
        car!.position = _spawnPoint!.clone();
      }
      camera.follow(car!);
      world.remove(car!);
      car!.priority = 1;
      world.add(car!);
    }
  }

  void _applyCameraBounds() {
    if (_mapWidth == null || _mapHeight == null) return;
    final mapBounds = Rect.fromLTWH(0, 0, _mapWidth!, _mapHeight!);
    camera.setBounds(Rectangle.fromRect(mapBounds), considerViewport: true);
  }

  void _applyCameraZoomForViewport() {
    if (_mapWidth == null || _mapHeight == null || size.x <= 0 || size.y <= 0) {
      return;
    }
    // Prevent black space by ensuring visible world <= map size on both axes.
    final minZoomToAvoidVoid = math.max(size.x / _mapWidth!, size.y / _mapHeight!);
    final finalZoom = math.max(preferredCameraZoom, minZoomToAvoidVoid);
    camera.viewfinder.zoom = finalZoom;
  }

  /// Reset scenario after failure so the player can retry without replacing [GameScreen]
  /// (avoids dispose/orientation races with `Navigator.pushReplacement`).
  void restartLevel() {
    _testFinished = false;
    _zonesInsidePreviousFrame.clear();
    _lastCompletedStepId = 0;
    _attemptStartedAt = DateTime.now();
    _enteredApproachZone = false;
    _signalOkInApproachZone = false;
    _enteredMidTurnZone = false;
    _midTurnSignalWasCorrect = false;
    _reachedFinishZone = false;
    _latestFailureMessage = null;
    _nonCrashBumpCount = 0;
    _lastNonCrashBumpAt = null;
    _roadCrossingStopActive = false;
    _roadCrossingStopSatisfied = false;
    _roadCrossingStopStepId = null;
    _roadCrossingStopElapsed = 0.0;
    _activeRoadCrossingWaitZone = null;
    roadCrossingCountdown.value = null;
    roadCrossingApproachHint.value = null;
    _junctionBoxStoppedElapsedSec = 0.0;
    final c = car;
    if (c == null) return;
    c.velocity = Vector2.zero();
    c.acceleration = Vector2.zero();
    c.coast();
    c.isSteering = false;
    c.steerAngle = 0;
    c.angle = -math.pi / 2;
    if (_spawnPoint != null) {
      c.position.setFrom(_spawnPoint!);
    } else {
      final cx = (_mapWidth ?? 1600) / 2;
      final cy = (_mapHeight ?? 1600) / 2;
      c.position = Vector2(cx, cy);
    }
    camera.follow(c);
  }

  @override
  void onRemove() {
    _vehicleSfx.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _vehicleSfx.tick(dt, car);
    _updateRoadCrossingApproachHint();
    _updateRoadCrossingParkCountdown(dt);
    _enforceSpeedLimitZones();
    _updateMidTurnSignalValidation();
    _updateDrivingRuleZones();
    _updateJunctionBoxStopFail(dt);
  }

  /// [road-crossing.tmx]: countdown runs only inside a Zig_Zag (grey) wait zone
  /// while the car is in **Park (P)**. Leaving the zone or shifting out of P pauses
  /// and resets the timer.
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

    final parkedInZone = allWheelsInWaitZone && car!.isInPark;
    final waitDurationSec =
        activeWaitZone?.waitTimeSec ?? _roadCrossingStopDurationSec;

    if (parkedInZone && !_roadCrossingStopSatisfied) {
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
        // Fallback for maps where Zig_Zag wait zone has no explicit step_id.
        _lastCompletedStepId = 1;
      }
    }
  }

  bool _isRoadCrossingMap() {
    final asset = mapAsset?.toLowerCase() ?? '';
    return asset.contains('road-crossing');
  }

  void _updateRoadCrossingApproachHint() {
    if (!_isRoadCrossingMap() || _testFinished || car == null) {
      if (roadCrossingApproachHint.value != null) {
        roadCrossingApproachHint.value = null;
      }
      return;
    }

    // Once inside the yellow approach zone, remove pre-approach guidance.
    if (_enteredApproachZone) {
      if (roadCrossingApproachHint.value != null) {
        roadCrossingApproachHint.value = null;
      }
      return;
    }

    final carCenter = Offset(car!.position.x, car!.position.y);
    double? nearestDistance;
    for (final zone in _drivingZones) {
      final zoneKind = _zoneKindForScenario(zone.zoneClass);
      if (zoneKind != 'zone_check') continue; // yellow approach zone
      final d = _distancePointToRect(carCenter, zone.rect);
      if (nearestDistance == null || d < nearestDistance) {
        nearestDistance = d;
      }
    }

    // Strict requirement: warning is shown only from Zone_Check class areas.
    // If no Zone_Check exists, hide the hint.
    if (nearestDistance == null) {
      if (roadCrossingApproachHint.value != null) {
        roadCrossingApproachHint.value = null;
      }
      return;
    }

    final meters = (nearestDistance / 10).clamp(1, 999).toInt();
    final hint = 'Slow down: zebra crossing ahead (${meters}m)';
    if (roadCrossingApproachHint.value != hint) {
      roadCrossingApproachHint.value = hint;
    }
  }

  double _distancePointToRect(Offset p, Rect r) {
    final dx = p.dx < r.left
        ? r.left - p.dx
        : (p.dx > r.right ? p.dx - r.right : 0.0);
    final dy = p.dy < r.top
        ? r.top - p.dy
        : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
    return math.sqrt((dx * dx) + (dy * dy));
  }

  bool _areAllWheelsInsideRect(Rect zoneRect) {
    final c = car;
    if (c == null) return false;
    final center = c.position;
    final halfW = c.size.x / 2;
    final halfH = c.size.y / 2;
    final cosA = math.cos(c.angle);
    final sinA = math.sin(c.angle);

    // Approximate 4 wheel contact points near each corner.
    final wheelOffsets = <Offset>[
      Offset(-halfW * 0.7, -halfH * 0.7),
      Offset(halfW * 0.7, -halfH * 0.7),
      Offset(-halfW * 0.7, halfH * 0.7),
      Offset(halfW * 0.7, halfH * 0.7),
    ];

    for (final o in wheelOffsets) {
      final rx = (o.dx * cosA) - (o.dy * sinA);
      final ry = (o.dx * sinA) + (o.dy * cosA);
      final wheelPoint = Offset(center.x + rx, center.y + ry);
      if (!zoneRect.contains(wheelPoint)) {
        return false;
      }
    }
    return true;
  }

  void _enforceSpeedLimitZones() {
    if (_testFinished || car == null || _drivingZones.isEmpty) return;

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );

    double? activeMaxSpeed;
    for (final zone in _drivingZones) {
      if (!carRect.overlaps(zone.rect)) continue;
      final zoneKind = _zoneKindForScenario(zone.zoneClass);
      final defaultZigZagLimit = zoneKind == 'zig_zag' ? 30.0 : null;
      final zoneLimit = zone.maxSpeed ?? defaultZigZagLimit;
      if (zoneKind != 'zone_speedlimit' && zoneKind != 'zig_zag' && zoneLimit == null) {
        continue;
      }
      if (zoneLimit == null || zoneLimit <= 0) continue;
      if (activeMaxSpeed == null || zoneLimit < activeMaxSpeed) {
        activeMaxSpeed = zoneLimit;
      }
    }

    if (activeMaxSpeed == null) return;
    final currentSpeed = car!.velocity.length;
    if (currentSpeed <= activeMaxSpeed) return;
    car!.velocity = car!.velocity.normalized() * activeMaxSpeed;
  }

  String _sanitizeFailMessage(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  String _zoneKindForScenario(String zoneClass) {
    final normalized = zoneClass.trim().toLowerCase();
    if (normalized == 'zone_check' || normalized.startsWith('zone_check')) {
      return 'zone_check';
    }
    if (normalized == 'zig_zag' || normalized.startsWith('zig_zag')) {
      return 'zig_zag';
    }
    if (normalized == 'zone_finish' || normalized.startsWith('zone_finish')) {
      return 'zone_finish';
    }
    if (normalized == 'zone_fail_wt' || normalized.startsWith('zone_fail_wt')) {
      return 'zone_fail_wt';
    }
    if (normalized == 'zone_fail_it' || normalized.startsWith('zone_fail_it')) {
      return 'zone_fail_it';
    }
    if (normalized == 'zone_speedlimit' || normalized.startsWith('zone_speedlimit')) {
      return 'zone_speedlimit';
    }
    // Some maps use Finish_Zone as a restricted area to avoid.
    if (normalized == 'finish_zone') {
      return 'zone_fail_wt';
    }
    return normalized;
  }

  bool _isSupportedDrivingZoneLabel(String raw) {
    final v = raw.trim().toLowerCase();
    return v == 'zone_check' ||
        v.startsWith('zone_check') ||
        v == 'zone_finish' ||
        v.startsWith('zone_finish') ||
        v == 'finish_zone' ||
        v.startsWith('finish_zone') ||
        v == 'zone_fail_wt' ||
        v.startsWith('zone_fail_wt') ||
        v == 'zone_fail_it' ||
        v.startsWith('zone_fail_it') ||
        v == 'zone_speedlimit' ||
        v.startsWith('zone_speedlimit') ||
        v == 'zig_zag' ||
        v.startsWith('zig_zag');
  }

  String _expectedSignalForSummary() {
    for (final zone in _midTurnZones) {
      if (zone.expectedSignal == 'left' || zone.expectedSignal == 'right') {
        return zone.expectedSignal;
      }
    }
    return 'none';
  }

  bool _signalsMatchExpectedForSummary(String expected) {
    final leftOn = turnSignalLeft?.value ?? false;
    final rightOn = turnSignalRight?.value ?? false;
    return _turnSignalsMatchExpected(expected, leftOn, rightOn);
  }

  int _computeScore(Duration elapsed) {
    final expected = _expectedSignalForSummary();
    var score = 0;
    if (_enteredApproachZone) score += 20;
    if (_signalOkInApproachZone) score += 20;
    if (_midTurnSignalWasCorrect) score += 30;
    if (_reachedFinishZone) score += 20;

    // Time bonus (0-10): full at <=30s, linearly decays to 0 at >=120s.
    final ms = elapsed.inMilliseconds;
    int timeBonus;
    if (ms <= 30000) {
      timeBonus = 10;
    } else if (ms >= 120000) {
      timeBonus = 0;
    } else {
      final t = (ms - 30000) / 90000.0; // 0..1
      timeBonus = ((1 - t) * 10).round().clamp(0, 10);
    }
    score += timeBonus;

    // Small guard: if expected is none, don't over-penalize approach signaling.
    if (expected == 'none' && !_signalOkInApproachZone && score >= 5) {
      score += 5;
    }
    // Penalize minor obstacle bumps (non-crash) a little, with a cap.
    final bumpPenalty = (_nonCrashBumpCount * 2).clamp(0, 20);
    score -= bumpPenalty;
    return score.clamp(0, 100);
  }

  DrivingAttemptSummary getAttemptSummary({bool? passed, String? failureMessage}) {
    final now = DateTime.now();
    final startedAt = _attemptStartedAt ?? now;
    final elapsed = now.difference(startedAt);
    final expected = _expectedSignalForSummary();
    final resolvedFailure = failureMessage ?? _latestFailureMessage;
    return DrivingAttemptSummary(
      passed: passed ?? (_testFinished && resolvedFailure == null),
      failureMessage: resolvedFailure,
      timeSpent: elapsed,
      expectedTurnSignal: expected,
      waitedAtRoadCrossing: _roadCrossingStopSatisfied,
      enteredApproachZone: _enteredApproachZone,
      signaledCorrectlyInApproachZone: _signalOkInApproachZone,
      enteredMidTurnZone: _enteredMidTurnZone,
      hadCorrectSignalInMidTurnZone: _midTurnSignalWasCorrect,
      reachedFinishZone: _reachedFinishZone,
      nonCrashBumpCount: _nonCrashBumpCount,
      score: _computeScore(elapsed),
    );
  }

  void registerNonCrashBump() {
    final now = DateTime.now();
    // Debounce to avoid counting a continuous scrape as dozens of bumps.
    if (_lastNonCrashBumpAt != null &&
        now.difference(_lastNonCrashBumpAt!).inMilliseconds < 700) {
      return;
    }
    _lastNonCrashBumpAt = now;
    _nonCrashBumpCount += 1;
  }

  bool _turnSignalsMatchExpected(String expected, bool leftOn, bool rightOn) {
    switch (expected) {
      case 'left':
        return leftOn && !rightOn;
      case 'right':
        return rightOn && !leftOn;
      case 'none':
      case 'straight':
        return !leftOn && !rightOn;
      default:
        return true;
    }
  }

  String _midTurnFailMessage(_MidTurnZone zone, bool leftOn, bool rightOn) {
    final exp = zone.expectedSignal;
    if (exp == 'left') {
      return 'Use your left signal when taking the left path of the junction.';
    }
    if (exp == 'right') {
      return 'Use your right signal when taking the right path of the junction.';
    }
    if (exp == 'none' || exp == 'straight') {
      if (leftOn && rightOn) {
        return 'Turn signals must be off when going straight through the junction.';
      }
      if (leftOn) {
        return 'Turn off your left signal when going straight through the junction.';
      }
      if (rightOn) {
        return 'Turn off your right signal when going straight through the junction.';
      }
      return 'Turn signals must be off when going straight through the junction.';
    }
    return 'Incorrect turn signal for this lane.';
  }

  void _updateMidTurnSignalValidation() {
    if (_testFinished ||
        car == null ||
        _midTurnZones.isEmpty ||
        turnSignalLeft == null ||
        turnSignalRight == null) {
      return;
    }

    final leftOn = turnSignalLeft!.value;
    final rightOn = turnSignalRight!.value;
    final center = Offset(car!.position.x, car!.position.y);

    // Re-check every frame while the car is inside a zone so turning a signal
    // on/off mid-junction is still validated (e.g. straight path + blinker on).
    for (final zone in _midTurnZones) {
      if (!zone.hitPath.contains(center)) continue;
      _enteredMidTurnZone = true;
      if (!_turnSignalsMatchExpected(zone.expectedSignal, leftOn, rightOn)) {
        _testFinished = true;
        car?.coast();
        final message = _midTurnFailMessage(zone, leftOn, rightOn);
        _latestFailureMessage = message;
        onTestFailed?.call(message);
        return;
      }
      _midTurnSignalWasCorrect = true;
    }
  }

  bool _carRectOverlapsJunctionBoxTiles(Rect carWorldRect) {
    final mask = _junctionBoxTileMask;
    final mw = _junctionBoxMaskWidthTiles;
    final mh = _junctionBoxMaskHeightTiles;
    if (mask == null || mw == null || mh == null) return false;

    final tw = _junctionBoxTileWorldSize;
    var tx0 = (carWorldRect.left / tw).floor();
    var tx1 = (carWorldRect.right / tw).ceil() - 1;
    var ty0 = (carWorldRect.top / tw).floor();
    var ty1 = (carWorldRect.bottom / tw).ceil() - 1;
    tx0 = math.max(0, math.min(mw - 1, tx0));
    tx1 = math.max(0, math.min(mw - 1, tx1));
    ty0 = math.max(0, math.min(mh - 1, ty0));
    ty1 = math.max(0, math.min(mh - 1, ty1));

    for (var ty = ty0; ty <= ty1; ty++) {
      final row = ty * mw;
      for (var tx = tx0; tx <= tx1; tx++) {
        final idx = row + tx;
        if (idx >= 0 && idx < mask.length && mask[idx]) return true;
      }
    }
    return false;
  }

  void _failStoppedInJunctionBox(String message) {
    if (_testFinished) return;
    _testFinished = true;
    car?.coast();
    _latestFailureMessage = message;
    onTestFailed?.call(message);
  }

  /// UK-style junction box: stopping or parking on hatched tiles fails the level.
  void _updateJunctionBoxStopFail(double dt) {
    if (_testFinished || car == null || _junctionBoxTileMask == null) return;

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    final inBox = _carRectOverlapsJunctionBoxTiles(carRect);
    if (!inBox) {
      _junctionBoxStoppedElapsedSec = 0.0;
      return;
    }

    if (car!.isInPark) {
      _failStoppedInJunctionBox(
        'Do not stop or park in the junction box — wait behind the line until you can clear the junction.',
      );
      return;
    }

    final speed = car!.velocity.length;
    if (speed < _junctionBoxStoppedSpeedThreshold) {
      _junctionBoxStoppedElapsedSec += dt;
      if (_junctionBoxStoppedElapsedSec >= _junctionBoxStoppedSecondsToFail) {
        _failStoppedInJunctionBox(
          'Do not stop in the junction box. Keep moving or wait behind the line until the way is clear.',
        );
      }
    } else {
      _junctionBoxStoppedElapsedSec = 0.0;
    }
  }

  void _updateDrivingRuleZones() {
    if (_testFinished || car == null || _drivingZones.isEmpty) return;

    final currentInside = <int>{};
    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );

    for (final zone in _drivingZones) {
      if (!carRect.overlaps(zone.rect)) continue;
      currentInside.add(zone.objectId);
      if (_zonesInsidePreviousFrame.contains(zone.objectId)) continue;
      _handleZoneEntry(zone);
      if (_testFinished) break;
    }

    _zonesInsidePreviousFrame
      ..clear()
      ..addAll(currentInside);
  }

  void _handleZoneEntry(_DrivingZone zone) {
    final zoneKind = _zoneKindForScenario(zone.zoneClass);

    if (zoneKind == 'zone_check') {
      _enteredApproachZone = true;
      final expected = _expectedSignalForSummary();
      if (_signalsMatchExpectedForSummary(expected)) {
        _signalOkInApproachZone = true;
      }
      final step = zone.stepId;
      if (_isRoadCrossingMap()) {
        // Step advances only after park + countdown in [_updateRoadCrossingParkCountdown].
        return;
      }
      if (step == null) return;
      if (step == _lastCompletedStepId + 1) {
        _lastCompletedStepId = step;
      }
      return;
    }

    if (zoneKind == 'zone_finish') {
      _reachedFinishZone = true;
      final requiredPreviousStep = (zone.stepId ?? 1) - 1;
      if (_lastCompletedStepId < requiredPreviousStep) {
        return;
      }
      _testFinished = true;
      car?.coast();
      onTestPassed?.call();
      return;
    }

    if (zoneKind == 'zone_fail_wt' || zoneKind == 'zone_fail_it') {
      _testFinished = true;
      car?.coast();
      final defaultMessage = zoneKind == 'zone_fail_it'
          ? 'Driving in oncoming traffic!'
          : 'Wrong Turn!';
      final message =
          zone.failMessage?.isNotEmpty == true ? zone.failMessage! : defaultMessage;
      _latestFailureMessage = message;
      onTestFailed?.call(message);
    }
  }

  void _failFromHighSpeedWallCrash() {
    if (_testFinished) return;
    _testFinished = true;
    car?.coast();
    const message = 'High-speed crash! You hit an obstacle too fast.';
    _latestFailureMessage = message;
    onTestFailed?.call(message);
  }
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    return false;
  }
}

class Car extends SpriteComponent {
  // Physics properties
  Vector2 velocity = Vector2.zero();
  Vector2 acceleration = Vector2.zero();
  double maxSpeed = 200.0;
  double accelerationForce = 450.0;
  double brakeForce = 600.0;
  double friction = 400.0;
  
  // Steering properties
  double steerAngle = 0;
  double maxSteerAngle = 72.0; // Maximum steering angle in degrees (wheel input cap)
  double steerReturnSpeed = 300.0; // how fast steering returns to center
  bool isSteering = false; // Track if user is actively steering
  double turnRate = 4.25; // Scales how steering translates to rotation (higher = tighter turns)
  
  // Control flags to maintain acceleration/braking states
  bool isAccelerating = false;
  bool isBraking = false;
  
  // Gear system properties
  int currentGear = 1; // P=0, 1-4=forward gears, R=-1
  bool isInPark = false;
  
  // Debug counter
  int _debugFrameCount = 0;
  
  // Separate multipliers keep gears easier to control:
  // lower gears = stronger pull but lower top speed.
  final Map<int, double> gearAccelerationMultipliers = {
    -1: 0.35, // Reverse
    0: 0.0, // Park
    1: 0.55, // 1st gear
    2: 0.45, // 2nd gear
    3: 0.35, // 3rd gear
    4: 0.30, // 4th gear
  };

  final Map<int, double> gearSpeedMultipliers = {
    -1: 0.18, // Reverse (~36 if maxSpeed is 200)
    0: 0.0, // Park
    1: 0.14, // 1st gear (~28)
    2: 0.24, // 2nd gear (~48)
    3: 0.36, // 3rd gear (~72)
    4: 0.50, // 4th gear (~100)
  };
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Load the black car sprite
    sprite = await Sprite.load('BlackCar.png');
    
    // Set car size and anchor
    size = Vector2(60, 60);
    anchor = Anchor.center;
    angle = -math.pi / 2; // Car starts facing up (negative Y direction)
  }
  
  @override
  void onMount() {
    super.onMount();
    
    // Position car at CENTER of map for better initial visibility
    // Map is 1600x1600, so center is 800x800
    // FIXED: Get game through findGame() since parent is now World
    final game = findGame()! as RealisticCarGame;
    final centerX = (game._mapWidth ?? 1600) / 2;
    final centerY = (game._mapHeight ?? 1600) / 2;
    position = game._spawnPoint?.clone() ?? Vector2(centerX, centerY);
    // Start following this car (bounds are set in _setupRoad when map is loaded)
    game.camera.follow(this);
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Safety check - ensure game exists
    // FIXED: Get game through findGame() since parent is now World
    final game = findGame();
    if (game == null) return;
    final realisticGame = game as RealisticCarGame;

    // Update friction from map (e.g. Base layer property) if available
    friction = realisticGame._baseLayerFriction;
    
    // Don't allow movement if in park
    if (isInPark) {
      velocity = Vector2.zero();
      acceleration = Vector2.zero();
      return;
    }
    
    // Calculate effective acceleration based on current gear
    double effectiveAcceleration =
        accelerationForce * (gearAccelerationMultipliers[currentGear] ?? 0.4);
    
    // Apply continuous acceleration/braking based on button states
    // Acceleration is now in the direction the car is facing
    if (isAccelerating) {
      if (currentGear == -1) {
        // Reverse gear - accelerate backwards (opposite of car's facing direction)
        acceleration.x = math.cos(angle + math.pi) * effectiveAcceleration;
        acceleration.y = math.sin(angle + math.pi) * effectiveAcceleration;
      } else if (currentGear > 0) {
        // Forward gears - accelerate in car's facing direction
        acceleration.x = math.cos(angle) * effectiveAcceleration;
        acceleration.y = math.sin(angle) * effectiveAcceleration;
      }
    } else if (isBraking) {
      if (velocity.length > 0) {
        acceleration = velocity.normalized() * -brakeForce;
      }
    } else {
      // Apply friction when coasting
      if (velocity.length > 0) {
        final frictionForce = velocity.normalized() * -friction;
        acceleration = frictionForce;
      } else {
        acceleration = Vector2.zero();
      }
    }
    
    // Apply acceleration to velocity
    velocity += acceleration * dt;
    
    // Calculate effective max speed based on gear
    double effectiveMaxSpeed =
        maxSpeed * (gearSpeedMultipliers[currentGear]?.abs() ?? 0.2);
    
    // Limit max speed based on current gear
    if (velocity.length > effectiveMaxSpeed) {
      velocity = velocity.normalized() * effectiveMaxSpeed;
    }
    
    // Apply steering to car's rotation and direction (only when moving)
    if (velocity.length > 0.1) {
      // Convert steering angle from degrees to radians
      double steeringRadians = steerAngle * (math.pi / 180.0);
      
      // Rotate the car based on steering input
      // Turn rate is proportional to steering angle and speed
      double currentSpeed = velocity.length;
      double normalizedSpeed = currentSpeed / maxSpeed; // 0 to 1
      
      // Determine if car is moving forward or backward BEFORE rotating
      // Check if velocity is aligned with car's facing direction
      double forwardDot = math.cos(angle) * velocity.x + math.sin(angle) * velocity.y;
      bool isMovingForward = forwardDot > 0;
      
      // Apply rotation: more steering + more speed = faster turning
      angle += steeringRadians * turnRate * normalizedSpeed * dt;
      
      // Rotate velocity vector to match car's new direction
      // Preserve forward/backward direction
      double speed = velocity.length;
      if (isMovingForward) {
        // Moving forward - velocity in car's facing direction
        velocity.x = math.cos(angle) * speed;
        velocity.y = math.sin(angle) * speed;
      } else {
        // Moving backward - velocity opposite to car's facing direction
        velocity.x = math.cos(angle + math.pi) * speed;
        velocity.y = math.sin(angle + math.pi) * speed;
      }
    }
    
    // Apply velocity to position
    final oldPosition = position.clone();
    position += velocity * dt;

    // Simple wall collision: push car out of any wall rect and stop movement into it
    if (realisticGame._wallRects.isNotEmpty) {
      final carRect = Rect.fromCenter(
        center: Offset(position.x, position.y),
        width: size.x,
        height: size.y,
      );
      for (final wall in realisticGame._wallRects) {
        if (carRect.overlaps(wall)) {
          final impactSpeed = velocity.length;
          position.setFrom(oldPosition);
          velocity = Vector2.zero();
          acceleration = Vector2.zero();
          if (impactSpeed >= RealisticCarGame.wallHighSpeedCrashThreshold) {
            realisticGame._failFromHighSpeedWallCrash();
          } else {
            realisticGame.registerNonCrashBump();
          }
          break;
        }
      }
    }
    
    // Gradually return steering to center only when NOT actively steering
    if (!isSteering && steerAngle != 0) {
      final returnAmount = steerReturnSpeed * dt;
      if (steerAngle > 0) {
        steerAngle = math.max(0, steerAngle - returnAmount);
      } else {
        steerAngle = math.min(0, steerAngle + returnAmount);
      }
    }
    
    // Keep car within world bounds (map boundaries)
    // Only prevent going completely off map edges - camera handles visibility
    if (realisticGame._mapWidth != null && realisticGame._mapHeight != null) {
      // Horizontal world bounds - prevent going off map edges
      if (position.x < 0) {
        print('[DEBUG] Car.update() - Hit LEFT boundary! position.x=$position.x, setting to 0');
        position.x = 0;
        velocity.x = 0; // Stop horizontal movement at left edge
      } else if (position.x > realisticGame._mapWidth!) {
        print('[DEBUG] Car.update() - Hit RIGHT boundary! position.x=$position.x, mapWidth=${realisticGame._mapWidth}, setting to ${realisticGame._mapWidth}');
        position.x = realisticGame._mapWidth!;
        velocity.x = 0; // Stop horizontal movement at right edge
      }
      
      // Vertical world bounds - prevent going off map edges
      if (position.y < 0) {
        print('[DEBUG] Car.update() - Hit TOP boundary! position.y=$position.y, setting to 0');
        position.y = 0;
        velocity.y = math.max(0, velocity.y); // Stop upward movement
      } else if (position.y > realisticGame._mapHeight!) {
        print('[DEBUG] Car.update() - Hit BOTTOM boundary! position.y=$position.y, mapHeight=${realisticGame._mapHeight}, setting to ${realisticGame._mapHeight}');
        position.y = realisticGame._mapHeight!;
        velocity.y = math.min(0, velocity.y); // Stop downward movement
      }
      
      // Debug boundary info periodically
      _debugFrameCount++;
      if (_debugFrameCount % 60 == 0) {
        print('[DEBUG] Car.update() - Position: $position, Map bounds: 0,0 to ${realisticGame._mapWidth},${realisticGame._mapHeight}');
        print('[DEBUG] Car.update() - Velocity: $velocity, Speed: ${velocity.length}');
      }
    } else {
      _debugFrameCount++;
      if (_debugFrameCount % 60 == 0) {
        print('[DEBUG] Car.update() - Map dimensions not set! _mapWidth=${realisticGame._mapWidth}, _mapHeight=${realisticGame._mapHeight}');
      }
    }
    
    // Visual rotation - angle is already set by steering above
    // The car sprite faces up by default, so we offset by -90 degrees (-pi/2)
    // This is already handled in the velocity rotation, so angle is correct
  }
  
  void steerLeft() {
    isSteering = true;
    steerAngle = -maxSteerAngle;
  }
  
  void steerRight() {
    isSteering = true;
    steerAngle = maxSteerAngle;
  }
  
  void setSteeringAngle(double angle) {
    isSteering = true;
    steerAngle = angle.clamp(-maxSteerAngle, maxSteerAngle);
  }
  
  void resetSteering() {
    isSteering = false;
    // Steering will gradually return to center in update method
  }
  
  void accelerate() {
    isAccelerating = true;
    isBraking = false;
  }
  
  void brake() {
    isBraking = true;
    isAccelerating = false;
  }
  
  void coast() {
    isAccelerating = false;
    isBraking = false;
  }
  
  double getCurrentSpeed() {
    return velocity.length;
  }
}

/// Engine, brake, and reverse-beep sounds using [FlameAudio] (`assets/audio/`).
/// Optional: add `accelerate.mp3` for engine loop and `brake.wav` for heavy-brake ticks.
class VehicleSfx {
  static const String _engineLoopAsset = 'accelerate.mp3';
  static const String _brakeAsset = 'brake.wav';
  static const String _reverseLoopAsset = 'Reverse_Sound.m4a';

  static const double _engineVol = 0.28;
  static const double _reverseVol = 0.24;
  static const double _brakeVol = 0.34;

  AudioPlayer? _engine;
  AudioPlayer? _reverse;
  int _engineSeq = 0;
  int _reverseSeq = 0;
  bool _wantEngine = false;
  bool _wantReverse = false;
  double _brakeRepeat = 0;

  void tick(double dt, Car? car) {
    if (car == null) return;

    final canMove = !car.isInPark && car.currentGear != 0;
    final speed = car.getCurrentSpeed();
    final wantEngine =
        car.isAccelerating && canMove && car.currentGear != -1;
    final wantReverse = car.currentGear == -1 &&
        !car.isInPark &&
        (car.isAccelerating || speed > 6);

    if (wantEngine != _wantEngine) {
      _wantEngine = wantEngine;
      if (wantEngine) {
        unawaited(_startEngine());
      } else {
        unawaited(_stopEngine());
      }
    }

    if (wantReverse != _wantReverse) {
      _wantReverse = wantReverse;
      if (wantReverse) {
        unawaited(_startReverse());
      } else {
        unawaited(_stopReverse());
      }
    }

    if (car.isBraking && speed > 14) {
      _brakeRepeat -= dt;
      if (_brakeRepeat <= 0) {
        _brakeRepeat = 0.32;
        unawaited(_playBrakeIfAvailable());
      }
    } else {
      _brakeRepeat = 0;
    }
  }

  static Future<void> _playBrakeIfAvailable() async {
    try {
      await FlameAudio.play(_brakeAsset, volume: _brakeVol);
    } catch (_) {
      // Optional asset; folder may only ship reverse / UI clips.
    }
  }

  void dispose() {
    unawaited(_stopEngine());
    unawaited(_stopReverse());
  }

  Future<void> _startEngine() async {
    await _stopEngineInternal();
    final seq = ++_engineSeq;
    try {
      final p = await FlameAudio.loop(_engineLoopAsset, volume: _engineVol);
      if (seq != _engineSeq) {
        await p.stop();
        await p.dispose();
        return;
      }
      _engine = p;
    } catch (e, st) {
      debugPrint('VehicleSfx engine loop failed: $e\n$st');
    }
  }

  Future<void> _stopEngine() async {
    _engineSeq++;
    await _stopEngineInternal();
  }

  Future<void> _stopEngineInternal() async {
    final p = _engine;
    _engine = null;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      await p.dispose();
    }
  }

  Future<void> _startReverse() async {
    await _stopReverseInternal();
    final seq = ++_reverseSeq;
    try {
      final p = await FlameAudio.loop(_reverseLoopAsset, volume: _reverseVol);
      if (seq != _reverseSeq) {
        await p.stop();
        await p.dispose();
        return;
      }
      _reverse = p;
    } catch (e, st) {
      debugPrint('VehicleSfx reverse loop failed: $e\n$st');
    }
  }

  Future<void> _stopReverse() async {
    _reverseSeq++;
    await _stopReverseInternal();
  }

  Future<void> _stopReverseInternal() async {
    final p = _reverse;
    _reverse = null;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      await p.dispose();
    }
  }
}