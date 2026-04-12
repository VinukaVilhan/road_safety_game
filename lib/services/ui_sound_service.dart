import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Short UI feedback for menus and dialogs. Uses [soundEnabled] / [vibrationEnabled]
/// so the options screen can turn each off independently.
///
/// [playMenuTap] — buttons; [playMenuToggle] — `Switch` widgets; [playLevelEngineStart] — after level load / briefing.
class UiSoundService {
  static final UiSoundService _instance = UiSoundService._();
  factory UiSoundService() => _instance;

  UiSoundService._();

  static const String _tapAsset =
      'assets/audio/litupsubway-ui-hover-sfx-513360.mp3';
  static const String _toggleAsset =
      'assets/audio/freesound_community-menu-selection-102220.mp3';
  static const String _engineStartAsset =
      'assets/audio/freesound_community-car-engine-starting-43705.mp3';

  final AudioPlayer _tapPlayer = AudioPlayer();
  final AudioPlayer _togglePlayer = AudioPlayer();
  final AudioPlayer _engineStartPlayer = AudioPlayer();
  final AudioPlayer _levelPassPlayer = AudioPlayer();
  final AudioPlayer _levelFailPlayer = AudioPlayer();
  bool _tapReady = false;
  bool _toggleReady = false;
  bool _engineStartReady = false;
  bool _levelPassReady = false;
  bool _levelFailReady = false;

  bool soundEnabled = true;
  bool vibrationEnabled = true;

  /// Decodes and buffers UI clips so the first menu tap is not blocked by [setAsset].
  /// Safe to call multiple times; overlaps with other startup work if started early.
  Future<void> preload() async {
    await Future.wait<void>([
      _warmTap(),
      _warmToggle(),
      _warmEngineStart(),
      _warmLevel(
        player: _levelPassPlayer,
        assetPath: 'assets/audio/level_pass.wav',
        volume: 0.5,
        readyFlag: (v) => _levelPassReady = v,
        isReady: () => _levelPassReady,
      ),
      _warmLevel(
        player: _levelFailPlayer,
        assetPath: 'assets/audio/level_fail.wav',
        volume: 0.48,
        readyFlag: (v) => _levelFailReady = v,
        isReady: () => _levelFailReady,
      ),
    ], eagerError: false);
  }

  Future<void> _warmTap() async {
    try {
      if (_tapReady) return;
      await _tapPlayer.setAsset(_tapAsset);
      await _tapPlayer.setVolume(0.5);
      _tapReady = true;
    } catch (_) {}
  }

  Future<void> _warmToggle() async {
    try {
      if (_toggleReady) return;
      await _togglePlayer.setAsset(_toggleAsset);
      await _togglePlayer.setVolume(0.55);
      _toggleReady = true;
    } catch (_) {}
  }

  Future<void> _warmEngineStart() async {
    try {
      if (_engineStartReady) return;
      await _engineStartPlayer.setAsset(_engineStartAsset);
      await _engineStartPlayer.setVolume(0.65);
      _engineStartReady = true;
    } catch (_) {}
  }

  Future<void> _warmLevel({
    required AudioPlayer player,
    required String assetPath,
    required double volume,
    required void Function(bool) readyFlag,
    required bool Function() isReady,
  }) async {
    try {
      if (isReady()) return;
      await player.setAsset(assetPath);
      await player.setVolume(volume);
      readyFlag(true);
    } catch (_) {}
  }

  void playMenuTap() {
    if (vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
    if (soundEnabled) {
      unawaited(_playTapSound());
    }
  }

  /// Toggle switches (e.g. Options sound / vibration).
  ///
  /// When [playSfxEvenWhenSoundOff] is true, the toggle clip still plays so flipping
  /// **Sound** from off → on is audible (otherwise [soundEnabled] would block it).
  void playMenuToggle({bool playSfxEvenWhenSoundOff = false}) {
    if (vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
    if (playSfxEvenWhenSoundOff || soundEnabled) {
      unawaited(_playToggleSound());
    }
  }

  /// Car engine start once the driving screen is ready and any level briefing was dismissed.
  void playLevelEngineStart() {
    if (!soundEnabled) return;
    unawaited(_playEngineStartSound());
  }

  Future<void> _playTapSound() async {
    try {
      if (!_tapReady) {
        await _tapPlayer.setAsset(_tapAsset);
        await _tapPlayer.setVolume(0.5);
        _tapReady = true;
      }
      await _tapPlayer.seek(Duration.zero);
      await _tapPlayer.play();
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _playToggleSound() async {
    try {
      if (!_toggleReady) {
        await _togglePlayer.setAsset(_toggleAsset);
        await _togglePlayer.setVolume(0.55);
        _toggleReady = true;
      }
      await _togglePlayer.seek(Duration.zero);
      await _togglePlayer.play();
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _playEngineStartSound() async {
    try {
      if (!_engineStartReady) {
        await _engineStartPlayer.setAsset(_engineStartAsset);
        await _engineStartPlayer.setVolume(0.65);
        _engineStartReady = true;
      }
      await _engineStartPlayer.seek(Duration.zero);
      await _engineStartPlayer.play();
    } catch (_) {
      // Optional SFX
    }
  }

  void playLevelPassed() {
    if (!soundEnabled) return;
    unawaited(_playLevelAsset(
      player: _levelPassPlayer,
      assetPath: 'assets/audio/level_pass.wav',
      volume: 0.5,
      readyFlag: (v) => _levelPassReady = v,
      isReady: () => _levelPassReady,
    ));
  }

  void playLevelFailed() {
    if (!soundEnabled) return;
    unawaited(_playLevelAsset(
      player: _levelFailPlayer,
      assetPath: 'assets/audio/level_fail.wav',
      volume: 0.48,
      readyFlag: (v) => _levelFailReady = v,
      isReady: () => _levelFailReady,
    ));
  }

  Future<void> _playLevelAsset({
    required AudioPlayer player,
    required String assetPath,
    required double volume,
    required void Function(bool) readyFlag,
    required bool Function() isReady,
  }) async {
    try {
      if (!isReady()) {
        await player.setAsset(assetPath);
        await player.setVolume(volume);
        readyFlag(true);
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Level SFX is optional; ignore missing/unsupported assets.
    }
  }
}
