import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/driving/game_level.dart';
import '../../models/learning/learning_path.dart';
import '../progress/level_progress_service.dart';
import '../../data/repositories/progress_repository.dart';
import 'driving_levels_service.dart';

/// Loads the consolidated learning path and resolves unlock / completion state.
class LearningPathService {
  LearningPathService._();
  static final LearningPathService instance = LearningPathService._();

  static const _assetPath = 'assets/config/learning_path.json';

  static const Set<String> _underDevelopmentRoadMarkingsLevelIds = {
    'markings_stop_yield',
    'markings_bus_lanes',
    'markings_complex',
  };

  static const Set<String> _underDevelopmentEmergencyLevelIds = {
    'emergency_braking',
    'emergency_breakdown',
  };

  LearningPathCurriculum? _cached;

  Future<LearningPathCurriculum> loadCurriculum() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString(_assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cached = _parse(map);
    return _cached!;
  }

  void clearCache() => _cached = null;

  Future<LearningPathProgress> loadProgress() async {
    final passed = await ProgressRepository.instance.getCompletedTestIds();
    final viewed = await ProgressRepository.instance.getRoadSignsLearnViewedModuleIds();
    final levels = await LevelProgressService.getCompletedLevelIds();
    return LearningPathProgress(
      passedMcqIds: passed,
      viewedIntroIds: viewed,
      completedLevelIds: levels,
    );
  }

  bool isNodeUnderDevelopment(LearningPathNode node) {
    if (node.underDevelopment) return true;
    if (node.kind != LearningPathNodeKind.drivingLevel || node.ref == null) {
      return false;
    }
    final level = DrivingLevelsService.findLevelById(node.ref!);
    if (level == null) return true;
    return _isDrivingLevelUnderDevelopment(level);
  }

  bool isNodeComplete(LearningPathNode node, LearningPathProgress progress) {
    if (node.isCheckpoint) {
      return node.unlockRequirementIds.every(
        (id) => isNodeCompleteById(id, progress),
      );
    }

    final ref = node.ref?.trim();
    if (ref == null || ref.isEmpty) return false;

    switch (node.kind) {
      case LearningPathNodeKind.theoryIntro:
      case LearningPathNodeKind.roadSignsIntro:
        return progress.viewedIntroIds.contains(ref);
      case LearningPathNodeKind.theoryMcq:
      case LearningPathNodeKind.roadSignsMcq:
        return progress.passedMcqIds.contains(ref);
      case LearningPathNodeKind.roadSignsMinigame:
        return progress.viewedIntroIds.contains(ref);
      case LearningPathNodeKind.drivingLevel:
        return _isDrivingLevelComplete(ref, progress.completedLevelIds);
      case LearningPathNodeKind.moduleFinal:
      case LearningPathNodeKind.grandFinal:
        return false;
    }
  }

  bool isNodeCompleteById(String nodeId, LearningPathProgress progress) {
    final node = _cached?.nodeById(nodeId);
    if (node == null) return false;
    return isNodeComplete(node, progress);
  }

  bool isNodeUnlocked(LearningPathNode node, LearningPathProgress progress) {
    if (isNodeUnderDevelopment(node)) return false;
    if (node.unlockRequirementIds.isEmpty) return true;
    return node.unlockRequirementIds.every(
      (id) => isNodeCompleteById(id, progress),
    );
  }

  /// First unlocked-but-incomplete node across the full path (for highlighting).
  LearningPathNode? currentFocusNode(
    LearningPathCurriculum curriculum,
    LearningPathProgress progress,
  ) {
    for (final module in curriculum.modules) {
      for (final node in module.nodes) {
        if (isNodeUnlocked(node, progress) && !isNodeComplete(node, progress)) {
          return node;
        }
      }
    }
    return null;
  }

  static bool _isDrivingLevelComplete(String levelId, Set<String> completed) {
    if (completed.contains(levelId)) return true;
    if (levelId == 'emergency_ambulance' && completed.contains('emergency_vehicles')) {
      return true;
    }
    return false;
  }

  static bool _isDrivingLevelUnderDevelopment(GameLevel level) {
    if (level.topic == DrivingTopic.Parking || level.topic == DrivingTopic.RoadSigns) {
      return true;
    }
    if (level.topic == DrivingTopic.RoadMarkings &&
        _underDevelopmentRoadMarkingsLevelIds.contains(level.id)) {
      return true;
    }
    if (level.topic == DrivingTopic.EmergencySituations &&
        _underDevelopmentEmergencyLevelIds.contains(level.id)) {
      return true;
    }
    final map = level.mapAsset?.trim();
    if (map == null || map.isEmpty) {
      return level.id != 'emergency_vehicles';
    }
    return false;
  }

  static LearningPathCurriculum _parse(Map<String, dynamic> root) {
    final version = (root['version'] as num?)?.toInt() ?? 1;
    final modulesJson = root['modules'] as List<dynamic>? ?? [];
    final modules = modulesJson
        .map((m) => _parseModule(m as Map<String, dynamic>))
        .toList();
    return LearningPathCurriculum(version: version, modules: modules);
  }

  static LearningPathModule _parseModule(Map<String, dynamic> m) {
    final nodesJson = m['nodes'] as List<dynamic>? ?? [];
    final nodes = nodesJson.map((n) => _parseNode(n as Map<String, dynamic>)).toList();
    return LearningPathModule(
      id: m['id'] as String? ?? 'module',
      title: m['title'] as String? ?? 'Module',
      description: m['description'] as String? ?? '',
      nodes: nodes,
    );
  }

  static LearningPathNode _parseNode(Map<String, dynamic> n) {
    final unlockRaw = n['unlockRequirementIds'] as List<dynamic>? ?? [];
    return LearningPathNode(
      id: n['id'] as String? ?? 'node',
      kind: _parseKind(n['kind'] as String?),
      title: n['title'] as String? ?? 'Step',
      ref: n['ref'] as String?,
      categoryId: n['categoryId'] as String?,
      groupId: n['groupId'] as String?,
      subgroupId: n['subgroupId'] as String?,
      unlockRequirementIds: unlockRaw.map((e) => '$e').toList(),
      underDevelopment: n['underDevelopment'] as bool? ?? false,
    );
  }

  static LearningPathNodeKind _parseKind(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'theory_intro':
        return LearningPathNodeKind.theoryIntro;
      case 'theory_mcq':
        return LearningPathNodeKind.theoryMcq;
      case 'road_signs_intro':
        return LearningPathNodeKind.roadSignsIntro;
      case 'road_signs_mcq':
        return LearningPathNodeKind.roadSignsMcq;
      case 'road_signs_minigame':
        return LearningPathNodeKind.roadSignsMinigame;
      case 'driving_level':
        return LearningPathNodeKind.drivingLevel;
      case 'module_final':
        return LearningPathNodeKind.moduleFinal;
      case 'grand_final':
        return LearningPathNodeKind.grandFinal;
      default:
        return LearningPathNodeKind.theoryIntro;
    }
  }
}
