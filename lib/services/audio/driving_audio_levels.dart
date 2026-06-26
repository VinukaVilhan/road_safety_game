/// Shared volume levels for in-lesson vehicle SFX and background radio/music.
///
/// Radio must stay below idle, reverse, and accelerate engine loops so driving
/// feedback remains audible ([VehicleSfx] in `lib/game/audio/vehicle_sfx.dart`).
abstract final class DrivingAudioLevels {
  static const double engineStart = 0.55;
  static const double engineIdle = 0.32;
  static const double engineMax = 0.72;
  static const double reverse = 0.24;
  static const double brake = 0.34;

  /// Quietest continuous vehicle loop while driving (reverse beep).
  static const double quietestVehicleLoop = reverse;

  /// Internet radio / local music during a driving lesson — capped below
  /// [quietestVehicleLoop] so car idle, reverse, and acceleration SFX stay louder.
  static const double radioMaxDuringLesson = quietestVehicleLoop * 0.85;
}
