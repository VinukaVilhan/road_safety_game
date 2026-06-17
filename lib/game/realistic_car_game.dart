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

import '../models/driving/last_driving_report.dart';
part 'types/realistic_car_game_types.dart';
part 'map/realistic_car_game_map_helpers.dart';
part 'map/realistic_car_game_ambulance_map_loaders.dart';
part 'scenarios/realistic_car_game_ambulance_decoration.dart';
part 'scenarios/realistic_car_game_emergency_ambulance.dart';
part 'entities/realistic_car_game_car.dart';
part 'entities/realistic_car_game_ambulance.dart';
part 'audio/realistic_car_game_vehicle_sfx.dart';

class RealisticCarGame extends FlameGame with KeyboardHandler {
  Car? car; // Make car accessible - nullable to handle initialization order

  // --- Ambulance decoration (maps with Ambulance_Spawn / Ambulance_Route) ---
  /// Ambulance AI from `Ambulance_Spawn` + [Ambulance_Route] on [ambulance-reaction.tmx].
  Ambulance? _ambulanceDecoration;
  /// When the map has [Siren_Layer] rects, the ambulance is hidden until the car overlaps one.
  final List<Rect> _sirenTriggerRects = [];
  ({Vector2 position, double angle, double sirenVolume})? _ambulanceSpawnConfig;
  bool _ambulanceSirenRevealDone = false;
  AudioPlayer? _ambulanceSirenPlayer;
  static const String _ambulanceLoopAsset = 'Ambulance_Sound.m4a';
  static const double _ambulanceSirenMasterGain = 0.05;
  final List<Vector2> _ambulanceRouteWaypoints = [];
  final List<Rect> _safeZoneLeftRects = [];
  final List<Rect> _safeZoneRightRects = [];
  final List<Rect> _successLayerRects = [];

  // --- Emergency ambulance scenario (`scenarioId: emergency_ambulance`) ---

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

  bool _ambulancePullOverComplete = false;
  bool? _ambulanceYieldCompletedLeftSide;
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
  /// Pairs of zig-zag zone object ids on the same horizontal row (road-crossing).
  List<List<int>> _zigZagRowZoneIds = [];
  final List<Rect> _spawnSignRects = [];
  String _spawnSignAssetPath = 'assets/roadsigns/Pedestrian_Crossing.jpeg';
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
  final ValueNotifier<bool> pedestrianCrossingSignVisible =
      ValueNotifier<bool>(false);
  /// Metres to the nearest zebra [Zig_Zag] zone while the spawn sign HUD is shown.
  final ValueNotifier<int?> pedestrianCrossingDistanceMeters =
      ValueNotifier<int?>(null);
  bool _roadCrossingStopActive = false;
  bool _roadCrossingStopSatisfied = false;
  int? _roadCrossingStopStepId;
  double _roadCrossingStopElapsed = 0.0;
  static const double _roadCrossingStopDurationSec = 3.0;
  static const double _zigZagStoppedSpeedThreshold = 18.0;
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

  /// True while the zebra-crossing wait countdown is running (stopped in zig-zag).
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

        final layerIsZoneCheck = layerClassLower == 'zone_check' ||
            layerClassLower.startsWith('zone_check');
        final effectiveZoneClass = layerIsZoneCheck
            ? (layerClass.isNotEmpty ? layerClass : 'Zone_Check')
            : (zoneClassLower.isNotEmpty ? zoneClass : layerClass);
        final stepId = obj.properties.getValue<int>('step_id') ?? layerStepId;
        final failMessage =
            obj.properties.getValue<String>('fail_message') ?? layerFailMessage;
        final maxSpeed =
            _readZoneSpeedLimit(obj.properties, layer.properties);
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
    _rebuildZigZagRows();
    _loadSpawnSignZones(tiledMap);

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

    _loadAmbulanceRouteFromTmx(tiledMap);

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

    _loadAmbulanceDecorationMapData(objectGroupLayers);
    _loadEmergencyAmbulanceCheckpointsFromTiledMap(tiledMap.tileMap.map);
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
    pedestrianCrossingSignVisible.value = false;
    pedestrianCrossingDistanceMeters.value = null;
    _junctionBoxStoppedElapsedSec = 0.0;
    _resetEmergencyAmbulanceForRestart();
    _resetAmbulanceDecorationForRestart();
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
    _resumeAmbulanceSirenIfPaused();
  }

  @override
  void resumeEngine() {
    super.resumeEngine();
    resumeAmbientAudioAfterUiOverlay();
  }

  @override
  void onRemove() {
    _vehicleSfx.dispose();
    _disposeAmbulanceDecoration();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _vehicleSfx.tick(dt, car);
    _maybePlaceDeferredAmbulanceDecoration();
    _updateAmbulanceSirenTrigger();
    _updatePedestrianCrossingSignHud();
    _updateRoadCrossingParkCountdown(dt);
    _updateZigZagStraddleFail();
    _updateZigZagRoadCrossingRules();
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
  /// while the car is **fully stopped** (stay in gear — no Park in zig-zags).
  /// Leaving the zone or moving again pauses and resets the timer.
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
        car!.velocity.length < _zigZagStoppedSpeedThreshold;
    final waitDurationSec =
        activeWaitZone?.waitTimeSec ?? _roadCrossingStopDurationSec;

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
        // Fallback for maps where Zig_Zag wait zone has no explicit step_id.
        _lastCompletedStepId = 1;
      }
    }
  }

  bool _isRoadCrossingMap() {
    final asset = mapAsset?.toLowerCase() ?? '';
    return asset.contains('road-crossing');
  }

  bool _isSpawnSignLabel(String raw) {
    final v = raw.trim().toLowerCase().replaceAll(' ', '_');
    return v == 'spawn_sign' || v.contains('spawn_sign');
  }

  void _loadSpawnSignZones(TiledComponent tiledMap) {
    _spawnSignRects.clear();
    _spawnSignAssetPath = 'assets/roadsigns/Pedestrian_Crossing.jpeg';

    for (final layer in tiledMap.tileMap.map.layers.whereType<ObjectGroup>()) {
      final layerClassLower = (layer.class_ ?? '').trim().toLowerCase();
      final layerNameLower = layer.name.trim().toLowerCase();
      final layerIsSpawnSign = _isSpawnSignLabel(layerClassLower) ||
          _isSpawnSignLabel(layerNameLower);

      final customAsset = layer.properties.getValue<String>('sign_asset') ??
          layer.properties.getValue<String>('sign_image');
      if (customAsset != null && customAsset.trim().isNotEmpty) {
        _spawnSignAssetPath = customAsset.trim();
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
        if (!layerIsSpawnSign &&
            !_isSpawnSignLabel(objectClass) &&
            !_isSpawnSignLabel(objectType) &&
            !_isSpawnSignLabel(objectName)) {
          continue;
        }

        _spawnSignRects.add(
          Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height),
        );
      }
    }
    print(
      '[DEBUG] _setupRoad() - Spawn sign rects: ${_spawnSignRects.length} asset=$_spawnSignAssetPath',
    );
  }

  void _updatePedestrianCrossingSignHud() {
    if (!_isRoadCrossingMap() || _testFinished || car == null) {
      if (pedestrianCrossingDistanceMeters.value != null) {
        pedestrianCrossingDistanceMeters.value = null;
      }
      return;
    }

    if (!pedestrianCrossingSignVisible.value && _spawnSignRects.isNotEmpty) {
      final carRect = Rect.fromCenter(
        center: Offset(car!.position.x, car!.position.y),
        width: car!.size.x,
        height: car!.size.y,
      );
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

  /// Asset path for the HUD sign shown after [Spawn_Sign] zone entry.
  String get spawnSignAssetPath => _spawnSignAssetPath;

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

  /// Zig-zag rects on the same horizontal row share overlapping Y ranges (Tiled pairs).
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

  /// Fail when any wheel touches two zig-zag zones on the same row (straddling lanes).
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

  double _distancePointToRect(Offset p, Rect r) {
    final dx = p.dx < r.left
        ? r.left - p.dx
        : (p.dx > r.right ? p.dx - r.right : 0.0);
    final dy = p.dy < r.top
        ? r.top - p.dy
        : (p.dy > r.bottom ? p.dy - r.bottom : 0.0);
    return math.sqrt((dx * dx) + (dy * dy));
  }

  /// Approximate wheel contact points in world space (used for zig-zag wait + fail zones).
  List<Offset> _carWheelWorldPoints() {
    final c = car;
    if (c == null) return const [];
    final center = c.position;
    final halfW = c.size.x / 2;
    final halfH = c.size.y / 2;
    final cosA = math.cos(c.angle);
    final sinA = math.sin(c.angle);

    final wheelOffsets = <Offset>[
      Offset(-halfW * 0.7, -halfH * 0.7),
      Offset(halfW * 0.7, -halfH * 0.7),
      Offset(-halfW * 0.7, halfH * 0.7),
      Offset(halfW * 0.7, halfH * 0.7),
    ];

    final points = <Offset>[];
    for (final o in wheelOffsets) {
      final rx = (o.dx * cosA) - (o.dy * sinA);
      final ry = (o.dx * sinA) + (o.dy * cosA);
      points.add(Offset(center.x + rx, center.y + ry));
    }
    return points;
  }

  bool _areAllWheelsInsideRect(Rect zoneRect) {
    for (final wheelPoint in _carWheelWorldPoints()) {
      if (!zoneRect.contains(wheelPoint)) return false;
    }
    return _carWheelWorldPoints().isNotEmpty;
  }

  bool _anyWheelInsideRect(Rect zoneRect) {
    for (final wheelPoint in _carWheelWorldPoints()) {
      if (zoneRect.contains(wheelPoint)) return true;
    }
    return false;
  }

  bool _carContactsDrivingZone(_DrivingZone zone, Rect carRect) {
    final zoneKind = _zoneKindForScenario(zone.zoneClass);
    // Thin fail strips (e.g. road-crossing wrong-turn) can be shorter than the car.
    if (zoneKind == 'zone_fail_wt' || zoneKind == 'zone_fail_it') {
      return _anyWheelInsideRect(zone.rect);
    }
    return carRect.overlaps(zone.rect);
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
      if (zoneKind != 'zone_speedlimit' &&
          zoneKind != 'zig_zag' &&
          zoneKind != 'zone_check' &&
          zoneLimit == null) {
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
    if (normalized == 'wrong_turn_layer' || normalized.startsWith('wrong_turn_layer')) {
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
        v.startsWith('zig_zag') ||
        v == 'wrong_layer' ||
        v.startsWith('wrong_layer') ||
        v == 'wrong_turn_layer' ||
        v.startsWith('wrong_turn_layer');
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
    AmbulanceAttemptSnapshot? ambSnap = _buildAmbulanceAttemptSnapshot();

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
      if (!_carContactsDrivingZone(zone, carRect)) continue;
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
          : (_isRoadCrossingMap()
              ? 'Wrong route — cross via the zebra markings; do not continue past the stop line.'
              : 'Wrong Turn!');
      final message =
          zone.failMessage?.isNotEmpty == true ? zone.failMessage! : defaultMessage;
      _failTest(message);
      return;
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