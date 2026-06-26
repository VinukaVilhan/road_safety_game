part of '../driving_game.dart';

/// `scenarioId: emergency_weather` — viewport rain, reduced grip, wet-road speed cap.
extension _EmergencyWeatherScenario on RealisticCarGameBase {
  static const double _weatherFrictionMultiplier = 0.55;
  static const double _weatherBrakeMultiplier = 0.6;
  static const double _weatherSteerGripMultiplier = 0.72;
  static const double _weatherMaxSpeedWorldUnits = 72.0;

  bool get _isEmergencyWeatherScenario =>
      (scenarioId ?? '').trim().toLowerCase() == 'emergency_weather';

  double get weatherFrictionMultiplier =>
      _isEmergencyWeatherScenario ? _weatherFrictionMultiplier : 1.0;

  double get weatherBrakeMultiplier =>
      _isEmergencyWeatherScenario ? _weatherBrakeMultiplier : 1.0;

  double get weatherSteerGripMultiplier =>
      _isEmergencyWeatherScenario ? _weatherSteerGripMultiplier : 1.0;

  Vector2 _weatherViewportSize() {
    final viewport = camera.viewport;
    final vs = viewport.virtualSize;
    if (vs.x > 0 && vs.y > 0) return vs.clone();
    if (size.x > 0 && size.y > 0) return size.clone();
    return Vector2.zero();
  }

  void _logWeatherSessionStart() {
    WeatherEffectsLog.info(
      'SESSION START levelId=${_weatherLevelId ?? "(unknown)"} '
      'scenarioId=${scenarioId ?? "(null)"} '
      'mapAsset=${mapAsset ?? "(default)"} '
      'isWeather=${_isEmergencyWeatherScenario}',
    );
    if (!_isEmergencyWeatherScenario) {
      WeatherEffectsLog.warn(
        'Rain only runs when scenarioId==emergency_weather. '
        'Open Driving test → Weather Conditions → Adverse Weather.',
      );
    }
  }

  bool _weatherComponentsHealthy() {
    final dim = _weatherDimOverlay;
    final rain = _weatherRainOverlay;
    final thunder = _weatherThunderOverlay;
    return dim != null &&
        rain != null &&
        thunder != null &&
        dim.isMounted &&
        rain.isMounted &&
        thunder.isMounted &&
        dim.parent == camera.viewport &&
        rain.parent == camera.viewport &&
        thunder.parent == camera.viewport;
  }

  Future<void> _setupAdverseWeatherEffects({required String reason}) async {
    WeatherEffectsLog.info(
      'SETUP attempt reason=$reason '
      'scenarioActive=${_isEmergencyWeatherScenario} '
      'flagMounted=$_weatherEffectsMounted',
    );

    if (!_isEmergencyWeatherScenario) {
      WeatherEffectsLog.info('SETUP skipped — not emergency_weather scenario');
      return;
    }

    if (_weatherComponentsHealthy()) {
      _weatherEffectsMounted = true;
      WeatherEffectsLog.info('SETUP skipped — components already healthy');
      if (_lessonAudioActive) {
        unawaited(_weatherSfx.ensureRainLoop());
      }
      return;
    }

    // Stale flag after hot reload or viewport replacement.
    if (_weatherEffectsMounted && !_weatherComponentsHealthy()) {
      WeatherEffectsLog.warn(
        'SETUP remounting — flag was true but components missing',
      );
      _weatherEffectsMounted = false;
      _weatherDimOverlay = null;
      _weatherRainOverlay = null;
      _weatherThunderOverlay = null;
    }

    final viewportSize = _weatherViewportSize();
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      WeatherEffectsLog.warn(
        'SETUP deferred — viewport size zero '
        '(game=${size.x}×${size.y} viewport=${viewportSize.x}×${viewportSize.y})',
      );
      return;
    }

    try {
      final dim = RainVisibilityDimOverlay();
      final rain = RainViewportOverlay();
      final thunder = ThunderFlashOverlay();
      dim.resizeViewport(viewportSize);
      rain.resizeViewport(viewportSize);

      await camera.viewport.addAll([dim, rain, thunder]);

      _weatherDimOverlay = dim;
      _weatherRainOverlay = rain;
      _weatherThunderOverlay = thunder;
      _scheduleNextThunderStrike(initial: true);
      _weatherEffectsMounted = _weatherComponentsHealthy();

      if (_weatherEffectsMounted) {
        WeatherEffectsLog.info(
          'SETUP OK viewport=${viewportSize.x.toStringAsFixed(0)}×'
          '${viewportSize.y.toStringAsFixed(0)} '
          'viewportChildren=${camera.viewport.children.length} '
          'dimMounted=${dim.isMounted} rainMounted=${rain.isMounted} '
          'thunderMounted=${thunder.isMounted} '
          'drops=${rain.activeDropCount} '
          'nextThunder=${_thunderCountdownSec.toStringAsFixed(1)}s',
        );
        if (_lessonAudioActive) {
          unawaited(_weatherSfx.ensureRainLoop());
        }
      } else {
        WeatherEffectsLog.error(
          'SETUP FAILED after add — dimMounted=${dim.isMounted} '
          'rainMounted=${rain.isMounted} parent=${rain.parent?.runtimeType}',
        );
      }
    } catch (e, st) {
      WeatherEffectsLog.error('SETUP exception', e, st);
      _weatherEffectsMounted = false;
    }
  }

  void _resizeAdverseWeatherEffects() {
    if (!_isEmergencyWeatherScenario) return;
    final viewportSize = _weatherViewportSize();
    if (viewportSize.x <= 0 || viewportSize.y <= 0) return;
    _weatherDimOverlay?.resizeViewport(viewportSize);
    _weatherRainOverlay?.resizeViewport(viewportSize);
  }

  void _scheduleNextThunderStrike({bool initial = false}) {
    // First strike after a short wait; then long random gaps between events.
    final minSec = initial ? 10.0 : 32.0;
    final maxSec = initial ? 18.0 : 58.0;
    _thunderCountdownSec =
        minSec + _thunderRandom.nextDouble() * (maxSec - minSec);
  }

  void _triggerThunderStrike() {
    final overlay = _weatherThunderOverlay;
    if (overlay == null || !overlay.isMounted) return;

    final strength = 0.38 + _thunderRandom.nextDouble() * 0.35;
    final doubleFlash =
        _thunderRandom.nextDouble() < ThunderFlashOverlay.doubleFlashChance;
    overlay.strike(strength: strength, doubleFlash: doubleFlash);
    unawaited(_weatherSfx.playThunderOnce());

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  void _tickThunder(double dt) {
    if (!_isEmergencyWeatherScenario || _testFinished || paused) return;
    if (_weatherThunderOverlay == null || !_weatherThunderOverlay!.isMounted) {
      return;
    }

    _thunderCountdownSec -= dt;
    if (_thunderCountdownSec > 0) return;

    _triggerThunderStrike();
    _scheduleNextThunderStrike();
  }

  void _tickWeatherMountRetry(double dt) {
    if (!_isEmergencyWeatherScenario) return;
    _weatherMountRetryTimer += dt;
    if (_weatherMountRetryTimer < 0.75) return;
    _weatherMountRetryTimer = 0;

    if (_weatherComponentsHealthy()) {
      _weatherEffectsMounted = true;
      if (_lessonAudioActive) {
        unawaited(_weatherSfx.ensureRainLoop());
      }
      return;
    }

    unawaited(_setupAdverseWeatherEffects(reason: 'retry_timer'));
  }

  void _tickWeatherHealthLog(double dt) {
    if (!_isEmergencyWeatherScenario) return;
    _weatherHealthLogTimer += dt;
    if (_weatherHealthLogTimer < 4.0) return;
    _weatherHealthLogTimer = 0;

    final vs = _weatherViewportSize();
    WeatherEffectsLog.health(
      phase: 'runtime',
      levelId: _weatherLevelId,
      scenarioId: scenarioId,
      scenarioActive: _isEmergencyWeatherScenario,
      effectsFlagMounted: _weatherEffectsMounted,
      dimMounted: _weatherDimOverlay?.isMounted ?? false,
      rainMounted: _weatherRainOverlay?.isMounted ?? false,
      viewportChildCount: camera.viewport.children.length,
      viewportW: vs.x,
      viewportH: vs.y,
      dropCount: _weatherRainOverlay?.activeDropCount ?? 0,
      renderFrames: _weatherRainOverlay?.renderFrameCount ?? 0,
      enginePaused: paused,
    );

    if (_weatherRainOverlay != null &&
        _weatherRainOverlay!.isMounted &&
        _weatherRainOverlay!.renderFrameCount == 0) {
      WeatherEffectsLog.error(
        'Rain overlay mounted but render() never called — '
        'check camera viewport render path',
      );
    }
  }

  void _updateAdverseWeatherRules() {
    if (!_isEmergencyWeatherScenario || _testFinished) return;
    final c = car;
    if (c == null) return;

    final maxSpeed = _weatherMaxSpeedWorldUnits;
    final currentSpeed = c.velocity.length;
    if (currentSpeed <= maxSpeed) return;

    if (!_weatherSpeedPenaltyIssued) {
      _weatherSpeedPenaltyIssued = true;
      _recordPenalty('Driving too fast for wet road conditions');
    }
    c.velocity = c.velocity.normalized() * maxSpeed;
  }

  void _resetEmergencyWeatherForRestart() {
    _weatherSpeedPenaltyIssued = false;
    _scheduleNextThunderStrike(initial: true);
    _weatherThunderOverlay?.clear();
  }
}
