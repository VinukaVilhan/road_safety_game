import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/repositories/progress_repository.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';

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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (!_finished)
              LinearProgressIndicator(
                value: _answered / _totalRounds,
                minHeight: 3,
                backgroundColor: SwissTheme.backgroundLightGrey,
                color: SwissTheme.accentBlue,
              ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: Padding(
                padding: LandscapeLayout.bodyPadding(context),
                child: LandscapeLayout.bodyMaxWidth(
                  child: _finished ? _buildResults() : _buildPlay(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: LandscapeLayout.headerPadding(context),
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
              widget.module.title.toUpperCase(),
              style: AppFonts.pixelifySans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SwissTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_finished)
            Text(
              'Round ${min(_answered + 1, _totalRounds)} / $_totalRounds',
              style: AppFonts.pixelifySans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SwissTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlay() {
    final phase = _current;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 280;
        final lightSize = compact ? 88.0 : 104.0;

        final prompt = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Which action matches this light?',
              textAlign: TextAlign.center,
              style: AppFonts.pixelifySans(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: SwissTheme.textPrimary,
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            if (phase != null) ...[
              Container(
                width: lightSize,
                height: lightSize,
                decoration: BoxDecoration(
                  color: _phaseColor(phase),
                  shape: BoxShape.circle,
                  border: Border.all(color: SwissTheme.borderBlack, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _phaseColor(phase).withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _phaseLabel(phase),
                style: AppFonts.pixelifySans(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  color: SwissTheme.textPrimary,
                ),
              ),
            ],
            if (_lastWasCorrect != null) ...[
              const SizedBox(height: 8),
              Text(
                _lastWasCorrect! ? 'Correct!' : 'Try again next round.',
                style: AppFonts.pixelifySans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _lastWasCorrect! ? SwissTheme.accentGreen : SwissTheme.textSecondary,
                ),
              ),
            ],
          ],
        );

        final actions = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionButton(
              label: 'STOP',
              accent: const Color(0xFFE53935),
              compact: compact,
              onPressed: () => _answer(0),
            ),
            SizedBox(height: compact ? 8 : 10),
            _ActionButton(
              label: 'SLOW / PREPARE',
              accent: const Color(0xFFFFC107),
              compact: compact,
              onPressed: () => _answer(1),
            ),
            SizedBox(height: compact ? 8 : 10),
            _ActionButton(
              label: 'GO',
              accent: const Color(0xFF43A047),
              compact: compact,
              onPressed: () => _answer(2),
            ),
          ],
        );

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Center(child: prompt),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: actions,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'FINISHED',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: SwissTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You matched $_correct / $_totalRounds lights correctly.',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: SwissTheme.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Red → stop. Amber → slow and prepare to stop. Green → go only when the way is clear.',
            textAlign: TextAlign.center,
            style: SwissTheme.monospacedText.copyWith(
              fontSize: 11,
              color: SwissTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: 220,
              child: TextButton(
                onPressed: _onDone,
                style: TextButton.styleFrom(
                  backgroundColor: SwissTheme.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'DONE',
                  style: AppFonts.pixelifySans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color accent;
  final bool compact;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.accent,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          UiSoundService().playMenuTap();
          onPressed();
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 12,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            border: Border.all(color: accent, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 10 : 12,
                height: compact ? 10 : 12,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.pixelifySans(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    color: SwissTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
