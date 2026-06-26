import 'package:flutter/foundation.dart';

/// Structured diagnostics for adverse-weather viewport rain.
///
/// Filter logcat / terminal with: `WeatherFX`
class WeatherEffectsLog {
  WeatherEffectsLog._();

  static const String tag = 'WeatherFX';

  static int _seq = 0;

  static void info(String message) {
    debugPrint('[$tag #${++_seq}] $message');
  }

  static void warn(String message) {
    debugPrint('[$tag #${++_seq}] WARN $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$tag #${++_seq}] ERROR $message');
    if (error != null) {
      debugPrint('[$tag #${++_seq}]   cause: $error');
    }
    if (stackTrace != null) {
      debugPrint('[$tag #${++_seq}]   $stackTrace');
    }
  }

  /// One-line snapshot for periodic health checks.
  static void health({
    required String phase,
    required String? levelId,
    required String? scenarioId,
    required bool scenarioActive,
    required bool effectsFlagMounted,
    required bool dimMounted,
    required bool rainMounted,
    required int viewportChildCount,
    required double viewportW,
    required double viewportH,
    required int dropCount,
    required int renderFrames,
    required bool enginePaused,
  }) {
    info(
      'HEALTH phase=$phase '
      'level=${levelId ?? "(none)"} '
      'scenario=${scenarioId ?? "(null)"} '
      'active=$scenarioActive '
      'flagMounted=$effectsFlagMounted '
      'dim=$dimMounted rain=$rainMounted '
      'viewportChildren=$viewportChildCount '
      'viewport=${viewportW.toStringAsFixed(0)}x${viewportH.toStringAsFixed(0)} '
      'drops=$dropCount renderFrames=$renderFrames '
      'paused=$enginePaused',
    );
  }
}
