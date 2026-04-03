import 'dart:math' as math;
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
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

class _DrivingZone {
  final int objectId;
  final Rect rect;
  final String zoneClass;
  final int? stepId;
  final String? failMessage;

  const _DrivingZone({
    required this.objectId,
    required this.rect,
    required this.zoneClass,
    this.stepId,
    this.failMessage,
  });
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

  /// Optional TMX map path (e.g. 'assets/tiles/T-junction-left.tmx'). If null, default map is used.
  final String? mapAsset;
  /// Optional scenario key to alter objective routing on a shared map.
  final String? scenarioId;
  final void Function(String message)? onTestFailed;
  final VoidCallback? onTestPassed;

  final List<_DrivingZone> _drivingZones = [];
  final Set<int> _zonesInsidePreviousFrame = <int>{};
  int _lastCompletedStepId = 0;
  bool _testFinished = false;

  RealisticCarGame({
    this.mapAsset,
    this.scenarioId,
    this.onTestFailed,
    this.onTestPassed,
  });
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
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
            (obj.class_ ?? '').replaceAll(' ', '_').toLowerCase();
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
      final frictionProp = baseLayer.properties.getValue<double>('friction');
      if (frictionProp != null) {
        _baseLayerFriction = frictionProp * 400.0; // scale tile friction into force
        print('[DEBUG] _setupRoad() - Base layer friction from TMX: $frictionProp -> $_baseLayerFriction');
      } else {
        print('[DEBUG] _setupRoad() - Base layer has no friction property, using default: $_baseLayerFriction');
      }
    } else {
      print('[DEBUG] _setupRoad() - No Base layer found, using default friction: $_baseLayerFriction');
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
      final layerStepId = layer.properties.getValue<int>('step_id');
      final layerFailMessage = layer.properties.getValue<String>('fail_message');

      for (final obj in layer.objects) {
        if (!obj.visible || obj.width <= 0 || obj.height <= 0) continue;
        if (obj.isPoint || obj.isPolygon || obj.isPolyline || obj.isEllipse) continue;
        if (obj.rotation != 0) continue;

        final objectClass = (obj.class_ ?? '').trim();
        final objectType = obj.type.trim();
        final zoneClass = objectClass.isNotEmpty
            ? objectClass
            : (objectType.isNotEmpty ? objectType : layerClass);
        final zoneClassLower = zoneClass.toLowerCase();

        if (zoneClassLower != 'zone_check' &&
            zoneClassLower != 'zone_finish' &&
            zoneClassLower != 'zone_fail_wt' &&
            zoneClassLower != 'zone_fail_it' &&
            layerClassLower != 'zone_check' &&
            layerClassLower != 'zone_finish' &&
            layerClassLower != 'zone_fail_wt' &&
            layerClassLower != 'zone_fail_it') {
          continue;
        }

        final effectiveZoneClass =
            zoneClassLower.isNotEmpty ? zoneClass : layerClass;
        final stepId = obj.properties.getValue<int>('step_id') ?? layerStepId;
        final failMessage =
            obj.properties.getValue<String>('fail_message') ?? layerFailMessage;

        _drivingZones.add(
          _DrivingZone(
            objectId: obj.id,
            rect: Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height),
            zoneClass: effectiveZoneClass.toLowerCase(),
            stepId: stepId,
            failMessage: _sanitizeFailMessage(failMessage),
          ),
        );
      }
    }
    print('[DEBUG] _setupRoad() - Loaded driving zones: ${_drivingZones.length}');
    
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
  
  @override
  void update(double dt) {
    super.update(dt);
    _updateDrivingRuleZones();
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
    return zoneClass;
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
      final step = zone.stepId;
      if (step == null) return;
      if (step == _lastCompletedStepId + 1) {
        _lastCompletedStepId = step;
      }
      return;
    }

    if (zoneKind == 'zone_finish') {
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
      onTestFailed?.call(
        zone.failMessage?.isNotEmpty == true ? zone.failMessage! : defaultMessage,
      );
    }
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
  double maxSteerAngle = 50.0; // Maximum steering angle in degrees (allows sharp turns for U-turns)
  double steerReturnSpeed = 300.0; // how fast steering returns to center
  bool isSteering = false; // Track if user is actively steering
  double turnRate = 3.0; // Changed from 3.0 to 1.5 (reduced for smoother, less rapid turning)
  
  // Control flags to maintain acceleration/braking states
  bool isAccelerating = false;
  bool isBraking = false;
  
  // Gear system properties
  int currentGear = 1; // P=0, 1-5=forward gears, R=-1
  bool isInPark = false;
  
  // Debug counter
  int _debugFrameCount = 0;
  
  // Gear ratios for different performance characteristics
  final Map<int, double> gearRatios = {
    -1: 0.8,  // Reverse
    0: 0.0,   // Park
    1: 1.0,   // 1st gear
    2: 0.85,  // 2nd gear
    3: 0.7,   // 3rd gear
    4: 0.55,  // 4th gear
    5: 0.4,   // 5th gear
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
    double effectiveAcceleration = accelerationForce * (gearRatios[currentGear] ?? 1.0);
    
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
    double effectiveMaxSpeed = maxSpeed * (gearRatios[currentGear]?.abs() ?? 1.0);
    
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
          // Resolve collision by snapping back to previous position
          position.setFrom(oldPosition);
          velocity = Vector2.zero();
          acceleration = Vector2.zero();
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