part of '../driving_game.dart';

/// HUD copy shown while the player is inside [Speed_Layer] on adverse weather maps.
class WeatherSpeedHudHint {
  final String message;
  final int recommendedGear;

  const WeatherSpeedHudHint({
    required this.message,
    required this.recommendedGear,
  });
}

/// Prompt shown when the car enters [Check_Layer] on `adverse_weather.tmx`.
class WeatherCheckPromptRequest {
  final bool requireHeadlights;
  final bool requireWindshield;
  final String title;
  final String message;
  final void Function({required bool headlights, required bool windshield})
      onSubmit;

  const WeatherCheckPromptRequest({
    required this.requireHeadlights,
    required this.requireWindshield,
    required this.title,
    required this.message,
    required this.onSubmit,
  });
}

class _WeatherRectZone {
  final Rect rect;
  final int? stepId;
  const _WeatherRectZone({required this.rect, this.stepId});
}

/// TMX object rects must include the parent [ObjectGroup] offset (Tiled layer drag).
Rect _weatherZoneRect(ObjectGroup layer, TiledObject obj) {
  return Rect.fromLTWH(
    obj.x + layer.offsetX,
    obj.y + layer.offsetY,
    obj.width,
    obj.height,
  );
}

extension _WeatherRuleZones on RealisticCarGameBase {
  bool get _usesPenaltyModeWeather => _isEmergencyWeatherScenario;

  void _resetWeatherRuleStateForRestart() {
    _weatherEnteredCheckZone = false;
    _weatherCheckRequirementsMet = false;
    _weatherHeadlightsActive = false;
    _weatherWindshieldActive = false;
    _weatherCheckPromptShown = false;
    _weatherCheckPromptArmed = true;
    _weatherInsideCheckZone = false;
    _weatherInsideSpeedZone = false;
    _weatherEverEnteredSpeedZone = false;
    _weatherSpeedPenaltyIssued = false;
    _weatherMaxSpeedInSpeedZone = 0;
    weatherSpeedHud.value = null;
    _applyWeatherVisualEffects();
    car?.weatherHeadlightsEnabled = false;
  }

  void _loadWeatherScenarioZones(TiledMap tiledMap) {
    _weatherCheckZone = null;
    _weatherSpeedZone = null;
    _weatherFinishRect = null;
    _weatherFinishRequiredStep = null;
    _weatherSpeedLimit = null;
    _weatherSpeedMessage = null;

    for (final layer in tiledMap.layers.whereType<ObjectGroup>()) {
      final layerName =
          layer.name.trim().toLowerCase().replaceAll(' ', '_');
      for (final obj in layer.objects) {
        if (!obj.visible || obj.width <= 0 || obj.height <= 0) continue;
        if (obj.isPoint || obj.isPolyline || obj.isPolygon || obj.isEllipse) {
          continue;
        }
        if (obj.rotation != 0) continue;

        final rect = _weatherZoneRect(layer, obj);
        if (layerName == 'check_layer') {
          _weatherRequireHeadlights = _readBoolProperty(
            layer.properties,
            'require_headlights',
            defaultValue: true,
          );
          _weatherRequireWindshield = _readBoolProperty(
            layer.properties,
            'require_windshield_wipers',
            defaultValue: true,
          );
          _weatherPopupTitle = _readStringProperty(layer.properties, 'popup_title') ??
              'Prepare for rain';
          _weatherPopupMessage =
              _readStringProperty(layer.properties, 'popup_message') ??
                  'Turn on headlights and windshield wipers before continuing.';
          _weatherCheckZone = _WeatherRectZone(
            rect: rect,
            stepId: _readNumericPropertyAsDouble(layer.properties, 'step_id')
                    ?.round() ??
                _readNumericPropertyAsDouble(obj.properties, 'step_id')?.round(),
          );
        } else if (layerName == 'speed_layer') {
          final limit = _readNumericPropertyAsDouble(obj.properties, 'max_speed')
                  ?.round() ??
              _readNumericPropertyAsDouble(layer.properties, 'max_speed')?.round();
          _weatherSpeedZone = _WeatherRectZone(rect: rect);
          _weatherSpeedLimit = limit;
          _weatherSpeedMessage = _readStringProperty(layer.properties, 'speed_message') ??
              _readStringProperty(obj.properties, 'speed_message');
        }
      }
    }

    for (final zone in _drivingZones) {
      if (_zoneKindForScenario(zone.zoneClass) != 'zone_finish') continue;
      _weatherFinishRect = zone.rect;
      _weatherFinishRequiredStep = zone.stepId ?? 1;
    }

    print(
      '[DEBUG] Weather zones — check=${_weatherCheckZone != null} '
      'speed=${_weatherSpeedZone != null} limit=$_weatherSpeedLimit '
      'finish=${_weatherFinishRect != null}',
    );
  }

  void setWeatherHeadlightsActive(bool enabled) {
    _weatherHeadlightsActive = enabled;
    car?.weatherHeadlightsEnabled = enabled;
  }

  void setWeatherWindshieldActive(bool enabled) {
    _weatherWindshieldActive = enabled;
    _applyWeatherVisualEffects();
  }

  void _applyWeatherVisualEffects() {
    _weatherRainOverlay?.dropOpacityScale =
        _weatherWindshieldActive ? 0.42 : 1.0;
  }

  void _showWeatherCheckPromptIfNeeded() {
    if (_weatherCheckPromptShown || onWeatherCheckPrompt == null) return;
    _weatherCheckPromptShown = true;
    pauseEngine();

    onWeatherCheckPrompt!(
      WeatherCheckPromptRequest(
        requireHeadlights: _weatherRequireHeadlights,
        requireWindshield: _weatherRequireWindshield,
        title: _weatherPopupTitle,
        message: _weatherPopupMessage,
        onSubmit: _submitWeatherCheckPrompt,
      ),
    );
  }

  void _submitWeatherCheckPrompt({
    required bool headlights,
    required bool windshield,
  }) {
    resumeEngine();
    setWeatherHeadlightsActive(headlights);
    setWeatherWindshieldActive(windshield);

    final lightsOk = !_weatherRequireHeadlights || headlights;
    final wipersOk = !_weatherRequireWindshield || windshield;
    if (lightsOk && wipersOk) {
      _weatherCheckRequirementsMet = true;
      final step = _weatherCheckZone?.stepId ?? 1;
      if (step > _lastCompletedStepId) {
        _lastCompletedStepId = step;
      }
      return;
    }

    final missing = <String>[];
    if (!lightsOk) missing.add('headlights');
    if (!wipersOk) missing.add('windshield wipers');
    _recordPenalty(
      'Did not turn on ${missing.join(' and ')} at the check zone.',
      playWhistle: true,
    );
  }

  void _updateWeatherRuleZones() {
    if (!_isEmergencyWeatherScenario || _testFinished || car == null) return;

    final carRect = _weatherCarRect();
    if (carRect == null) return;

    // Headlights only after the player confirms them in the check-zone popup.
    if (!_weatherCheckRequirementsMet && car!.weatherHeadlightsEnabled) {
      car!.weatherHeadlightsEnabled = false;
    }

    _updateWeatherCheckZone(carRect);
    _updateWeatherSpeedZone(carRect);
    _updateWeatherFinishZone(carRect);
  }

  Rect? _weatherCarRect() {
    final c = car;
    if (c == null) return null;
    return Rect.fromCenter(
      center: Offset(c.position.x, c.position.y),
      width: c.size.x,
      height: c.size.y,
    );
  }

  /// If the car spawns overlapping the check zone, suppress the popup until it
  /// leaves and drives back in. Headlights stay off until the popup is confirmed.
  void _seedWeatherRuleZonesAtSpawn() {
    if (!_isEmergencyWeatherScenario || car == null) return;

    car!.weatherHeadlightsEnabled = false;
    _weatherHeadlightsActive = false;
    _applyWeatherVisualEffects();

    final zone = _weatherCheckZone;
    final carRect = _weatherCarRect();
    if (zone == null || carRect == null) {
      _weatherCheckPromptArmed = true;
      _weatherInsideCheckZone = false;
      return;
    }

    if (carRect.overlaps(zone.rect)) {
      _weatherInsideCheckZone = true;
      _weatherCheckPromptArmed = false;
    } else {
      _weatherInsideCheckZone = false;
      _weatherCheckPromptArmed = true;
    }
  }

  void _updateWeatherCheckZone(Rect carRect) {
    final zone = _weatherCheckZone;
    if (zone == null) return;

    final inside = carRect.overlaps(zone.rect);
    if (inside && !_weatherInsideCheckZone) {
      _weatherEnteredCheckZone = true;
      if (_weatherCheckPromptArmed) {
        _showWeatherCheckPromptIfNeeded();
      }
    } else if (!inside && _weatherInsideCheckZone) {
      if (_weatherEnteredCheckZone &&
          !_weatherCheckRequirementsMet &&
          _weatherCheckPromptShown) {
        _recordPenalty(
          'Left the check zone without turning on required lights and wipers.',
          playWhistle: true,
        );
      }
      if (!_weatherCheckRequirementsMet) {
        _weatherCheckPromptArmed = true;
      }
    }
    _weatherInsideCheckZone = inside;
  }

  int _recommendedGearForSpeedLimit(int limit) {
    final c = car;
    if (c == null) return 1;
    var best = 1;
    for (var gear = 1; gear <= 4; gear++) {
      final cap = c.maxSpeed * (c.gearSpeedMultipliers[gear] ?? 0);
      if (cap <= limit) best = gear;
    }
    return best;
  }

  void _evaluateWeatherSpeedAfterLeavingZone(int limit) {
    if (_weatherSpeedPenaltyIssued || !_weatherEverEnteredSpeedZone) return;
    if (_weatherMaxSpeedInSpeedZone <= limit) return;

    _weatherSpeedPenaltyIssued = true;
    _recordPenalty(
      'Drove too fast through the wet speed section (limit $limit).',
      playWhistle: true,
    );
  }

  void _updateWeatherSpeedZone(Rect carRect) {
    final zone = _weatherSpeedZone;
    final limit = _weatherSpeedLimit;
    if (zone == null || limit == null || limit <= 0) {
      weatherSpeedHud.value = null;
      _weatherInsideSpeedZone = false;
      return;
    }

    if (!_weatherCheckRequirementsMet) {
      weatherSpeedHud.value = null;
      _weatherInsideSpeedZone = false;
      return;
    }

    final inside = carRect.overlaps(zone.rect);
    if (inside) {
      if (!_weatherInsideSpeedZone) {
        _weatherEverEnteredSpeedZone = true;
        _weatherMaxSpeedInSpeedZone = 0;
      }
      final speed = car!.velocity.length;
      if (speed > _weatherMaxSpeedInSpeedZone) {
        _weatherMaxSpeedInSpeedZone = speed;
      }

      weatherSpeedHud.value = WeatherSpeedHudHint(
        message: _weatherSpeedMessage ??
            'Maintain a low speed in this wet section',
        recommendedGear: _recommendedGearForSpeedLimit(limit),
      );
    } else if (_weatherInsideSpeedZone) {
      weatherSpeedHud.value = null;
      _evaluateWeatherSpeedAfterLeavingZone(limit);
    } else {
      weatherSpeedHud.value = null;
    }
    _weatherInsideSpeedZone = inside;
  }

  void _updateWeatherFinishZone(Rect carRect) {
    final finish = _weatherFinishRect;
    if (finish == null || !carRect.overlaps(finish)) return;
    if (_reachedFinishZone) return;

    _reachedFinishZone = true;
    final requiredStep = (_weatherFinishRequiredStep ?? 1) - 1;
    if (_lastCompletedStepId < requiredStep) {
      _failTest(
        'Complete the check zone (lights and wipers) before the finish.',
      );
      return;
    }
    if (!_weatherCheckRequirementsMet) {
      _failTest(
        'Turn on headlights and windshield wipers at the check zone before finishing.',
      );
      return;
    }
    if (_penalties.isNotEmpty) {
      _testFinished = true;
      car?.coast();
      _latestFailureMessage =
          'You reached the finish but broke wet-weather rules — see penalties in your report.';
      onTestFailed?.call(_latestFailureMessage!);
      return;
    }

    _testFinished = true;
    car?.coast();
    onTestPassed?.call();
  }

  WeatherAttemptSnapshot _buildWeatherAttemptSnapshot() {
    if (!_isEmergencyWeatherScenario) return const WeatherAttemptSnapshot();
    return WeatherAttemptSnapshot(
      enteredCheckZone: _weatherEnteredCheckZone,
      checkRequirementsMet: _weatherCheckRequirementsMet,
      headlightsActive: _weatherHeadlightsActive,
      windshieldActive: _weatherWindshieldActive,
      enteredSpeedZone: _weatherEverEnteredSpeedZone,
      speedLimit: _weatherSpeedLimit,
      exceededSpeedInZone: _weatherSpeedPenaltyIssued,
    );
  }
}
