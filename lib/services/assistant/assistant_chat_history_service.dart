import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/assistant/assistant_message.dart';
import 'assistant_service.dart';

/// Persists the AI instructor transcript locally and rebuilds Gemini history.
class AssistantChatHistoryService {
  AssistantChatHistoryService._();
  static final AssistantChatHistoryService instance = AssistantChatHistoryService._();

  static const _prefsKey = 'assistant_chat_history_v1';
  static const _maxMessages = 120;

  Future<List<AssistantMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AssistantMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<AssistantMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed =
        messages.length <= _maxMessages ? messages : messages.sublist(messages.length - _maxMessages);
    final encoded =
        jsonEncode(trimmed.map((m) => m.toJson()).toList(growable: false));
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// History for [GenerativeModel.startChat]: skips leading assistant-only UI (welcome),
  /// drops a trailing user turn without a following assistant reply, and uses [userModelText]
  /// when set for user turns.
  static List<Content> toGeminiHistory(List<AssistantMessage> messages) {
    if (messages.isEmpty) return [];

    var slice = List<AssistantMessage>.from(messages);
    while (slice.isNotEmpty && slice.first.role == AssistantMessageRole.assistant) {
      slice = slice.sublist(1);
    }
    while (slice.isNotEmpty && slice.last.role == AssistantMessageRole.user) {
      slice = slice.sublist(0, slice.length - 1);
    }

    final out = <Content>[];
    for (final m in slice) {
      if (m.role == AssistantMessageRole.user) {
        String t;
        if (m.userModelText != null && m.userModelText!.isNotEmpty) {
          t = m.userModelText!;
        } else if (m.hasUserImage && m.text == AssistantService.imageOnlyDisplayPlaceholder) {
          t = AssistantService.imageOnlyUserPrompt;
        } else {
          t = m.text;
        }
        if (t.isEmpty) continue;
        out.add(Content.text(t));
      } else {
        if (m.text.isEmpty) continue;
        out.add(Content.model([TextPart(m.text)]));
      }
    }
    return out;
  }
}
