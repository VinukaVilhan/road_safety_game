import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

class RealisticCarGame extends FlameGame with KeyboardHandler {
  late Car car; // Make car accessible
  late SpriteComponent roadBackground;
  double roadSpeed = 200.0;
  List<SpriteComponent> roadTiles = [];
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Load and setup scrolling road background
    await _setupRoad();
    
    // Add the car
    car = Car();
    await car.onLoad();
    add(car);
  }
  
  Future<void> _setupRoad() async {
    // Create multiple road tiles for seamless scrolling
    final roadSprite = await Sprite.load('Road.png');
    
    for (int i = 0; i < 3; i++) {
      final roadTile = SpriteComponent(
        sprite: roadSprite,
        size: Vector2(size.x, size.y),
        position: Vector2(0, -size.y * i),
      );
      roadTiles.add(roadTile);
      add(roadTile);
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Scroll road tiles
    for (var tile in roadTiles) {
      tile.position.y += roadSpeed * dt;
      
      // Reset tile position when it goes off screen
      if (tile.position.y > size.y) {
        tile.position.y = -size.y * 2;
      }
    }
  }
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Handle keyboard input for car movement
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) || 
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      car.steerLeft();
    } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight) || 
               keysPressed.contains(LogicalKeyboardKey.keyD)) {
      car.steerRight();
    }
    
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp) || 
        keysPressed.contains(LogicalKeyboardKey.keyW)) {
      car.accelerate();
    } else if (keysPressed.contains(LogicalKeyboardKey.arrowDown) || 
               keysPressed.contains(LogicalKeyboardKey.keyS)) {
      car.brake();
    }
    
    // Reset steering when no horizontal keys are pressed
    if (!keysPressed.contains(LogicalKeyboardKey.arrowLeft) &&
        !keysPressed.contains(LogicalKeyboardKey.arrowRight) &&
        !keysPressed.contains(LogicalKeyboardKey.keyA) &&
        !keysPressed.contains(LogicalKeyboardKey.keyD)) {
      car.resetSteering();
    }
    
    // Coast when no vertical keys are pressed
    if (!keysPressed.contains(LogicalKeyboardKey.arrowUp) &&
        !keysPressed.contains(LogicalKeyboardKey.arrowDown) &&
        !keysPressed.contains(LogicalKeyboardKey.keyW) &&
        !keysPressed.contains(LogicalKeyboardKey.keyS)) {
      car.coast();
    }
    
    return true;
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
    
    // Gradually return steering to center when not actively steering
    if (steerAngle != 0) {
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
    steerAngle = -maxSteerAngle;
  }
  
  void steerRight() {
    steerAngle = maxSteerAngle;
  }
  
  void resetSteering() {
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