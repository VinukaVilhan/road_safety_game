import 'dart:io';

Future<List<String>> getLocalMusicPathsFromFolder(String? path) async {
  if (path == null || path.isEmpty) return [];
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    const supported = ['.mp3', '.m4a', '.aac', '.ogg', '.wav'];
    final files = await dir
        .list(recursive: false)
        .where((e) => e is File && supported.any((ext) => e.path.toLowerCase().endsWith(ext)))
        .map((e) => (e as File).path)
        .toList();
    return files;
  } catch (_) {
    return [];
  }
}
