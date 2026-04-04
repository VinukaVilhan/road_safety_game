import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Short UI feedback for menus and dialogs. Uses [soundEnabled] / [vibrationEnabled]
/// so the options screen can turn each off independently.
class UiSoundService {
  static final UiSoundService _instance = UiSoundService._();
  factory UiSoundService() => _instance;

  UiSoundService._();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _levelPassPlayer = AudioPlayer();
  final AudioPlayer _levelFailPlayer = AudioPlayer();
  bool _assetReady = false;
  bool _levelPassReady = false;
  bool _levelFailReady = false;

  bool soundEnabled = true;
  bool vibrationEnabled = true;

  void playMenuTap() {
    if (vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
    if (soundEnabled) {
      unawaited(_playTapSound());
    }
  }

  Future<void> _playTapSound() async {
    try {
      if (!_assetReady) {
        await _sfxPlayer.setAsset('assets/audio/menu_tap.wav');
        await _sfxPlayer.setVolume(0.45);
        _assetReady = true;
      }
      await _sfxPlayer.seek(Duration.zero);
      await _sfxPlayer.play();
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
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
