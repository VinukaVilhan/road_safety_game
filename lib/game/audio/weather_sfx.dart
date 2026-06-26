part of '../driving_game.dart';

/// Looping rain ambience + one-shot thunder for [emergency_weather] levels.
class WeatherSfx {
  static const double _rainVolume = DrivingAudioLevels.rainAmbience;
  static const double _thunderVolume = DrivingAudioLevels.thunderClap;

  AudioPlayer? _rainPlayer;
  int _generation = 0;

  /// Synchronously blocks new loops and tears down the current player (async).
  void invalidate() {
    _generation++;
    final player = _rainPlayer;
    _rainPlayer = null;
    if (player != null) {
      unawaited(_tearDownPlayer(player));
    }
  }

  Future<void> startRainLoop() async {
    final gen = _generation;
    final stale = _rainPlayer;
    _rainPlayer = null;
    if (stale != null) {
      unawaited(_tearDownPlayer(stale));
    }
    if (gen != _generation) return;

    try {
      final player = _makeWeatherPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      if (gen != _generation) {
        await _tearDownPlayer(player);
        return;
      }
      await player.play(
        AssetSource(MediaAssets.rainAmbience),
        volume: _rainVolume,
      );
      if (gen != _generation) {
        await _tearDownPlayer(player);
        return;
      }
      _rainPlayer = player;
    } catch (e, st) {
      debugPrint('WeatherSfx rain loop failed: $e\n$st');
    }
  }

  /// (Re)starts rain if missing, stopped, or paused — safe after briefing / resume.
  Future<void> ensureRainLoop() async {
    final gen = _generation;
    final player = _rainPlayer;
    if (player != null) {
      if (player.state == PlayerState.playing) return;
      if (player.state == PlayerState.paused) {
        if (gen != _generation) return;
        try {
          await player.resume();
        } catch (e, st) {
          debugPrint('WeatherSfx rain resume failed: $e\n$st');
          if (gen != _generation) return;
          await startRainLoop();
        }
        if (gen != _generation) {
          _rainPlayer = null;
          unawaited(_tearDownPlayer(player));
        }
        return;
      }
    }
    if (gen != _generation) return;
    await startRainLoop();
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
    invalidate();
  }

  Future<void> dispose() async {
    invalidate();
  }

  static Future<void> _tearDownPlayer(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  static AudioPlayer _makeWeatherPlayer() {
    return AudioPlayer()..audioCache = FlameAudio.audioCache;
  }
}
