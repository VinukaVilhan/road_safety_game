import 'dart:io';

const _maxFiles = 800;

/// Lists audio files under [path] (recursive). Empty if missing or unreadable.
Future<List<String>> getLocalMusicPathsFromFolder(String? path) async {
  if (path == null || path.isEmpty) return [];
  final trimmed = path.trim();
  if (trimmed.startsWith('content:')) return [];

  try {
    final dir = Directory(trimmed);
    if (!await dir.exists()) return [];
    const supported = [
      '.mp3',
      '.m4a',
      '.aac',
      '.ogg',
      '.wav',
      '.flac',
    ];
    final out = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!supported.any((ext) => lower.endsWith(ext))) continue;
      out.add(entity.path);
      if (out.length >= _maxFiles) break;
    }
    out.sort();
    return out;
  } catch (_) {
    return [];
  }
}
