part of '../driving_game.dart';

extension ZoneHelpers on RealisticCarGameBase {
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
    if (zoneKind == 'zone_fail_wt' || zoneKind == 'zone_fail_it') {
      return _anyWheelInsideRect(zone.rect);
    }
    return carRect.overlaps(zone.rect);
  }

  void _enforceSpeedLimitZones() {
    if (!drivingRulesEnabled) return;
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
}
