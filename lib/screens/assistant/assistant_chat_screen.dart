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
import '../../widgets/assistant/assistant_chat_composer.dart';
import '../../widgets/assistant/attached_report_banner.dart';
import '../../widgets/assistant/chat_image_preview.dart';
import '../../widgets/assistant/chat_message_bubble.dart';
import '../../widgets/assistant/chats_history_sidebar.dart';
import 'assistant_chat_constants.dart';
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
    if (_effectiveReport != null) return AssistantChatConstants.reportQuickChips;
    return AssistantChatConstants.defaultQuickChips;
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
    await Navigator.of(context).pushReplacement(
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

  Future<void> _send([String? textOverride]) async {
    if (_sending || _bootstrapping || _preparingImage) return;
    final trimmed = (textOverride ?? _controller.text).trim();
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
    _loadChatSessions();
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
                ChatsHistorySidebar(
                  width: LandscapeLayout.chatSidebarWidth(context),
                  sessions: _chatSessions,
                  currentSessionId: _sessionId,
                  loading: _loadingChatSessions,
                  onNewChat: _sending || _bootstrapping ? null : () => unawaited(_newChat()),
                  onSelect: _switchToSession,
                ),
                const VerticalDivider(width: 1, thickness: 1, color: SwissTheme.dividerBlack),
                Expanded(
                  child: Column(
                    children: [
                      if (_effectiveReport != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: AttachedReportBanner(report: _effectiveReport!),
                        ),
                      if (!_bootstrapping &&
                          AssistantService.instance.isReady &&
                          _messages.length <= 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickChipsForLaunch().length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (context, i) {
                                final c = _quickChipsForLaunch()[i];
                                return ActionChip(
                                  label: Text(
                                    c,
                                    style: AppFonts.pixelifySans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: SwissTheme.backgroundLightGrey,
                                  side: const BorderSide(color: SwissTheme.borderBlack),
                                  onPressed: (_sending || _preparingImage) ? null : () => _send(c),
                                );
                              },
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            return ChatMessageBubble(
                              message: m,
                              bodyStyle: bodyStyle,
                              maxWidth: LandscapeLayout.chatBubbleMaxWidth(context),
                              onImageTap: (bytes) => showAssistantChatImagePreview(context, bytes),
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
                      AssistantChatComposer(
                        controller: _controller,
                        bodyStyle: bodyStyle,
                        preparingImage: _preparingImage,
                        pendingImagePreview: _pendingImagePreview,
                        sending: _sending,
                        bootstrapping: _bootstrapping,
                        assistantReady: AssistantService.instance.isReady,
                        hasPendingImage: _pendingImageFull != null,
                        onPickGallery: _pickRoadSignPhoto,
                        onTakePhoto: _takeRoadSignPhotoWithCamera,
                        onClearPendingImage: _clearPendingImage,
                        onPreviewImage: (bytes) => showAssistantChatImagePreview(context, bytes),
                        onSend: () => _send(),
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
