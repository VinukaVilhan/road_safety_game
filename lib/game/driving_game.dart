import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'
    show BlurStyle, BlendMode, Canvas, Color, MaskFilter, Offset, Paint, Path, PictureRecorder, Radius, Rect, RRect;

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient, RadialGradient;
import 'package:flutter/services.dart';

import '../constants/media_assets.dart';
import '../models/driving/last_driving_report.dart';
import '../services/audio/driving_audio_levels.dart';
import '../services/audio/weather_sfx_service.dart';
import 'effects/rain_viewport_overlay.dart';
import 'effects/thunder_flash_overlay.dart';
import 'effects/weather_effects_log.dart';
part 'types/types.dart';
part 'map/map_helpers.dart';
part 'map/tiled_map_loader.dart';
part 'map/ambulance_map_loaders.dart';
part 'scenarios/ambulance_decoration.dart';
part 'scenarios/emergency_ambulance.dart';
part 'scenarios/emergency_weather.dart';
part 'scenarios/weather_rule_zones.dart';
part 'entities/car_facing.dart';
part 'entities/car.dart';
part 'entities/ambulance.dart';
part 'effects/car_headlights.dart';
part 'audio/vehicle_sfx.dart';
part 'zones/zone_helpers.dart';
part 'zones/road_crossing_zones.dart';
part 'zones/mid_turn_zones.dart';
part 'zones/junction_box_zones.dart';
part 'zones/driving_rule_zones.dart';
part 'zones/attempt_scoring.dart';

abstract class RealisticCarGameBase extends FlameGame with KeyboardHandler {
  Car? car; // Make car accessible - nullable to handle initialization order

  // --- Ambulance decoration (maps with Ambulance_Spawn / Ambulance_Route) ---
  /// Ambulance AI from `Ambulance_Spawn` + [Ambulance_Route] on [ambulance-reaction.tmx].
  Ambulance? _ambulanceDecoration;
  /// When the map has [Siren_Layer] rects, the ambulance is hidden until the car overlaps one.
  final List<Rect> _sirenTriggerRects = [];
  ({Vector2 position, double angle, double sirenVolume})? _ambulanceSpawnConfig;
  bool _ambulanceSirenRevealDone = false;
  AudioPlayer? _ambulanceSirenPlayer;
  static const double _ambulanceSirenMasterGain = 0.05;
  final List<Vector2> _ambulanceRouteWaypoints = [];
  final List<Rect> _safeZoneLeftRects = [];
  final List<Rect> _safeZoneRightRects = [];
  final List<Rect> _successLayerRects = [];

  // --- Emergency weather scenario (`scenarioId: emergency_weather`) ---
  bool _weatherEffectsMounted = false;
  RainVisibilityDimOverlay? _weatherDimOverlay;
  RainViewportOverlay? _weatherRainOverlay;
  ThunderFlashOverlay? _weatherThunderOverlay;
  double _thunderCountdownSec = 8.0;
  final math.Random _thunderRandom = math.Random();
  String? _weatherLevelId;
  double _weatherMountRetryTimer = 0;
  double _weatherHealthLogTimer = 0;

  // --- Adverse weather TMX zones (Check_Layer / Speed_Layer) ---
  _WeatherRectZone? _weatherCheckZone;
  _WeatherRectZone? _weatherSpeedZone;
  Rect? _weatherFinishRect;
  int? _weatherFinishRequiredStep;
  bool _weatherEnteredCheckZone = false;
  bool _weatherCheckRequirementsMet = false;
  bool _weatherHeadlightsActive = false;
  bool _weatherWindshieldActive = false;
  bool _weatherCheckPromptShown = false;
  /// When false, the car is treated as already inside the check zone (e.g. spawn
  /// overlap) and the popup waits until the player leaves and re-enters.
  bool _weatherCheckPromptArmed = true;
  bool _weatherInsideCheckZone = false;
  bool _weatherInsideSpeedZone = false;
  bool _weatherEverEnteredSpeedZone = false;
  bool _weatherSpeedPenaltyIssued = false;
  double _weatherMaxSpeedInSpeedZone = 0;
  int? _weatherSpeedLimit;
  String? _weatherSpeedMessage;
  bool _weatherRequireHeadlights = true;
  bool _weatherRequireWindshield = true;
  String _weatherPopupTitle = 'Prepare for rain';
  String _weatherPopupMessage =
      'Turn on headlights and windshield wipers before continuing.';
  final ValueNotifier<WeatherSpeedHudHint?> weatherSpeedHud =
      ValueNotifier<WeatherSpeedHudHint?>(null);

  // --- Emergency ambulance scenario (`scenarioId: emergency_ambulance`) ---

  /// One-shot police whistle when a driving rule is broken (see [_playRuleBreakWhistle]).
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

  /// Multiplier on map travel only — [Car.getCurrentSpeed] / HUD still use raw [Car.velocity].
  static const double worldTravelScale = 2.0;

  /// Optional TMX map path (e.g. 'assets/tiles/T-junction-left.tmx'). If null, default map is used.
  final String? mapAsset;
  /// Optional level id for diagnostics (e.g. `emergency_weather`).
  final String? levelId;
  /// Optional scenario key to alter objective routing on a shared map.
  final String? scenarioId;
  /// When false, TMX driving zones / mid-turn validation are not loaded or enforced.
  final bool drivingRulesEnabled;
  final void Function(String message)? onTestFailed;
  final VoidCallback? onTestPassed;

  /// Optional: called when a non-fatal penalty is recorded (e.g. dashed-lines signalling).
  final void Function(String description)? onPenaltyRecorded;

  /// Adverse weather: show lights/wipers popup when entering [Check_Layer].
  final void Function(WeatherCheckPromptRequest request)? onWeatherCheckPrompt;

  /// Optional: approximate distance driven this session (metres) for profile / stats.
  final void Function(double deltaMeters)? onOdometerDeltaMeters;

  /// Synced from [GameScreen] turn-signal UI; required for [Zone_MidTurn] checks.
  final ValueNotifier<bool>? turnSignalLeft;
  final ValueNotifier<bool>? turnSignalRight;

  final List<_DrivingZone> _drivingZones = [];
  /// Pairs of zig-zag zone object ids on the same horizontal row (road-crossing).
  List<List<int>> _zigZagRowZoneIds = [];
  final List<Rect> _spawnSignRects = [];
  String _spawnSignAssetPath = MediaAssets.pedestrianCrossingSign;
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

  /// False after [endLessonAudio] — blocks engine / rain / siren from starting again.
  bool _lessonAudioActive = true;
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

  RealisticCarGameBase({
    this.mapAsset,
    this.levelId,
    this.scenarioId,
    this.drivingRulesEnabled = true,
    this.onTestFailed,
    this.onTestPassed,
    this.onPenaltyRecorded,
    this.onWeatherCheckPrompt,
    this.onOdometerDeltaMeters,
    this.turnSignalLeft,
    this.turnSignalRight,
  });

  bool get isAdverseWeatherActive =>
      (scenarioId ?? '').trim().toLowerCase() == 'emergency_weather';

  /// Dashed lane markings level: non-fatal penalties + Wrong_Layer fail.
  /// Never mixed with the ambulance scenario (even if the TMX was copied from a dashed map).
  bool get _usesPenaltyModeMarkingsDashed {
    if (_isEmergencyAmbulanceScenario) return false;
    final a = (mapAsset ?? '').toLowerCase();
    final s = (scenarioId ?? '').toLowerCase();
    return a.contains('lane_markings_dashed') || s == 'markings_dashed';
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
        MediaAssets.carStart,
        MediaAssets.carIdle,
        MediaAssets.reverseLoop,
      ]);
    } catch (e, st) {
      debugPrint('Vehicle SFX preload failed: $e\n$st');
    }
    try {
      await FlameAudio.audioCache.load(MediaAssets.ambulanceSiren);
    } catch (_) {
      // Optional: add assets/audio/ambulance_siren.m4a for ambulance-reaction level.
    }
    try {
      await FlameAudio.audioCache.load(MediaAssets.ruleWhistle);
    } catch (_) {
      // Optional: add assets/audio/rule_whistle.m4a for rule-failure feedback.
    }
    if (_isEmergencyWeatherScenario) {
      try {
        await FlameAudio.audioCache.loadAll([
          MediaAssets.rainAmbience,
          MediaAssets.thunderClap,
        ]);
      } catch (e, st) {
        debugPrint('Weather SFX preload failed: $e\n$st');
      }
    }
    
    print('[DEBUG] onLoad() - Game size: ${size.x} x ${size.y}');

    _weatherLevelId = levelId;
    _logWeatherSessionStart();

    // Default camera already uses MaxViewport — do not replace it (that drops HUD children).
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
    _applyPlayerSpawnToWorld();
    print('[DEBUG] onLoad() - Car added to WORLD at position: ${car!.position}');

    if (_isEmergencyWeatherScenario) {
      await _setupAdverseWeatherEffects(reason: 'onLoad_end');
    }
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
    if (_isEmergencyWeatherScenario) {
      if (_weatherComponentsHealthy()) {
        _resizeAdverseWeatherEffects();
      } else if (size.x > 0 && size.y > 0) {
        unawaited(_setupAdverseWeatherEffects(reason: 'onGameResize'));
      }
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
      '(mapAsset=${mapAsset ?? "(default)"}, rules=$drivingRulesEnabled)',
    );
    final mapInstance = await _loadTiledMapComponent(tmxPath);
    final tiledMap = mapInstance;
    final tiled = tiledMap.tileMap.map;

    final mapSize = _mapPixelSize(tiled);
    _mapWidth = mapSize.width;
    _mapHeight = mapSize.height;
    print('[DEBUG] _setupRoad() - Map dimensions (px): ${_mapWidth} x ${_mapHeight}');
    print('[DEBUG] _setupRoad() - Map size (tiles): ${tiled.width} x ${tiled.height}');

    final objectGroupLayers = _objectGroupsFromTiledMap(tiled);
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
    for (final layer in tiled.layers.whereType<TileLayer>()) {
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

    // Junction box tiles: fail when the player stops inside (rules-enabled levels only).
    _junctionBoxTileMask = null;
    _junctionBoxMaskWidthTiles = null;
    _junctionBoxMaskHeightTiles = null;
    if (drivingRulesEnabled) {
      for (final layer in tiled.layers.whereType<TileLayer>()) {
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
    }

    // Read collision rectangles from Tiled object layers:
    // - Layer name "Obstacles_Layer" / "Obstacles Layer", OR
    // - Layer class "Collision_Box" (Tiled 1.9+ <objectgroup class="...">).
    // - Skip hidden objects (visible="0") so old placeholder walls don't block the road.
    // - Use every visible axis-aligned rectangle unless type is a known non-solid (spawn, trigger, …).
    // - Plain rectangles without a class/type still collide (Tiled defaults type to "").
    _wallRects.clear();
    final collisionLayers = tiled.layers
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

    // Read rule zones (checkpoint, finish, fail) when this level uses TMX rules.
    _drivingZones.clear();
    if (drivingRulesEnabled) {
      for (final layer in tiled.layers.whereType<ObjectGroup>()) {
        final layerNameNorm =
            layer.name.trim().toLowerCase().replaceAll(' ', '_');
        if (_isEmergencyWeatherScenario &&
            (layerNameNorm == 'check_layer' ||
                layerNameNorm == 'speed_layer')) {
          continue;
        }
        final layerClass = (layer.class_ ?? '').trim();
        final layerClassLower = layerClass.toLowerCase();
        final layerNameLower = layer.name.trim().toLowerCase();
        final layerStepId = layer.properties.getValue<int>('step_id');
        final layerFailMessage = layer.properties.getValue<String>('fail_message');

        for (final obj in layer.objects) {
          if (!obj.visible || obj.width <= 0 || obj.height <= 0) continue;
          if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) {
            continue;
          }
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
          if (_isEmergencyWeatherScenario) {
            final kind = _zoneKindForScenario(effectiveZoneClass.toLowerCase());
            if (kind == 'zone_fail_wt' || kind == 'wrong_layer') {
              continue;
            }
          }
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
      if (_isEmergencyWeatherScenario) {
        _loadWeatherScenarioZones(tiled);
      }
      _rebuildZigZagRows();
      _loadSpawnSignZones(tiledMap);

      _midTurnZones.clear();
      if (!_isEmergencyWeatherScenario) {
      for (final layer in tiled.layers.whereType<ObjectGroup>()) {
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
      }
    } else {
      _midTurnZones.clear();
      print('[DEBUG] _setupRoad() - Driving rules disabled; skipping TMX zones');
    }

    _loadAmbulanceRouteFromTmx(tiledMap);

    roadTiles.add(mapInstance);
    world.add(mapInstance);

    _loadAmbulanceDecorationMapData(objectGroupLayers);
    _loadEmergencyAmbulanceCheckpointsFromTiledMap(tiled);
    await _setupAmbulanceDecorationFromTmx(objectGroupLayers);

    _roadInitialized = true;
    _finalizeMapSpawnAndCamera();
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

  /// World position for the player car: TMX spawn point, else map centre.
  Vector2 _playerSpawnOrMapCenter() {
    if (_spawnPoint != null) return _spawnPoint!.clone();
    final w = _mapWidth ?? 1600;
    final h = _mapHeight ?? 1600;
    return Vector2(w / 2, h / 2);
  }

  /// Single place that places the car and camera from the resolved TMX spawn.
  void _applyPlayerSpawnToWorld({bool snapCamera = true}) {
    final spawn = _playerSpawnOrMapCenter();
    final c = car;
    if (c != null) {
      c.position.setFrom(spawn);
    }
    if (!snapCamera) return;
    // Always attach follow when the car exists. Do not gate on [isMounted]:
    // [Component.onMount] runs before the mounted flag is set, and
    // `await car.loaded` completes before mount — so a strict isMounted check
    // leaves the viewfinder stuck at the spawn with no [FollowBehavior].
    if (c != null) {
      camera.follow(c, snap: true);
    } else {
      camera.viewfinder.position = spawn.clone();
    }
  }

  /// Zones overlapping the spawn pose are treated as already entered so a
  /// misplaced fail strip beside the spawn does not end the run on frame one.
  void _seedDrivingZonesAtSpawn() {
    if (!drivingRulesEnabled || car == null || _drivingZones.isEmpty) return;

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    for (final zone in _drivingZones) {
      if (_carContactsDrivingZone(zone, carRect)) {
        _zonesInsidePreviousFrame.add(zone.objectId);
      }
    }
  }

  void _finalizeMapSpawnAndCamera() {
    _applyCameraZoomForViewport();
    _applyCameraBounds();
    _applyPlayerSpawnToWorld();
    _seedDrivingZonesAtSpawn();
    _seedWeatherRuleZonesAtSpawn();
    if (_isEmergencyWeatherScenario && !_weatherComponentsHealthy()) {
      unawaited(_setupAdverseWeatherEffects(reason: 'finalize_map'));
    }
  }

  Future<void> _playRuleBreakWhistle() async {
    try {
      await FlameAudio.play(
        MediaAssets.ruleWhistle,
        volume: 0.88,
      );
    } catch (e, st) {
      debugPrint(
        'Rule-break whistle failed (add assets/audio/${MediaAssets.ruleWhistle}): $e\n$st',
      );
    }
  }

  /// Reset scenario after failure so the player can retry without replacing [GameScreen]
  /// (avoids dispose/orientation races with `Navigator.pushReplacement`).
  void restartLevel() {
    _lessonAudioActive = true;
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
    _resetEmergencyWeatherForRestart();
    _resetWeatherRuleStateForRestart();
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
    c.markOdometerTeleport();
    c.pathHistory.clear();
    _applyPlayerSpawnToWorld();
    _seedDrivingZonesAtSpawn();
    _seedWeatherRuleZonesAtSpawn();
    resumeEngine();
    resumeAmbientAudioAfterUiOverlay();
  }

  /// Stops all in-lesson loops (engine, rain, ambulance siren). Safe to call multiple times.
  void endLessonAudio() {
    if (!_lessonAudioActive) return;
    _lessonAudioActive = false;
    pauseEngine();
    _vehicleSfx.dispose();
    WeatherSfxService.instance.invalidate();
    unawaited(_stopAmbulanceSiren());
  }

  /// After route overlays or OS audio ducking, [audioplayers] loops can stay paused
  /// while state still expects them to run. Safe to call from UI when dialogs close.
  void resumeAmbientAudioAfterUiOverlay() {
    if (!_lessonAudioActive) return;
    _vehicleSfx.resumePausedOutputs();
    _resumeAmbulanceSirenIfPaused();
    if (_isEmergencyWeatherScenario && !paused && WeatherSfxService.instance.isLessonActive) {
      unawaited(WeatherSfxService.instance.ensureRainLoop());
    }
  }

  /// Gear UI left reverse or entered park — stop reverse beep without waiting for next tick.
  void cancelReverseAudio() {
    _vehicleSfx.cancelReverseAudio();
  }

  @override
  void resumeEngine() {
    if (!_lessonAudioActive) return;
    super.resumeEngine();
    resumeAmbientAudioAfterUiOverlay();
  }

  @override
  void onRemove() {
    endLessonAudio();
    _disposeAmbulanceDecoration();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_lessonAudioActive) {
      _vehicleSfx.tick(dt, car);
    }
    _maybePlaceDeferredAmbulanceDecoration();
    _updateAmbulanceSirenTrigger();
    _updatePedestrianCrossingSignHud();
    _updateRoadCrossingParkCountdown(dt);
    _updateZigZagStraddleFail();
    _updateZigZagRoadCrossingRules();
    _enforceSpeedLimitZones();
    _updateMarkingsDashedYellowZoneRules();
    _updateMidTurnSignalValidation();
    if (_isEmergencyWeatherScenario) {
      _updateWeatherRuleZones();
    } else {
      _updateDrivingRuleZones();
    }
    _updateJunctionBoxStopFail(dt);
    // Checkpoints before pull-over (CP overlap can occur same frame as pull-over update).
    _updateAmbulanceCheckpoints(dt);
    _updateAmbulancePullOverState();
    _updateAmbulanceLevelSuccess();
    _tickWeatherMountRetry(dt);
    _tickWeatherHealthLog(dt);
    _tickThunder(dt);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    return false;
  }
}

class RealisticCarGame extends RealisticCarGameBase {
  RealisticCarGame({
    super.mapAsset,
    super.levelId,
    super.scenarioId,
    super.drivingRulesEnabled = true,
    super.onTestFailed,
    super.onTestPassed,
    super.onPenaltyRecorded,
    super.onWeatherCheckPrompt,
    super.onOdometerDeltaMeters,
    super.turnSignalLeft,
    super.turnSignalRight,
  });
}
