import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/theory/theory_category_curriculum.dart';
import '../../models/theory/theory_test.dart';

/// Loads theory category curriculum (intro + MCQ modules) from bundled JSON.
class TheoryCurriculumService {
  TheoryCurriculumService._();
  static final TheoryCurriculumService instance = TheoryCurriculumService._();

  static const _assetPath = 'assets/config/theory_curriculum.json';

  TheoryCategoryCurriculum? _cached;

  Future<TheoryCategoryCurriculum> loadCurriculum() async {
    final raw = await rootBundle.loadString(_assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cached = _parse(map);
    return _cached!;
  }

  void clearCache() => _cached = null;

  static TheoryCategoryCurriculum _parse(Map<String, dynamic> root) {
    final version = (root['version'] as num?)?.toInt() ?? 1;
    final categoriesJson = root['categories'] as List<dynamic>? ?? [];
    final categories =
        categoriesJson.map((c) => _parseCategory(c as Map<String, dynamic>)).toList();
    return TheoryCategoryCurriculum(version: version, categories: categories);
  }

  static TheoryCategory _parseCategory(Map<String, dynamic> c) {
    final bulletsJson = c['bullets'] as List<dynamic>? ?? [];
    final bullets = bulletsJson
        .map(
          (b) => TheoryIntroBullet(
            title: (b as Map<String, dynamic>)['title'] as String? ?? '',
            body: b['body'] as String? ?? '',
          ),
        )
        .toList();
    final slidesJson = c['introSlides'] as List<dynamic>? ?? [];
    final introSlides = slidesJson
        .map(
          (s) => TheoryIntroSlide(
            id: (s as Map<String, dynamic>)['id'] as String? ?? '',
            title: s['title'] as String? ?? '',
            body: s['body'] as String? ?? '',
            imageAsset: s['imageAsset'] as String? ?? '',
          ),
        )
        .toList();
    final modulesJson = c['modules'] as List<dynamic>? ?? [];
    final modules = modulesJson.map((m) => _parseModule(m as Map<String, dynamic>)).toList();
    return TheoryCategory(
      id: c['id'] as String? ?? 'category',
      title: c['title'] as String? ?? 'Category',
      description: c['description'] as String? ?? '',
      introImageAsset: c['introImageAsset'] as String? ?? '',
      introHeading: c['introHeading'] as String? ?? '',
      introLead: c['introLead'] as String? ?? '',
      bullets: bullets,
      introSlides: introSlides,
      modules: modules,
    );
  }

  static TheoryCategoryModule _parseModule(Map<String, dynamic> m) {
    final kindStr = (m['kind'] as String? ?? 'mcq').toLowerCase();
    final kind = kindStr == 'intro' ? TheoryCategoryModuleKind.intro : TheoryCategoryModuleKind.mcq;
    final unlockRaw = m['unlockRequirementIds'] as List<dynamic>? ?? [];
    return TheoryCategoryModule(
      id: m['id'] as String? ?? 'module',
      kind: kind,
      order: (m['order'] as num?)?.toInt() ?? 0,
      title: m['title'] as String? ?? 'Module',
      description: m['description'] as String? ?? '',
      mcqTestId: m['mcqTestId'] as String?,
      questionCount: (m['questionCount'] as num?)?.toInt() ?? 6,
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

  static bool isModuleUnlocked(
    TheoryCategoryModule module,
    Set<String> passedMcqModuleIds,
    Set<String> viewedIntroModuleIds,
  ) {
    if (module.unlockRequirementIds.isEmpty) return true;
    return module.unlockRequirementIds.every((req) {
      if (viewedIntroModuleIds.contains(req)) return true;
      if (passedMcqModuleIds.contains(req)) return true;
      return false;
    });
  }
}
