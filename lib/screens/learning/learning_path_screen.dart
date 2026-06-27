import 'package:flutter/material.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/learning/learning_path.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/content/learning_path_service.dart';
import '../../services/learning/learning_path_navigator.dart';
import '../../services/progress/last_driving_report_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import '../../widgets/learning/path_snake_track.dart';

/// Consolidated curriculum map: theory → driving → module checkpoints per section.
class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  LearningPathCurriculum? _curriculum;
  LearningPathProgress _progress = LearningPathProgress.empty;
  Object? _loadError;
  bool _loading = true;
  Set<String> _levelIdsWithReport = {};
  Map<String, bool> _levelPassStatus = {};
  final ScrollController _scrollController = ScrollController();

  late final TextStyle _headerStyle = AppFonts.pixelifySans(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: SwissTheme.textPrimary,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void activate() {
    super.activate();
    _refreshSavedDrivingReports();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final curriculum = await LearningPathService.instance.loadCurriculum();
      final progress = await LearningPathService.instance.loadProgress();
      if (!mounted) return;
      setState(() {
        _curriculum = curriculum;
        _progress = progress;
        _loading = false;
      });
      await _refreshSavedDrivingReports();
      if (!mounted) return;
      _scrollToCurrentNode(curriculum, progress);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _scrollToCurrentNode(LearningPathCurriculum curriculum, LearningPathProgress progress) {
    final focus = LearningPathService.instance.currentFocusNode(curriculum, progress);
    if (focus == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      var nodeIndex = 0;
      var found = false;
      for (final module in curriculum.modules) {
        for (var i = 0; i < module.nodes.length; i++) {
          if (module.nodes[i].id == focus.id) {
            found = true;
            break;
          }
          nodeIndex++;
        }
        if (found) break;
        nodeIndex++; // module header row
      }
      if (!found) return;
      // ~148px per node row (tile + connector + header allowance).
      final offset = (nodeIndex * 148.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _refreshProgress() async {
    final progress = await LearningPathService.instance.loadProgress();
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  Future<void> _refreshSavedDrivingReports() async {
    try {
      await LastDrivingReportService.instance.mergeRemoteSummariesIfSignedIn();
      final ids = await LastDrivingReportService.instance.levelIdsWithSavedReports();
      final passStatus =
          await LastDrivingReportService.instance.levelPassStatusByLevelId();
      if (!mounted) return;
      setState(() {
        _levelIdsWithReport = ids;
        _levelPassStatus = passStatus;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _levelIdsWithReport = {};
          _levelPassStatus = {};
        });
      }
    }
  }

  Future<void> _onNodeTap(LearningPathNode node, bool unlocked) async {
    UiSoundService().playMenuTap();
    if (!unlocked) {
      _showLockedDialog(node);
      return;
    }
    if (LearningPathService.instance.isNodeUnderDevelopment(node)) {
      _showUnderDevelopmentDialog(node);
      return;
    }
    await LearningPathNavigator.openNode(context, node);
    await _refreshProgress();
    await _refreshSavedDrivingReports();
  }

  void _showLockedDialog(LearningPathNode node) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
        title: Text('LOCKED', style: AppFonts.pixelifySans(fontSize: 20, fontWeight: FontWeight.w800)),
        content: Text(
          node.unlockRequirementIds.isEmpty
              ? 'Complete earlier steps on the path to unlock this one.'
              : 'Finish the previous step(s) on the path first.',
          style: AppFonts.pixelifySans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.pop(ctx);
            },
            child: Text('OK', style: TextStyle(color: SwissTheme.accentBlue)),
          ),
        ],
      ),
    );
  }

  void _showUnderDevelopmentDialog(LearningPathNode node) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
        title: Text(
          'UNDER DEVELOPMENT',
          style: AppFonts.pixelifySans(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${node.title}" is not playable yet.',
          style: AppFonts.pixelifySans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.pop(ctx);
            },
            child: Text('OK', style: TextStyle(color: SwissTheme.accentBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curriculum = _curriculum;
    final service = LearningPathService.instance;
    final focus = curriculum != null ? service.currentFocusNode(curriculum, _progress) : null;

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrowseScreenHeader(
              title: 'LEARNING PATH',
              titleStyle: _headerStyle,
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_learning_path',
              launchContext: const AssistantLaunchContext(
                screenTitle: 'Learning path — full curriculum',
                includeFullRoadSignCatalog: true,
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(child: _buildBody(curriculum, service, focus)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    LearningPathCurriculum? curriculum,
    LearningPathService service,
    LearningPathNode? focus,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: SwissTheme.textPrimary));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load learning path.\n$_loadError',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 13, color: SwissTheme.textSecondary),
          ),
        ),
      );
    }
    if (curriculum == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      color: SwissTheme.accentRed,
      onRefresh: () async {
        await _load();
        await _refreshSavedDrivingReports();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: LandscapeLayout.bodyPadding(context),
        itemCount: curriculum.modules.length,
        itemBuilder: (context, moduleIndex) {
          final module = curriculum.modules[moduleIndex];
          final prevModule = moduleIndex > 0 ? curriculum.modules[moduleIndex - 1] : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (prevModule != null)
                PathModuleBridgeConnector(
                  fromLeft: (prevModule.nodes.length - 1).isEven,
                  done: prevModule.nodes.every(
                    (n) => service.isNodeComplete(n, _progress),
                  ),
                ),
              PathModuleSnakeSection(
                module: module,
                moduleIndex: moduleIndex,
                service: service,
                progress: _progress,
                focusNodeId: focus?.id,
                onNodeTap: _onNodeTap,
                levelIdsWithReport: _levelIdsWithReport,
                levelPassStatus: _levelPassStatus,
              ),
            ],
          );
        },
      ),
    );
  }
}
