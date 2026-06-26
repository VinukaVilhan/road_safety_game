import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/learning/module_final_assessment.dart';
import '../../models/theory/mcq_question.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/audio/weather_sfx_service.dart';
import '../../services/content/driving_levels_service.dart';
import '../../services/content/module_finals_service.dart';
import '../../data/repositories/progress_repository.dart';
import '../../screens/driving/game_screen.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/learning/module_final_mcq_panel.dart';

enum _ModuleFinalPhase { loading, intro, mcq, practicalIntro, practical, result }

/// Mixed MCQ + practical assessment for a learning-path module final node.
class ModuleFinalScreen extends StatefulWidget {
  final String nodeId;

  const ModuleFinalScreen({super.key, required this.nodeId});

  @override
  State<ModuleFinalScreen> createState() => _ModuleFinalScreenState();
}

class _ModuleFinalScreenState extends State<ModuleFinalScreen> {
  _ModuleFinalPhase _phase = _ModuleFinalPhase.loading;
  ModuleFinalAssessment? _assessment;
  List<McqQuestion> _questions = const [];
  int _practicalIndex = 0;
  int _mcqAttempt = 0;
  bool _passed = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assessment = await ModuleFinalsService.instance.assessmentForNode(widget.nodeId);
      if (assessment == null) {
        setState(() {
          _loadError = 'No assessment configured for this module.';
          _phase = _ModuleFinalPhase.intro;
        });
        return;
      }
      final questions = ModuleFinalsService.instance.questionsForAssessment(assessment);
      if (assessment.hasMcqSection && questions.isEmpty) {
        setState(() {
          _loadError = 'Theory questions are not available yet.';
          _phase = _ModuleFinalPhase.intro;
        });
        return;
      }
      setState(() {
        _assessment = assessment;
        _questions = questions;
        _phase = _ModuleFinalPhase.intro;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _phase = _ModuleFinalPhase.intro;
      });
    }
  }

  void _startAssessment() {
    final a = _assessment;
    if (a == null) return;
    UiSoundService().playMenuTap();
    if (a.hasMcqSection) {
      setState(() => _phase = _ModuleFinalPhase.mcq);
    } else if (a.hasPracticalSection) {
      setState(() {
        _practicalIndex = 0;
        _phase = _ModuleFinalPhase.practicalIntro;
      });
    }
  }

  void _onMcqFinished(bool passed) {
    if (!passed) {
      setState(() {
        _mcqAttempt++;
        _phase = _ModuleFinalPhase.mcq;
      });
      return;
    }
    final a = _assessment!;
    if (a.hasPracticalSection) {
      setState(() {
        _practicalIndex = 0;
        _phase = _ModuleFinalPhase.practicalIntro;
      });
    } else {
      unawaited(_completeAssessment(passed: true));
    }
  }

  Future<void> _beginPracticalLevel() async {
    final a = _assessment;
    if (a == null || !mounted) return;
    final levelId = a.drivingLevelIds[_practicalIndex];
    final level = DrivingLevelsService.findLevelById(levelId);
    if (level == null) {
      setState(() => _loadError = 'Driving level "$levelId" is not available.');
      return;
    }

    setState(() => _phase = _ModuleFinalPhase.practical);
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(level: level)),
    );
    await WeatherSfxService.instance.endLesson();
    if (!mounted) return;

    final passedLevel = result != null;
    if (!passedLevel) {
      setState(() => _phase = _ModuleFinalPhase.practicalIntro);
      return;
    }

    if (_practicalIndex + 1 < a.drivingLevelIds.length) {
      setState(() {
        _practicalIndex++;
        _phase = _ModuleFinalPhase.practicalIntro;
      });
      return;
    }

    await _completeAssessment(passed: true);
  }

  Future<void> _completeAssessment({required bool passed}) async {
    if (passed) {
      await ProgressRepository.instance.recordModuleFinalPassed(widget.nodeId);
    }
    if (!mounted) return;
    setState(() {
      _passed = passed;
      _phase = _ModuleFinalPhase.result;
    });
  }

  void _exit() {
    UiSoundService().playMenuTap();
    Navigator.of(context).pop(_passed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: LandscapeLayout.bodyPadding(context),
          child: LandscapeLayout.bodyMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 12),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _exit,
          icon: const Icon(Icons.arrow_back_sharp, color: SwissTheme.textPrimary, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            (_assessment?.title ?? 'MODULE TEST').toUpperCase(),
            style: AppFonts.pixelifySans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SwissTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _ModuleFinalPhase.loading:
        return const Center(child: CircularProgressIndicator(color: SwissTheme.accentBlue));
      case _ModuleFinalPhase.intro:
        return _buildIntro();
      case _ModuleFinalPhase.mcq:
        return ModuleFinalMcqPanel(
          key: ValueKey('mcq-${widget.nodeId}-$_mcqAttempt'),
          questions: _questions,
          passScorePercent: _assessment!.passScorePercent,
          onFinished: _onMcqFinished,
        );
      case _ModuleFinalPhase.practicalIntro:
        return _buildPracticalIntro();
      case _ModuleFinalPhase.practical:
        return const Center(child: CircularProgressIndicator(color: SwissTheme.accentBlue));
      case _ModuleFinalPhase.result:
        return _buildFinalResult();
    }
  }

  Widget _buildIntro() {
    final a = _assessment;
    final parts = <String>[];
    if (a?.hasMcqSection == true) parts.add('theory questions');
    if (a?.hasPracticalSection == true) parts.add('practical driving');
    final mixLabel = parts.isEmpty ? 'steps' : parts.join(' and ');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 56, color: SwissTheme.accentBlue),
            const SizedBox(height: 16),
            Text(
              'MODULE TEST',
              style: AppFonts.pixelifySans(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_loadError != null)
              Text(
                _loadError!,
                style: AppFonts.pixelifySans(fontSize: 14, color: SwissTheme.accentRed),
                textAlign: TextAlign.center,
              )
            else ...[
              Text(
                a?.description ?? '',
                style: AppFonts.pixelifySans(fontSize: 14, color: SwissTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This test mixes $mixLabel. Pass score: ${a?.passScorePercent ?? 70}% on theory.',
                style: AppFonts.pixelifySans(fontSize: 13, color: SwissTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            if (_loadError == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startAssessment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwissTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
                  ),
                  child: Text(
                    'START TEST',
                    style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticalIntro() {
    final a = _assessment!;
    final levelId = a.drivingLevelIds[_practicalIndex];
    final level = DrivingLevelsService.findLevelById(levelId);
    final total = a.drivingLevelIds.length;
    final step = _practicalIndex + 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined, size: 56, color: SwissTheme.accentBlue),
            const SizedBox(height: 16),
            Text(
              'PRACTICAL $step / $total',
              style: AppFonts.pixelifySans(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              level?.name ?? levelId,
              style: AppFonts.pixelifySans(fontSize: 16, color: SwissTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pass this driving lesson to continue the module test.',
              style: AppFonts.pixelifySans(fontSize: 14, color: SwissTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _beginPracticalLevel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwissTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
                ),
                child: Text(
                  'START DRIVING',
                  style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalResult() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _passed ? Icons.emoji_events_outlined : Icons.cancel_outlined,
              size: 56,
              color: _passed ? SwissTheme.accentGreen : SwissTheme.accentRed,
            ),
            const SizedBox(height: 16),
            Text(
              _passed ? 'MODULE TEST PASSED' : 'MODULE TEST FAILED',
              style: AppFonts.pixelifySans(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _passed
                  ? 'You completed this module test. The next section on the learning path is unlocked.'
                  : 'Review the lessons in this module and try again.',
              style: AppFonts.pixelifySans(fontSize: 14, color: SwissTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _exit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwissTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
                ),
                child: Text(
                  'BACK TO PATH',
                  style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
