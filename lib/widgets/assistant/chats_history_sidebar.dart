import 'package:flutter/material.dart';

import '../../models/assistant/instructor_chat_session.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';

class ChatsHistorySidebar extends StatelessWidget {
  const ChatsHistorySidebar({
    super.key,
    required this.width,
    required this.sessions,
    required this.currentSessionId,
    required this.loading,
    required this.onNewChat,
    required this.onSelect,
  });

  final double width;
  final List<InstructorChatSession> sessions;
  final String currentSessionId;
  final bool loading;
  final VoidCallback? onNewChat;
  final void Function(InstructorChatSession session) onSelect;

  String _subtitle(InstructorChatSession s) {
    final kind = s.isReport ? 'Report' : 'General';
    return '$kind · ${s.messageCount} msgs';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: SwissTheme.backgroundWhite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'CHATS',
                      style: AppFonts.pixelifySans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: SwissTheme.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onNewChat,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '+ NEW',
                      style: AppFonts.pixelifySans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: SwissTheme.accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : sessions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No chats yet.',
                              textAlign: TextAlign.center,
                              style: AppFonts.pixelifySans(
                                fontSize: 11,
                                color: SwissTheme.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: sessions.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: SwissTheme.dividerBlack,
                          ),
                          itemBuilder: (context, i) {
                            final s = sessions[i];
                            final selected = s.id == currentSessionId;
                            return Material(
                              color: selected
                                  ? SwissTheme.accentBlue.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () => onSelect(s),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        s.isReport
                                            ? Icons.description_outlined
                                            : Icons.chat_bubble_outline,
                                        size: 16,
                                        color: selected
                                            ? SwissTheme.accentBlue
                                            : SwissTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppFonts.pixelifySans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: SwissTheme.textPrimary,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _subtitle(s),
                                              style: AppFonts.pixelifySans(
                                                fontSize: 9,
                                                color: SwissTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
