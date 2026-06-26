import 'theory_test.dart';

/// Kind of learning unit under a theory category (intro, MCQ, …).
enum TheoryCategoryModuleKind {
  intro,
  mcq,
}

class TheoryIntroBullet {
  final String title;
  final String body;

  const TheoryIntroBullet({required this.title, required this.body});
}

/// One scenario slide in a theory intro carousel (image + explanation).
class TheoryIntroSlide {
  final String id;
  final String title;
  final String body;
  final String imageAsset;

  const TheoryIntroSlide({
    required this.id,
    required this.title,
    required this.body,
    required this.imageAsset,
  });
}

class TheoryCategoryModule {
  final String id;
  final TheoryCategoryModuleKind kind;
  final int order;
  final String title;
  final String description;
  final String? mcqTestId;
  final int questionCount;
  final TestDifficulty difficulty;
  final List<String> unlockRequirementIds;

  const TheoryCategoryModule({
    required this.id,
    required this.kind,
    required this.order,
    required this.title,
    required this.description,
    this.mcqTestId,
    this.questionCount = 6,
    this.difficulty = TestDifficulty.Easy,
    this.unlockRequirementIds = const [],
  });

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
      mcqQuestionPoolId: kind == TheoryCategoryModuleKind.mcq ? effectiveMcqPoolId : null,
    );
  }

  String get effectiveMcqPoolId =>
      (mcqTestId != null && mcqTestId!.trim().isNotEmpty) ? mcqTestId!.trim() : id;
}

class TheoryCategory {
  final String id;
  final String title;
  final String description;
  final String introImageAsset;
  final String introHeading;
  final String introLead;
  final List<TheoryIntroBullet> bullets;
  final List<TheoryIntroSlide> introSlides;
  final List<TheoryCategoryModule> modules;

  const TheoryCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.introImageAsset,
    required this.introHeading,
    required this.introLead,
    required this.bullets,
    this.introSlides = const [],
    required this.modules,
  });

  bool get hasIntroCarousel => introSlides.isNotEmpty;

  List<TheoryCategoryModule> get modulesSorted => List<TheoryCategoryModule>.from(modules)
    ..sort((a, b) => a.order.compareTo(b.order));
}

class TheoryCategoryCurriculum {
  final int version;
  final List<TheoryCategory> categories;

  const TheoryCategoryCurriculum({required this.version, required this.categories});

  TheoryCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
