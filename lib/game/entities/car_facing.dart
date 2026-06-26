part of '../driving_game.dart';

/// Driving-relative sides for [Car] — aligned with [Car.angle] / acceleration.
enum CarSide {
  front,
  back,
  left,
  right,
}

/// Unit vectors in [Car] **local render space** (Flame top-left origin, `size` box).
///
/// Matches world driving direction: **+X = forward**, **+Y = driver left**,
/// **−Y = driver right**, **−X = rear** (for default `angle = −π/2`, forward is world −Y).
class CarFacing {
  CarFacing._();

  static final Vector2 forward = Vector2(1, 0);
  static final Vector2 back = Vector2(-1, 0);
  static final Vector2 left = Vector2(0, 1);
  static final Vector2 right = Vector2(0, -1);

  static Vector2 unit(CarSide side) {
    switch (side) {
      case CarSide.front:
        return forward;
      case CarSide.back:
        return back;
      case CarSide.left:
        return left;
      case CarSide.right:
        return right;
    }
  }

  /// Edge centre on [side] (`along` 0–1 from back→front or right→left).
  static Vector2 edgePoint(Vector2 size, CarSide side, {double along = 0.5}) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final t = along.clamp(0.0, 1.0);
    switch (side) {
      case CarSide.front:
        return Vector2(size.x, cy);
      case CarSide.back:
        return Vector2(0, cy);
      case CarSide.left:
        return Vector2(cx + (t - 0.5) * size.x, size.y);
      case CarSide.right:
        return Vector2(cx + (t - 0.5) * size.x, 0);
    }
  }

  /// Point [distance] world-units from [origin] toward [side].
  static Vector2 offset(Vector2 origin, CarSide side, double distance) {
    return origin + unit(side) * distance;
  }
}

/// Named attachment points on the player car in [CarFacing] local space.
class CarZones {
  final Vector2 size;
  const CarZones(this.size);

  // ── Headlight placement (weather level) — tweak these to move the lamps ──
  /// How far back from the front edge (0 = on bumper, 0.1 = 10% of car length).
  static const double headlightForwardInset = 0.06;
  /// Half-gap from car centre to each lamp, as a fraction of car width (smaller = closer).
  static const double headlightHalfSpread = 0.12;

  Vector2 get center => Vector2(size.x / 2, size.y / 2);

  // Corners — inset 12% from sides, 18% from front/rear ends.
  Vector2 get frontLeft => Vector2(size.x * 0.82, size.y * 0.88);
  Vector2 get frontRight => Vector2(size.x * 0.82, size.y * 0.12);
  Vector2 get rearLeft => Vector2(size.x * 0.18, size.y * 0.88);
  Vector2 get rearRight => Vector2(size.x * 0.18, size.y * 0.12);

  Vector2 get frontBumper => CarFacing.edgePoint(size, CarSide.front);
  Vector2 get rearBumper => CarFacing.edgePoint(size, CarSide.back);
  Vector2 get leftSide => CarFacing.edgePoint(size, CarSide.left);
  Vector2 get rightSide => CarFacing.edgePoint(size, CarSide.right);

  Vector2 get frontCenter => center + CarFacing.forward * (size.x / 2);
  Vector2 get rearCenter => center + CarFacing.back * (size.x / 2);

  /// Headlight lamp positions on the front bumper (see [headlightHalfSpread]).
  Vector2 get frontLeftHeadlight => Vector2(
        size.x * (1 - headlightForwardInset),
        center.y + size.y * headlightHalfSpread,
      );

  Vector2 get frontRightHeadlight => Vector2(
        size.x * (1 - headlightForwardInset),
        center.y - size.y * headlightHalfSpread,
      );

  /// Extend from a local point toward [CarSide.front] (low-beam direction).
  Vector2 forwardFrom(Vector2 origin, double distance) {
    return CarFacing.offset(origin, CarSide.front, distance);
  }

  /// Which named zone is closest to [localPoint] (diagnostics / impacts).
  String closestZoneName(Vector2 localPoint) {
    var bestName = 'frontLeft';
    var bestDist = double.infinity;
    void consider(String name, Vector2 p) {
      final d = localPoint.distanceToSquared(p);
      if (d < bestDist) {
        bestDist = d;
        bestName = name;
      }
    }

    consider('frontLeft', frontLeft);
    consider('frontRight', frontRight);
    consider('rearLeft', rearLeft);
    consider('rearRight', rearRight);
    consider('frontBumper', frontBumper);
    consider('rearBumper', rearBumper);
    consider('leftSide', leftSide);
    consider('rightSide', rightSide);
    return bestName;
  }
}
