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

  bool get _controlsDisabled => sending || bootstrapping || preparingImage || !assistantReady;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
        if (preparingImage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Preparing photo…',
                  style: bodyStyle.copyWith(fontSize: 11, color: SwissTheme.textSecondary),
                ),
              ],
            ),
          ),
        if (pendingImagePreview != null)
          Material(
            color: SwissTheme.backgroundLightGrey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatImagePreview(
                    bytes: pendingImagePreview!,
                    maxHeight: 72,
                    onTap: () => onPreviewImage(pendingImagePreview!),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photo ready to send',
                          style: bodyStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add a message or tap send.',
                          style: bodyStyle.copyWith(
                            fontSize: 11,
                            color: SwissTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: sending ? null : onClearPendingImage,
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ComposerIconButton(
                  tooltip: 'Photo from gallery',
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: _controlsDisabled ? null : onPickGallery,
                ),
                if (!kIsWeb)
                  ComposerIconButton(
                    tooltip: 'Take photo with camera',
                    icon: Icons.photo_camera_outlined,
                    onPressed: _controlsDisabled ? null : onTakePhoto,
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      final t = controller.text;
                      if (t.trim().isNotEmpty || hasPendingImage) {
                        onSend();
                      }
                    },
                    style: bodyStyle.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ask about signs, rules, or your last run…',
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
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: (_controlsDisabled ||
                          (controller.text.trim().isEmpty && !hasPendingImage))
                      ? null
                      : onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: SwissTheme.textPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
