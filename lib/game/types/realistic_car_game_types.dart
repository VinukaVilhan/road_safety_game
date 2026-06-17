part of '../realistic_car_game.dart';

class _DrivingZone {
  final int objectId;
  final Rect rect;
  final String zoneClass;
  final int? stepId;
  final String? failMessage;
  final double? maxSpeed;
  final double? waitTimeSec;

  const _DrivingZone({
    required this.objectId,
    required this.rect,
    required this.zoneClass,
    this.stepId,
    this.failMessage,
    this.maxSpeed,
    this.waitTimeSec,
  });
}

/// [emergency_ambulance]: CP1–CP4 and CPF from Tiled (`class` CP1…CP4 / CPF, including under [Group]).
class _AmbulanceCheckpoint {
  final String id;
  final Rect rect;
  /// Seconds allowed to reach this checkpoint after the previous timed one; 0 = no limit.
  final double timeLimitSecs;

  const _AmbulanceCheckpoint({
    required this.id,
    required this.rect,
    this.timeLimitSecs = 0,
  });
}

/// Junction "brown" validation: [expectedSignal] is `left`, `right`, or `none`.
class _MidTurnZone {
  final int objectId;
  final Path hitPath;
  final String expectedSignal;

  const _MidTurnZone({
    required this.objectId,
    required this.hitPath,
    required this.expectedSignal,
  });
}

class DrivingAttemptSummary {
  final bool passed;
  final String? failureMessage;
  final Duration timeSpent;
  final String expectedTurnSignal;
  final bool waitedAtRoadCrossing;
  final bool enteredApproachZone;
  final bool signaledCorrectlyInApproachZone;
  final bool enteredMidTurnZone;
  final bool hadCorrectSignalInMidTurnZone;
  final bool reachedFinishZone;
  final int nonCrashBumpCount;
  final int score;
  /// Recorded rule violations (e.g. dashed-lines penalties) that do not stop the run.
  final List<String> penalties;
  /// Non-null when the attempt was the ambulance practical scenario.
  final AmbulanceAttemptSnapshot? ambulance;

  const DrivingAttemptSummary({
    required this.passed,
    required this.failureMessage,
    required this.timeSpent,
    required this.expectedTurnSignal,
    required this.waitedAtRoadCrossing,
    required this.enteredApproachZone,
    required this.signaledCorrectlyInApproachZone,
    required this.enteredMidTurnZone,
    required this.hadCorrectSignalInMidTurnZone,
    required this.reachedFinishZone,
    required this.nonCrashBumpCount,
    required this.score,
    this.penalties = const [],
    this.ambulance,
  });
}

/// Player path sample for ambulance "tethered breadcrumb" tailgating.
class PathNode {
  final Vector2 position;
  final double angle;
  /// False when the sample was taken while overlapping a wall / off valid road.
  final bool isSafe;

  PathNode(this.position, this.angle, this.isSafe);
}

enum AmbulanceState { catchingUp, tailgating, passing }
