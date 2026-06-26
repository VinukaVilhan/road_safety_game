import 'package:flutter/material.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../data/repositories/progress_repository.dart';
import '../../models/theory/theory_test.dart';
import '../../models/theory/mcq_question.dart';
import '../../services/content/road_signs_questions_service.dart';
import '../../services/audio/ui_sound_service.dart';

/// Full-screen MCQ test for road signs. Shows one question at a time with optional image.
class RoadSignMcqScreen extends StatefulWidget {
  final TheoryTest test;

  const RoadSignMcqScreen({super.key, required this.test});

  @override
  State<RoadSignMcqScreen> createState() => _RoadSignMcqScreenState();
}

class _RoadSignMcqScreenState extends State<RoadSignMcqScreen> {
  late List<McqQuestion> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  bool _testComplete = false;
  bool _resultPersisted = false;

  late final TextStyle _headerStyle;
  late final TextStyle _questionStyle;
  late final TextStyle _optionStyle;
  late final TextStyle _resultTitleStyle;
  late final TextStyle _resultBodyStyle;

  @override
  void initState() {
    super.initState();
    final poolId = widget.test.mcqQuestionPoolId ?? widget.test.id;
    _questions = RoadSignsQuestionsService.getQuestionsForTest(
      poolId,
      count: widget.test.questionCount,
    );
    if (_questions.isEmpty) {
      _questions = RoadSignsQuestionsService.getQuestionsForTest('warning_signs_mcq', count: 10);
    }
    _initStyles();
  }

  void _initStyles() {
    _headerStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textSecondary,
    );
    _questionStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    _optionStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: SwissTheme.textPrimary,
    );
    _resultTitleStyle = AppFonts.pixelifySans(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: SwissTheme.textPrimary,
    );
    _resultBodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textSecondary,
    );
  }

  void _onOptionSelected(int index) {
    if (_hasAnswered) return;
    UiSoundService().playMenuTap();
    setState(() {
      _selectedOptionIndex = index;
      _hasAnswered = true;
      final correct = index == _questions[_currentIndex].correctIndex;
      if (correct) _correctCount++;
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex + 1 >= _questions.length) {
      await _persistResultIfNeeded();
      setState(() => _testComplete = true);
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOptionIndex = null;
      _hasAnswered = false;
    });
  }

  void _exitTest() {
    UiSoundService().playMenuTap();
    Navigator.of(context).pop();
  }

  Future<void> _persistResultIfNeeded() async {
    if (_resultPersisted) return;
    final total = _questions.length;
    if (total == 0) return;
    final score = ((_correctCount / total) * 100).round();
    await ProgressRepository.instance.recordTheoryAttempt(
      testId: widget.test.id,
      totalQuestions: total,
      correctCount: _correctCount,
      score: score,
    );
    _resultPersisted = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_testComplete) {
      return _buildResultScreen();
    }
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: _buildQuestionContent(),
              ),
            ),
            if (_hasAnswered) _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              _showExitConfirm();
            },
            icon: const Icon(Icons.arrow_back_sharp, color: SwissTheme.textPrimary, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            'Question ${_currentIndex + 1} of ${_questions.length}',
            style: _headerStyle,
          ),
          const Spacer(),
          Text(
            '$_correctCount correct',
            style: _headerStyle.copyWith(color: SwissTheme.accentGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent() {
    final q = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q.hasImage) ...[
          _buildQuestionImage(q),
          const SizedBox(height: 20),
        ],
        Text(
          q.questionText,
          style: _questionStyle,
        ),
        const SizedBox(height: 24),
        ...List.generate(q.options.length, (i) => _buildOption(q, i)),
      ],
    );
  }

  Widget _buildQuestionImage(McqQuestion q) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: SwissTheme.backgroundLightGrey,
          border: Border.all(color: SwissTheme.borderBlack, width: 1),
        ),
        child: ClipRect(
          child: q.imageAssetPath != null
              ? Image.asset(
                  q.imageAssetPath!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildPlaceholderSign(q.id),
                )
              : (q.imageUrl != null
                  ? Image.network(
                      q.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildPlaceholderSign(q.id),
                    )
                  : _buildPlaceholderSign(q.id)),
        ),
      ),
    );
  }

  /// Simple placeholder when asset is missing (e.g. before running download script).
  Widget _buildPlaceholderSign(String id) {
    return Center(
      child: Icon(
        Icons.traffic,
        size: 80,
        color: SwissTheme.textSecondary.withOpacity(0.5),
      ),
    );
  }

  Widget _buildOption(McqQuestion q, int index) {
    final isSelected = _selectedOptionIndex == index;
    final correctIndex = q.correctIndex;
    final showCorrect = _hasAnswered && index == correctIndex;
    final showWrong = _hasAnswered && isSelected && index != correctIndex;

    Color? bgColor;
    if (showCorrect) bgColor = SwissTheme.accentGreen.withOpacity(0.15);
    if (showWrong) bgColor = SwissTheme.accentRed.withOpacity(0.15);
    if (isSelected && !showWrong) bgColor = SwissTheme.backgroundLightGrey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onOptionSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: bgColor ?? SwissTheme.backgroundWhite,
              border: Border.all(
                color: showWrong
                    ? SwissTheme.accentRed
                    : (showCorrect ? SwissTheme.accentGreen : SwissTheme.borderBlack),
                width: showCorrect || showWrong ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: SwissTheme.borderBlack, width: 1),
                    color: showCorrect
                        ? SwissTheme.accentGreen
                        : (showWrong ? SwissTheme.accentRed : null),
                  ),
                  child: _hasAnswered && (showCorrect || showWrong)
                      ? Icon(
                          showCorrect ? Icons.check : Icons.close,
                          size: 18,
                          color: Colors.white,
                        )
                      : Text(
                          String.fromCharCode(0x41 + index),
                          style: _optionStyle.copyWith(fontSize: 12),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    q.options[index],
                    style: _optionStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SwissTheme.borderBlack, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () {
            UiSoundService().playMenuTap();
            _nextQuestion();
          },
          style: TextButton.styleFrom(
            backgroundColor: SwissTheme.accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: Text(
            _currentIndex + 1 >= _questions.length ? 'SEE RESULTS' : 'NEXT',
            style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final score = _questions.isEmpty ? 0 : ((_correctCount / _questions.length) * 100).round();
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _exitTest,
                    icon: const Icon(Icons.arrow_back_sharp, color: SwissTheme.textPrimary, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text('RESULT', style: _resultTitleStyle),
                ],
              ),
              const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 24),
              const SizedBox(height: 24),
              Text(
                '${widget.test.name}',
                style: _resultTitleStyle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              Text(
                'You got $_correctCount out of ${_questions.length} correct.',
                style: _resultBodyStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Score: $score%',
                style: AppFonts.pixelifySans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: score >= 70 ? SwissTheme.accentGreen : SwissTheme.accentRed,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await _persistResultIfNeeded();
                    _exitTest();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: SwissTheme.textPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(
                    'BACK TO TESTS',
                    style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: SwissTheme.borderBlack, width: 1),
        ),
        title: Text('Exit test?', style: _questionStyle),
        content: Text(
          'Your progress will be lost.',
          style: _resultBodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.of(ctx).pop();
            },
            child: Text('Cancel', style: TextStyle(color: SwissTheme.accentBlue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _exitTest();
            },
            child: Text('Exit', style: TextStyle(color: SwissTheme.accentRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
