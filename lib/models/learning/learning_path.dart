/// Node kinds on the consolidated learning path.
enum LearningPathNodeKind {
  theoryIntro,
  theoryMcq,
  roadSignsIntro,
  roadSignsMcq,
  roadSignsMinigame,
  drivingLevel,
  moduleFinal,
  grandFinal,
}

class LearningPathNode {
  final String id;
  final LearningPathNodeKind kind;
  final String title;
  final String? ref;
  final String? categoryId;
  final String? groupId;
  final String? subgroupId;
  final List<String> unlockRequirementIds;
  final bool underDevelopment;

  const LearningPathNode({
    required this.id,
    required this.kind,
    required this.title,
    this.ref,
    this.categoryId,
    this.groupId,
    this.subgroupId,
    this.unlockRequirementIds = const [],
    this.underDevelopment = false,
  });

  bool get isCheckpoint =>
      kind == LearningPathNodeKind.moduleFinal || kind == LearningPathNodeKind.grandFinal;
}

class LearningPathModule {
  final String id;
  final String title;
  final String description;
  final List<LearningPathNode> nodes;

  const LearningPathModule({
    required this.id,
    required this.title,
    required this.description,
    required this.nodes,
  });

  LearningPathNode? nodeById(String nodeId) {
    for (final n in nodes) {
      if (n.id == nodeId) return n;
    }
    return null;
  }
}

class LearningPathCurriculum {
  final int version;
  final List<LearningPathModule> modules;

  const LearningPathCurriculum({
    required this.version,
    required this.modules,
  });

  List<LearningPathNode> get allNodes =>
      modules.expand((m) => m.nodes).toList(growable: false);

  LearningPathNode? nodeById(String nodeId) {
    for (final m in modules) {
      final n = m.nodeById(nodeId);
      if (n != null) return n;
    }
    return null;
  }
}

/// Snapshot of progress used for path unlock / completion.
class LearningPathProgress {
  final Set<String> passedMcqIds;
  final Set<String> viewedIntroIds;
  final Set<String> completedLevelIds;
  final Set<String> passedModuleFinalIds;

  const LearningPathProgress({
    required this.passedMcqIds,
    required this.viewedIntroIds,
    required this.completedLevelIds,
    required this.passedModuleFinalIds,
  });

  static const empty = LearningPathProgress(
    passedMcqIds: {},
    viewedIntroIds: {},
    completedLevelIds: {},
    passedModuleFinalIds: {},
  );
}
