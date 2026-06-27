import 'package:flutter/material.dart';

import '../../models/learning/learning_path.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../screens/driving/level_selection_screen.dart' show HatchingPainter;
import '../driving/driving_level_report_icon_button.dart';

/// One step on the consolidated learning path.
class PathNodeTile extends StatelessWidget {
  final LearningPathNode node;
  final bool unlocked;
  final bool done;
  final bool isCurrent;
  final VoidCallback onTap;
  final bool hasDrivingReport;
  final bool drivingReportPassed;

  const PathNodeTile({
    super.key,
    required this.node,
    required this.unlocked,
    required this.done,
    required this.isCurrent,
    required this.onTap,
    this.hasDrivingReport = false,
    this.drivingReportPassed = false,
  });

  IconData get _icon {
    switch (node.kind) {
      case LearningPathNodeKind.theoryIntro:
      case LearningPathNodeKind.roadSignsIntro:
        return Icons.menu_book_outlined;
      case LearningPathNodeKind.theoryMcq:
      case LearningPathNodeKind.roadSignsMcq:
        return Icons.quiz_outlined;
      case LearningPathNodeKind.roadSignsMinigame:
        return Icons.videogame_asset_outlined;
      case LearningPathNodeKind.drivingLevel:
        return Icons.directions_car_outlined;
      case LearningPathNodeKind.moduleFinal:
        return Icons.flag_outlined;
      case LearningPathNodeKind.grandFinal:
        return Icons.emoji_events_outlined;
    }
  }

  String get _kindLabel {
    switch (node.kind) {
      case LearningPathNodeKind.theoryIntro:
      case LearningPathNodeKind.roadSignsIntro:
        return 'Theory';
      case LearningPathNodeKind.theoryMcq:
      case LearningPathNodeKind.roadSignsMcq:
        return 'Quiz';
      case LearningPathNodeKind.roadSignsMinigame:
        return 'Mini game';
      case LearningPathNodeKind.drivingLevel:
        return 'Drive';
      case LearningPathNodeKind.moduleFinal:
        return 'Module test';
      case LearningPathNodeKind.grandFinal:
        return 'Grand final';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = !unlocked
        ? SwissTheme.backgroundLightGrey
        : isCurrent
            ? SwissTheme.accentRed.withValues(alpha: 0.08)
            : SwissTheme.backgroundWhite;

    final showReport =
        node.kind == LearningPathNodeKind.drivingLevel && hasDrivingReport;
    final levelId = node.ref?.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160,
        height: 100,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isCurrent ? SwissTheme.accentRed : SwissTheme.borderBlack,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!unlocked)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.45,
                  child: CustomPaint(painter: HatchingPainter()),
                ),
              ),
            InkWell(
              onTap: unlocked ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _icon,
                          size: 18,
                          color: unlocked ? SwissTheme.textPrimary : SwissTheme.textSecondary,
                        ),
                        const Spacer(),
                        if (showReport)
                          const SizedBox(width: 28, height: 28)
                        else if (!unlocked)
                          const Icon(Icons.lock_outline, size: 16, color: SwissTheme.textPrimary)
                        else if (done)
                          Icon(Icons.check_circle, size: 16, color: SwissTheme.accentGreen),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      node.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.pixelifySans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: unlocked ? SwissTheme.textPrimary : SwissTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kindLabel.toUpperCase(),
                      style: SwissTheme.monospacedText.copyWith(
                        fontSize: 8,
                        color: SwissTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showReport && levelId != null && levelId.isNotEmpty)
              Positioned(
                top: 4,
                right: 4,
                child: DrivingLevelReportIconButton(
                  levelId: levelId,
                  passed: drivingReportPassed,
                  iconSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
