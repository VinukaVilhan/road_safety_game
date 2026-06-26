import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';

import 'weather_effects_log.dart';

/// Brief full-screen lightning flash on the camera viewport.
class ThunderFlashOverlay extends Component with HasGameReference<FlameGame> {
  ThunderFlashOverlay({this.priority = 950});

  @override
  final int priority;

  double _primaryIntensity = 0;
  double _secondaryIntensity = 0;

  /// 0 = none; 1 = holding first flash; 2 = dark gap before second flash.
  int _doubleFlashPhase = 0;
  double _doubleFlashTimer = 0;
  double _pendingSecondaryStrength = 0;
  final math.Random _flashRandom = math.Random();

  int strikeCount = 0;

  bool get isFlashing =>
      _primaryIntensity > 0.03 ||
      _secondaryIntensity > 0.03 ||
      _doubleFlashPhase > 0;

  /// ~35% of strikes use a visible double flash (bright → dark gap → second flash).
  static const double doubleFlashChance = 0.35;

  Vector2 _readViewportSize() {
    final vs = game.camera.viewport.virtualSize;
    if (vs.x > 0 && vs.y > 0) return vs.clone();
    return game.canvasSize.clone();
  }

  /// Trigger a lightning flash. [strength] 0–1; [doubleFlash] mimics a quick double strike.
  void strike({double strength = 0.5, bool doubleFlash = false}) {
    if (strength <= 0) {
      clear();
      return;
    }
    clear();
    _primaryIntensity = strength.clamp(0.25, 0.85);
    strikeCount++;
    if (doubleFlash) {
      _doubleFlashPhase = 1;
      _doubleFlashTimer = 0.06 + _flashRandom.nextDouble() * 0.05;
      _pendingSecondaryStrength =
          (strength * (0.62 + _flashRandom.nextDouble() * 0.28)).clamp(0.22, 0.75);
    }
    WeatherEffectsLog.info(
      'THUNDER strike #$strikeCount strength=${strength.toStringAsFixed(2)} '
      'double=$doubleFlash',
    );
  }

  void clear() {
    _primaryIntensity = 0;
    _secondaryIntensity = 0;
    _doubleFlashPhase = 0;
    _doubleFlashTimer = 0;
    _pendingSecondaryStrength = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_doubleFlashPhase == 1) {
      _doubleFlashTimer -= dt;
      if (_doubleFlashTimer <= 0) {
        _primaryIntensity = 0;
        _doubleFlashPhase = 2;
        _doubleFlashTimer = 0.1 + _flashRandom.nextDouble() * 0.14;
      }
    } else if (_doubleFlashPhase == 2) {
      _doubleFlashTimer -= dt;
      if (_doubleFlashTimer <= 0) {
        _primaryIntensity = _pendingSecondaryStrength;
        _pendingSecondaryStrength = 0;
        _doubleFlashPhase = 0;
      }
    }

    if (_doubleFlashPhase != 1) {
      _primaryIntensity = _decay(_primaryIntensity, dt, decayRate: 7.5);
    }
    _secondaryIntensity = _decay(_secondaryIntensity, dt, decayRate: 9.0);
  }

  double _decay(double value, double dt, {required double decayRate}) {
    if (value <= 0) return 0;
    final next = value * math.exp(-decayRate * dt);
    return next < 0.02 ? 0 : next;
  }

  @override
  void render(Canvas canvas) {
    final intensity =
        _primaryIntensity > _secondaryIntensity
            ? _primaryIntensity
            : _secondaryIntensity;
    if (intensity < 0.02) return;

    final size = _readViewportSize();
    if (size.x <= 0 || size.y <= 0) return;

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Cool white core + faint blue edge read as lightning, not a flat whiteout.
    final coreAlpha = (intensity * 0.42 * 255).round().clamp(0, 255);
    canvas.drawRect(
      rect,
      Paint()..color = Color.fromARGB(coreAlpha, 235, 245, 255),
    );

    final edgeAlpha = (intensity * 0.14 * 255).round().clamp(0, 255);
    if (edgeAlpha > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Color.fromARGB(edgeAlpha, 170, 200, 255),
      );
    }
  }
}
