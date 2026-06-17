import 'package:flutter/material.dart';

import '../models/assistant/assistant_launch_context.dart';
import '../screens/assistant/assistant_chat_screen.dart';
import '../services/audio/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';

/// Opens the AI instructor chat with optional [launchContext].
class AssistantButton extends StatelessWidget {
  const AssistantButton({
    super.key,
    this.launchContext = const AssistantLaunchContext(),
    this.mini = false,
    this.heroTag,
    this.tooltip = 'AI instructor',
  });

  final AssistantLaunchContext launchContext;
  final bool mini;
  final Object? heroTag;
  final String tooltip;

  void _open(BuildContext context) {
    UiSoundService().playMenuTap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssistantChatScreen(launchContext: launchContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? 'assistant_${identityHashCode(launchContext)}';

    if (mini) {
      return Tooltip(
        message: tooltip,
        child: FloatingActionButton.small(
          heroTag: tag,
          backgroundColor: SwissTheme.accentBlue,
          foregroundColor: Colors.white,
          onPressed: () => _open(context),
          child: const Icon(Icons.smart_toy_outlined),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: FloatingActionButton.extended(
        heroTag: tag,
        backgroundColor: SwissTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.smart_toy_outlined),
        label: Text(
          'ASK AI',
          style: AppFonts.pixelifySans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        onPressed: () => _open(context),
      ),
    );
  }
}
