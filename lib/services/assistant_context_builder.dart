import '../models/assistant_launch_context.dart';
import '../models/game_level.dart';
import '../models/last_driving_report.dart';
import '../models/mcq_question.dart';
import 'last_driving_report_service.dart';
import 'road_signs_questions_service.dart';

/// Builds extra text injected into the assistant system prompt (game-aligned).
class AssistantContextBuilder {
  AssistantContextBuilder._();

  /// Checklist rows for standard (junction-style) practical levels — matches in-game rubric.
  static const String standardTurnRubric = '''
Standard driving-level checklist (junction / turn maps):
1) Approach zone — Enter the yellow marked approach zone.
2) Signalling (approach) — Show the correct turn signal for the scenario in the yellow approach zone (left, right, or none for straight).
3) Turn execution — Enter the purple turn execution zone.
4) Signalling (during turn) — Maintain the required signal throughout the purple zone.
5) Route completion — Reach the green finish zone.
6) Obstacle discipline — Avoid minor non-crash contacts with obstacles; a clean run requires zero.
''';

  /// Checklist for road-crossing (zebra-style) maps.
  static const String roadCrossingRubric = '''
Road-crossing (zebra-style) level checklist:
1) Approach control — Enter the yellow speed-limit / approach zone before the attempt ends.
2) Zebra crossing — Full stop in Park and completed wait within the grey zig-zag zone.
3) Route completion — Reach the green finish zone.
4) Obstacle discipline — Avoid minor non-crash contacts; a clean run requires zero.
''';

  static String _formatReport(LastDrivingReport r) {
    final details = r.mistakeDetails.isEmpty
        ? '(none)'
        : r.mistakeDetails.map((e) => '  - $e').join('\n');
    final fail = (r.failureMessage == null || r.failureMessage!.trim().isEmpty)
        ? ''
        : '\nFailure message: ${r.failureMessage}';
    return '''
Level: ${r.levelName} (id: ${r.levelId})
Passed: ${r.passed}
Score: ${r.score}
Checklist: ${r.correctMoves} satisfied, ${r.mistakes} missed
Road-crossing layout: ${r.roadCrossingLayout}
Time (ms): ${r.timeSpentMs}
Mistake / feedback lines:
$details$fail
''';
  }

  static String _formatLevel(GameLevel level) {
    return '''
Focused level: ${level.name} (id: ${level.id})
Topic: ${level.topic.displayName}
Description: ${level.description}
Difficulty: ${level.difficulty.name}
Map: ${level.mapAsset ?? '(default)'}
Scenario: ${level.scenarioId ?? '(none)'}
''';
  }

  static String _roadSignCatalogDigest() {
    final qs = RoadSignsQuestionsService.allQuestionsForAssistant();
    final buf = StringBuffer()
      ..writeln('Bundled road-sign reference (question id → correct meaning):');
    for (final McqQuestion q in qs) {
      if (q.options.isEmpty || q.correctIndex < 0 || q.correctIndex >= q.options.length) {
        continue;
      }
      final correct = q.options[q.correctIndex];
      final asset = q.imageAssetPath ?? q.imageUrl ?? '';
      buf.writeln('- ${q.id}: $correct${asset.isNotEmpty ? ' [$asset]' : ''}');
    }
    return buf.toString();
  }

  static String _formatMcq(McqQuestion q) {
    final correct = q.options.isNotEmpty &&
            q.correctIndex >= 0 &&
            q.correctIndex < q.options.length
        ? q.options[q.correctIndex]
        : '?';
    return '''
Current theory question id: ${q.id}
Prompt: ${q.questionText}
Correct answer text: $correct
Options: ${q.options.join(' | ')}
''';
  }

  /// Assembles the augmented context block for the system prompt.
  static Future<String> build(AssistantLaunchContext ctx) async {
    final sections = <String>[];

    if (ctx.screenTitle != null && ctx.screenTitle!.trim().isNotEmpty) {
      sections.add('User screen: ${ctx.screenTitle!.trim()}');
    }

    if (ctx.theoryTestName != null && ctx.theoryTestName!.trim().isNotEmpty) {
      sections.add('Theory test: ${ctx.theoryTestName!.trim()}');
    }

    if (ctx.drivingTopic != null) {
      sections.add(
        'Driving topic in UI: ${ctx.drivingTopic!.displayName} — ${ctx.drivingTopic!.description}',
      );
    }

    sections.add('Game rubric — standard turns:\n$standardTurnRubric');
    sections.add('Game rubric — road crossing:\n$roadCrossingRubric');

    if (ctx.includeFullRoadSignCatalog) {
      sections.add(_roadSignCatalogDigest());
    }

    if (ctx.currentMcqQuestion != null) {
      sections.add('Current question context:\n${_formatMcq(ctx.currentMcqQuestion!)}');
    }

    if (ctx.level != null) {
      sections.add(_formatLevel(ctx.level!));
      LastDrivingReport? report = ctx.lastReport;
      report ??= await LastDrivingReportService.instance.loadReportForLevel(ctx.level!.id);
      if (report != null) {
        sections.add('Latest saved practical report for this level:\n${_formatReport(report)}');
      } else {
        sections.add('No saved practical report yet for this level.');
      }
    }

    final ids = ctx.levelIdsForReportDigest;
    if (ids != null && ids.isNotEmpty) {
      final buf = StringBuffer()
        ..writeln('Saved practical reports for levels on this list (if any):');
      for (final id in ids) {
        final r = await LastDrivingReportService.instance.loadReportForLevel(id);
        if (r != null) {
          buf.writeln('---\n${_formatReport(r)}');
        }
      }
      sections.add(buf.toString());
    }

    return sections.join('\n\n---\n\n');
  }
}
