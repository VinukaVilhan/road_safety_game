library;

/// Cloudinary credentials for client-side uploads (unsigned preset).
///
/// Use an **unsigned upload preset** in the Cloudinary console; never ship
/// `api_secret` in the app. Restrict the preset (folder, formats, max size).
///
/// Resolution order:
/// 1. `--dart-define=CLOUDINARY_CLOUD_NAME=...` and `CLOUDINARY_UPLOAD_PRESET=...`
/// 2. Bundled `assets/config/developer_env.json` (`CLOUDINARY_CLOUD_NAME`,
///    `CLOUDINARY_UPLOAD_PRESET`).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class CloudinaryConfig {
  CloudinaryConfig._();

  static String _cloudName = '';
  static String _uploadPreset = '';

  static Future<void> ensureLoaded() async {
    const cloudFromDefine = String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: '',
    );
    const presetFromDefine = String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: '',
    );
    if (cloudFromDefine.isNotEmpty && presetFromDefine.isNotEmpty) {
      _cloudName = cloudFromDefine.trim();
      _uploadPreset = presetFromDefine.trim();
      return;
    }

    try {
      final raw = await rootBundle.loadString('assets/config/developer_env.json');
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      final c = map?['CLOUDINARY_CLOUD_NAME'];
      final p = map?['CLOUDINARY_UPLOAD_PRESET'];
      _cloudName = c is String ? c.trim() : '';
      _uploadPreset = p is String ? p.trim() : '';
    } catch (_) {
      _cloudName = '';
      _uploadPreset = '';
    }
  }

  static String get cloudName => _cloudName;
  static String get uploadPreset => _uploadPreset;

  static bool get isConfigured =>
      _cloudName.isNotEmpty && _uploadPreset.isNotEmpty;
}
