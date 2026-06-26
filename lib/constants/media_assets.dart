/// Canonical bundled media paths (snake_case filenames).
abstract final class MediaAssets {
  // ── Audio (Flame [AssetSource] / cache keys — filename under assets/audio/) ──
  static const String carStart = 'car_start.m4a';
  static const String carIdle = 'car_idle.m4a';
  static const String reverseLoop = 'reverse_loop.m4a';
  static const String ambulanceSiren = 'ambulance_siren.m4a';
  static const String ruleWhistle = 'rule_whistle.m4a';
  static const String rainAmbience = 'rain_ambience.mp3';
  static const String thunderClap = 'thunder_clap.mp3';
  static const String brake = 'brake.wav';

  static const String uiTap = 'assets/audio/ui_tap.mp3';
  static const String uiToggle = 'assets/audio/ui_toggle.mp3';
  static const String uiEngineStart = 'assets/audio/ui_engine_start.mp3';
  static const String levelPass = 'assets/audio/level_pass.wav';
  static const String levelFail = 'assets/audio/level_fail.wav';

  // ── Images (Flame sprite keys — filename under assets/images/) ──
  static const String blackCar = 'black_car.png';
  static const String ambulanceV1 = 'ambulance_v1.png';
  static const String ambulanceV2 = 'ambulance_v2.png';

  // ── Full Flutter asset paths ──
  static const String radioIcon = 'assets/images/radio.png';
  static const String signalLight = 'assets/images/signal_light.png';
  static const String steeringWheelRescaled =
      'assets/images/rescaled/steering_wheel.png';
  static const String gearboxCubicRescaled =
      'assets/images/rescaled/gearbox_cubic.png';
  static const String gasNormalRescaled = 'assets/images/rescaled/gas_normal.png';
  static const String gasPressedRescaled =
      'assets/images/rescaled/gas_pressed.png';
  static const String gasPressedSimpleRescaled =
      'assets/images/rescaled/gas_pressed_simple.png';
  static const String brakeNormalRescaled =
      'assets/images/rescaled/brake_normal.png';
  static const String brakePressedRescaled =
      'assets/images/rescaled/brake_pressed.png';
  static const String brakePressedSimpleRescaled =
      'assets/images/rescaled/brake_pressed_simple.png';

  static const String pedestrianCrossingSign =
      'assets/roadsigns/pedestrian_crossing.jpeg';
}
