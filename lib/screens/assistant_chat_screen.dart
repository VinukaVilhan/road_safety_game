import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_launch_context.dart';
import '../models/assistant_message.dart';
import '../services/assistant_chat_history_service.dart';
import '../services/assistant_context_builder.dart';
import '../services/assistant_image_prepare.dart';
import '../services/assistant_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../services/ui_sound_service.dart';

/// Full-screen chat with the Gemini-backed virtual instructor.
class AssistantChatScreen extends StatefulWidget {
  const AssistantChatScreen({
    super.key,
    this.launchContext = const AssistantLaunchContext(),
  });

  final AssistantLaunchContext launchContext;

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AssistantMessage> _messages = [];
  bool _bootstrapping = true;
  bool _sending = false;
  String? _banner;
  Uint8List? _pendingImageBytes;
  String _pendingMimeType = 'image/jpeg';

  static const List<String> _quickChips = [
    'What are the rules for practical levels?',
    'Explain road signs from this app.',
    'How do I read my last level report?',
    'What does this sign mean? (attach a photo)',
  ];

  static AssistantMessage _welcomeMessage() {
    return AssistantMessage(
      role: AssistantMessageRole.assistant,
      text:
          "Hi — I'm your Road Rules instructor. Ask about signs, procedures, "
          'in-game checklists, or your latest level reports. Tap the image icon '
          'to attach a photo of a real road sign.',
      at: DateTime.now(),
    );
  }

  Future<void> _persistMessages() async {
    if (_messages.isEmpty) return;
    await AssistantChatHistoryService.instance.save(_messages);
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _banner = null;
    });
    var saved = <AssistantMessage>[];
    try {
      saved = await AssistantChatHistoryService.instance.load();
    } catch (_) {}
    try {
      final augmented = await AssistantContextBuilder.build(widget.launchContext);
      final geminiHistory = AssistantChatHistoryService.toGeminiHistory(saved);
      await AssistantService.instance.init(
        augmentedContext: augmented,
        history: geminiHistory,
      );
      if (!AssistantService.instance.isReady) {
        setState(() {
          _banner = AssistantService.instance.initError ??
              'Assistant could not start. Check your API key.';
          _messages
            ..clear()
            ..addAll(saved);
        });
      } else if (saved.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..addAll(saved);
        });
      } else {
        setState(() {
          _messages.add(_welcomeMessage());
        });
        await _persistMessages();
      }
    } catch (e) {
      setState(() {
        _banner = 'Could not load context: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _bootstrapping = false);
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    unawaited(AssistantChatHistoryService.instance.save(List<AssistantMessage>.from(_messages)));
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _clearHistory() async {
    if (_bootstrapping || _sending) return;
    UiSoundService().playMenuTap();
    setState(() {
      _bootstrapping = true;
      _banner = null;
    });
    await AssistantChatHistoryService.instance.clear();
    try {
      final augmented = await AssistantContextBuilder.build(widget.launchContext);
      await AssistantService.instance.init(augmentedContext: augmented, history: const []);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        if (AssistantService.instance.isReady) {
          _messages.add(_welcomeMessage());
        }
        _banner = AssistantService.instance.isReady
            ? null
            : (AssistantService.instance.initError ??
                'Assistant could not start. Check your API key.');
      });
      await _persistMessages();
    } catch (e) {
      if (mounted) {
        setState(() => _banner = 'Could not reset chat: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _bootstrapping = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickRoadSignPhoto() async {
    if (_sending || _bootstrapping || !AssistantService.instance.isReady) return;
    UiSoundService().playMenuTap();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowCompression: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      if (f.bytes == null || f.bytes!.isEmpty) {
        setState(() {
          _banner = 'Could not read that image. Try another photo or pick from gallery again.';
        });
        return;
      }
      setState(() {
        _pendingImageBytes = f.bytes;
        _pendingMimeType = mimeTypeFromFileName(f.name);
        _banner = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _banner = 'Could not open photo picker: $e');
      }
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingMimeType = 'image/jpeg';
    });
  }

  Future<void> _send(String text) async {
    if (_sending || _bootstrapping) return;
    final trimmed = text.trim();
    final imageBytes = _pendingImageBytes;
    final imageMime = _pendingMimeType;
    if (trimmed.isEmpty && imageBytes == null) return;

    UiSoundService().playMenuTap();
    final displayText =
        trimmed.isEmpty ? AssistantService.imageOnlyDisplayPlaceholder : trimmed;
    final modelUserText =
        trimmed.isEmpty && imageBytes != null ? AssistantService.imageOnlyUserPrompt : trimmed;
    setState(() {
      _messages.add(
        AssistantMessage(
          role: AssistantMessageRole.user,
          text: displayText,
          at: DateTime.now(),
          hasUserImage: imageBytes != null,
          userModelText: modelUserText == displayText ? null : modelUserText,
        ),
      );
      _sending = true;
      _pendingImageBytes = null;
      _pendingMimeType = 'image/jpeg';
    });
    unawaited(_persistMessages());
    _controller.clear();
    _scrollToBottom();

    final reply = await AssistantService.instance.sendUserMessage(
      trimmed,
      imageBytes: imageBytes,
      imageMimeType: imageMime,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(
        AssistantMessage(role: AssistantMessageRole.assistant, text: reply, at: DateTime.now()),
      );
      _sending = false;
    });
    await _persistMessages();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.pixelifySans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: SwissTheme.textPrimary,
    );
    final bodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textPrimary,
      height: 1.35,
    );

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SwissTheme.backgroundWhite,
        foregroundColor: SwissTheme.textPrimary,
        title: Text('AI INSTRUCTOR', style: titleStyle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') _clearHistory();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear chat history'),
              ),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
        ),
      ),
      body: Column(
        children: [
          if (_banner != null)
            Material(
              color: SwissTheme.accentOrange.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: SwissTheme.textPrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _banner!,
                        style: bodyStyle.copyWith(fontSize: 12, color: SwissTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_bootstrapping)
            const LinearProgressIndicator(minHeight: 2, color: SwissTheme.accentBlue),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m.role == AssistantMessageRole.user;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
                    decoration: BoxDecoration(
                      color: isUser ? SwissTheme.accentBlue.withValues(alpha: 0.12) : SwissTheme.backgroundLightGrey,
                      border: Border.all(color: SwissTheme.borderBlack, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUser && m.hasUserImage) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 16,
                                color: SwissTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Photo attached',
                                style: bodyStyle.copyWith(
                                  fontSize: 12,
                                  color: SwissTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (m.text.isNotEmpty) const SizedBox(height: 8),
                        ],
                        if (m.text.isNotEmpty)
                          Text(
                            m.text,
                            style: bodyStyle.copyWith(
                              color: SwissTheme.textPrimary,
                              fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_bootstrapping && AssistantService.instance.isReady && _messages.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickChips
                    .map(
                      (c) => ActionChip(
                        label: Text(
                          c,
                          style: AppFonts.pixelifySans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: SwissTheme.textPrimary,
                          ),
                        ),
                        backgroundColor: SwissTheme.backgroundLightGrey,
                        side: const BorderSide(color: SwissTheme.borderBlack, width: 1),
                        onPressed: _sending ? null : () => _send(c),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SwissTheme.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Thinking…',
                    style: bodyStyle.copyWith(fontSize: 12, color: SwissTheme.textSecondary),
                  ),
                ],
              ),
            ),
          const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
          if (_pendingImageBytes != null)
            Material(
              color: SwissTheme.backgroundLightGrey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _pendingImageBytes!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Road sign photo will be sent with your next message.',
                        style: bodyStyle.copyWith(fontSize: 12, color: SwissTheme.textSecondary),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: _sending ? null : _clearPendingImage,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach road sign photo',
                    onPressed: (_sending || _bootstrapping || !AssistantService.instance.isReady)
                        ? null
                        : _pickRoadSignPhoto,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: SwissTheme.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        final t = _controller.text;
                        if (t.trim().isNotEmpty || _pendingImageBytes != null) {
                          _send(t);
                        }
                      },
                      style: bodyStyle,
                      decoration: InputDecoration(
                        hintText: 'Ask about signs, rules, or attach a photo…',
                        hintStyle: bodyStyle.copyWith(color: SwissTheme.textSecondary),
                        filled: true,
                        fillColor: SwissTheme.backgroundWhite,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: SwissTheme.borderBlack, width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: SwissTheme.accentBlue, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: (_sending ||
                            _bootstrapping ||
                            !AssistantService.instance.isReady ||
                            (_controller.text.trim().isEmpty && _pendingImageBytes == null))
                        ? null
                        : () => _send(_controller.text),
                    style: IconButton.styleFrom(
                      backgroundColor: SwissTheme.textPrimary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
