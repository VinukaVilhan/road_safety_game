import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/assistant/assistant_message.dart';
import '../../services/assistant/assistant_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import 'chat_image_preview.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.bodyStyle,
    required this.maxWidth,
    this.onImageTap,
  });

  final AssistantMessage message;
  final TextStyle bodyStyle;
  final double maxWidth;
  final void Function(Uint8List bytes)? onImageTap;

  Uint8List? get _imageBytes {
    final b64 = message.userImageBase64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AssistantMessageRole.user;
    final label = isUser ? 'YOU' : 'INSTRUCTOR';
    final bubbleColor =
        isUser ? SwissTheme.accentBlue.withValues(alpha: 0.1) : SwissTheme.backgroundLightGrey;
    final imageBytes = _imageBytes;
    final showImage = isUser && (imageBytes != null || message.hasUserImage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _ChatAvatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppFonts.pixelifySans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: SwissTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: Border.all(color: SwissTheme.borderBlack, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showImage) ...[
                          if (imageBytes != null)
                            ChatImagePreview(
                              bytes: imageBytes,
                              maxHeight: 100,
                              onTap: onImageTap == null ? null : () => onImageTap!(imageBytes),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_outlined, size: 14, color: SwissTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Photo sent',
                                  style: bodyStyle.copyWith(
                                    fontSize: 11,
                                    color: SwissTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (message.text.isNotEmpty &&
                              message.text != AssistantService.imageOnlyDisplayPlaceholder)
                            const SizedBox(height: 8),
                        ],
                        if (message.text.isNotEmpty &&
                            message.text != AssistantService.imageOnlyDisplayPlaceholder)
                          Text(
                            message.text,
                            style: bodyStyle.copyWith(
                              fontSize: 13,
                              color: SwissTheme.textPrimary,
                              fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _ChatAvatar(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.isUser});

  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isUser ? SwissTheme.accentBlue.withValues(alpha: 0.15) : SwissTheme.textPrimary,
        border: const Border.fromBorderSide(BorderSide(color: SwissTheme.borderBlack)),
      ),
      child: Icon(
        isUser ? Icons.person_outline : Icons.school_outlined,
        size: 16,
        color: isUser ? SwissTheme.accentBlue : SwissTheme.backgroundWhite,
      ),
    );
  }
}
