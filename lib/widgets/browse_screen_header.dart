import 'package:flutter/material.dart';

import '../models/assistant/assistant_launch_context.dart';
import '../services/audio/ui_sound_service.dart';
import '../theme/landscape_layout.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import 'assistant_button.dart';

/// Top bar row: optional back, title, and Ask AI action.
class BrowseScreenHeader extends StatelessWidget {
  const BrowseScreenHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.onBack,
    required this.launchContext,
    this.heroTag,
    this.titleStyle,
    this.maxTitleLines = 2,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBack;
  final AssistantLaunchContext launchContext;
  final Object? heroTag;
  final TextStyle? titleStyle;
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = titleStyle ??
        AppFonts.pixelifySans(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: SwissTheme.textPrimary,
        );

    return Padding(
      padding: LandscapeLayout.headerPadding(context),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: () {
                UiSoundService().playMenuTap();
                onBack!();
              },
              icon: const Icon(
                Icons.arrow_back_sharp,
                color: SwissTheme.textPrimary,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: titleWidget ??
                Text(
                  title!,
                  style: resolvedTitleStyle,
                  maxLines: maxTitleLines,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
          const SizedBox(width: 12),
          AssistantButton(
            inAppBar: true,
            heroTag: heroTag,
            launchContext: launchContext,
          ),
        ],
      ),
    );
  }
}
