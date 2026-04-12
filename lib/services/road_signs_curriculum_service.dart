import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/road_signs_curriculum.dart';
import '../models/theory_test.dart';

/// Loads hierarchical road-signs curriculum from bundled JSON.
class RoadSignsCurriculumService {
  RoadSignsCurriculumService._();
  static final RoadSignsCurriculumService instance = RoadSignsCurriculumService._();

  static const _assetPath = 'assets/config/road_signs_curriculum.json';

  RoadSignsCurriculum? _cached;

  /// Always reads from the asset bundle so curriculum updates apply (hot reload
  /// and code deploy used to leave a stale singleton cache).
  Future<RoadSignsCurriculum> loadCurriculum() async {
    final raw = await rootBundle.loadString(_assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cached = _parse(map);
    return _cached!;
  }

  void clearCache() => _cached = null;

  static RoadSignsCurriculum _parse(Map<String, dynamic> root) {
    final version = (root['version'] as num?)?.toInt() ?? 1;
    final groupsJson = root['groups'] as List<dynamic>? ?? [];
    final groups = groupsJson.map((g) => _parseGroup(g as Map<String, dynamic>)).toList();
    return RoadSignsCurriculum(version: version, groups: groups);
  }

  static RoadSignsGroup _parseGroup(Map<String, dynamic> g) {
    final subRaw = g['subgroups'] as List<dynamic>? ?? [];
    final subgroups = subRaw.map((s) => _parseSubgroup(s as Map<String, dynamic>)).toList();
    final modRaw = g['modules'] as List<dynamic>? ?? [];
    final modules = modRaw.map((m) => _parseModule(m as Map<String, dynamic>)).toList();
    return RoadSignsGroup(
      id: g['id'] as String? ?? 'group',
      title: g['title'] as String? ?? 'Group',
      description: g['description'] as String? ?? '',
      subgroups: subgroups,
      modules: modules,
    );
  }

  static RoadSignsSubgroup _parseSubgroup(Map<String, dynamic> s) {
    final modRaw = s['modules'] as List<dynamic>? ?? [];
    final modules = modRaw.map((m) => _parseModule(m as Map<String, dynamic>)).toList();
    return RoadSignsSubgroup(
      id: s['id'] as String? ?? 'subgroup',
      order: (s['order'] as num?)?.toInt() ?? 0,
      title: s['title'] as String? ?? 'Subgroup',
      description: s['description'] as String? ?? '',
      modules: modules,
    );
  }

  static RoadSignsModule _parseModule(Map<String, dynamic> m) {
    final kindStr = (m['kind'] as String? ?? 'mcq').toLowerCase();
    final kind = switch (kindStr) {
      'learn' => RoadSignsModuleKind.learn,
      'intro' => RoadSignsModuleKind.intro,
      'minigame' => RoadSignsModuleKind.minigame,
      _ => RoadSignsModuleKind.mcq,
    };
    final unlockRaw = m['unlockRequirementIds'] as List<dynamic>? ?? [];
    return RoadSignsModule(
      id: m['id'] as String? ?? 'module',
      kind: kind,
      order: (m['order'] as num?)?.toInt() ?? 0,
      title: m['title'] as String? ?? 'Module',
      description: m['description'] as String? ?? '',
      mcqTestId: m['mcqTestId'] as String?,
      questionCount: (m['questionCount'] as num?)?.toInt() ?? 10,
      difficulty: _parseDifficulty(m['difficulty'] as String?),
      unlockRequirementIds: unlockRaw.map((e) => '$e').toList(),
    );
  }

  static TestDifficulty _parseDifficulty(String? s) {
    switch ((s ?? 'easy').toLowerCase()) {
      case 'medium':
        return TestDifficulty.Medium;
      case 'hard':
        return TestDifficulty.Hard;
      default:
        return TestDifficulty.Easy;
    }
  }

  /// Whether the user may open this module (MCQ: passed prerequisite test; learn: viewed prerequisite learn).
  static bool isModuleUnlocked(
    RoadSignsModule module,
    Set<String> passedMcqModuleIds,
    Set<String> viewedLearnModuleIds,
  ) {
    if (module.unlockRequirementIds.isEmpty) return true;
    return module.unlockRequirementIds.every((req) {
      if (viewedLearnModuleIds.contains(req)) return true;
      if (passedMcqModuleIds.contains(req)) return true;
      return false;
    });
  }
}
