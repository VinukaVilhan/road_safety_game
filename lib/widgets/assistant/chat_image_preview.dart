import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';

class ChatImagePreview extends StatelessWidget {
  const ChatImagePreview({
    super.key,
    required this.bytes,
    required this.maxHeight,
    this.maxWidth,
    this.onTap,
  });

  final Uint8List bytes;
  final double maxHeight;
  final double? maxWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = maxWidth ?? maxHeight;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: w,
        height: maxHeight,
        cacheWidth: 400,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          height: maxHeight,
          alignment: Alignment.center,
          color: SwissTheme.backgroundLightGrey,
          child: const Icon(Icons.broken_image_outlined, size: 24),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: SwissTheme.borderBlack, width: 1),
          ),
          child: onTap != null
              ? Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    image,
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.zoom_in,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ],
                )
              : image,
        ),
      ),
    );
  }
}

void showAssistantChatImagePreview(BuildContext context, Uint8List bytes) {
  UiSoundService().playMenuTap();
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: SwissTheme.backgroundWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(ctx).width * 0.75,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () {
                  UiSoundService().playMenuTap();
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.close),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
