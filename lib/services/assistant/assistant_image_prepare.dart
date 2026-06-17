import 'dart:typed_data';
import 'dart:ui' as ui;

/// Shrinks and re-encodes as PNG so inline Gemini requests stay within limits.
Future<Uint8List?> shrinkImageForModel(Uint8List raw) async {
  try {
    Uint8List working = raw;
    const maxBytes = 3 * 1024 * 1024; // ~3 MiB inline target
    const dims = <int>[1280, 960, 640, 480];

    for (final dim in dims) {
      final codec = await ui.instantiateImageCodec(
        working,
        targetWidth: dim,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd == null) return null;
      working = bd.buffer.asUint8List();
      if (working.length <= maxBytes) return working;
    }
    return working.length <= 4 * 1024 * 1024 ? working : null;
  } catch (_) {
    return raw.length <= 4 * 1024 * 1024 ? raw : null;
  }
}

String mimeTypeFromFileName(String? name) {
  if (name == null) return 'image/jpeg';
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  return 'image/jpeg';
}
