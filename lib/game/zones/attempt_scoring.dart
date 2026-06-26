part of '../driving_game.dart';

extension AttemptScoring on RealisticCarGameBase {
  String _expectedSignalForSummary() {
    for (final zone in _midTurnZones) {
      if (zone.expectedSignal == 'left' || zone.expectedSignal == 'right') {
        return zone.expectedSignal;
      }
    }
    return 'none';
  }

  bool _signalsMatchExpectedForSummary(String expected) {
    final leftOn = turnSignalLeft?.value ?? false;
    final rightOn = turnSignalRight?.value ?? false;
    return _turnSignalsMatchExpected(expected, leftOn, rightOn);
  }

  int _computeScore(Duration elapsed) {
    final expected = _expectedSignalForSummary();
    var score = 0;
    if (_enteredApproachZone) score += 20;
    if (_signalOkInApproachZone) score += 20;
    if (_midTurnSignalWasCorrect) score += 30;
    if (_reachedFinishZone) score += 20;

    final ms = elapsed.inMilliseconds;
    int timeBonus;
    if (ms <= 30000) {
      timeBonus = 10;
    } else if (ms >= 120000) {
      timeBonus = 0;
    } else {
      final t = (ms - 30000) / 90000.0;
      timeBonus = ((1 - t) * 10).round().clamp(0, 10);
    }
    score += timeBonus;

    if (expected == 'none' && !_signalOkInApproachZone && score >= 5) {
      score += 5;
    }
    final bumpPenalty = (_nonCrashBumpCount * 2).clamp(0, 20).toInt();
    score -= bumpPenalty;
    return score.clamp(0, 100);
  }

  DrivingAttemptSummary getAttemptSummary({bool? passed, String? failureMessage}) {
    final now = DateTime.now();
    final startedAt = _attemptStartedAt ?? now;
    final elapsed = now.difference(startedAt);
    final expected = _expectedSignalForSummary();
    final resolvedFailure = failureMessage ?? _latestFailureMessage;
    var effectivePassed = passed ?? (_testFinished && resolvedFailure == null);
    if (_usesPenaltyModeMarkingsDashed &&
        effectivePassed &&
        _penalties.isNotEmpty) {
      effectivePassed = false;
    }
    String? failureOut = resolvedFailure;
    if (!effectivePassed &&
        failureOut == null &&
        _usesPenaltyModeMarkingsDashed &&
        _penalties.isNotEmpty &&
        _testFinished &&
        _reachedFinishZone) {
      failureOut =
          'You reached the finish but had driving rule penalties — attempt did not pass.';
    }
    final ambSnap = _buildAmbulanceAttemptSnapshot();

    return DrivingAttemptSummary(
      passed: effectivePassed,
      failureMessage: failureOut,
      timeSpent: elapsed,
      expectedTurnSignal: expected,
      waitedAtRoadCrossing: _roadCrossingStopSatisfied,
      enteredApproachZone: _enteredApproachZone,
      signaledCorrectlyInApproachZone: _signalOkInApproachZone,
      enteredMidTurnZone: _enteredMidTurnZone,
      hadCorrectSignalInMidTurnZone: _midTurnSignalWasCorrect,
      reachedFinishZone: _reachedFinishZone,
      nonCrashBumpCount: _nonCrashBumpCount,
      score: _computeScore(elapsed),
      penalties: List<String>.unmodifiable(_penalties),
      ambulance: ambSnap,
    );
  }

  void registerNonCrashBump() {
    final now = DateTime.now();
    if (_lastNonCrashBumpAt != null &&
        now.difference(_lastNonCrashBumpAt!).inMilliseconds < 700) {
      return;
    }
    _lastNonCrashBumpAt = now;
    _nonCrashBumpCount += 1;
  }

  void _recordPenalty(String description, {bool playWhistle = true}) {
    if (_testFinished) return;
    _penalties.add(description);
    if (playWhistle && _usesPenaltyModeMarkingsDashed) {
      unawaited(_playRuleBreakWhistle());
    }
    onPenaltyRecorded?.call(description);
  }
}
