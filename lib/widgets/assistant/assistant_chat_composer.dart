import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/swiss_theme.dart';
import 'chat_image_preview.dart';

class ComposerIconButton extends StatelessWidget {
  const ComposerIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22, color: SwissTheme.textPrimary),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class AssistantChatComposer extends StatelessWidget {
  const AssistantChatComposer({
    super.key,
    required this.controller,
    required this.bodyStyle,
    required this.preparingImage,
    required this.pendingImagePreview,
    required this.sending,
    required this.bootstrapping,
    required this.assistantReady,
    required this.hasPendingImage,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onClearPendingImage,
    required this.onPreviewImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final TextStyle bodyStyle;
  final bool preparingImage;
  final Uint8List? pendingImagePreview;
  final bool sending;
  final bool bootstrapping;
  final bool assistantReady;
  final bool hasPendingImage;
  final VoidCallback? onPickGallery;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onClearPendingImage;
  final void Function(Uint8List bytes) onPreviewImage;
  final VoidCallback onSend;

  bool get _inputDisabled => sending || bootstrapping || preparingImage || !assistantReady;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwissTheme.backgroundWhite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
          if (preparingImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Preparing photo…',
                    style: bodyStyle.copyWith(fontSize: 10, color: SwissTheme.textSecondary),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final canSend =
                      !_inputDisabled && (controller.text.trim().isNotEmpty || hasPendingImage);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ComposerIconButton(
                        tooltip: 'Photo from gallery',
                        icon: Icons.add_photo_alternate_outlined,
                        onPressed: _inputDisabled ? null : onPickGallery,
                      ),
                      if (!kIsWeb)
                        ComposerIconButton(
                          tooltip: 'Take photo with camera',
                          icon: Icons.photo_camera_outlined,
                          onPressed: _inputDisabled ? null : onTakePhoto,
                        ),
                      if (pendingImagePreview != null) ...[
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ChatImagePreview(
                                bytes: pendingImagePreview!,
                                maxHeight: 48,
                                maxWidth: 48,
                                onTap: () => onPreviewImage(pendingImagePreview!),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Material(
                                  color: SwissTheme.backgroundWhite,
                                  shape: const CircleBorder(
                                    side: BorderSide(color: SwissTheme.borderBlack, width: 1),
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: sending ? null : onClearPendingImage,
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.close, size: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: !_inputDisabled,
                          minLines: 1,
                          maxLines: 2,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (canSend) onSend();
                          },
                          style: bodyStyle.copyWith(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: pendingImagePreview != null
                                ? 'Optional caption…'
                                : 'Ask about signs, rules, or your last run…',
                            hintStyle: bodyStyle.copyWith(
                              fontSize: 12,
                              color: SwissTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: SwissTheme.backgroundWhite,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: SwissTheme.borderBlack, width: 1),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: SwissTheme.accentBlue, width: 2),
                            ),
                            disabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: SwissTheme.dividerBlack, width: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: canSend ? onSend : null,
                        style: IconButton.styleFrom(
                          backgroundColor: SwissTheme.textPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.send, size: 20),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
