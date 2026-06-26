/// Mixed MCQ + practical assessment for a learning-path module final node.
class ModuleFinalAssessment {
  final String nodeId;
  final String title;
  final String description;
  final List<String> mcqPools;
  final int mcqQuestionCount;
  final List<String> drivingLevelIds;
  final int passScorePercent;

  const ModuleFinalAssessment({
    required this.nodeId,
    required this.title,
    required this.description,
    this.mcqPools = const [],
    this.mcqQuestionCount = 0,
    this.drivingLevelIds = const [],
    this.passScorePercent = 70,
  });

  bool get hasMcqSection => mcqPools.isNotEmpty && mcqQuestionCount > 0;

  bool get hasPracticalSection => drivingLevelIds.isNotEmpty;
}

class ModuleFinalsCatalog {
  final int version;
  final List<ModuleFinalAssessment> assessments;

  const ModuleFinalsCatalog({
    required this.version,
    required this.assessments,
  });

  ModuleFinalAssessment? byNodeId(String nodeId) {
    for (final a in assessments) {
      if (a.nodeId == nodeId) return a;
    }
    return null;
  }
}
