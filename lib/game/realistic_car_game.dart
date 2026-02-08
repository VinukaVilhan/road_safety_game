import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/services.dart';

class RealisticCarGame extends FlameGame with KeyboardHandler {
  Car? car; // Make car accessible - nullable to handle initialization order
  late SpriteComponent roadBackground;
  double roadSpeed = 200.0;
  List<TiledComponent> roadTiles = [];
  bool _roadInitialized = false;
  bool _cameraReady = false; // Track if camera is properly positioned
  double? _mapWidth;
  double? _mapHeight;
  int _frameCount = 0; // For debug output
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    print('[DEBUG] onLoad() - Game size: ${size.x} x ${size.y}');
    
    // Use MaxViewport to fill screen - road will stretch to fill
    camera.viewport = MaxViewport();
    
    // Set camera to center on target (car)
    camera.viewfinder.anchor = Anchor.center;
    print('[DEBUG] onLoad() - Camera viewfinder anchor set to center');
    print('[DEBUG] onLoad() - Initial camera position: ${camera.viewfinder.position}');
    
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
    
    print('[DEBUG] onLoad() - After frame delay, car position: ${car!.position}');
    print('[DEBUG] onLoad() - After frame delay, camera position: ${camera.viewfinder.position}');
    
    // DON'T use camera.follow() - we'll manually control camera in update()
    // This gives us full control over camera positioning
    print('[DEBUG] onLoad() - Camera will be manually controlled in update()');
  }
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    print('[DEBUG] onGameResize() - New size: ${size.x} x ${size.y}');
    
    // Initialize road tiles when size is known
    if (!_roadInitialized && size.x > 0 && size.y > 0) {
      _setupRoad();
    }
    
    // Set camera to car position after car is mounted and map is loaded
    // This ensures camera starts centered on car
    if (_roadInitialized && car != null && car!.isMounted) {
      print('[DEBUG] onGameResize() - Setting camera to car position: ${car!.position}');
      camera.viewfinder.position = car!.position;
      print('[DEBUG] onGameResize() - Camera position after set: ${camera.viewfinder.position}');
      
      // Mark camera as ready once it's successfully positioned
      _cameraReady = true;
      print('[DEBUG] onGameResize() - Camera is now READY!');
    } else {
      print('[DEBUG] onGameResize() - Not setting camera: _roadInitialized=$_roadInitialized, car=${car != null ? "exists, isMounted=${car!.isMounted}" : "null"}');
    }
  }
  
  Future<void> _setupRoad() async {
    if (_roadInitialized) return;
    
    // Remove existing tiles if any
    for (var tile in roadTiles) {
      remove(tile);
    }
    roadTiles.clear();
    
    // Load the Tiled map
    final tiledMap = await TiledComponent.load(
      'town_tiles_2.tmx',
      Vector2.all(16), // Tile size from TMX file (16x16)
    );
    
    // Calculate and store map dimensions
    _mapWidth = tiledMap.tileMap.map.width * 16.0; // 16 is tile width
    _mapHeight = tiledMap.tileMap.map.height * 16.0; // 16 is tile height
    print('[DEBUG] _setupRoad() - Map dimensions: ${_mapWidth} x ${_mapHeight}');
    print('[DEBUG] _setupRoad() - Map tiles: ${tiledMap.tileMap.map.width} x ${tiledMap.tileMap.map.height}');
    
    // Create a single static map instance at (0, 0) covering the entire world
    final mapInstance = await TiledComponent.load(
      'town_tiles_2.tmx',
      Vector2.all(16),
    );
    
    // Position map at world origin (0, 0) - covers entire world space
    mapInstance.position = Vector2(0, 0);
    mapInstance.priority = 0; // Lower priority - renders behind
    
    roadTiles.add(mapInstance);
    world.add(mapInstance);  // Add to world, not game
    
    _roadInitialized = true;
    
    // Ensure car is on top by re-adding it if it exists and is loaded
    if (car != null) {
      if (car!.isMounted) {
        print('[DEBUG] _setupRoad() - Car is mounted, position: ${car!.position}');
        world.remove(car!);  // Remove from world
        car!.priority = 1; // Higher priority - renders on top
        world.add(car!);  // Add back to world
        
        // Set camera to car position immediately after map is loaded
        print('[DEBUG] _setupRoad() - Setting camera to car position: ${car!.position}');
        camera.viewfinder.position = car!.position;
        print('[DEBUG] _setupRoad() - Camera position after set: ${camera.viewfinder.position}');
      } else {
        print('[DEBUG] _setupRoad() - Car exists but not mounted yet');
      }
    } else {
      // Car not yet loaded, will be added in onLoad
      print('[DEBUG] _setupRoad() - Car not created yet (will be added in onLoad)');
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    _frameCount++;
    
    // Manually update camera position to follow car
    // This ensures camera always stays centered on car
    if (car != null && car!.isMounted && _roadInitialized && _cameraReady) {
      final oldCameraPos = camera.viewfinder.position.clone();
      
      // CRITICAL FIX: Use assignment (like onGameResize) instead of .x/.y
      camera.viewfinder.position = car!.position.clone();
      
      // Debug every 60 frames (roughly once per second at 60fps)
      if (_frameCount % 60 == 0) {
        print('[DEBUG] update() - Frame: $_frameCount');
        print('[DEBUG] update() - Car position: ${car!.position}');
        print('[DEBUG] update() - Camera position AFTER UPDATE: ${camera.viewfinder.position} (was: $oldCameraPos)');
        print('[DEBUG] update() - Did camera move? ${camera.viewfinder.position != oldCameraPos}');
        print('[DEBUG] update() - Camera viewfinder anchor: ${camera.viewfinder.anchor}');
        print('[DEBUG] update() - Game size: ${size.x} x ${size.y}');
        print('[DEBUG] update() - Map size: $_mapWidth x $_mapHeight');
        print('[DEBUG] update() - Viewport size: ${camera.viewport.size}');
      }
    } else {
      // Debug why camera isn't updating
      if (_frameCount % 60 == 0) {
        print('[DEBUG] update() - Camera NOT updating: car=${car != null ? "exists, isMounted=${car!.isMounted}" : "null"}, _roadInitialized=$_roadInitialized, _cameraReady=$_cameraReady');
      }
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
    size = Vector2(90, 90);
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
    
    position = Vector2(centerX, centerY);
    print('[DEBUG] Car.onMount() - Car positioned at CENTER: $position');
    print('[DEBUG] Car.onMount() - Parent type: ${parent.runtimeType}');
    print('[DEBUG] Car.onMount() - Game type: ${game.runtimeType}');
    print('[DEBUG] Car.onMount() - Map dimensions: ${game._mapWidth} x ${game._mapHeight}');
    
    // CRITICAL FIX: Directly set x and y instead of using setFrom
    print('[DEBUG] Car.onMount() - Setting camera to car position: $position');
    print('[DEBUG] Car.onMount() - Camera position BEFORE: ${game.camera.viewfinder.position}');
    
    game.camera.viewfinder.position.x = position.x;
    game.camera.viewfinder.position.y = position.y;
    
    print('[DEBUG] Car.onMount() - Camera position AFTER: ${game.camera.viewfinder.position}');
    print('[DEBUG] Car.onMount() - Camera successfully moved? ${game.camera.viewfinder.position.x == position.x && game.camera.viewfinder.position.y == position.y}');
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Safety check - ensure game exists
    // FIXED: Get game through findGame() since parent is now World
    final game = findGame();
    if (game == null) return;
    final realisticGame = game as RealisticCarGame;
    
    // CRITICAL: Don't allow movement until camera is ready!
    if (!realisticGame._cameraReady) {
      velocity = Vector2.zero();
      acceleration = Vector2.zero();
      return;
    }
    
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
    position += velocity * dt;
    
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
      bool hitBoundary = false;
      
      // Horizontal world bounds - prevent going off map edges
      if (position.x < 0) {
        print('[DEBUG] Car.update() - Hit LEFT boundary! position.x=$position.x, setting to 0');
        position.x = 0;
        velocity.x = 0; // Stop horizontal movement at left edge
        hitBoundary = true;
      } else if (position.x > realisticGame._mapWidth!) {
        print('[DEBUG] Car.update() - Hit RIGHT boundary! position.x=$position.x, mapWidth=${realisticGame._mapWidth}, setting to ${realisticGame._mapWidth}');
        position.x = realisticGame._mapWidth!;
        velocity.x = 0; // Stop horizontal movement at right edge
        hitBoundary = true;
      }
      
      // Vertical world bounds - prevent going off map edges
      if (position.y < 0) {
        print('[DEBUG] Car.update() - Hit TOP boundary! position.y=$position.y, setting to 0');
        position.y = 0;
        velocity.y = math.max(0, velocity.y); // Stop upward movement
        hitBoundary = true;
      } else if (position.y > realisticGame._mapHeight!) {
        print('[DEBUG] Car.update() - Hit BOTTOM boundary! position.y=$position.y, mapHeight=${realisticGame._mapHeight}, setting to ${realisticGame._mapHeight}');
        position.y = realisticGame._mapHeight!;
        velocity.y = math.min(0, velocity.y); // Stop downward movement
        hitBoundary = true;
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