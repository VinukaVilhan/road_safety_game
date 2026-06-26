part of '../driving_game.dart';

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
  /// Non-null when the attempt was adverse weather (`emergency_weather`).
  final WeatherAttemptSnapshot? weather;

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
    this.weather,
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

/// Wet-weather level rubric (`emergency_weather` / `adverse_weather.tmx`).
class WeatherAttemptSnapshot {
  final bool enteredCheckZone;
  final bool checkRequirementsMet;
  final bool headlightsActive;
  final bool windshieldActive;
  final bool enteredSpeedZone;
  final int? speedLimit;
  final bool exceededSpeedInZone;

  const WeatherAttemptSnapshot({
    this.enteredCheckZone = false,
    this.checkRequirementsMet = false,
    this.headlightsActive = false,
    this.windshieldActive = false,
    this.enteredSpeedZone = false,
    this.speedLimit,
    this.exceededSpeedInZone = false,
  });
}

enum AmbulanceState { catchingUp, tailgating, passing }
