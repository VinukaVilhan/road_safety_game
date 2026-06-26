import 'package:flutter/material.dart';

import '../../models/assistant/instructor_chat_session.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import 'chats_history_sidebar.dart';

/// Collapsible chat-history rail; chat expands into freed space when collapsed.
class RetractableChatsSidebar extends StatelessWidget {
  const RetractableChatsSidebar({
    super.key,
    required this.expanded,
    required this.expandedWidth,
    required this.sessions,
    required this.currentSessionId,
    required this.loading,
    required this.onNewChat,
    required this.onSelect,
    required this.onToggle,
  });

  final bool expanded;
  final double expandedWidth;
  final List<InstructorChatSession> sessions;
  final String currentSessionId;
  final bool loading;
  final VoidCallback? onNewChat;
  final void Function(InstructorChatSession session) onSelect;
  final VoidCallback onToggle;

  void _toggle() {
    UiSoundService().playMenuTap();
    onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final width = expanded ? expandedWidth : LandscapeLayout.chatSidebarRailWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      child: ColoredBox(
        color: SwissTheme.backgroundWhite,
        child: expanded
            ? ChatsHistorySidebar(
                width: expandedWidth,
                sessions: sessions,
                currentSessionId: currentSessionId,
                loading: loading,
                onNewChat: onNewChat,
                onSelect: onSelect,
                onCollapse: _toggle,
              )
            : Material(
                color: SwissTheme.backgroundWhite,
                child: InkWell(
                  onTap: _toggle,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const Icon(Icons.chevron_right, size: 22, color: SwissTheme.textPrimary),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              'CHATS',
                              style: AppFonts.pixelifySans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: SwissTheme.textSecondary,
                              ),
                            ),
                          ),
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
