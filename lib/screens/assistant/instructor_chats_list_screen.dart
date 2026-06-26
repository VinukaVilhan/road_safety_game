import 'package:flutter/material.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/assistant/instructor_chat_session.dart';
import '../../services/assistant/instructor_chat_sessions_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import 'assistant_chat_screen.dart';

/// Browse, rename, delete, and create instructor chat threads.
class InstructorChatsListScreen extends StatefulWidget {
  const InstructorChatsListScreen({super.key});

  @override
  State<InstructorChatsListScreen> createState() => _InstructorChatsListScreenState();
}

class _InstructorChatsListScreenState extends State<InstructorChatsListScreen> {
  List<InstructorChatSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await InstructorChatSessionsService.instance.listSessions();
      if (mounted) setState(() => _sessions = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AssistantLaunchContext _launchFor(InstructorChatSession s) {
    if (s.isReport) {
      final r = s.lastReport;
      return AssistantLaunchContext(
        assistantSessionId: s.id,
        lastReport: r,
        screenTitle: r != null ? 'Last run report — ${r.levelName}' : null,
      );
    }
    return AssistantLaunchContext(assistantSessionId: s.id);
  }

  Future<void> _openChat(InstructorChatSession s) async {
    UiSoundService().playMenuTap();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AssistantChatScreen(launchContext: _launchFor(s)),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _rename(InstructorChatSession s) async {
    UiSoundService().playMenuTap();
    final controller = TextEditingController(text: s.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename chat', style: AppFonts.pixelifySans(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = controller.text.trim();
    controller.dispose();
    if (t.isEmpty) return;
    await InstructorChatSessionsService.instance.renameSession(s.id, t);
    await _reload();
  }

  Future<void> _delete(InstructorChatSession s) async {
    UiSoundService().playMenuTap();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete chat?', style: AppFonts.pixelifySans(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          '“${s.title}” will be removed. This cannot be undone.',
          style: AppFonts.pixelifySans(fontSize: 14, height: 1.35),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SwissTheme.accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await InstructorChatSessionsService.instance.deleteSession(s.id);
    await _reload();
  }

  Future<void> _newGeneralChat() async {
    UiSoundService().playMenuTap();
    final id = await InstructorChatSessionsService.instance.createGeneralSession();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AssistantChatScreen(
          launchContext: AssistantLaunchContext(assistantSessionId: id),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  String _subtitle(InstructorChatSession s) {
    final kind = s.isReport ? 'Level report' : 'General';
    return '$kind · Created ${s.createdDateLabel} · ${s.messageCount} messages';
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.pixelifySans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: SwissTheme.textPrimary,
    );

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SwissTheme.backgroundWhite,
        foregroundColor: SwissTheme.textPrimary,
        title: Text('INSTRUCTOR CHATS', style: titleStyle),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _newGeneralChat,
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            label: Text(
              'NEW',
              style: AppFonts.pixelifySans(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SwissTheme.accentBlue))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  color: SwissTheme.accentBlue,
                  onRefresh: _reload,
                  child: _sessions.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No saved chats yet.')),
                          ],
                        )
                      : GridView.builder(
                          padding: LandscapeLayout.bodyPadding(context),
                          gridDelegate: LandscapeLayout.listCardGridDelegate(context),
                          itemCount: _sessions.length,
                          itemBuilder: (context, i) => _ChatListCard(
                            session: _sessions[i],
                            subtitle: _subtitle(_sessions[i]),
                            onTap: () => _openChat(_sessions[i]),
                            onRename: () => _rename(_sessions[i]),
                            onDelete: () => _delete(_sessions[i]),
                          ),
                        ),
                ),
    );
  }
}

class _ChatListCard extends StatelessWidget {
  final InstructorChatSession session;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ChatListCard({
    required this.session,
    required this.subtitle,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwissTheme.backgroundWhite,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: SwissTheme.borderBlack, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                session.isReport ? Icons.description_outlined : Icons.chat_bubble_outline,
                size: 20,
                color: SwissTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: AppFonts.pixelifySans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SwissTheme.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppFonts.pixelifySans(
                        fontSize: 10,
                        color: SwissTheme.textSecondary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
