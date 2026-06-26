part of '../driving_game.dart';

/// Engine audio: car_start.m4a (one-shot) → car_idle.m4a (seamless loop with
/// dynamic pitch + volume). Uses [AudioPlayer] in [PlayerMode.mediaPlayer]
/// directly so that [AudioPlayer.setPlaybackRate] and [ReleaseMode.loop] work
/// reliably on Android (SoundPool / lowLatency does NOT support these).
class VehicleSfx {
  static const String _engineIdleLoopAsset = MediaAssets.carIdle;
  static const String _engineStartAsset = MediaAssets.carStart;
  static const String _reverseLoopAsset = MediaAssets.reverseLoop;
  static const String _brakeAsset = MediaAssets.brake;

  static const double _engineStartVol = DrivingAudioLevels.engineStart;
  static const double _idleEngineVol = DrivingAudioLevels.engineIdle;
  static const double _maxEngineVol = DrivingAudioLevels.engineMax;
  static const double _reverseVol = DrivingAudioLevels.reverse;
  static const double _brakeVol = DrivingAudioLevels.brake;

  /// Playback rate = pitch multiplier. 0.85 = low idle rumble, 2.0 = screaming.
  /// Clamped to 0.5–2.0 which is the universal safe range across platforms.
  static const double _idlePitch = 0.85;
  static const double _maxPitch = 2.0;

  AudioPlayer? _startPlayer;
  AudioPlayer? _engine;
  AudioPlayer? _reverse;

  /// Incremented whenever forward-engine audio is torn down; lets async tasks
  /// detect they are stale and bail out without touching new players.
  int _forwardSeq = 0;
  int _reverseSeq = 0;

  bool _wantForwardEngine = false;
  bool _wantReverse = false;

  /// dt-accumulator so the idle loop starts after the start clip finishes.
  double _startElapsed = 0.0;
  /// How long car_start.m4a runs before we switch to the idle loop.
  static const double _startDuration = 2.4;
  bool _inStartPhase = false;

  double _lastPitch = -1;
  double _lastVol = -1;
  double _brakeRepeat = 0;

  /// After the first car start in a level, only the idle loop is used when
  /// returning from P/R to forward gears (see [resetForLevelRestart] on retry).
  bool _playedCarStartForLevel = false;

  /// Call when the driving level restarts (e.g. Retry) so car start plays again.
  void resetForLevelRestart() {
    _playedCarStartForLevel = false;
    // Force the forward/reverse state machine to re-run; otherwise [wantForward]
    // can stay true across retry and [tick] never calls [_beginForwardEngine] again.
    _wantForwardEngine = false;
    _wantReverse = false;
    _inStartPhase = false;
    _startElapsed = 0;
    _stopForwardEngine();
    unawaited(_stopReverse());
  }

  /// [AudioPlayer]s are sometimes left [PlayerState.paused] after route overlays or
  /// focus changes even though we still want loops to play.
  void resumePausedOutputs() {
    for (final p in <AudioPlayer?>[_startPlayer, _engine, _reverse]) {
      if (p == null || p.state != PlayerState.paused) continue;
      unawaited(p.resume());
    }
  }

  /// Stops reverse loop immediately (e.g. UI shifted to P or a forward gear).
  void cancelReverseAudio() {
    if (!_wantReverse && _reverse == null) return;
    _wantReverse = false;
    unawaited(_stopReverse());
  }

  void tick(double dt, Car? car) {
    if (car == null) return;

    final speed = car.getCurrentSpeed();
    final wantForward = !car.isInPark && car.currentGear > 0;
    final wantReverse = !car.isInPark &&
        car.currentGear == -1 &&
        (car.isAccelerating || speed > 6);

    // ── Forward engine state machine ──
    if (wantForward != _wantForwardEngine) {
      _wantForwardEngine = wantForward;
      if (wantForward) {
        unawaited(_beginForwardEngine());
      } else {
        _stopForwardEngine();
      }
    }

    // Advance start-sound timer → switch to idle loop
    if (_wantForwardEngine && _inStartPhase) {
      _startElapsed += dt;
      if (_startElapsed >= _startDuration) {
        _inStartPhase = false;
        final seq = _forwardSeq;
        unawaited(_launchIdleLoop(seq));
      }
    }

    // Modulate idle loop every frame
    if (_wantForwardEngine && _engine != null) {
      _modulateEngine(car);
    }

    // ── Reverse ──
    if (wantReverse != _wantReverse) {
      _wantReverse = wantReverse;
      if (wantReverse) {
        unawaited(_startReverse());
      } else {
        unawaited(_stopReverse());
      }
    } else if (_reverse != null && !wantReverse) {
      // Async _startReverse can finish after gear already left R/P — stop orphaned loop.
      _wantReverse = false;
      unawaited(_stopReverse());
    }

    // ── Brake tick ──
    if (car.isBraking && speed > 14) {
      _brakeRepeat -= dt;
      if (_brakeRepeat <= 0) {
        _brakeRepeat = 0.32;
        unawaited(_playBrakeIfAvailable());
      }
    } else {
      _brakeRepeat = 0;
    }
  }

  void dispose() {
    _stopForwardEngine();
    unawaited(_stopReverse());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _stopForwardEngine() {
    _forwardSeq++;
    _inStartPhase = false;
    _startElapsed = 0;
    _lastPitch = -1;
    _lastVol = -1;
    _disposePlayer(_startPlayer);
    _startPlayer = null;
    _disposePlayer(_engine);
    _engine = null;
  }

  static void _disposePlayer(AudioPlayer? p) {
    if (p == null) return;
    unawaited(() async {
      try {
        await p.stop();
      } catch (_) {}
      await p.dispose();
    }());
  }

  /// Creates a fresh [AudioPlayer] that uses [PlayerMode.mediaPlayer] (default).
  /// This is the only mode that reliably supports [setPlaybackRate] and
  /// [ReleaseMode.loop] on all platforms.
  static AudioPlayer _makePlayer() {
    return AudioPlayer()..audioCache = FlameAudio.audioCache;
  }

  Future<void> _beginForwardEngine() async {
    final seq = _forwardSeq;
    _inStartPhase = false;
    _startElapsed = 0;
    _lastPitch = -1;
    _lastVol = -1;

    // Stop any previous engine audio
    _disposePlayer(_engine);
    _engine = null;
    _disposePlayer(_startPlayer);
    _startPlayer = null;

    // First forward engagement this level: car start → idle. Later P/R→D: idle only.
    if (_playedCarStartForLevel) {
      unawaited(_launchIdleLoop(seq));
      return;
    }

    try {
      final p = _makePlayer();
      await p.setReleaseMode(ReleaseMode.release);
      await p.play(AssetSource(_engineStartAsset), volume: _engineStartVol);
      if (seq != _forwardSeq) {
        _disposePlayer(p);
        return;
      }
      _playedCarStartForLevel = true;
      _startPlayer = p;
      _inStartPhase = true;
    } catch (e, st) {
      debugPrint('VehicleSfx start failed: $e\n$st');
      _playedCarStartForLevel = true;
      if (seq == _forwardSeq) {
        unawaited(_launchIdleLoop(seq));
      }
    }
  }

  Future<void> _launchIdleLoop(int seq) async {
    if (seq != _forwardSeq) return;

    // Dispose start player now that we are done with it
    _disposePlayer(_startPlayer);
    _startPlayer = null;

    try {
      final p = _makePlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource(_engineIdleLoopAsset), volume: _idleEngineVol);
      await p.setPlaybackRate(_idlePitch);
      if (seq != _forwardSeq) {
        _disposePlayer(p);
        return;
      }
      _engine = p;
      _lastPitch = _idlePitch;
      _lastVol = _idleEngineVol;
    } catch (e, st) {
      debugPrint('VehicleSfx idle loop failed: $e\n$st');
    }
  }

  void _modulateEngine(Car car) {
    final p = _engine;
    if (p == null) return;

    final gearCap =
        car.maxSpeed * (car.gearSpeedMultipliers[car.currentGear]?.abs() ?? 0.2);
    if (gearCap <= 1e-6) return;

    final ratio = (car.getCurrentSpeed() / gearCap).clamp(0.0, 1.0);
    final pitch = (_idlePitch + ratio * (_maxPitch - _idlePitch)).clamp(0.5, 2.0);
    final vol = _idleEngineVol + ratio * (_maxEngineVol - _idleEngineVol);

    // Skip trivial updates to avoid hammering the platform channel
    if ((pitch - _lastPitch).abs() < 0.015 && (vol - _lastVol).abs() < 0.02) {
      return;
    }
    _lastPitch = pitch;
    _lastVol = vol;
    unawaited(p.setPlaybackRate(pitch));
    unawaited(p.setVolume(vol));
  }

  static Future<void> _playBrakeIfAvailable() async {
    try {
      await FlameAudio.play(_brakeAsset, volume: _brakeVol);
    } catch (_) {}
  }

  Future<void> _startReverse() async {
    await _stopReverseInternal();
    final seq = ++_reverseSeq;
    try {
      final p = _makePlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource(_reverseLoopAsset), volume: _reverseVol);
      if (seq != _reverseSeq) {
        _disposePlayer(p);
        return;
      }
      if (!_wantReverse) {
        _disposePlayer(p);
        return;
      }
      _reverse = p;
    } catch (e, st) {
      debugPrint('VehicleSfx reverse loop failed: $e\n$st');
    }
  }

  Future<void> _stopReverse() async {
    _reverseSeq++;
    await _stopReverseInternal();
  }

  Future<void> _stopReverseInternal() async {
    final p = _reverse;
    _reverse = null;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
      await p.dispose();
    }
  }
}
