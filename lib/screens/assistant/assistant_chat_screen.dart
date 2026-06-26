import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/assistant/assistant_message.dart';
import '../../models/assistant/instructor_chat_session.dart';
import '../../models/driving/last_driving_report.dart';
import '../../services/assistant/assistant_context_builder.dart';
import '../../services/assistant/assistant_image_prepare.dart';
import '../../services/assistant/assistant_service.dart';
import '../../services/assistant/instructor_chat_sessions_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../services/audio/ui_sound_service.dart';
import 'instructor_chats_list_screen.dart';

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

  late final String _sessionId =
      InstructorChatSessionsService.instance.resolveSessionId(widget.launchContext);

  /// Report shown in the reference card and sent to the model (from launch or stored session).
  LastDrivingReport? _effectiveReport;
  InstructorChatSession? _sessionMeta;
  String _appBarTitle = 'AI INSTRUCTOR';

  bool _bootstrapping = true;
  bool _sending = false;
  String? _banner;
  Uint8List? _pendingImagePreview;
  Uint8List? _pendingImageFull;
  String _pendingMimeType = 'image/jpeg';
  bool _preparingImage = false;

  List<InstructorChatSession> _chatSessions = [];
  bool _loadingChatSessions = true;

  static const List<String> _defaultQuickChips = [
    'What are the rules for practical levels?',
    'Explain road signs from this app.',
    'How do I read my last level report?',
    'What does this sign mean? (attach a photo)',
  ];

  static const List<String> _reportQuickChips = [
    'What do the checklist lines mean for this attempt?',
    'What should I practise before trying again?',
    'How does this score relate to passing?',
  ];

  AssistantLaunchContext _contextForModel() {
    return AssistantLaunchContext(
      screenTitle: widget.launchContext.screenTitle,
      level: widget.launchContext.level,
      lastReport: _effectiveReport ?? widget.launchContext.lastReport,
      drivingTopic: widget.launchContext.drivingTopic,
      levelIdsForReportDigest: widget.launchContext.levelIdsForReportDigest,
      includeFullRoadSignCatalog: widget.launchContext.includeFullRoadSignCatalog,
      theoryTestName: widget.launchContext.theoryTestName,
      currentMcqQuestion: widget.launchContext.currentMcqQuestion,
      assistantSessionId: _sessionId,
    );
  }

  List<String> _quickChipsForLaunch() {
    if (_effectiveReport != null) return _reportQuickChips;
    return _defaultQuickChips;
  }

  AssistantMessage _welcomeForLaunch() {
    final r = _effectiveReport ?? widget.launchContext.lastReport;
    if (r != null) {
      return AssistantMessage(
        role: AssistantMessageRole.assistant,
        text:
            "Hi — you've opened the instructor from your saved run on \"${r.levelName}\". "
            'The checklist and scores from that attempt are in my context. Ask what anything means '
            'or how to improve next time. Use the gallery or camera button to attach a road-sign photo.',
        at: DateTime.now(),
      );
    }
    return AssistantMessage(
      role: AssistantMessageRole.assistant,
      text:
          "Hi — I'm your Road Rules instructor. Ask about signs, procedures, "
            'in-game checklists, or your latest level reports. Use the gallery or camera '
            'button to attach a photo of a real road sign.',
      at: DateTime.now(),
    );
  }

  Future<void> _persistMessages() async {
    await InstructorChatSessionsService.instance.saveMessages(_sessionId, _messages);
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _bootstrap();
    _loadChatSessions();
  }

  Future<void> _loadChatSessions() async {
    setState(() => _loadingChatSessions = true);
    try {
      final list = await InstructorChatSessionsService.instance.listSessions();
      if (!mounted) return;
      setState(() {
        _chatSessions = list;
        _loadingChatSessions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingChatSessions = false);
    }
  }

  AssistantLaunchContext _launchForSession(InstructorChatSession s) {
    if (s.isReport) {
      final r = s.lastReport;
      return AssistantLaunchContext(
        assistantSessionId: s.id,
        lastReport: r,
        screenTitle: r != null ? 'Last run report — ${r.levelName}' : null,
      );
    }
    return AssistantLaunchContext(assistantSessionId: s.id);
  }

  Future<void> _switchToSession(InstructorChatSession s) async {
    if (s.id == _sessionId) return;
    UiSoundService().playMenuTap();
    await Navigator.of(context).pushReplacement<void>(
      MaterialPageRoute<void>(
        builder: (_) => AssistantChatScreen(launchContext: _launchForSession(s)),
      ),
    );
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _banner = null;
    });
    final kind = _sessionId.startsWith('report_')
        ? InstructorChatSession.kindLevelReport
        : InstructorChatSession.kindGeneral;
    await InstructorChatSessionsService.instance.ensureSession(
      id: _sessionId,
      kind: kind,
      report: widget.launchContext.lastReport,
    );
    _sessionMeta = await InstructorChatSessionsService.instance.getSession(_sessionId);
    _effectiveReport = widget.launchContext.lastReport ?? _sessionMeta?.lastReport;
    _appBarTitle = _sessionMeta?.title ??
        (_effectiveReport != null ? 'INSTRUCTOR · LAST RUN' : 'AI INSTRUCTOR');

    var saved = <AssistantMessage>[];
    try {
      saved = await InstructorChatSessionsService.instance.loadMessages(_sessionId);
    } catch (_) {}
    try {
      final augmented = await AssistantContextBuilder.build(_contextForModel());
      final geminiHistory = InstructorChatSessionsService.toGeminiHistory(saved);
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
          _messages.add(_welcomeForLaunch());
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
    unawaited(
      InstructorChatSessionsService.instance.saveMessages(_sessionId, List<AssistantMessage>.from(_messages)),
    );
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
    await InstructorChatSessionsService.instance.saveMessages(_sessionId, const []);
    try {
      final augmented = await AssistantContextBuilder.build(_contextForModel());
      await AssistantService.instance.init(augmentedContext: augmented, history: const []);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        if (AssistantService.instance.isReady) {
          _messages.add(_welcomeForLaunch());
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

  Future<void> _renameThisChat() async {
    if (_bootstrapping || _sending) return;
    UiSoundService().playMenuTap();
    final controller = TextEditingController(text: _sessionMeta?.title ?? _appBarTitle);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename chat', style: AppFonts.pixelifySans(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = controller.text.trim();
    controller.dispose();
    if (t.isEmpty) return;
    await InstructorChatSessionsService.instance.renameSession(_sessionId, t);
    final m = await InstructorChatSessionsService.instance.getSession(_sessionId);
    if (!mounted) return;
    setState(() {
      _sessionMeta = m;
      _appBarTitle = m?.title ?? _appBarTitle;
    });
  }

  void _openChatsList() {
    UiSoundService().playMenuTap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const InstructorChatsListScreen()),
    ).then((_) {
      if (mounted) _loadChatSessions();
    });
  }

  Future<void> _newChat() async {
    if (_bootstrapping || _sending) return;
    UiSoundService().playMenuTap();
    final id = await InstructorChatSessionsService.instance.createGeneralSession();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => AssistantChatScreen(
          launchContext: AssistantLaunchContext(assistantSessionId: id),
        ),
      ),
    );
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

  Future<void> _preparePendingImage(Uint8List raw, {required String mimeType}) async {
    if (!mounted) return;
    setState(() {
      _preparingImage = true;
      _pendingImagePreview = null;
      _pendingImageFull = null;
      _banner = null;
    });

    Uint8List? preview;
    try {
      preview = await shrinkImageForChatPreview(raw);
    } catch (_) {}

    if (!mounted) return;

    if (preview == null && raw.length > 600 * 1024) {
      setState(() {
        _preparingImage = false;
        _banner = 'Image too large. Try a smaller photo or lower camera resolution.';
      });
      return;
    }

    setState(() {
      _pendingImagePreview = preview ?? raw;
      _pendingImageFull = raw;
      _pendingMimeType = mimeType;
      _preparingImage = false;
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
      await _preparePendingImage(f.bytes!, mimeType: mimeTypeFromFileName(f.name));
    } catch (e) {
      if (mounted) {
        setState(() => _banner = 'Could not open photo picker: $e');
      }
    }
  }

  Future<void> _takeRoadSignPhotoWithCamera() async {
    if (_sending || _bootstrapping || !AssistantService.instance.isReady) return;
    if (kIsWeb) {
      setState(() {
        _banner = 'Camera is not available in the web build. Use gallery attach instead.';
      });
      return;
    }
    UiSoundService().playMenuTap();
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted) return;
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _banner = 'Empty photo. Try taking the picture again.');
        return;
      }
      await _preparePendingImage(bytes, mimeType: 'image/jpeg');
    } catch (e) {
      if (mounted) {
        setState(() => _banner = 'Could not use camera: $e');
      }
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImagePreview = null;
      _pendingImageFull = null;
      _pendingMimeType = 'image/jpeg';
      _preparingImage = false;
    });
  }

  void _openImagePreview(BuildContext context, Uint8List bytes) {
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

  Future<void> _send(String text) async {
    if (_sending || _bootstrapping || _preparingImage) return;
    final trimmed = text.trim();
    final imageBytes = _pendingImageFull;
    final previewBytes = _pendingImagePreview;
    final imageMime = _pendingMimeType;
    if (trimmed.isEmpty && imageBytes == null) return;

    UiSoundService().playMenuTap();
    final displayText =
        trimmed.isEmpty ? AssistantService.imageOnlyDisplayPlaceholder : trimmed;
    final modelUserText =
        trimmed.isEmpty && imageBytes != null ? AssistantService.imageOnlyUserPrompt : trimmed;

    String? previewBase64;
    if (previewBytes != null && previewBytes.isNotEmpty) {
      previewBase64 = base64Encode(previewBytes);
    }

    setState(() {
      _messages.add(
        AssistantMessage(
          role: AssistantMessageRole.user,
          text: displayText,
          at: DateTime.now(),
          hasUserImage: imageBytes != null,
          userModelText: modelUserText == displayText ? null : modelUserText,
          userImageBase64: previewBase64,
          userImageMimeType: previewBase64 != null ? 'image/png' : null,
        ),
      );
      _sending = true;
      _pendingImagePreview = null;
      _pendingImageFull = null;
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
        title: Text(
          _appBarTitle,
          style: titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'new_chat') unawaited(_newChat());
              if (value == 'chats') _openChatsList();
              if (value == 'rename') unawaited(_renameThisChat());
              if (value == 'clear') _clearHistory();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'new_chat', child: Text('New chat')),
              PopupMenuItem<String>(value: 'chats', child: Text('Your chats')),
              PopupMenuItem<String>(value: 'rename', child: Text('Rename this chat')),
              PopupMenuItem<String>(value: 'clear', child: Text('Clear this chat')),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: SwissTheme.textPrimary, size: 18),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChatContextSidebar(
                  width: LandscapeLayout.chatSidebarWidth(context),
                  report: _effectiveReport,
                  quickChips: _quickChipsForLaunch(),
                  showQuickChips: !_bootstrapping &&
                      AssistantService.instance.isReady &&
                      _messages.length <= 1,
                  sending: _sending,
                  onChipTap: _send,
                  bodyStyle: bodyStyle,
                ),
                const VerticalDivider(width: 1, thickness: 1, color: SwissTheme.dividerBlack),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            return _ChatMessageBubble(
                              message: m,
                              bodyStyle: bodyStyle,
                              maxWidth: LandscapeLayout.chatBubbleMaxWidth(context),
                              onImageTap: (bytes) => _openImagePreview(context, bytes),
                            );
                          },
                        ),
                      ),
                      if (_sending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SwissTheme.accentBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Thinking…',
                                style: bodyStyle.copyWith(fontSize: 11, color: SwissTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
                      if (_pendingImageBytes != null)
                        Material(
                          color: SwissTheme.backgroundLightGrey,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ChatImagePreview(
                                  bytes: _pendingImageBytes!,
                                  maxHeight: 72,
                                  onTap: () => _openImagePreview(context, _pendingImageBytes!),
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
                                  onPressed: _sending ? null : _clearPendingImage,
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
                              _ComposerIconButton(
                                tooltip: 'Photo from gallery',
                                icon: Icons.add_photo_alternate_outlined,
                                onPressed: (_sending ||
                                        _bootstrapping ||
                                        !AssistantService.instance.isReady)
                                    ? null
                                    : _pickRoadSignPhoto,
                              ),
                              if (!kIsWeb)
                                _ComposerIconButton(
                                  tooltip: 'Take photo with camera',
                                  icon: Icons.photo_camera_outlined,
                                  onPressed: (_sending ||
                                          _bootstrapping ||
                                          !AssistantService.instance.isReady)
                                      ? null
                                      : _takeRoadSignPhotoWithCamera,
                                ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 2,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) {
                                    final t = _controller.text;
                                    if (t.trim().isNotEmpty || _pendingImageBytes != null) {
                                      _send(t);
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
                                onPressed: (_sending ||
                                        _bootstrapping ||
                                        !AssistantService.instance.isReady ||
                                        (_controller.text.trim().isEmpty &&
                                            _pendingImageBytes == null))
                                    ? null
                                    : () => _send(_controller.text),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal “this chat is tied to a saved run” hint (full report stays in the model context).
class _AttachedReportBanner extends StatelessWidget {
  const _AttachedReportBanner({required this.report, this.compact = false});

  final LastDrivingReport report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwissTheme.backgroundLightGrey,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 8 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.description_outlined, size: compact ? 18 : 22, color: SwissTheme.accentBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ATTACHED RUN',
                    style: AppFonts.pixelifySans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: SwissTheme.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.levelName,
                    style: AppFonts.pixelifySans(
                      fontSize: compact ? 12 : 15,
                      fontWeight: FontWeight.w700,
                      color: SwissTheme.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatContextSidebar extends StatelessWidget {
  final double width;
  final LastDrivingReport? report;
  final List<String> quickChips;
  final bool showQuickChips;
  final bool sending;
  final void Function(String) onChipTap;
  final TextStyle bodyStyle;

  const _ChatContextSidebar({
    required this.width,
    required this.report,
    required this.quickChips,
    required this.showQuickChips,
    required this.sending,
    required this.onChipTap,
    required this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: SwissTheme.backgroundWhite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                'CONTEXT',
                style: AppFonts.pixelifySans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: SwissTheme.textSecondary,
                ),
              ),
            ),
            if (report != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _AttachedReportBanner(report: report!, compact: true),
              ),
              const SizedBox(height: 10),
            ],
            if (showQuickChips) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Text(
                  'SUGGESTED',
                  style: AppFonts.pixelifySans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: SwissTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  itemCount: quickChips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final c = quickChips[i];
                    return Material(
                      color: SwissTheme.backgroundLightGrey,
                      child: InkWell(
                        onTap: sending ? null : () => onChipTap(c),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: SwissTheme.borderBlack, width: 1),
                          ),
                          child: Text(
                            c,
                            style: AppFonts.pixelifySans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: SwissTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    report != null
                        ? 'Ask about checklist lines, mistakes, or how to improve on this run.'
                        : 'Ask about road signs, in-game rules, theory topics, or attach a photo.',
                    style: bodyStyle.copyWith(fontSize: 11, color: SwissTheme.textSecondary, height: 1.35),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final AssistantMessage message;
  final TextStyle bodyStyle;
  final double maxWidth;
  final void Function(Uint8List bytes)? onImageTap;

  const _ChatMessageBubble({
    required this.message,
    required this.bodyStyle,
    required this.maxWidth,
    this.onImageTap,
  });

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
                            _ChatImagePreview(
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

class _ChatImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final double maxHeight;
  final VoidCallback? onTap;

  const _ChatImagePreview({
    required this.bytes,
    required this.maxHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: maxHeight,
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

class _ChatAvatar extends StatelessWidget {
  final bool isUser;

  const _ChatAvatar({required this.isUser});

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

class _ComposerIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ComposerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

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
