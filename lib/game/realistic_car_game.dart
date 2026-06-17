import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'
    show Canvas, Color, Offset, Paint, Path, PictureRecorder, Radius, Rect, RRect;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/last_driving_report.dart';
part 'realistic_car_game_types.dart';
part 'realistic_car_game_map_helpers.dart';
part 'realistic_car_game_car.dart';
part 'realistic_car_game_ambulance.dart';
part 'realistic_car_game_vehicle_sfx.dart';

class RealisticCarGame extends FlameGame with KeyboardHandler {
  Car? car; // Make car accessible - nullable to handle initialization order
  /// Ambulance AI from `Ambulance_Spawn` + [Ambulance_Route] on [ambulance-reaction.tmx].
  Ambulance? _ambulanceDecoration;
  /// When the map has [Siren_Layer] rects, the ambulance is hidden until the car overlaps one.
  final List<Rect> _sirenTriggerRects = [];
  ({Vector2 position, double angle, double sirenVolume})? _ambulanceSpawnConfig;
  bool _ambulanceSirenRevealDone = false;
  AudioPlayer? _ambulanceSirenPlayer;

  /// Looping `assets/audio/Ambulance_Sound.m4a` while the ambulance is active (spawn or Siren_Layer reveal).
  static const String _ambulanceLoopAsset = 'Ambulance_Sound.m4a';

  /// Applied after TMX `sirenVolume` / spawn config so the siren sits under engine/UI in the mix.
  static const double _ambulanceSirenMasterGain = 0.05;

  /// One-shot police whistle when a driving rule is broken (see [_playRuleBreakWhistle]).
  static const String _ruleBreakWhistleAsset = 'Whistle_Sound.m4a';
  late SpriteComponent roadBackground;
  double roadSpeed = 200.0;
  List<TiledComponent> roadTiles = [];
  bool _roadInitialized = false;
  /// Single shared future so [onGameResize] and [onLoad] cannot run [_setupRoad] concurrently.
  Future<void>? _setupRoadFuture;
  double? _mapWidth;
  double? _mapHeight;
  double _baseLayerFriction = 400.0; // default fallback friction
  final List<Rect> _wallRects = [];
  Vector2? _spawnPoint;

  /// World waypoints from Tiled `Ambulance_Route` / class `AmbulanceRoute` (polygon or polyline).
  final List<Vector2> _ambulanceRouteWaypoints = [];

  /// [ambulance-reaction.tmx]: pull over zones (`Safe_Zone_Left` / `Safe_Zone_Right`).
  final List<Rect> _safeZoneLeftRects = [];
  final List<Rect> _safeZoneRightRects = [];
  /// Win trigger after the ambulance has cleared its route ([Success_Layer]).
  final List<Rect> _successLayerRects = [];

  /// [emergency_ambulance]: parked in matching safe zone with correct signal; ambulance may pass
  /// once true (then signal may be cancelled while staying in P in that zone).
  bool _ambulancePullOverComplete = false;

  /// Locked when stage 1 completes: `true` = left safe zone sequence, `false` = right.
  bool? _ambulanceYieldCompletedLeftSide;

  /// [emergency_ambulance]: CP1–CP4 and CPF rects from TMX (including nested under [Group]).
  final List<_AmbulanceCheckpoint> _ambCheckpoints = [];
  bool _ambCp1Cleared = false;
  bool _ambCp2Cleared = false;
  double _ambCpElapsed = 0.0;
  double _ambTotalElapsed = 0.0;

  static const double _ambCpDefaultTimeLimitSecs = 40.0;
  static const double _ambLevelTimeoutSecs = 180.0;

  /// Preferred camera zoom level (> 1 = zoom in, < 1 = zoom out).
  /// Final zoom is clamped so camera never shows outside-map void.
  static const double preferredCameraZoom = 1.4;

  /// Impact speed (world units/sec, same scale as [Car.maxSpeed]) at or above which
  /// hitting a Collision_Box / Obstacles_Layer wall fails the test as a crash.
  static const double wallHighSpeedCrashThreshold = 125.0;

  /// Converts world-space travel (same units as [Car.velocity]) to metres for the odometer.
  static const double worldUnitsToMeters = 0.022;

  /// Optional TMX map path (e.g. 'assets/tiles/T-junction-left.tmx'). If null, default map is used.
  final String? mapAsset;
  /// Optional scenario key to alter objective routing on a shared map.
  final String? scenarioId;
  final void Function(String message)? onTestFailed;
  final VoidCallback? onTestPassed;

  /// Optional: called when a non-fatal penalty is recorded (e.g. dashed-lines signalling).
  final void Function(String description)? onPenaltyRecorded;

  /// Optional: approximate distance driven this session (metres) for profile / stats.
  final void Function(double deltaMeters)? onOdometerDeltaMeters;

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
  final List<String> _penalties = [];
  /// Approach zones the car is currently overlapping (dashed level — exit detection).
  final Set<int> _approachZonesCurrentlyInside = {};
  /// Approach zones where the right signal was turned on during the current visit.
  final Set<int> _approachZonesRightSignalGiven = {};
  /// Mid-turn zones the car center is currently inside ([markings_dashed]).
  final Set<int> _midTurnZonesCurrentlyInside = {};
  /// Mid-turn zones where a wrong-signal penalty has already been issued this visit.
  /// Cleared on zone exit so re-entry can be penalized again.
  final Set<int> _midTurnZonesWrongSignalPenaltyIssued = {};
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
    this.onPenaltyRecorded,
    this.onOdometerDeltaMeters,
    this.turnSignalLeft,
    this.turnSignalRight,
  });

  bool get _isEmergencyAmbulanceScenario =>
      (scenarioId ?? '').trim().toLowerCase() == 'emergency_ambulance';

  /// Dashed lane markings level: non-fatal penalties + Wrong_Layer fail.
  /// Never mixed with the ambulance scenario (even if the TMX was copied from a dashed map).
  bool get _usesPenaltyModeMarkingsDashed {
    if (_isEmergencyAmbulanceScenario) return false;
    final a = (mapAsset ?? '').toLowerCase();
    final s = (scenarioId ?? '').toLowerCase();
    return a.contains('lane-markings-dashed') || s == 'markings_dashed';
  }

  void reportOdometerMeters(double deltaMeters) {
    if (_testFinished) return;
    if (deltaMeters <= 0 || deltaMeters.isNaN || deltaMeters.isInfinite) return;
    onOdometerDeltaMeters?.call(deltaMeters);
  }

  /// True while the zebra-crossing wait countdown is running (car in zone + Park).
  bool get isRoadCrossingStopActive => _roadCrossingStopActive;
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    _attemptStartedAt = DateTime.now();

    // Tell audioplayers to never request AudioFocus on Android.
    // This prevents just_audio UI sounds from stealing focus away from the
    // engine / siren loops and silencing them.
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          stayAwake: false,
          isSpeakerphoneOn: false,
        ),
      ));
    } catch (_) {}

    // Only preload assets that exist under assets/audio/ (see pubspec assets).
    try {
      await FlameAudio.audioCache.loadAll([
        'Car_Start.m4a',
        'Car_Idle.m4a',
        'Reverse_Sound.m4a',
      ]);
    } catch (e, st) {
      debugPrint('Vehicle SFX preload failed: $e\n$st');
    }
    try {
      await FlameAudio.audioCache.load(_ambulanceLoopAsset);
    } catch (_) {
      // Optional: add assets/audio/Ambulance_Sound.m4a for ambulance-reaction level.
    }
    try {
      await FlameAudio.audioCache.load(_ruleBreakWhistleAsset);
    } catch (_) {
      // Optional: add assets/audio/Whistle_Sound.m4a for rule-failure feedback.
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
      await _ensureRoadSetup();
    }
    // Otherwise, onGameResize will handle it
    
    // Add the car after road so it renders on top (Flame runs [Car.onLoad]; do not call it twice).
    final newCar = Car();
    newCar.priority = 1; // Higher priority - renders on top of road
    world.add(newCar);
    await newCar.loaded;
    car = newCar;
    if (_spawnPoint != null) {
      car!.position.setFrom(_spawnPoint!);
    }
    camera.viewfinder.position = car!.position.clone();
    camera.follow(car!, snap: true);
    print('[DEBUG] onLoad() - Car added to WORLD at position: ${car!.position}');
  }
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    print('[DEBUG] onGameResize() - New size: ${size.x} x ${size.y}');
    
    // Initialize road tiles when size is known
    if (!_roadInitialized && size.x > 0 && size.y > 0) {
      unawaited(_ensureRoadSetup());
    }
    // Re-apply bounds after resize/orientation changes to avoid clipped camera limits.
    if (_roadInitialized) {
      _applyCameraZoomForViewport();
      _applyCameraBounds();
    }
  }

  /// Ensures [_setupRoad] runs at most once; concurrent callers share the same future.
  Future<void> _ensureRoadSetup() {
    _setupRoadFuture ??= _setupRoad();
    return _setupRoadFuture!;
  }
  
  Future<void> _setupRoad() async {
    if (_roadInitialized) return;

    _ambCheckpoints.clear();
    
    // Remove existing tiles if any
    for (var tile in roadTiles) {
      remove(tile);
    }
    roadTiles.clear();
    
    final tmxPath = mapAsset ?? 'town_tiles_2.tmx';
    print(
      '[DEBUG] _setupRoad() - Loading TMX: $tmxPath '
      '(mapAsset=${mapAsset ?? "(default)"})',
    );
    // Load the Tiled map
    final tiledMap = await TiledComponent.load(
      tmxPath,
      Vector2.all(16), // Tile size from TMX file (16x16)
    );
    
    // Calculate and store map dimensions
    _mapWidth = tiledMap.tileMap.map.width * 16.0; // 16 is tile width
    _mapHeight = tiledMap.tileMap.map.height * 16.0; // 16 is tile height
    print('[DEBUG] _setupRoad() - Map dimensions (px): ${_mapWidth} x ${_mapHeight}');
    print('[DEBUG] _setupRoad() - Map size (tiles): ${tiledMap.tileMap.map.width} x ${tiledMap.tileMap.map.height}');

    final objectGroupLayers =
        tiledMap.tileMap.map.layers.whereType<ObjectGroup>().toList();
    print('[DEBUG] _setupRoad() - ObjectGroup layers (${objectGroupLayers.length}):');
    for (final og in objectGroupLayers) {
      final tag = _tiledLayerTag(og);
      final cls = (og.class_ ?? '').trim();
      final clsTag = cls.replaceAll(' ', '_').toLowerCase();
      final spawnRelated = tag.contains('spawn') || clsTag.contains('spawn');
      final marker = spawnRelated ? ' [spawn-related]' : '';
      print(
        '[DEBUG]   - name="${og.name}" class="$cls" objects=${og.objects.length}$marker',
      );
    }

    // Read spawn point (prefer Player_Spawn over Ambulance_Spawn marker layers).
    _spawnPoint = _pickPlayerSpawnFromObjectGroups(objectGroupLayers);
    if (_spawnPoint != null) {
      print('[DEBUG] _setupRoad() - Resolved player spawn (world px): $_spawnPoint');
    } else {
      print(
        '[DEBUG] _setupRoad() - WARNING: no player spawn in TMX; '
        'Car will use map centre until layers match _pickPlayerSpawn rules',
      );
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

    // Ambulance tether route: layer name `Ambulance_Route` and/or class `AmbulanceRoute`.
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
    _loadAmbulanceCheckpointsFromTiledMap(tiledMap.tileMap.map);
    await _setupAmbulanceDecorationFromTmx(objectGroupLayers);
    
    _roadInitialized = true;
    
    // Set camera bounds so the view never shows past the map edges (no black void).
    // Without considerViewport, the camera centre can reach spawns near map edges
    // (e.g. portrait layout before landscape lock would otherwise clamp Y too high).
    _applyCameraZoomForViewport();
    _applyCameraBounds();
    
    // Follow the car (if already in world); otherwise Car.onMount will call follow
    if (car != null && car!.isMounted) {
      if (_spawnPoint != null) {
        car!.position = _spawnPoint!.clone();
        camera.viewfinder.position = _spawnPoint!.clone();
      }
      camera.follow(car!, snap: true);
    }
  }

  void _applyCameraBounds() {
    if (_mapWidth == null || _mapHeight == null) return;
    final mapBounds = Rect.fromLTWH(0, 0, _mapWidth!, _mapHeight!);
    camera.setBounds(Rectangle.fromRect(mapBounds));
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

    // No siren triggers: place once [car] exists (see [_maybePlaceDeferredAmbulanceDecoration]).
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
      final v = (volume * _ambulanceSirenMasterGain).clamp(0.0, 1.0);
      _ambulanceSirenPlayer = await FlameAudio.loop(
        _ambulanceLoopAsset,
        volume: v,
      );
    } catch (e, st) {
      debugPrint(
        'Ambulance loop failed (add assets/audio/$_ambulanceLoopAsset): $e\n$st',
      );
    }
  }

  Future<void> _playRuleBreakWhistle() async {
    try {
      await FlameAudio.play(
        _ruleBreakWhistleAsset,
        volume: 0.88,
      );
    } catch (e, st) {
      debugPrint(
        'Rule-break whistle failed (add assets/audio/$_ruleBreakWhistleAsset): $e\n$st',
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

  /// Reset scenario after failure so the player can retry without replacing [GameScreen]
  /// (avoids dispose/orientation races with `Navigator.pushReplacement`).
  void restartLevel() {
    _vehicleSfx.resetForLevelRestart();
    _testFinished = false;
    _zonesInsidePreviousFrame.clear();
    _lastCompletedStepId = 0;
    _attemptStartedAt = DateTime.now();
    _enteredApproachZone = false;
    _signalOkInApproachZone = false;
    _enteredMidTurnZone = false;
    _midTurnSignalWasCorrect = false;
    _reachedFinishZone = false;
    _penalties.clear();
    _approachZonesCurrentlyInside.clear();
    _approachZonesRightSignalGiven.clear();
    _midTurnZonesCurrentlyInside.clear();
    _midTurnZonesWrongSignalPenaltyIssued.clear();
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
    _ambulancePullOverComplete = false;
    _ambulanceYieldCompletedLeftSide = null;
    _ambCp1Cleared = false;
    _ambCp2Cleared = false;
    _ambCpElapsed = 0.0;
    _ambTotalElapsed = 0.0;
    _ambulanceDecoration?.removeFromParent();
    _ambulanceDecoration = null;
    _ambulanceSirenRevealDone = false;
    unawaited(_stopAmbulanceSiren());
    if (_ambulanceSpawnConfig != null && _sirenTriggerRects.isEmpty) {
      unawaited(_placeAmbulanceDecoration(_ambulanceSpawnConfig!));
    }
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
    c.markOdometerTeleport();
    c.pathHistory.clear();
    camera.follow(c, snap: true);
    resumeAmbientAudioAfterUiOverlay();
  }

  /// After route overlays or OS audio ducking, [audioplayers] loops can stay paused
  /// while state still expects them to run. Safe to call from UI when dialogs close.
  void resumeAmbientAudioAfterUiOverlay() {
    _vehicleSfx.resumePausedOutputs();
    final siren = _ambulanceSirenPlayer;
    if (siren != null && siren.state == PlayerState.paused) {
      unawaited(siren.resume());
    }
  }

  @override
  void resumeEngine() {
    super.resumeEngine();
    resumeAmbientAudioAfterUiOverlay();
  }

  @override
  void onRemove() {
    _vehicleSfx.dispose();
    _ambulanceDecoration?.removeFromParent();
    _ambulanceDecoration = null;
    unawaited(_stopAmbulanceSiren());
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _vehicleSfx.tick(dt, car);
    _maybePlaceDeferredAmbulanceDecoration();
    _updateAmbulanceSirenTrigger();
    _updateRoadCrossingApproachHint();
    _updateRoadCrossingParkCountdown(dt);
    _enforceSpeedLimitZones();
    _updateMarkingsDashedYellowZoneRules();
    _updateMidTurnSignalValidation();
    _updateDrivingRuleZones();
    _updateJunctionBoxStopFail(dt);
    // Checkpoints before pull-over (CP overlap can occur same frame as pull-over update).
    _updateAmbulanceCheckpoints(dt);
    _updateAmbulancePullOverState();
    _updateAmbulanceLevelSuccess();
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
    // With safe zones, pull-over must be completed ([_updateAmbulancePullOverState]).
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

  /// Safe-zone pull-over: complete when Park + overlap matching zone + correct exclusive
  /// signal. After that, signal may be cancelled while the car stays in P in that zone.
  void _updateAmbulancePullOverState() {
    if (scenarioId != 'emergency_ambulance' || _testFinished || car == null) {
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

  void _loadAmbulanceCheckpointsFromTiledMap(TiledMap map) {
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
              ? _ambCpDefaultTimeLimitSecs
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

  void _updateAmbulanceCheckpoints(double dt) {
    if (scenarioId != 'emergency_ambulance' || _testFinished || car == null) {
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
    if (_ambTotalElapsed > _ambLevelTimeoutSecs) {
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

    // After CP2, the player must complete pull-over before crossing CPF (Tiled final gate).
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
    if (scenarioId != 'emergency_ambulance') return;
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
    // Tiled often sets object type to Zone_Approach on yellow approach rects (lane-markings-dashed, etc.).
    if (normalized == 'zone_approach' || normalized.startsWith('zone_approach')) {
      return 'zone_check';
    }
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
    if (normalized == 'wrong_layer' || normalized.startsWith('wrong_layer')) {
      return 'wrong_layer';
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
        v.startsWith('zig_zag') ||
        v == 'wrong_layer' ||
        v.startsWith('wrong_layer');
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
    var effectivePassed = passed ?? (_testFinished && resolvedFailure == null);
    if (_usesPenaltyModeMarkingsDashed &&
        effectivePassed &&
        _penalties.isNotEmpty) {
      effectivePassed = false;
    }
    String? failureOut = resolvedFailure;
    if (!effectivePassed &&
        failureOut == null &&
        _usesPenaltyModeMarkingsDashed &&
        _penalties.isNotEmpty &&
        _testFinished &&
        _reachedFinishZone) {
      failureOut =
          'You reached the finish but had driving rule penalties — attempt did not pass.';
    }
    AmbulanceAttemptSnapshot? ambSnap;
    if (_isEmergencyAmbulanceScenario) {
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
      ambSnap = AmbulanceAttemptSnapshot(
        mapHasCp1: cp1 != null,
        mapHasCp2: cp2 != null,
        mapHasCpf: cpf != null,
        cp1Cleared: _ambCp1Cleared,
        cp2Cleared: _ambCp2Cleared,
        pullOverCompleted: _ambulancePullOverComplete,
        yieldLeftSide: _ambulanceYieldCompletedLeftSide,
        elapsedSecs: _ambTotalElapsed,
        levelTimeoutSecs: _ambLevelTimeoutSecs,
        cp1TimeLimitSecs: cp1?.timeLimitSecs ?? 0,
        cp2TimeLimitSecs: cp2?.timeLimitSecs ?? 0,
        ambulanceRouteCompleted: deco?.routeCompleted ?? false,
        ambulanceAiState: deco == null ? 'none' : deco.state.name,
      );
    }

    return DrivingAttemptSummary(
      passed: effectivePassed,
      failureMessage: failureOut,
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
      penalties: List<String>.unmodifiable(_penalties),
      ambulance: ambSnap,
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

  void _recordPenalty(String description, {bool playWhistle = true}) {
    if (_testFinished) return;
    _penalties.add(description);
    if (playWhistle && _usesPenaltyModeMarkingsDashed) {
      unawaited(_playRuleBreakWhistle());
    }
    onPenaltyRecorded?.call(description);
  }

  /// [lane-markings-dashed]: the driver must turn the **right** signal on (left off)
  /// at some point **before leaving** the yellow approach zone. A penalty fires on
  /// exit if the right signal was never turned on during that visit.
  void _updateMarkingsDashedYellowZoneRules() {
    if (!_usesPenaltyModeMarkingsDashed ||
        _testFinished ||
        car == null ||
        turnSignalLeft == null ||
        turnSignalRight == null) {
      return;
    }

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    final rightOn = turnSignalRight!.value;
    final leftOn = turnSignalLeft!.value;
    final approachOk = rightOn && !leftOn;

    final nowInside = <int>{};

    for (final zone in _drivingZones) {
      if (_zoneKindForScenario(zone.zoneClass) != 'zone_check') continue;

      if (carRect.overlaps(zone.rect)) {
        nowInside.add(zone.objectId);
        if (approachOk) {
          _signalOkInApproachZone = true;
          _approachZonesRightSignalGiven.add(zone.objectId);
        }
      } else if (_approachZonesCurrentlyInside.contains(zone.objectId)) {
        // Car just exited this approach zone.
        if (!_approachZonesRightSignalGiven.contains(zone.objectId)) {
          _recordPenalty(
            'Right turn signal was not used before leaving the yellow approach zone.',
          );
        }
        _approachZonesRightSignalGiven.remove(zone.objectId);
      }
    }

    _approachZonesCurrentlyInside
      ..clear()
      ..addAll(nowInside);
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
    if (_isEmergencyAmbulanceScenario) return;
    if (_testFinished ||
        car == null ||
        _midTurnZones.isEmpty ||
        turnSignalLeft == null ||
        turnSignalRight == null) {
      return;
    }

    if (_usesPenaltyModeMarkingsDashed) {
      _updateMidTurnSignalValidationPenaltyMode();
    } else {
      _updateMidTurnSignalValidationFailMode();
    }
  }

  /// Junction-style maps: wrong signal while inside mid-turn zone fails the run.
  void _updateMidTurnSignalValidationFailMode() {
    final leftOn = turnSignalLeft!.value;
    final rightOn = turnSignalRight!.value;
    final center = Offset(car!.position.x, car!.position.y);

    // Re-check every frame while the car is inside a zone so turning a signal
    // on/off mid-junction is still validated (e.g. straight path + blinker on).
    for (final zone in _midTurnZones) {
      if (!zone.hitPath.contains(center)) continue;
      _enteredMidTurnZone = true;
      if (!_turnSignalsMatchExpected(zone.expectedSignal, leftOn, rightOn)) {
        final message = _midTurnFailMessage(zone, leftOn, rightOn);
        _failTest(message);
        return;
      }
      _midTurnSignalWasCorrect = true;
    }
  }

  /// True if [center] is inside the mid-turn hit path, with a small padding so boundary
  /// float errors do not miss a frame the player is clearly in the zone.
  bool _carCenterInMidTurnZone(_MidTurnZone zone, Offset center) {
    if (zone.hitPath.contains(center)) return true;
    final b = zone.hitPath.getBounds();
    if (b.isEmpty ||
        !b.left.isFinite ||
        !b.top.isFinite ||
        !b.right.isFinite ||
        !b.bottom.isFinite) {
      return false;
    }
    const pad = 6.0;
    return Rect.fromLTRB(
      b.left - pad,
      b.top - pad,
      b.right + pad,
      b.bottom + pad,
    ).contains(center);
  }

  /// Dashed markings: the expected signal must be **on the whole time** the car is inside
  /// the purple mid-turn zone — from entry to exit. The first frame the signal is wrong
  /// while inside issues one penalty; the penalty flag resets on zone exit.
  void _updateMidTurnSignalValidationPenaltyMode() {
    final leftOn = turnSignalLeft!.value;
    final rightOn = turnSignalRight!.value;
    final center = Offset(car!.position.x, car!.position.y);
    final nowInside = <int>{};

    for (final zone in _midTurnZones) {
      final id = zone.objectId;
      final inside = _carCenterInMidTurnZone(zone, center);

      if (inside) {
        nowInside.add(id);
        _enteredMidTurnZone = true;
        final signalOk = _turnSignalsMatchExpected(zone.expectedSignal, leftOn, rightOn);
        if (signalOk) {
          // Signal is correct this frame — mark success and allow re-penalizing if
          // they turn the signal off again later in the same visit.
          _midTurnSignalWasCorrect = true;
          _midTurnZonesWrongSignalPenaltyIssued.remove(id);
        } else if (!_midTurnZonesWrongSignalPenaltyIssued.contains(id)) {
          // Signal is wrong and we haven't penalized yet this spell → penalty.
          _midTurnZonesWrongSignalPenaltyIssued.add(id);
          _midTurnSignalWasCorrect = false;
          _recordPenalty(_midTurnPenaltyDescription(zone, leftOn, rightOn));
        }
      } else if (_midTurnZonesCurrentlyInside.contains(id)) {
        // Car just exited — reset so re-entry gets a clean slate.
        _midTurnZonesWrongSignalPenaltyIssued.remove(id);
      }
    }

    _midTurnZonesCurrentlyInside
      ..clear()
      ..addAll(nowInside);
  }

  String _midTurnPenaltyDescription(_MidTurnZone zone, bool leftOn, bool rightOn) {
    final exp = zone.expectedSignal;
    if (exp == 'right') {
      return 'Right turn signal must be on throughout the purple turn zone.';
    }
    if (exp == 'left') {
      return 'Left turn signal must be on throughout the purple turn zone.';
    }
    return _midTurnFailMessage(zone, leftOn, rightOn);
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

  void _failTest(String message) {
    if (_testFinished) return;
    _testFinished = true;
    car?.coast();
    _latestFailureMessage = message;
    unawaited(_playRuleBreakWhistle());
    onTestFailed?.call(message);
  }

  void _failStoppedInJunctionBox(String message) {
    _failTest(message);
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
    if (_isEmergencyAmbulanceScenario) return;
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

    if (zoneKind == 'wrong_layer') {
      _recordPenalty(
        'Entered the wrong lane / prohibited area.',
        playWhistle: false,
      );
      _failTest(
        zone.failMessage?.isNotEmpty == true
            ? zone.failMessage!
            : 'Wrong turn — you entered the wrong lane.',
      );
      return;
    }

    if (zoneKind == 'zone_fail_wt' || zoneKind == 'zone_fail_it') {
      final defaultMessage = zoneKind == 'zone_fail_it'
          ? 'Driving in oncoming traffic!'
          : 'Wrong Turn!';
      final message =
          zone.failMessage?.isNotEmpty == true ? zone.failMessage! : defaultMessage;
      _failTest(message);
    }
  }

  void _failFromHighSpeedWallCrash() {
    _failTest('High-speed crash! You hit an obstacle too fast.');
  }
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    return false;
  }
}