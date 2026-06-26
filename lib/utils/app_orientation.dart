import 'package:flutter/services.dart';

/// App-wide landscape lock — same mode as the practical driving game.
abstract final class AppOrientation {
  static const List<DeviceOrientation> landscapeOnly = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Call once from [main] before [runApp].
  static Future<void> lockLandscape() {
    return SystemChrome.setPreferredOrientations(landscapeOnly);
  }
}
