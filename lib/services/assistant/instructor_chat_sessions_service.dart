import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/assistant/assistant_message.dart';
import '../../models/assistant/instructor_chat_session.dart';
import '../../models/driving/last_driving_report.dart';
import 'assistant_chat_history_service.dart';

/// Multi-thread local storage for instructor chats (general + per level report).
class InstructorChatSessionsService {
  InstructorChatSessionsService._();
  static final InstructorChatSessionsService instance = InstructorChatSessionsService._();

  static const _prefsV2 = 'instructor_chat_sessions_v2';
  static const _legacyV1 = 'assistant_chat_history_v1';
  static const _maxMessagesPerSession = 120;
  static const _generalDefaultId = 'general';

  static const _uuid = Uuid();

  /// Stable id for this saved report attempt (separate thread per run).
  static String sessionIdForReport(LastDrivingReport report) {
    final ms = report.recordedAt.toUtc().millisecondsSinceEpoch;
    final lid = report.levelId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'report_${lid}_$ms';
  }

  static String _defaultTitle({required String kind, LastDrivingReport? report}) {
    if (kind == InstructorChatSession.kindLevelReport && report != null) {
      final l = report.recordedAt.toLocal();
      final d = '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
      return '${report.levelName} · $d';
    }
    if (kind == InstructorChatSession.kindGeneral) {
      return 'Main instructor';
    }
    return 'Chat';
  }

  Future<Map<String, dynamic>> _readRoot() async {
    final prefs = await SharedPreferences.getInstance();
    await migrateV1IfNeeded(prefs);
    final raw = prefs.getString(_prefsV2);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{
        'version': 2,
        'sessions': <String, dynamic>{},
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {'version': 2, 'sessions': <String, dynamic>{}};
      }
      final root = Map<String, dynamic>.from(decoded);
      root['sessions'] = Map<String, dynamic>.from(root['sessions'] as Map? ?? {});
      return root;
    } catch (_) {
      return {'version': 2, 'sessions': <String, dynamic>{}};
    }
  }

  Future<void> _writeRoot(Map<String, dynamic> root) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsV2, jsonEncode(root));
  }

  /// One-time migration from single global transcript.
  Future<void> migrateV1IfNeeded(SharedPreferences prefs) async {
    if (prefs.getString(_prefsV2) != null) return;
    final legacy = prefs.getString(_legacyV1);
    final sessions = <String, dynamic>{};
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final list = jsonDecode(legacy) as List<dynamic>;
        final messages = list
            .map((e) => AssistantMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final now = DateTime.now().toUtc().toIso8601String();
        sessions[_generalDefaultId] = {
          'title': _defaultTitle(kind: InstructorChatSession.kindGeneral, report: null),
          'kind': InstructorChatSession.kindGeneral,
          'createdAt': now,
          'updatedAt': now,
          'report': null,
          'messages': messages.map((m) => m.toJson()).toList(),
        };
      } catch (_) {}
    }
    if (sessions.isEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      sessions[_generalDefaultId] = {
        'title': _defaultTitle(kind: InstructorChatSession.kindGeneral, report: null),
        'kind': InstructorChatSession.kindGeneral,
        'createdAt': now,
        'updatedAt': now,
        'report': null,
        'messages': <dynamic>[],
      };
    }
    await prefs.setString(_prefsV2, jsonEncode({'version': 2, 'sessions': sessions}));
  }

  Map<String, dynamic> _sessionMap(Map<String, dynamic> root) =>
      Map<String, dynamic>.from(root['sessions'] as Map? ?? {});

  /// Resolves which storage key this screen should use.
  String resolveSessionId(AssistantLaunchContext ctx) {
    if (ctx.assistantSessionId != null && ctx.assistantSessionId!.trim().isNotEmpty) {
      return ctx.assistantSessionId!.trim();
    }
    if (ctx.lastReport != null) {
      return sessionIdForReport(ctx.lastReport!);
    }
    return _generalDefaultId;
  }

  Future<void> ensureSession({
    required String id,
    required String kind,
    String? title,
    LastDrivingReport? report,
  }) async {
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    if (sessions.containsKey(id)) return;
    final now = DateTime.now().toUtc().toIso8601String();
    sessions[id] = {
      'title': title ?? _defaultTitle(kind: kind, report: report),
      'kind': kind,
      'createdAt': now,
      'updatedAt': now,
      'report': report?.toJson(),
      'messages': <dynamic>[],
    };
    root['sessions'] = sessions;
    await _writeRoot(root);
  }

  Future<InstructorChatSession?> getSession(String id) async {
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    final raw = sessions[id];
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final msgs = (m['messages'] as List?) ?? const [];
    return InstructorChatSession.fromStorage(id, m, messageCount: msgs.length);
  }

  Future<List<InstructorChatSession>> listSessions() async {
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    final out = <InstructorChatSession>[];
    for (final e in sessions.entries) {
      final id = e.key;
      final raw = e.value;
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final msgs = (m['messages'] as List?) ?? const [];
      out.add(InstructorChatSession.fromStorage(id, m, messageCount: msgs.length));
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<List<AssistantMessage>> loadMessages(String sessionId) async {
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    final raw = sessions[sessionId];
    if (raw is! Map) return [];
    final list = (raw['messages'] as List?) ?? const [];
    try {
      return list
          .map((e) => AssistantMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages(String sessionId, List<AssistantMessage> messages) async {
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    final raw = sessions[sessionId];
    if (raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    final trimmed = messages.length <= _maxMessagesPerSession
        ? messages
        : messages.sublist(messages.length - _maxMessagesPerSession);
    m['messages'] = trimmed.map((x) => x.toJson()).toList();
    m['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    sessions[sessionId] = m;
    root['sessions'] = sessions;
    await _writeRoot(root);
  }

  Future<void> renameSession(String id, String newTitle) async {
    final t = newTitle.trim();
    if (t.isEmpty) return;
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    final raw = sessions[id];
    if (raw is! Map) return;
    final m = Map<String, dynamic>.from(raw);
    m['title'] = t;
    m['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    sessions[id] = m;
    root['sessions'] = sessions;
    await _writeRoot(root);
  }

  Future<void> deleteSession(String id) async {
    final root = await _readRoot();
    final sessions = _sessionMap(root);
    sessions.remove(id);
    root['sessions'] = sessions;
    await _writeRoot(root);
    if (id == _generalDefaultId && !sessions.containsKey(_generalDefaultId)) {
      await ensureSession(
        id: _generalDefaultId,
        kind: InstructorChatSession.kindGeneral,
        title: _defaultTitle(kind: InstructorChatSession.kindGeneral, report: null),
      );
    }
  }

  /// New empty general-purpose thread.
  Future<String> createGeneralSession({String? title}) async {
    final id = 'g_${_uuid.v4()}';
    await ensureSession(
      id: id,
      kind: InstructorChatSession.kindGeneral,
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'New chat',
    );
    return id;
  }

  Future<void> clearMessages(String sessionId) async {
    await saveMessages(sessionId, const []);
  }

  /// Same rules as [AssistantChatHistoryService.toGeminiHistory].
  static List<Content> toGeminiHistory(List<AssistantMessage> messages) =>
      AssistantChatHistoryService.toGeminiHistory(messages);
}
