import 'package:flutter/material.dart';

import '../models/assistant_launch_context.dart';
import '../models/instructor_chat_session.dart';
import '../services/assistant/instructor_chat_sessions_service.dart';
import '../services/audio/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
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
    final when = _formatRelative(s.updatedAt);
    return '$kind · $when · ${s.messageCount} messages';
  }

  String _formatRelative(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final d = now.difference(local);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _newGeneralChat,
        backgroundColor: SwissTheme.accentBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(
          'NEW CHAT',
          style: AppFonts.pixelifySans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
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
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                          itemCount: _sessions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: SwissTheme.dividerBlack),
                          itemBuilder: (context, i) {
                            final s = _sessions[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: Icon(
                                s.isReport ? Icons.description_outlined : Icons.chat_bubble_outline,
                                color: SwissTheme.textSecondary,
                              ),
                              title: Text(
                                s.title,
                                style: AppFonts.pixelifySans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: SwissTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _subtitle(s),
                                style: AppFonts.pixelifySans(
                                  fontSize: 12,
                                  color: SwissTheme.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                              onTap: () => _openChat(s),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (v) {
                                  if (v == 'rename') _rename(s);
                                  if (v == 'delete') _delete(s);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
