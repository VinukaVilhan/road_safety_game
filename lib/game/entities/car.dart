part of '../driving_game.dart';

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

  /// After respawn / teleport, skip one odometer sample so spawn jumps are not counted.
  bool _ignoreOdometerOnce = false;

  void markOdometerTeleport() {
    _ignoreOdometerOnce = true;
  }

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

  late CarZones zones;

  /// World-space driving forward (same axis as forward acceleration).
  Vector2 get worldForward => Vector2(math.cos(angle), math.sin(angle));

  Vector2 get worldBack => Vector2(math.cos(angle + math.pi), math.sin(angle + math.pi));

  Vector2 get worldLeft =>
      Vector2(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2));

  Vector2 get worldRight =>
      Vector2(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2));

  Vector2 worldPoint(Vector2 localPoint) => absolutePositionOf(localPoint);

  Vector2 worldPointOnSide(CarSide side, {double along = 0.5}) =>
      absolutePositionOf(CarFacing.edgePoint(size, side, along: along));

  /// Validated breadcrumbs for tethered ambulance AI ([PathNode.isSafe] from wall overlap).
  final List<PathNode> pathHistory = [];
  double _breadcrumbTimer = 0;
  bool isCurrentlyOffRoad = false;
  double _offRoadResetTimer = 0;

  /// Warm low-beam cones drawn on the road during `emergency_weather`.
  bool weatherHeadlightsEnabled = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Load the black car sprite
    sprite = await Sprite.load(MediaAssets.blackCar);

    // Set car size and anchor
    size = Vector2(60, 60);
    anchor = Anchor.center;
    angle = -math.pi / 2; // Car starts facing up (negative Y direction)
    zones = CarZones(size);
  }

  @override
  void render(Canvas canvas) {
    if (weatherHeadlightsEnabled) {
      CarWeatherHeadlightsPainter.drawBeams(canvas, zones);
    }
    super.render(canvas);
    if (weatherHeadlightsEnabled) {
      CarWeatherHeadlightsPainter.drawLenses(canvas, zones);
    }
  }

  @override
  void onMount() {
    super.onMount();

    // Tiled spawn layers — see [_pickPlayerSpawnFromObjectGroups] and [_applyPlayerSpawnToWorld].
    final game = findGame()! as RealisticCarGame;
    game._applyPlayerSpawnToWorld();
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
    friction = realisticGame._baseLayerFriction * realisticGame.weatherFrictionMultiplier;

    if (_offRoadResetTimer > 0) {
      _offRoadResetTimer -= dt;
      if (_offRoadResetTimer <= 0) {
        _offRoadResetTimer = 0;
        isCurrentlyOffRoad = false;
      }
    }

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
        acceleration = velocity.normalized() *
            -brakeForce *
            realisticGame.weatherBrakeMultiplier;
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
      angle += steeringRadians *
          turnRate *
          normalizedSpeed *
          realisticGame.weatherSteerGripMultiplier *
          dt;

      if (realisticGame.isAdverseWeatherActive &&
          currentSpeed > 20 &&
          steerAngle.abs() > 35) {
        final perp = Vector2(-math.sin(angle), math.cos(angle));
        final slide = steerAngle.sign * currentSpeed * 0.014 * dt;
        velocity += perp * slide;
      }

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
          isCurrentlyOffRoad = true;
          _offRoadResetTimer = 0.5;
          if (impactSpeed >= RealisticCarGameBase.wallHighSpeedCrashThreshold) {
            realisticGame._failFromHighSpeedWallCrash();
          } else {
            realisticGame.registerNonCrashBump();
          }
          break;
        }
      }
    }

    _breadcrumbTimer += dt;
    if (_breadcrumbTimer >= 0.05) {
      _breadcrumbTimer = 0;
      final rearWorld = absolutePositionOf(zones.rearBumper);
      pathHistory.add(PathNode(rearWorld.clone(), angle, !isCurrentlyOffRoad));
      const maxHistory = 100;
      while (pathHistory.length > maxHistory) {
        pathHistory.removeAt(0);
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

    if (_ignoreOdometerOnce) {
      _ignoreOdometerOnce = false;
    } else {
      final movedWorld = (position - oldPosition).length;
      final maxStep = math.max(velocity.length, 8.0) * dt * 2.5;
      final clamped = movedWorld > maxStep ? maxStep : movedWorld;
      if (clamped > 1e-6) {
        realisticGame.reportOdometerMeters(clamped * RealisticCarGameBase.worldUnitsToMeters);
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
