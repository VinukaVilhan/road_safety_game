import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../../constants/media_assets.dart';
import 'driving_audio_levels.dart';

/// App-wide rain ambience for adverse-weather driving lessons.
///
/// Uses a fixed [AudioPlayer] id so [endLesson] can always reach the native
/// loop even if a per-game reference was lost.
class WeatherSfxService {
  WeatherSfxService._();

  static final WeatherSfxService instance = WeatherSfxService._();

  static const String _rainPlayerId = 'driving_weather_rain_ambience';
  static const double _rainVolume = DrivingAudioLevels.rainAmbience;
  static const double _thunderVolume = DrivingAudioLevels.thunderClap;

  bool _lessonActive = false;
  int _generation = 0;
  AudioPlayer? _rainPlayer;

  bool get isLessonActive => _lessonActive;

  /// Call when a driving lesson route mounts ([GameScreen]).
  void beginLesson() {
    _lessonActive = true;
  }

  /// Synchronously blocks new loops and begins async teardown.
  void invalidate() {
    _lessonActive = false;
    _generation++;
    final player = _rainPlayer;
    _rainPlayer = null;
    if (player != null) {
      unawaited(_tearDownPlayer(player));
    }
    unawaited(_stopNativeRainPlayer());
  }

  /// Stops rain and waits for native release — call before route pop.
  Future<void> stopAndAwait() => endLesson();

  /// Ends the lesson and stops every rain player handle (tracked + fixed id).
  Future<void> endLesson() async {
    _lessonActive = false;
    _generation++;
    final player = _rainPlayer;
    _rainPlayer = null;
    if (player != null) {
      await _tearDownPlayer(player);
    }
    await _stopNativeRainPlayer();
  }

  AudioPlayer _acquireRainPlayer() {
    final existing = _rainPlayer;
    if (existing != null) return existing;
    final player = AudioPlayer(playerId: _rainPlayerId)
      ..audioCache = FlameAudio.audioCache;
    _rainPlayer = player;
    return player;
  }

  Future<void> startRainLoop() async {
    if (!_lessonActive) return;
    final gen = _generation;
    if (gen != _generation || !_lessonActive) return;

    try {
      final player = _acquireRainPlayer();
      if (gen != _generation || !_lessonActive) return;
      await player.setReleaseMode(ReleaseMode.loop);
      if (gen != _generation || !_lessonActive) {
        await _tearDownPlayer(player);
        return;
      }
      if (player.state == PlayerState.playing) return;
      await player.play(
        AssetSource(MediaAssets.rainAmbience),
        volume: _rainVolume,
      );
      if (gen != _generation || !_lessonActive) {
        _rainPlayer = null;
        await _tearDownPlayer(player);
      }
    } catch (e, st) {
      debugPrint('WeatherSfxService rain loop failed: $e\n$st');
    }
  }

  Future<void> ensureRainLoop() async {
    if (!_lessonActive) return;
    final gen = _generation;
    final player = _rainPlayer;
    if (player != null) {
      if (player.state == PlayerState.playing) return;
      if (player.state == PlayerState.paused) {
        if (gen != _generation || !_lessonActive) return;
        try {
          await player.resume();
        } catch (e, st) {
          debugPrint('WeatherSfxService rain resume failed: $e\n$st');
          if (!_lessonActive) return;
          await startRainLoop();
        }
        if (gen != _generation || !_lessonActive) {
          _rainPlayer = null;
          await _tearDownPlayer(player);
        }
        return;
      }
    }
    if (gen != _generation || !_lessonActive) return;
    await startRainLoop();
  }

  Future<void> playThunderOnce() async {
    if (!_lessonActive) return;
    try {
      await FlameAudio.play(
        MediaAssets.thunderClap,
        volume: _thunderVolume,
      );
    } catch (e, st) {
      debugPrint('WeatherSfxService thunder failed: $e\n$st');
    }
  }

  void resumePausedRain() {
    if (!_lessonActive) return;
    final gen = _generation;
    final player = _rainPlayer;
    if (player == null || player.state != PlayerState.paused) return;
    unawaited(() async {
      try {
        await player.resume();
      } catch (_) {}
      if (gen != _generation || !_lessonActive) {
        _rainPlayer = null;
        await _tearDownPlayer(player);
      }
    }());
  }

  static Future<void> _tearDownPlayer(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
    try {
      await player.release();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  /// Stops via the stable player id even when [_rainPlayer] was cleared.
  static Future<void> _stopNativeRainPlayer() async {
    try {
      final player = AudioPlayer(playerId: _rainPlayerId)
        ..audioCache = FlameAudio.audioCache;
      await _tearDownPlayer(player);
    } catch (e, st) {
      debugPrint('WeatherSfxService native rain stop failed: $e\n$st');
    }
  }
}
