import 'package:flutter/material.dart';

import '../../models/driving/game_level.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/content/level_briefing_registry.dart';
import 'level_briefing_dialog.dart';

bool willShowLevelBriefing(GameLevel level) {
  return LevelBriefingRegistry.resolve(level) != null;
}

/// Shows the paginated level briefing carousel; calls [onDismissed] when closed.
Future<void> showLevelBriefingDialog({
  required BuildContext context,
  required GameLevel level,
  required VoidCallback onDismissed,
}) {
  final briefing = LevelBriefingRegistry.resolve(level);
  if (briefing == null) {
    UiSoundService().playLevelEngineStart();
    return Future.value();
  }

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => LevelBriefingDialog(briefing: briefing),
  ).then((_) => onDismissed());
}
