part of 'realistic_car_game.dart';

/// Waypoint catch-up, heading-aligned tailgate behind the player, then Tiled route for pass.
class Ambulance extends SpriteComponent {
  Ambulance({
    required Sprite super.sprite,
    required this.player,
    required List<Vector2> routeWaypoints,
    super.position,
    super.size,
    super.angle,
    super.anchor,
    super.priority,
  }) : routeWaypoints = List<Vector2>.from(routeWaypoints);

  final Car player;
  final List<Vector2> routeWaypoints;

  AmbulanceState state = AmbulanceState.catchingUp;
  int _waypointIndex = 0;

  /// True once the ambulance has reached the final [routeWaypoints] node (route cleared).
  bool routeCompleted = false;

  /// Previous world position for movement-based heading smoothing.
  late Vector2 _prevPosition;

  static const double _safeDistance = 200.0;
  static const double _catchUpSpeed = 300.0;
  static const double _passSpeed = 320.0;

  /// World units behind the car's rear edge along its heading (tailgate target).
  static const double _tailgateStandoffWorld = 95.0;

  /// When passing, nudge laterally if the ambulance center is within this distance of the player.
  static const double _avoidanceRadius = 80.0;

  /// Lateral avoidance acceleration (world units / sec²) while inside [_avoidanceRadius].
  static const double _avoidanceStrength = 420.0;

  /// Shortest-path angle interpolation in radians.
  static double _lerpAngle(double from, double to, double t) {
    var d = to - from;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return from + d * t;
  }

  @override
  void onMount() {
    super.onMount();
    _prevPosition = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final distToPlayer = player.position.distanceTo(position);
    switch (state) {
      case AmbulanceState.catchingUp:
        _followWaypoints(dt, speed: _catchUpSpeed);
        if (distToPlayer <= _safeDistance) {
          state = AmbulanceState.tailgating;
        }
        break;
      case AmbulanceState.tailgating:
        // Dead-center behind the car along its heading (avoids lateral drift from bumper math).
        final forwardDir = Vector2(
          math.cos(player.angle),
          math.sin(player.angle),
        );
        final behindCar = player.position -
            forwardDir * (player.size.y / 2 + _tailgateStandoffWorld);
        final toRear = behindCar - position;
        final dist = toRear.length;
        if (dist > 100.0) {
          final speed = dist > _safeDistance
              ? _catchUpSpeed
              : player.velocity.length.clamp(80.0, _catchUpSpeed);
          final step = speed * dt;
          position += toRear.normalized() * math.min(step, dist - 95.0);
        }
        if (_playerYielded()) {
          _advanceWaypointToCurrent();
          state = AmbulanceState.passing;
        }
        break;
      case AmbulanceState.passing:
        _followWaypointsAvoidPlayer(dt, speed: _passSpeed);
        break;
    }

    final moved = position - _prevPosition;
    if (moved.length > 0.5) {
      // Ambulance PNG faces up; atan2 uses 0 = +X like BlackCar physics — offset +90°.
      final desiredAngle = math.atan2(moved.y, moved.x) + math.pi / 2;
      angle = _lerpAngle(angle, desiredAngle, math.min(1.0, dt * 6.0));
    }
    _prevPosition.setFrom(position);
  }

  bool _playerYielded() {
    final g = player.findGame();
    if (g is! RealisticCarGame) return false;
    return g.playerYieldedForAmbulance();
  }

  /// When leaving [AmbulanceState.tailgating], resume the Tiled route from the nearest
  /// waypoint ahead so we do not backtrack to stale indices (e.g. near spawn).
  void _advanceWaypointToCurrent() {
    if (routeWaypoints.isEmpty) return;
    var bestDist = double.infinity;
    var bestIdx = _waypointIndex;
    for (var i = _waypointIndex; i < routeWaypoints.length; i++) {
      final d = position.distanceTo(routeWaypoints[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    if (bestIdx < routeWaypoints.length - 1) {
      bestIdx++;
    }
    _waypointIndex = bestIdx;
  }

  void _followWaypoints(double dt, {required double speed}) {
    if (routeWaypoints.isEmpty) {
      routeCompleted = true;
      return;
    }
    if (_waypointIndex >= routeWaypoints.length) {
      routeCompleted = true;
      return;
    }
    final target = routeWaypoints[_waypointIndex];
    final toTarget = target - position;
    if (toTarget.length < 8) {
      if (_waypointIndex < routeWaypoints.length - 1) {
        _waypointIndex++;
      } else {
        routeCompleted = true;
      }
      return;
    }
    final step = speed * dt;
    position += toTarget.normalized() * math.min(step, toTarget.length);
  }

  /// Like [_followWaypoints] but adds a lateral repulsion from the player so the
  /// ambulance does not overlap the player car while overtaking on the route.
  void _followWaypointsAvoidPlayer(double dt, {required double speed}) {
    if (routeWaypoints.isEmpty) {
      routeCompleted = true;
      return;
    }
    if (_waypointIndex >= routeWaypoints.length) {
      routeCompleted = true;
      return;
    }
    final target = routeWaypoints[_waypointIndex];
    final toTarget = target - position;
    if (toTarget.length < 8) {
      if (_waypointIndex < routeWaypoints.length - 1) {
        _waypointIndex++;
      } else {
        routeCompleted = true;
      }
      return;
    }

    final travelDir = toTarget.normalized();
    final toPlayer = player.position - position;
    final dist = toPlayer.length;
    var avoidance = Vector2.zero();
    if (dist < _avoidanceRadius && dist > 0.1) {
      final perpCw = Vector2(travelDir.y, -travelDir.x);
      final perpCcw = Vector2(-travelDir.y, travelDir.x);
      // Player on the CW side of travel → steer CCW (and vice versa) to pass clear.
      final side = (toPlayer.dot(perpCw) > 0) ? perpCcw : perpCw;
      final t = 1.0 - dist / _avoidanceRadius;
      avoidance = side * (_avoidanceStrength * t);
    }

    final step = speed * dt;
    final along = travelDir * math.min(step, toTarget.length);
    position += along + avoidance * dt;
  }
}
