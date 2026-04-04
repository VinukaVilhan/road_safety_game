import 'dart:convert';

import '../data/repositories/progress_repository.dart';
import '../models/tutorial_progress.dart';

/// Loads and persists [TutorialProgress] for the signed-in user (Isar + sync outbox).
class TutorialProgressService {
  TutorialProgressService._();

  static const String _settingKey = 'driving_tutorial_progress';

  static Future<TutorialProgress> load() async {
    final raw = await ProgressRepository.instance.readSetting(_settingKey);
    if (raw == null || raw.isEmpty) return const TutorialProgress();
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return const TutorialProgress();
      return TutorialProgress.fromJson(map);
    } catch (_) {
      return const TutorialProgress();
    }
  }

  static Future<void> save(TutorialProgress progress) async {
    await ProgressRepository.instance.saveSetting(
      settingKey: _settingKey,
      value: jsonEncode(progress.toJson()),
    );
  }

  static Future<void> markLessonComplete(DrivingTutorialLesson lesson) async {
    final current = await load();
    if (current.completedLessons.contains(lesson)) return;
    await save(
      current.copyWith(
        completedLessons: {...current.completedLessons, lesson},
      ),
    );
  }
}
