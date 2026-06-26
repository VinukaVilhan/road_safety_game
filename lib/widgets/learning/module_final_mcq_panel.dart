import 'package:flutter/material.dart';

import '../../models/theory/mcq_question.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';

/// In-module MCQ section for a module final assessment (no separate route).
class ModuleFinalMcqPanel extends StatefulWidget {
  final List<McqQuestion> questions;
  final int passScorePercent;
  final ValueChanged<bool> onFinished;

  const ModuleFinalMcqPanel({
    super.key,
    required this.questions,
    required this.passScorePercent,
    required this.onFinished,
  });

  @override
  State<ModuleFinalMcqPanel> createState() => _ModuleFinalMcqPanelState();
}

class _ModuleFinalMcqPanelState extends State<ModuleFinalMcqPanel> {
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  bool _sectionComplete = false;
  bool? _passed;

  late final TextStyle _headerStyle = AppFonts.pixelifySans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: SwissTheme.textSecondary,
  );
  late final TextStyle _questionStyle = AppFonts.pixelifySans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: SwissTheme.textPrimary,
  );
  late final TextStyle _optionStyle = AppFonts.pixelifySans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: SwissTheme.textPrimary,
  );

  void _onOptionSelected(int index) {
    if (_hasAnswered) return;
    UiSoundService().playMenuTap();
    setState(() {
      _selectedOptionIndex = index;
      _hasAnswered = true;
      if (index == widget.questions[_currentIndex].correctIndex) {
        _correctCount++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= widget.questions.length) {
      final total = widget.questions.length;
      final score = total == 0 ? 0 : ((_correctCount / total) * 100).round();
      final passed = score >= widget.passScorePercent;
      setState(() {
        _sectionComplete = true;
        _passed = passed;
      });
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOptionIndex = null;
      _hasAnswered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sectionComplete) {
      return _buildSectionResult();
    }

    final q = widget.questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'THEORY — Question ${_currentIndex + 1} / ${widget.questions.length}',
          style: _headerStyle,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentIndex + (_hasAnswered ? 1 : 0)) / widget.questions.length,
          minHeight: 3,
          backgroundColor: SwissTheme.backgroundLightGrey,
          color: SwissTheme.accentBlue,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (q.hasImage) ...[
                  Center(child: _buildQuestionImage(q)),
                  const SizedBox(height: 16),
                ],
                Text(q.questionText, style: _questionStyle),
                const SizedBox(height: 16),
                ...List.generate(q.options.length, (i) => _buildOption(q, i)),
              ],
            ),
          ),
        ),
        if (_hasAnswered) _buildNextButton(),
      ],
    );
  }

  Widget _buildSectionResult() {
    final total = widget.questions.length;
    final score = total == 0 ? 0 : ((_correctCount / total) * 100).round();
    final passed = _passed == true;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              passed ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 56,
              color: passed ? SwissTheme.accentGreen : SwissTheme.accentRed,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? 'THEORY PASSED' : 'THEORY NOT PASSED',
              style: AppFonts.pixelifySans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: SwissTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: $score% ($_correctCount / $total correct)',
              style: AppFonts.pixelifySans(fontSize: 14, color: SwissTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  UiSoundService().playMenuTap();
                  widget.onFinished(passed);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: passed ? SwissTheme.accentBlue : SwissTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
                ),
                child: Text(
                  passed ? 'CONTINUE' : 'RETRY THEORY',
                  style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionImage(McqQuestion q) {
    const w = 200.0;
    const h = 160.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: SwissTheme.backgroundLightGrey,
        border: Border.all(color: SwissTheme.borderBlack),
      ),
      child: ClipRect(
        child: q.imageAssetPath != null
            ? Image.asset(
                q.imageAssetPath!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : (q.imageUrl != null
                ? Image.network(
                    q.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder()),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(Icons.traffic, size: 80, color: SwissTheme.textSecondary.withValues(alpha: 0.5)),
    );
  }

  Widget _buildOption(McqQuestion q, int index) {
    final isSelected = _selectedOptionIndex == index;
    final correctIndex = q.correctIndex;
    Color borderColor = SwissTheme.borderBlack;
    Color bg = SwissTheme.backgroundWhite;

    if (_hasAnswered) {
      if (index == correctIndex) {
        borderColor = SwissTheme.accentGreen;
        bg = SwissTheme.accentGreen.withValues(alpha: 0.12);
      } else if (isSelected) {
        borderColor = SwissTheme.accentRed;
        bg = SwissTheme.accentRed.withValues(alpha: 0.12);
      }
    } else if (isSelected) {
      borderColor = SwissTheme.accentBlue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: _hasAnswered ? null : () => _onOptionSelected(index),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: borderColor, width: 1.5)),
            child: Text(q.options[index], style: _optionStyle),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(
          onPressed: () {
            UiSoundService().playMenuTap();
            _nextQuestion();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: SwissTheme.accentBlue,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
          ),
          child: Text(
            _currentIndex + 1 >= widget.questions.length ? 'SEE RESULT' : 'NEXT',
            style: AppFonts.pixelifySans(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
