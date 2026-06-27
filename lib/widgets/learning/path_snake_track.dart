import 'package:flutter/material.dart';

import '../../models/learning/learning_path.dart';
import '../../services/content/learning_path_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import 'path_node_tile.dart';
import 'path_snake_connector.dart';

/// Vertical snake layout: nodes alternate left / right with curved connectors.
class PathSnakeTrack extends StatelessWidget {
  final List<LearningPathNode> nodes;
  final LearningPathService service;
  final LearningPathProgress progress;
  final String? focusNodeId;
  final Future<void> Function(LearningPathNode node, bool unlocked) onNodeTap;
  final Set<String> levelIdsWithReport;
  final Map<String, bool> levelPassStatus;

  const PathSnakeTrack({
    super.key,
    required this.nodes,
    required this.service,
    required this.progress,
    required this.focusNodeId,
    required this.onNodeTap,
    this.levelIdsWithReport = const {},
    this.levelPassStatus = const {},
  });

  bool _isLeft(int index) => index.isEven;

  bool _hasDrivingReport(LearningPathNode node) {
    final levelId = node.ref?.trim();
    return levelId != null && levelIdsWithReport.contains(levelId);
  }

  bool _drivingReportPassed(LearningPathNode node) {
    final levelId = node.ref?.trim();
    if (levelId == null) return false;
    return levelPassStatus[levelId] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          if (i > 0)
            PathSnakeConnector(
              fromLeft: _isLeft(i - 1),
              toLeft: _isLeft(i),
              done: service.isNodeComplete(nodes[i - 1], progress),
            ),
          Align(
            alignment: _isLeft(i) ? Alignment.centerLeft : Alignment.centerRight,
            child: PathNodeTile(
              node: nodes[i],
              unlocked: service.isNodeUnlocked(nodes[i], progress),
              done: service.isNodeComplete(nodes[i], progress),
              isCurrent: nodes[i].id == focusNodeId,
              onTap: () => onNodeTap(nodes[i], service.isNodeUnlocked(nodes[i], progress)),
              hasDrivingReport: _hasDrivingReport(nodes[i]),
              drivingReportPassed: _drivingReportPassed(nodes[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Module header + snake track for one path section.
class PathModuleSnakeSection extends StatelessWidget {
  final LearningPathModule module;
  final int moduleIndex;
  final LearningPathService service;
  final LearningPathProgress progress;
  final String? focusNodeId;
  final Future<void> Function(LearningPathNode node, bool unlocked) onNodeTap;
  final Set<String> levelIdsWithReport;
  final Map<String, bool> levelPassStatus;

  const PathModuleSnakeSection({
    super.key,
    required this.module,
    required this.moduleIndex,
    required this.service,
    required this.progress,
    required this.focusNodeId,
    required this.onNodeTap,
    this.levelIdsWithReport = const {},
    this.levelPassStatus = const {},
  });

  @override
  Widget build(BuildContext context) {
    final nodes = module.nodes;
    final moduleDone = nodes.every((n) => service.isNodeComplete(n, progress));

    return Padding(
      padding: const EdgeInsets.only(bottom: LandscapeLayout.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: moduleDone ? SwissTheme.accentGreen.withValues(alpha: 0.12) : SwissTheme.textPrimary,
              border: const Border.fromBorderSide(BorderSide(color: SwissTheme.borderBlack)),
            ),
            child: Row(
              children: [
                Text(
                  '${(moduleIndex + 1).toString().padLeft(2, '0')}',
                  style: AppFonts.pixelifySans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: moduleDone ? SwissTheme.textPrimary : SwissTheme.backgroundWhite,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title.toUpperCase(),
                        style: AppFonts.pixelifySans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: moduleDone ? SwissTheme.textPrimary : SwissTheme.backgroundWhite,
                        ),
                      ),
                      if (module.description.isNotEmpty)
                        Text(
                          module.description,
                          style: AppFonts.pixelifySans(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: moduleDone
                                ? SwissTheme.textSecondary
                                : SwissTheme.backgroundWhite.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                  ),
                ),
                if (moduleDone)
                  Icon(Icons.check_circle, color: SwissTheme.accentGreen, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PathSnakeTrack(
            nodes: nodes,
            service: service,
            progress: progress,
            focusNodeId: focusNodeId,
            onNodeTap: onNodeTap,
            levelIdsWithReport: levelIdsWithReport,
            levelPassStatus: levelPassStatus,
          ),
        ],
      ),
    );
  }
}

/// Curved connector from the last node of one module to the first of the next.
class PathModuleBridgeConnector extends StatelessWidget {
  final bool fromLeft;
  final bool done;

  const PathModuleBridgeConnector({
    super.key,
    required this.fromLeft,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: PathSnakeConnector(
        fromLeft: fromLeft,
        toLeft: true,
        done: done,
      ),
    );
  }
}
