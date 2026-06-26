import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/learning/module_final_assessment.dart';
import '../../models/theory/mcq_question.dart';
import 'mcq_questions_service.dart';

/// Loads module-final assessment definitions and resolves MCQ question sets.
class ModuleFinalsService {
  ModuleFinalsService._();
  static final ModuleFinalsService instance = ModuleFinalsService._();

  static const _assetPath = 'assets/config/module_finals.json';

  ModuleFinalsCatalog? _cached;

  Future<ModuleFinalsCatalog> loadCatalog() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString(_assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cached = _parse(map);
    return _cached!;
  }

  Future<ModuleFinalAssessment?> assessmentForNode(String nodeId) async {
    final catalog = await loadCatalog();
    return catalog.byNodeId(nodeId);
  }

  Future<Set<String>> allNodeIds() async {
    final catalog = await loadCatalog();
    return catalog.assessments.map((a) => a.nodeId).toSet();
  }

  void clearCache() => _cached = null;

  List<McqQuestion> questionsForAssessment(ModuleFinalAssessment assessment) {
    if (!assessment.hasMcqSection) return const [];
    return McqQuestionsService.getQuestionsFromPools(
      assessment.mcqPools,
      count: assessment.mcqQuestionCount,
    );
  }

  static ModuleFinalsCatalog _parse(Map<String, dynamic> root) {
    final version = (root['version'] as num?)?.toInt() ?? 1;
    final list = root['assessments'] as List<dynamic>? ?? [];
    final assessments = list
        .map((e) => _parseAssessment(e as Map<String, dynamic>))
        .toList();
    return ModuleFinalsCatalog(version: version, assessments: assessments);
  }

  static ModuleFinalAssessment _parseAssessment(Map<String, dynamic> m) {
    final poolsRaw = m['mcqPools'] as List<dynamic>? ?? [];
    final levelsRaw = m['drivingLevelIds'] as List<dynamic>? ?? [];
    return ModuleFinalAssessment(
      nodeId: m['nodeId'] as String? ?? 'module_final',
      title: m['title'] as String? ?? 'Module test',
      description: m['description'] as String? ?? '',
      mcqPools: poolsRaw.map((e) => '$e').toList(),
      mcqQuestionCount: (m['mcqQuestionCount'] as num?)?.toInt() ?? 0,
      drivingLevelIds: levelsRaw.map((e) => '$e').toList(),
      passScorePercent: (m['passScorePercent'] as num?)?.toInt() ?? 70,
    );
  }
}
