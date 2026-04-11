library;

/// Gemini API configuration for the in-app AI assistant.
///
/// Resolution order:
/// 1. Compile-time `--dart-define=GEMINI_API_KEY=...` (or `--dart-define-from-file`).
/// 2. Bundled asset `assets/config/developer_env.json` (field `GEMINI_API_KEY`).
///
/// See [README.md](README.md) in this folder.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AssistantConfig {
  AssistantConfig._();

  static String _geminiApiKey = '';

  /// Call once after [WidgetsFlutterBinding.ensureInitialized] (e.g. from [main]).
  static Future<void> ensureLoaded() async {
    const fromDefine = String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) {
      _geminiApiKey = fromDefine;
      return;
    }

    try {
      final raw = await rootBundle.loadString('assets/config/developer_env.json');
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      final fromFile = map?['GEMINI_API_KEY'];
      if (fromFile is String && fromFile.trim().isNotEmpty) {
        _geminiApiKey = fromFile.trim();
      } else {
        _geminiApiKey = '';
      }
    } catch (_) {
      _geminiApiKey = '';
    }
  }

  static String get geminiApiKey => _geminiApiKey;

  static bool get hasApiKey => _geminiApiKey.isNotEmpty;
}
