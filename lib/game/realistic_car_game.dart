import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter/services.dart';

class RealisticCarGame extends FlameGame with KeyboardHandler {
  late Car car; // Make car accessible
  late SpriteComponent roadBackground;
  double roadSpeed = 200.0;
  List<SpriteComponent> roadTiles = [];
  bool _roadInitialized = false;
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Use MaxViewport to fill screen - road will stretch to fill
    camera.viewport = MaxViewport();
    
    // Load road sprite first
    _roadSprite = await Sprite.load('road sprite.png');
    
    // Try to setup road if size is already available
    if (size.x > 0 && size.y > 0) {
      _setupRoad();
    }
    // Otherwise, onGameResize will handle it
    
    // Add the car after road so it renders on top
    car = Car();
    await car.onLoad();
    car.priority = 1; // Higher priority - renders on top of road
    add(car);
  }
  
  Sprite? _roadSprite;
  
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    // Initialize or update road tiles when size is known
    if (_roadSprite != null) {
      if (!_roadInitialized) {
        _setupRoad();
      } else {
        _updateRoadSize();
      }
    }
  }
  
  void _setupRoad() {
    if (_roadSprite == null) return;
    
    // Remove existing tiles if any
    for (var tile in roadTiles) {
      remove(tile);
    }
    roadTiles.clear();
    
    // Use the actual game size (which will be the screen size with MaxViewport)
    final roadSize = size;
    
    // Create multiple road tiles for seamless scrolling
    for (int i = 0; i < 3; i++) {
      final roadTile = SpriteComponent(
        sprite: _roadSprite!,
        size: roadSize, // Use actual screen size to fill entire screen
        position: Vector2(0, -roadSize.y * i),
        priority: 0, // Lower priority - renders behind
      );
      roadTiles.add(roadTile);
      // Add road tiles first (they render behind)
      add(roadTile);
    }
    _roadInitialized = true;
    
    // Ensure car is on top by re-adding it if it exists and is loaded
    try {
      if (car.isMounted) {
        remove(car);
        car.priority = 1; // Higher priority - renders on top
        add(car);
      }
    } catch (e) {
      // Car not yet loaded, will be added in onLoad
    }
  }
  
  void _updateRoadSize() {
    final roadSize = size;
    for (var tile in roadTiles) {
      tile.size = roadSize;
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Use actual game size (screen size)
    final roadSize = size;
    
    // Scroll road tiles
    for (var tile in roadTiles) {
      tile.position.y += roadSpeed * dt;
      
      // Reset tile position when it goes off screen
      if (tile.position.y > roadSize.y) {
        tile.position.y = -roadSize.y * 2;
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
  double maxSpeed = 300.0;
  double accelerationForce = 400.0;
  double brakeForce = 600.0;
  double friction = 200.0;
  
  // Steering properties
  double steerAngle = 0;
  double maxSteerAngle = 150.0; // degrees per second
  double steerReturnSpeed = 300.0; // how fast steering returns to center
  bool isSteering = false; // Track if user is actively steering
  
  // Control flags to maintain acceleration/braking states
  bool isAccelerating = false;
  bool isBraking = false;
  
  // Gear system properties
  int currentGear = 1; // P=0, 1-5=forward gears, R=-1
  bool isInPark = false;
  
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
    angle = -math.pi / 2;
  }
  
  @override
  void onMount() {
    super.onMount();
    
    // Position car at bottom center after being mounted to game
    final game = parent as RealisticCarGame;
    position = Vector2(
      game.size.x / 2, 
      game.size.y - size.y / 2 - 50
    );
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Safety check - ensure parent exists
    if (parent == null) return;
    final game = parent as RealisticCarGame;
    
    // Don't allow movement if in park
    if (isInPark) {
      velocity = Vector2.zero();
      acceleration = Vector2.zero();
      return;
    }
    
    // Calculate effective acceleration based on current gear
    double effectiveAcceleration = accelerationForce * (gearRatios[currentGear] ?? 1.0);
    
    // Apply continuous acceleration/braking based on button states
    if (isAccelerating) {
      if (currentGear == -1) {
        // Reverse gear - accelerate backwards
        acceleration.y = effectiveAcceleration;
      } else if (currentGear > 0) {
        // Forward gears - accelerate forwards
        acceleration.y = -effectiveAcceleration;
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
    
    // Apply velocity to position
    position += velocity * dt;
    
    // Apply steering (affects horizontal movement)
    position.x += steerAngle * dt;
    
    // Gradually return steering to center only when NOT actively steering
    if (!isSteering && steerAngle != 0) {
      final returnAmount = steerReturnSpeed * dt;
      if (steerAngle > 0) {
        steerAngle = math.max(0, steerAngle - returnAmount);
      } else {
        steerAngle = math.min(0, steerAngle + returnAmount);
      }
    }
    
    // Keep car within screen bounds
    final margin = size.x / 2;
    if (position.x < margin) {
      position.x = margin;
    } else if (position.x > game.size.x - margin) {
      position.x = game.size.x - margin;
    }
    
    // Keep car within vertical bounds (prevent going off screen)
    if (position.y < size.y / 2) {
      position.y = size.y / 2;
      velocity.y = math.max(0, velocity.y); // Stop upward movement
    } else if (position.y > game.size.y - size.y / 2) {
      position.y = game.size.y - size.y / 2;
      velocity.y = math.min(0, velocity.y); // Stop downward movement
    }
    
    // Visual rotation based on steering
    angle = -math.pi / 2 + (steerAngle * 0.001);
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