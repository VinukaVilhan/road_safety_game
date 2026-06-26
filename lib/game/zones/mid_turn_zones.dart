part of '../driving_game.dart';

extension MidTurnZones on RealisticCarGameBase {
  void _updateMarkingsDashedYellowZoneRules() {
    if (!_usesPenaltyModeMarkingsDashed ||
        _testFinished ||
        car == null ||
        turnSignalLeft == null ||
        turnSignalRight == null) {
      return;
    }

    final carRect = Rect.fromCenter(
      center: Offset(car!.position.x, car!.position.y),
      width: car!.size.x,
      height: car!.size.y,
    );
    final rightOn = turnSignalRight!.value;
    final leftOn = turnSignalLeft!.value;
    final approachOk = rightOn && !leftOn;

    final nowInside = <int>{};

    for (final zone in _drivingZones) {
      if (_zoneKindForScenario(zone.zoneClass) != 'zone_check') continue;

      if (carRect.overlaps(zone.rect)) {
        nowInside.add(zone.objectId);
        if (approachOk) {
          _signalOkInApproachZone = true;
          _approachZonesRightSignalGiven.add(zone.objectId);
        }
      } else if (_approachZonesCurrentlyInside.contains(zone.objectId)) {
        if (!_approachZonesRightSignalGiven.contains(zone.objectId)) {
          _recordPenalty(
            'Right turn signal was not used before leaving the yellow approach zone.',
          );
        }
        _approachZonesRightSignalGiven.remove(zone.objectId);
      }
    }

    _approachZonesCurrentlyInside
      ..clear()
      ..addAll(nowInside);
  }

  bool _turnSignalsMatchExpected(String expected, bool leftOn, bool rightOn) {
    switch (expected) {
      case 'left':
        return leftOn && !rightOn;
      case 'right':
        return rightOn && !leftOn;
      case 'none':
      case 'straight':
        return !leftOn && !rightOn;
      default:
        return true;
    }
  }

  String _midTurnFailMessage(_MidTurnZone zone, bool leftOn, bool rightOn) {
    final exp = zone.expectedSignal;
    if (exp == 'left') {
      return 'Use your left signal when taking the left path of the junction.';
    }
    if (exp == 'right') {
      return 'Use your right signal when taking the right path of the junction.';
    }
    if (exp == 'none' || exp == 'straight') {
      if (leftOn && rightOn) {
        return 'Turn signals must be off when going straight through the junction.';
      }
      if (leftOn) {
        return 'Turn off your left signal when going straight through the junction.';
      }
      if (rightOn) {
        return 'Turn off your right signal when going straight through the junction.';
      }
      return 'Turn signals must be off when going straight through the junction.';
    }
    return 'Incorrect turn signal for this lane.';
  }

  void _updateMidTurnSignalValidation() {
    if (!drivingRulesEnabled || _isEmergencyAmbulanceScenario) return;
    if (_testFinished ||
        car == null ||
        _midTurnZones.isEmpty ||
        turnSignalLeft == null ||
        turnSignalRight == null) {
      return;
    }

    if (_usesPenaltyModeMarkingsDashed) {
      _updateMidTurnSignalValidationPenaltyMode();
    } else {
      _updateMidTurnSignalValidationFailMode();
    }
  }

  void _updateMidTurnSignalValidationFailMode() {
    final leftOn = turnSignalLeft!.value;
    final rightOn = turnSignalRight!.value;
    final center = Offset(car!.position.x, car!.position.y);

    for (final zone in _midTurnZones) {
      if (!zone.hitPath.contains(center)) continue;
      _enteredMidTurnZone = true;
      if (!_turnSignalsMatchExpected(zone.expectedSignal, leftOn, rightOn)) {
        final message = _midTurnFailMessage(zone, leftOn, rightOn);
        _failTest(message);
        return;
      }
      _midTurnSignalWasCorrect = true;
    }
  }

  bool _carCenterInMidTurnZone(_MidTurnZone zone, Offset center) {
    if (zone.hitPath.contains(center)) return true;
    final b = zone.hitPath.getBounds();
    if (b.isEmpty ||
        !b.left.isFinite ||
        !b.top.isFinite ||
        !b.right.isFinite ||
        !b.bottom.isFinite) {
      return false;
    }
    const pad = 6.0;
    return Rect.fromLTRB(
      b.left - pad,
      b.top - pad,
      b.right + pad,
      b.bottom + pad,
    ).contains(center);
  }

  void _updateMidTurnSignalValidationPenaltyMode() {
    final leftOn = turnSignalLeft!.value;
    final rightOn = turnSignalRight!.value;
    final center = Offset(car!.position.x, car!.position.y);
    final nowInside = <int>{};

    for (final zone in _midTurnZones) {
      final id = zone.objectId;
      final inside = _carCenterInMidTurnZone(zone, center);

      if (inside) {
        nowInside.add(id);
        _enteredMidTurnZone = true;
        final signalOk = _turnSignalsMatchExpected(zone.expectedSignal, leftOn, rightOn);
        if (signalOk) {
          _midTurnSignalWasCorrect = true;
          _midTurnZonesWrongSignalPenaltyIssued.remove(id);
        } else if (!_midTurnZonesWrongSignalPenaltyIssued.contains(id)) {
          _midTurnZonesWrongSignalPenaltyIssued.add(id);
          _midTurnSignalWasCorrect = false;
          _recordPenalty(_midTurnPenaltyDescription(zone, leftOn, rightOn));
        }
      } else if (_midTurnZonesCurrentlyInside.contains(id)) {
        _midTurnZonesWrongSignalPenaltyIssued.remove(id);
      }
    }

    _midTurnZonesCurrentlyInside
      ..clear()
      ..addAll(nowInside);
  }

  String _midTurnPenaltyDescription(_MidTurnZone zone, bool leftOn, bool rightOn) {
    final exp = zone.expectedSignal;
    if (exp == 'right') {
      return 'Right turn signal must be on throughout the purple turn zone.';
    }
    if (exp == 'left') {
      return 'Left turn signal must be on throughout the purple turn zone.';
    }
    return _midTurnFailMessage(zone, leftOn, rightOn);
  }
}
