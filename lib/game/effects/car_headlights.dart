part of '../driving_game.dart';

/// Top-down low-beam cones for the player car during `emergency_weather`.
class CarWeatherHeadlightsPainter {
  CarWeatherHeadlightsPainter._();

  // ── Beam shape — tweak these to change cone length / width ──
  static const double _beamLength = 132;
  static const double _beamHalfWidth = 14;
  static const double _lensRadius = 3.2;

  static void drawBeams(Canvas canvas, CarZones zones) {
    _drawBeam(canvas, zones, zones.frontLeftHeadlight);
    _drawBeam(canvas, zones, zones.frontRightHeadlight);
  }

  static void drawLenses(Canvas canvas, CarZones zones) {
    _drawLens(canvas, zones.frontLeftHeadlight);
    _drawLens(canvas, zones.frontRightHeadlight);
  }

  static void _drawBeam(Canvas canvas, CarZones zones, Vector2 lampLocal) {
    final lamp = Offset(lampLocal.x, lampLocal.y);
    final farCenter = zones.forwardFrom(lampLocal, _beamLength);
    final farLeft = zones.forwardFrom(
      Vector2(lampLocal.x, lampLocal.y + _beamHalfWidth),
      _beamLength * 0.92,
    );
    final farRight = zones.forwardFrom(
      Vector2(lampLocal.x, lampLocal.y - _beamHalfWidth),
      _beamLength * 0.92,
    );

    final path = Path()
      ..moveTo(lamp.dx, lamp.dy)
      ..lineTo(farLeft.x, farLeft.y)
      ..lineTo(farRight.x, farRight.y)
      ..close();

    final bounds = Rect.fromPoints(
      Offset(farCenter.x - 6, farCenter.y - _beamHalfWidth),
      Offset(lamp.dx + 6, lamp.dy + _beamHalfWidth),
    );

    final beamPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.centerLeft,
        focal: Alignment.centerLeft,
        radius: 1.05,
        colors: const [
          Color(0x66FFF6D6),
          Color(0x38FFEEB8),
          Color(0x00FFEEB8),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds)
      ..blendMode = BlendMode.screen;

    canvas.drawPath(path, beamPaint);

    final corePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x55FFFBE8),
          Color(0x00FFFBE8),
        ],
      ).createShader(bounds)
      ..blendMode = BlendMode.plus;

    final coreFar = zones.forwardFrom(lampLocal, _beamLength);
    final corePath = Path()
      ..moveTo(lamp.dx, lamp.dy)
      ..lineTo(coreFar.x, coreFar.y - 6)
      ..lineTo(coreFar.x, coreFar.y + 6)
      ..close();
    canvas.drawPath(corePath, corePaint);
  }

  static void _drawLens(Canvas canvas, Vector2 lampLocal) {
    final center = Offset(lampLocal.x, lampLocal.y);
    canvas.drawCircle(
      center,
      _lensRadius + 1.2,
      Paint()
        ..color = const Color(0x33FFF8E0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      center,
      _lensRadius,
      Paint()..color = const Color(0xEEFFF4CC),
    );
    canvas.drawCircle(
      center.translate(-0.8, -0.8),
      _lensRadius * 0.35,
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }
}
