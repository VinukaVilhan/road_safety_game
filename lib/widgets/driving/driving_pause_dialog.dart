import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/driving_game.dart';
import '../../services/audio/music_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/audio/weather_sfx_service.dart';

/// Pause menu for the practical driving test.
Future<void> showDrivingPauseDialog({
  required BuildContext context,
  required RealisticCarGame game,
}) {
  final theme = Theme.of(context).textTheme;
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Game Paused',
          style: theme.titleLarge!.copyWith(color: Colors.white),
        ),
        content: Text(
          'What would you like to do?',
          style: theme.bodyLarge!.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.of(dialogContext).pop();
              game.resumeAmbientAudioAfterUiOverlay();
            },
            child: Text(
              'Resume',
              style: theme.labelLarge!.copyWith(color: Colors.green),
            ),
          ),
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              game.endLessonAudio();
              unawaited(() async {
                await WeatherSfxService.instance.endLesson();
                await MusicService().endDrivingLesson();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) Navigator.of(context).pop();
              }());
            },
            child: Text(
              'Quit',
              style: theme.labelLarge!.copyWith(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );
}
