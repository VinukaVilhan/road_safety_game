import 'theory_test.dart';

/// Kind of learning unit under road signs (extend with new kinds as you add screens).
enum RoadSignsModuleKind {
  mcq,
  learn,
  intro,
  minigame,
}

class RoadSignsModule {
  final String id;
  final RoadSignsModuleKind kind;
  final int order;
  final String title;
  final String description;
  /// Pool key for [RoadSignsQuestionsService]; for MCQ usually matches [id] or explicit test id.
  final String? mcqTestId;
  final int questionCount;
  final TestDifficulty difficulty;
  final List<String> unlockRequirementIds;

  const RoadSignsModule({
    required this.id,
    required this.kind,
    required this.order,
    required this.title,
    required this.description,
    this.mcqTestId,
    this.questionCount = 10,
    this.difficulty = TestDifficulty.Easy,
    this.unlockRequirementIds = const [],
  });

  /// Builds the legacy [TheoryTest] used by [RoadSignMcqScreen] for MCQ modules.
  TheoryTest toTheoryTest({required String categoryId}) {
    return TheoryTest(
      id: id,
      categoryId: categoryId,
      testNumber: order,
      name: title,
      description: description,
      difficulty: difficulty,
      isUnlocked: true,
      unlockRequirementIds: unlockRequirementIds,
      questionCount: questionCount,
      mcqQuestionPoolId: kind == RoadSignsModuleKind.mcq ? effectiveMcqPoolId : null,
    );
  }

  String get effectiveMcqPoolId => (mcqTestId != null && mcqTestId!.trim().isNotEmpty) ? mcqTestId!.trim() : id;
}

class RoadSignsSubgroup {
  final String id;
  final int order;
  final String title;
  final String description;
  final List<RoadSignsModule> modules;

  const RoadSignsSubgroup({
    required this.id,
    this.order = 0,
    required this.title,
    required this.description,
    required this.modules,
  });

  List<RoadSignsModule> get modulesSorted => List<RoadSignsModule>.from(modules)
    ..sort((a, b) => a.order.compareTo(b.order));
}

class RoadSignsGroup {
  final String id;
  final String title;
  final String description;
  final List<RoadSignsSubgroup> subgroups;
  final List<RoadSignsModule> modules;

  const RoadSignsGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.subgroups,
    required this.modules,
  });

  bool get hasSubgroups => subgroups.isNotEmpty;

  List<RoadSignsModule> get topLevelModulesSorted => List<RoadSignsModule>.from(modules)
    ..sort((a, b) => a.order.compareTo(b.order));
}

class RoadSignsCurriculum {
  final int version;
  final List<RoadSignsGroup> groups;

  const RoadSignsCurriculum({required this.version, required this.groups});

  RoadSignsGroup? groupById(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  RoadSignsModule? findModule(String moduleId) {
    for (final g in groups) {
      for (final m in g.modules) {
        if (m.id == moduleId) return m;
      }
      for (final sg in g.subgroups) {
        for (final m in sg.modules) {
          if (m.id == moduleId) return m;
        }
      }
    }
    return null;
  }
}
