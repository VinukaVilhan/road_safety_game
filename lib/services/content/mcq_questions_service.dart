import '../../models/theory/mcq_question.dart';
import 'road_signs_questions_service.dart';
import 'theory_questions_service.dart';

/// Resolves MCQ questions for any theory test pool id.
class McqQuestionsService {
  static List<McqQuestion> getQuestionsForTest(String testId, {int? count}) {
    final theory = TheoryQuestionsService.getQuestionsForTest(testId, count: count);
    if (theory.isNotEmpty) return theory;
    return RoadSignsQuestionsService.getQuestionsForTest(testId, count: count);
  }
}
