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
  bool _assetReady = false;

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
}
