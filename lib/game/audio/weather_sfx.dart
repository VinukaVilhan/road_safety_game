part of '../driving_game.dart';

/// Looping rain ambience + one-shot thunder for [emergency_weather] levels.
class WeatherSfx {
  static const double _rainVolume = 0.26;
  static const double _thunderVolume = 0.58;

  AudioPlayer? _rainPlayer;

  Future<void> startRainLoop() async {
    await stopRain();
    try {
      final player = _makeWeatherPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource(MediaAssets.rainAmbience),
        volume: _rainVolume,
      );
      _rainPlayer = player;
    } catch (e, st) {
      debugPrint('WeatherSfx rain loop failed: $e\n$st');
    }
  }

  /// One thunder clip per lightning event (including double-flash visuals).
  Future<void> playThunderOnce() async {
    try {
      await FlameAudio.play(
        MediaAssets.thunderClap,
        volume: _thunderVolume,
      );
    } catch (e, st) {
      debugPrint('WeatherSfx thunder failed: $e\n$st');
    }
  }

  void resumePausedRain() {
    final player = _rainPlayer;
    if (player == null || player.state != PlayerState.paused) return;
    unawaited(player.resume());
  }

  Future<void> stopRain() async {
    final player = _rainPlayer;
    _rainPlayer = null;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    await player.dispose();
  }

  Future<void> dispose() async {
    await stopRain();
  }

  static AudioPlayer _makeWeatherPlayer() {
    return AudioPlayer()..audioCache = FlameAudio.audioCache;
  }
}
