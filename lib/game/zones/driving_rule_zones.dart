part of '../driving_game.dart';

extension DrivingRuleZones on RealisticCarGameBase {
  void _failTest(String message) {
    if (_testFinished) return;
    _testFinished = true;
    car?.coast();
    _latestFailureMessage = message;
    unawaited(_playRuleBreakWhistle());
    onTestFailed?.call(message);
  }

  void _failStoppedInJunctionBox(String message) {
    _failTest(message);
  }

  void _failFromHighSpeedWallCrash() {
    _failTest('High-speed crash! You hit an obstacle too fast.');
  }

  void _updateDrivingRuleZones() {
    if (!drivingRulesEnabled || _isEmergencyAmbulanceScenario) return;
    if (_isEmergencyWeatherScenario) return;
    if (_testFinished || car == null || _drivingZones.isEmpty) return;

    final currentInside = <int>{};
    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );

    for (final zone in _drivingZones) {
      if (!_carContactsDrivingZone(zone, carRect)) continue;
      currentInside.add(zone.objectId);
      if (_zonesInsidePreviousFrame.contains(zone.objectId)) continue;
      _handleZoneEntry(zone);
      if (_testFinished) break;
    }

    _zonesInsidePreviousFrame
      ..clear()
      ..addAll(currentInside);
  }

  void _handleZoneEntry(_DrivingZone zone) {
    final zoneKind = _zoneKindForScenario(zone.zoneClass);

    if (zoneKind == 'zone_check') {
      _enteredApproachZone = true;
      final expected = _expectedSignalForSummary();
      if (_signalsMatchExpectedForSummary(expected)) {
        _signalOkInApproachZone = true;
      }
      final step = zone.stepId;
      if (_isRoadCrossingMap()) {
        return;
      }
      if (step == null) return;
      if (step == _lastCompletedStepId + 1) {
        _lastCompletedStepId = step;
      }
      return;
    }

    if (zoneKind == 'zone_finish') {
      _reachedFinishZone = true;
      final requiredPreviousStep = (zone.stepId ?? 1) - 1;
      if (_lastCompletedStepId < requiredPreviousStep) {
        return;
      }
      _testFinished = true;
      car?.coast();
      onTestPassed?.call();
      return;
    }

    if (zoneKind == 'wrong_layer') {
      _recordPenalty(
        'Entered the wrong lane / prohibited area.',
        playWhistle: false,
      );
      _failTest(
        zone.failMessage?.isNotEmpty == true
            ? zone.failMessage!
            : 'Wrong turn — you entered the wrong lane.',
      );
      return;
    }

    if (zoneKind == 'zone_fail_wt' || zoneKind == 'zone_fail_it') {
      final defaultMessage = zoneKind == 'zone_fail_it'
          ? 'Driving in oncoming traffic!'
          : (_isRoadCrossingMap()
              ? 'Wrong route — cross via the zebra markings; do not continue past the stop line.'
              : 'Wrong Turn!');
      final message =
          zone.failMessage?.isNotEmpty == true ? zone.failMessage! : defaultMessage;
      _failTest(message);
      return;
    }
  }
}
