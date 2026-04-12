import 'dart:math';

import 'package:flutter/material.dart';

import '../data/repositories/progress_repository.dart';
import '../models/assistant_launch_context.dart';
import '../models/road_signs_curriculum.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/assistant_button.dart';

enum _LightPhase { red, amber, green }

/// Quick reaction game: match the lit color to Stop / Slow / Go.
class TrafficColorLightsMinigameScreen extends StatefulWidget {
  final RoadSignsModule module;
  final String breadcrumb;

  const TrafficColorLightsMinigameScreen({
    super.key,
    required this.module,
    required this.breadcrumb,
  });

  @override
  State<TrafficColorLightsMinigameScreen> createState() => _TrafficColorLightsMinigameScreenState();
}

class _TrafficColorLightsMinigameScreenState extends State<TrafficColorLightsMinigameScreen> {
  static const _totalRounds = 6;
  final _random = Random();

  int _answered = 0;
  int _correct = 0;
  _LightPhase? _current;
  bool? _lastWasCorrect;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _rollPhase();
  }

  void _rollPhase() {
    final phases = _LightPhase.values;
    _current = phases[_random.nextInt(phases.length)];
  }

  void _advanceOrFinish() {
    if (_answered >= _totalRounds) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _rollPhase();
      _lastWasCorrect = null;
    });
  }

  void _answer(int choice) {
    if (_finished || _current == null) return;
    final ok = switch (_current!) {
      _LightPhase.red => choice == 0,
      _LightPhase.amber => choice == 1,
      _LightPhase.green => choice == 2,
    };
    setState(() {
      _lastWasCorrect = ok;
      if (ok) _correct++;
      _answered++;
    });
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _advanceOrFinish();
    });
  }

  Color _phaseColor(_LightPhase p) => switch (p) {
        _LightPhase.red => const Color(0xFFE53935),
        _LightPhase.amber => const Color(0xFFFFC107),
        _LightPhase.green => const Color(0xFF43A047),
      };

  String _phaseLabel(_LightPhase p) => switch (p) {
        _LightPhase.red => 'RED',
        _LightPhase.amber => 'AMBER',
        _LightPhase.green => 'GREEN',
      };

  Future<void> _onDone() async {
    UiSoundService().playMenuTap();
    await ProgressRepository.instance.markRoadSignsLearnModuleViewed(widget.module.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        mini: true,
        heroTag: 'assistant_traffic_color_minigame_${widget.module.id}',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Traffic lights — mini game',
          theoryTestName: widget.module.title,
          includeFullRoadSignCatalog: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      UiSoundService().playMenuTap();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_sharp, color: SwissTheme.textPrimary, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.breadcrumb.toUpperCase(),
                      style: AppFonts.pixelifySans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: SwissTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                widget.module.title.toUpperCase(),
                style: AppFonts.pixelifySans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SwissTheme.textPrimary,
                ),
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: _finished ? _buildResults() : _buildPlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlay() {
    final phase = _current;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Round ${min(_answered + 1, _totalRounds)} / $_totalRounds',
            style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w700, color: SwissTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Which action matches this light?',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 16, fontWeight: FontWeight.w600, color: SwissTheme.textPrimary),
          ),
          const SizedBox(height: 28),
          if (phase != null) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _phaseColor(phase),
                shape: BoxShape.circle,
                border: Border.all(color: SwissTheme.borderBlack, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _phaseColor(phase).withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _phaseLabel(phase),
              style: AppFonts.pixelifySans(fontSize: 20, fontWeight: FontWeight.w900, color: SwissTheme.textPrimary),
            ),
          ],
          if (_lastWasCorrect != null) ...[
            const SizedBox(height: 16),
            Text(
              _lastWasCorrect! ? 'Correct!' : 'Not quite — review the intro if needed.',
              style: AppFonts.pixelifySans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _lastWasCorrect! ? SwissTheme.accentGreen : SwissTheme.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          _ActionButton(label: 'STOP', onPressed: () => _answer(0)),
          const SizedBox(height: 10),
          _ActionButton(label: 'SLOW / PREPARE', subtitle: 'Amber: slow down, ready to stop', onPressed: () => _answer(1)),
          const SizedBox(height: 10),
          _ActionButton(label: 'GO', subtitle: 'Green: only when safe', onPressed: () => _answer(2)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'FINISHED',
            style: AppFonts.pixelifySans(fontSize: 26, fontWeight: FontWeight.w900, color: SwissTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            'You matched $_correct / $_totalRounds lights correctly.',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 15, fontWeight: FontWeight.w500, color: SwissTheme.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Red → stop. Amber → slow and prepare to stop. Green → go only when the way is clear.',
            textAlign: TextAlign.center,
            style: SwissTheme.monospacedText.copyWith(fontSize: 11, color: SwissTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _onDone,
            style: TextButton.styleFrom(
              backgroundColor: SwissTheme.textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(
              'DONE',
              style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          UiSoundService().playMenuTap();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: SwissTheme.textPrimary,
          side: const BorderSide(color: SwissTheme.borderBlack, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Column(
          children: [
            Text(label, style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: SwissTheme.monospacedText.copyWith(fontSize: 9, color: SwissTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
