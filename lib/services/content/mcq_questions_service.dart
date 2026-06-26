import '../../models/theory/mcq_question.dart';
import 'road_signs_questions_service.dart';
import 'theory_questions_service.dart';

import 'dart:math';

/// Resolves MCQ questions for any theory test pool id.
class McqQuestionsService {
  static final _rng = Random();

  static List<McqQuestion> getQuestionsForTest(String testId, {int? count}) {
    final theory = TheoryQuestionsService.getQuestionsForTest(testId, count: count);
    if (theory.isNotEmpty) return theory;
    return RoadSignsQuestionsService.getQuestionsForTest(testId, count: count);
  }

  /// Merges unique questions from [poolIds], shuffles, and returns up to [count].
  static List<McqQuestion> getQuestionsFromPools(
    List<String> poolIds, {
    required int count,
  }) {
    if (poolIds.isEmpty || count <= 0) return const [];

    final merged = <McqQuestion>[];
    final seen = <String>{};
    for (final poolId in poolIds) {
      for (final q in getQuestionsForTest(poolId)) {
        if (seen.add(q.id)) merged.add(q);
      }
    }
    if (merged.isEmpty) return const [];

    merged.shuffle(_rng);
    if (merged.length <= count) return merged;
    return merged.take(count).toList();
  }
}
