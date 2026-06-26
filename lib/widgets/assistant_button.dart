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
    this.inAppBar = false,
    this.onDarkBackground = false,
    this.heroTag,
    this.tooltip = 'AI instructor',
  });

  final AssistantLaunchContext launchContext;
  final bool mini;
  /// Compact top-bar control (replaces floating action button on browse screens).
  final bool inAppBar;
  /// Light foreground for overlays on the driving HUD.
  final bool onDarkBackground;
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
    if (inAppBar) {
      return _NavBarButton(
        tooltip: tooltip,
        onDarkBackground: onDarkBackground,
        onPressed: () => _open(context),
      );
    }

    final tag = heroTag ?? 'assistant_${identityHashCode(launchContext)}';

    if (mini) {
      return Tooltip(
        message: tooltip,
        child: FloatingActionButton.small(
          heroTag: tag,
          backgroundColor: SwissTheme.textPrimary,
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
        backgroundColor: SwissTheme.textPrimary,
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

class _NavBarButton extends StatelessWidget {
  const _NavBarButton({
    required this.tooltip,
    required this.onDarkBackground,
    required this.onPressed,
  });

  final String tooltip;
  final bool onDarkBackground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = onDarkBackground ? Colors.white : SwissTheme.textPrimary;
    final border = onDarkBackground ? Colors.white70 : SwissTheme.borderBlack;
    final fill = onDarkBackground
        ? Colors.black.withValues(alpha: 0.45)
        : SwissTheme.backgroundWhite;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: fill,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy_outlined, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  'ASK AI',
                  style: AppFonts.pixelifySans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
