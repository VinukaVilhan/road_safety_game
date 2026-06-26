import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';

import 'weather_effects_log.dart';

/// Screen-space rain for **top-down** driving: short, mostly-vertical streaks
/// (falling toward the bottom of the screen / ground plane), not side-scroller
/// diagonals.
class RainViewportOverlay extends Component with HasGameReference<FlameGame> {
  RainViewportOverlay({this.priority = 900});

  @override
  final int priority;

  static const int dropCount = 130;
  final math.Random _random = math.Random(42);
  final List<_RainDrop> _drops = [];

  bool _loggedFirstRender = false;
  int renderFrameCount = 0;

  Vector2 _viewportSize = Vector2.zero();

  int get activeDropCount => _drops.length;

  Vector2 _readViewportSize() {
    final camera = game.camera;
    final vs = camera.viewport.virtualSize;
    if (vs.x > 0 && vs.y > 0) return vs.clone();
    final canvas = game.canvasSize;
    if (canvas.x > 0 && canvas.y > 0) return canvas.clone();
    return Vector2.zero();
  }

  void resizeViewport(Vector2 viewportSize) {
    _viewportSize = viewportSize.clone();
    _seedDrops();
    WeatherEffectsLog.info(
      'RainOverlay resize → ${viewportSize.x.toStringAsFixed(0)}×'
      '${viewportSize.y.toStringAsFixed(0)} drops=$_drops.length',
    );
  }

  @override
  void onMount() {
    super.onMount();
    _viewportSize = _readViewportSize();
    _seedDrops();
    WeatherEffectsLog.info(
      'RainOverlay onMount parent=${parent?.runtimeType} '
      'priority=$priority drops=$_drops.length '
      'viewport=${_viewportSize.x.toStringAsFixed(0)}×'
      '${_viewportSize.y.toStringAsFixed(0)}',
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    resizeViewport(_readViewportSize());
  }

  void _seedDrops() {
    _drops.clear();
    if (_viewportSize.x <= 0 || _viewportSize.y <= 0) {
      WeatherEffectsLog.warn(
        'RainOverlay seed skipped — viewport size is zero '
        '(${_viewportSize.x}×${_viewportSize.y})',
      );
      return;
    }

    for (var i = 0; i < dropCount; i++) {
      _drops.add(_createDrop(spawnAnywhere: true));
    }
  }

  _RainDrop _createDrop({required bool spawnAnywhere}) {
    final w = _viewportSize.x;
    final h = _viewportSize.y;

    // Two depth tiers: faint “far” drops vs brighter “near” lens drops.
    final nearLayer = _random.nextDouble() > 0.62;
    final opacity = nearLayer
        ? 0.35 + _random.nextDouble() * 0.35
        : 0.18 + _random.nextDouble() * 0.22;

    return _RainDrop(
      x: _random.nextDouble() * w,
      y: spawnAnywhere
          ? _random.nextDouble() * h
          : -8 - _random.nextDouble() * 32,
      // Top-down: dominant fall is +Y (toward ground); tiny X drift for wind.
      speedX: -35 + _random.nextDouble() * 70,
      speedY: nearLayer
          ? 420 + _random.nextDouble() * 180
          : 280 + _random.nextDouble() * 120,
      length: nearLayer
          ? 5 + _random.nextDouble() * 7
          : 3 + _random.nextDouble() * 5,
      strokeWidth: nearLayer
          ? 0.9 + _random.nextDouble() * 0.8
          : 0.5 + _random.nextDouble() * 0.5,
      windSkew: -4 + _random.nextDouble() * 8,
      color: Color.fromARGB(
        (opacity * 255).round().clamp(0, 255),
        200,
        220,
        255,
      ),
    );
  }

  void _recycleIfOffScreen(_RainDrop drop) {
    final w = _viewportSize.x;
    final h = _viewportSize.y;
    if (drop.y > h + 16 || drop.x > w + 16 || drop.x < -16) {
      final fresh = _createDrop(spawnAnywhere: false);
      drop.x = fresh.x;
      drop.y = fresh.y;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_viewportSize.x <= 0 || _viewportSize.y <= 0) {
      _viewportSize = _readViewportSize();
      if (_viewportSize.x > 0 && _viewportSize.y > 0) _seedDrops();
    }
    for (final drop in _drops) {
      drop.x += drop.speedX * dt;
      drop.y += drop.speedY * dt;
      _recycleIfOffScreen(drop);
    }
  }

  @override
  void render(Canvas canvas) {
    renderFrameCount++;
    if (!_loggedFirstRender) {
      _loggedFirstRender = true;
      WeatherEffectsLog.info(
        'RainOverlay FIRST RENDER drops=$_drops.length '
        'viewport=${_viewportSize.x.toStringAsFixed(0)}×'
        '${_viewportSize.y.toStringAsFixed(0)}',
      );
    }

    if (_drops.isEmpty) return;

    for (final drop in _drops) {
      final paint = Paint()
        ..color = drop.color
        ..strokeWidth = drop.strokeWidth
        ..strokeCap = StrokeCap.round;

      // Tail points opposite to fall direction — mostly straight up (short streak).
      final headX = drop.x;
      final headY = drop.y;
      final tailX = headX + drop.windSkew;
      final tailY = headY - drop.length;

      canvas.drawLine(
        Offset(tailX, tailY),
        Offset(headX, headY),
        paint,
      );
    }
  }
}

/// Very light cool tint — keeps the road readable while suggesting wet weather.
class RainVisibilityDimOverlay extends Component with HasGameReference<FlameGame> {
  RainVisibilityDimOverlay({this.priority = 850});

  @override
  final int priority;

  /// ~12% cool shadow; previous ~47% was crushing the map.
  static const Color dimColor = Color(0x1E081820);

  Vector2 _size = Vector2.zero();
  bool _loggedFirstRender = false;
  int renderFrameCount = 0;

  Vector2 _readViewportSize() {
    final vs = game.camera.viewport.virtualSize;
    if (vs.x > 0 && vs.y > 0) return vs.clone();
    return game.canvasSize.clone();
  }

  void resizeViewport(Vector2 viewportSize) {
    _size = viewportSize.clone();
    WeatherEffectsLog.info(
      'DimOverlay resize → ${viewportSize.x.toStringAsFixed(0)}×'
      '${viewportSize.y.toStringAsFixed(0)}',
    );
  }

  @override
  void onMount() {
    super.onMount();
    _size = _readViewportSize();
    WeatherEffectsLog.info(
      'DimOverlay onMount parent=${parent?.runtimeType} '
      'size=${_size.x.toStringAsFixed(0)}×${_size.y.toStringAsFixed(0)}',
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    resizeViewport(_readViewportSize());
  }

  @override
  void render(Canvas canvas) {
    renderFrameCount++;
    if (_size.x <= 0 || _size.y <= 0) {
      _size = _readViewportSize();
    }
    if (!_loggedFirstRender && _size.x > 0 && _size.y > 0) {
      _loggedFirstRender = true;
      WeatherEffectsLog.info(
        'DimOverlay FIRST RENDER size=${_size.x.toStringAsFixed(0)}×'
        '${_size.y.toStringAsFixed(0)}',
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _size.x, _size.y),
      Paint()..color = dimColor,
    );
  }
}

class _RainDrop {
  double x;
  double y;
  final double speedX;
  final double speedY;
  final double length;
  final double strokeWidth;
  final double windSkew;
  final Color color;

  _RainDrop({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.length,
    required this.strokeWidth,
    required this.windSkew,
    required this.color,
  });
}
