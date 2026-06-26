import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/learning/learning_path.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../models/theory/theory_category_curriculum.dart';
import '../../screens/driving/game_screen.dart';
import '../../screens/learning/module_final_screen.dart';
import '../../screens/minigames/traffic_color_lights_intro_screen.dart';
import '../../screens/minigames/traffic_color_lights_minigame_screen.dart';
import '../../screens/road_signs/road_signs_learn_screen.dart';
import '../../screens/road_signs/roadsign_mcq_screen.dart';
import '../../screens/theory/theory_intro_screen.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/audio/weather_sfx_service.dart';
import '../../services/content/driving_levels_service.dart';
import '../../services/content/road_signs_curriculum_service.dart';
import '../../services/content/theory_curriculum_service.dart';
import '../../services/progress/level_progress_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';

/// Opens the correct existing lesson screen for a learning-path node.
class LearningPathNavigator {
  LearningPathNavigator._();

  static Future<void> openNode(
    BuildContext context,
    LearningPathNode node,
  ) async {
    if (node.kind == LearningPathNodeKind.moduleFinal) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ModuleFinalScreen(nodeId: node.id)),
      );
      return;
    }
    if (node.kind == LearningPathNodeKind.grandFinal) {
      await _showCheckpointDialog(context, node);
      return;
    }

    switch (node.kind) {
      case LearningPathNodeKind.theoryIntro:
      case LearningPathNodeKind.theoryMcq:
        await _openTheoryNode(context, node);
      case LearningPathNodeKind.roadSignsIntro:
      case LearningPathNodeKind.roadSignsMcq:
      case LearningPathNodeKind.roadSignsMinigame:
        await _openRoadSignsNode(context, node);
      case LearningPathNodeKind.drivingLevel:
        await _openDrivingLevel(context, node);
      case LearningPathNodeKind.moduleFinal:
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => ModuleFinalScreen(nodeId: node.id)),
        );
      case LearningPathNodeKind.grandFinal:
        await _showCheckpointDialog(context, node);
    }
  }

  static Future<void> _openTheoryNode(BuildContext context, LearningPathNode node) async {
    final categoryId = node.categoryId?.trim();
    final ref = node.ref?.trim();
    if (categoryId == null || ref == null) return;

    final curriculum = await TheoryCurriculumService.instance.loadCurriculum();
    final category = curriculum.categoryById(categoryId);
    if (category == null || !context.mounted) return;

    TheoryCategoryModule? module;
    for (final m in category.modules) {
      if (m.id == ref) {
        module = m;
        break;
      }
    }
    if (module == null || !context.mounted) return;

    if (module.kind == TheoryCategoryModuleKind.intro) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TheoryIntroScreen(category: category, module: module!),
        ),
      );
      return;
    }

    final test = module.toTheoryTest(categoryId: category.id);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoadSignMcqScreen(test: test)),
    );
  }

  static Future<void> _openRoadSignsNode(BuildContext context, LearningPathNode node) async {
    final groupId = node.groupId?.trim();
    final ref = node.ref?.trim();
    if (groupId == null || ref == null) return;

    final curriculum = await RoadSignsCurriculumService.instance.loadCurriculum();
    final group = curriculum.groupById(groupId);
    if (group == null || !context.mounted) return;

    RoadSignsModule? module = curriculum.findModule(ref);
    if (module == null || !context.mounted) return;

    final resolved = module;
    final breadcrumb = group.title;

    switch (resolved.kind) {
      case RoadSignsModuleKind.intro:
        if (resolved.id == 'traffic_color_lights_intro') {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TrafficColorLightsIntroScreen(module: resolved, breadcrumb: breadcrumb),
            ),
          );
        } else {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RoadSignsLearnScreen(module: resolved, breadcrumb: breadcrumb),
            ),
          );
        }
      case RoadSignsModuleKind.learn:
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => RoadSignsLearnScreen(module: resolved, breadcrumb: breadcrumb),
          ),
        );
      case RoadSignsModuleKind.mcq:
        final test = resolved.toTheoryTest(categoryId: 'road_signs');
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoadSignMcqScreen(test: test)),
        );
      case RoadSignsModuleKind.minigame:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrafficColorLightsMinigameScreen(module: resolved, breadcrumb: breadcrumb),
          ),
        );
    }
  }

  static Future<void> _openDrivingLevel(BuildContext context, LearningPathNode node) async {
    final ref = node.ref?.trim();
    if (ref == null) return;
    final level = DrivingLevelsService.findLevelById(ref);
    if (level == null || !context.mounted) return;

    await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(level: level)),
    );

    await WeatherSfxService.instance.endLesson();
    if (context.mounted) {
      unawaited(LevelProgressService.uploadLocalCompletedLevelsToFirestore());
    }
  }

  static Future<void> _showCheckpointDialog(BuildContext context, LearningPathNode node) async {
    UiSoundService().playMenuTap();
    final isGrand = node.kind == LearningPathNodeKind.grandFinal;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
        title: Text(
          isGrand ? 'GRAND FINAL' : 'MODULE COMPLETE',
          style: AppFonts.pixelifySans(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isGrand
              ? 'You have completed every module on the learning path. Well done!'
              : 'All steps in this module are done. Continue to the next section on the path.',
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
}
