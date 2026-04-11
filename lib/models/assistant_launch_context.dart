import 'game_level.dart';
import 'last_driving_report.dart';
import 'mcq_question.dart';

/// Optional context passed when opening the assistant so answers stay relevant.
class AssistantLaunchContext {
  const AssistantLaunchContext({
    this.screenTitle,
    this.level,
    this.lastReport,
    this.drivingTopic,
    this.levelIdsForReportDigest,
    this.includeFullRoadSignCatalog = false,
    this.theoryTestName,
    this.currentMcqQuestion,
  });

  /// Short label for the model, e.g. "Main menu", "Level list".
  final String? screenTitle;

  /// Current or focused practical level (driving test).
  final GameLevel? level;

  /// When set, overrides loading the latest saved report for [level].
  final LastDrivingReport? lastReport;

  /// Topic shown on the level list (if any).
  final DrivingTopic? drivingTopic;

  /// Level IDs currently listed; used to summarize saved "last run" reports.
  final List<String>? levelIdsForReportDigest;

  /// When true, inject a text digest of all bundled road-sign MCQs.
  final bool includeFullRoadSignCatalog;

  /// Theory test name (e.g. road signs basics).
  final String? theoryTestName;

  /// Current MCQ while doing a road-sign test.
  final McqQuestion? currentMcqQuestion;
}
