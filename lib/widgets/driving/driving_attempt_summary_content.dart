import 'package:flutter/material.dart';

import '../../game/driving_game.dart';
import '../../models/driving/game_level.dart';
import '../../models/driving/last_driving_report.dart';

/// Result dialog body for a completed practical driving attempt.
class DrivingAttemptSummaryContent extends StatelessWidget {
  const DrivingAttemptSummaryContent({
    super.key,
    required this.summary,
    required this.level,
  });

  final DrivingAttemptSummary summary;
  final GameLevel level;

  @override
  Widget build(BuildContext context) {
    final signalName = _signalLabel(summary.expectedTurnSignal);
    final midTurnLabel = level.isMarkingsDashedLevel
        ? 'Kept $signalName on throughout the purple turn zone.'
        : 'Kept $signalName while turning.';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!summary.passed && summary.failureMessage != null) ...[
            Text(
              summary.failureMessage!,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
          ],
          if (summary.penalties.isNotEmpty) ...[
            Text(
              'Penalties (${summary.penalties.length})',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...summary.penalties.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $p',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Screenshots for each penalty are saved in your driving report.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
          if (level.isRoadCrossingLevel) ...[
            _CheckRow(
              label: 'Entered speed limit zone.',
              ok: summary.enteredApproachZone,
            ),
            const SizedBox(height: 6),
            _CheckRow(
              label:
                  'Stopped in gear and completed zebra crossing wait in the grey zig-zag zone.',
              ok: summary.waitedAtRoadCrossing,
            ),
            const SizedBox(height: 6),
            _CheckRow(
              label: 'Reached finish zone.',
              ok: summary.reachedFinishZone,
            ),
          ] else if (level.isMarkingsDashedLevel) ...[
            _CheckRow(
              label: 'Right turn signal used in approach zone.',
              ok: summary.signaledCorrectlyInApproachZone,
            ),
            const SizedBox(height: 6),
            _CheckRow(
              label: 'Entered turn execution zone.',
              ok: summary.enteredMidTurnZone,
            ),
            const SizedBox(height: 6),
            _CheckRow(label: midTurnLabel, ok: summary.hadCorrectSignalInMidTurnZone),
            const SizedBox(height: 6),
            _CheckRow(
              label: 'Reached finish zone.',
              ok: summary.reachedFinishZone,
            ),
          ] else if (level.scenarioId == 'emergency_weather') ...[
            if (summary.weather != null)
              _WeatherSummarySection(w: summary.weather!),
            _CheckRow(
              label: 'Reached finish zone.',
              ok: summary.reachedFinishZone,
            ),
          ] else if (level.scenarioId == 'emergency_ambulance') ...[
            if (summary.ambulance != null) _AmbulanceSummarySection(a: summary.ambulance!),
            _CheckRow(
              label:
                  'Ambulance reached the finish area while you stayed correctly yielded.',
              ok: summary.reachedFinishZone && summary.passed,
            ),
          ] else ...[
            _CheckRow(
              label: 'Entered approach zone.',
              ok: summary.enteredApproachZone,
            ),
            const SizedBox(height: 6),
            _CheckRow(
              label: 'Used $signalName in approach zone.',
              ok: summary.signaledCorrectlyInApproachZone,
            ),
            const SizedBox(height: 6),
            _CheckRow(
              label: 'Entered turn execution zone.',
              ok: summary.enteredMidTurnZone,
            ),
            const SizedBox(height: 6),
            _CheckRow(label: midTurnLabel, ok: summary.hadCorrectSignalInMidTurnZone),
            const SizedBox(height: 6),
            _CheckRow(
              label: 'Reached finish zone.',
              ok: summary.reachedFinishZone,
            ),
          ],
          const SizedBox(height: 6),
          _CheckRow(
            label: 'Minor obstacle bumps (non-crash): ${summary.nonCrashBumpCount}',
            ok: summary.nonCrashBumpCount == 0,
          ),
          const SizedBox(height: 12),
          Text(
            'Time spent: ${_formatDuration(summary.timeSpent)}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Score: ${summary.score}/100',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _signalLabel(String expected) {
    switch (expected) {
      case 'left':
        return 'Left signal';
      case 'right':
        return 'Right signal';
      default:
        return 'Turn signal';
    }
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.greenAccent : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _WeatherSummarySection extends StatelessWidget {
  const _WeatherSummarySection({required this.w});

  final WeatherAttemptSnapshot w;

  @override
  Widget build(BuildContext context) {
    final limit = w.speedLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckRow(
          label: 'Entered check zone (lights & wipers prompt).',
          ok: w.enteredCheckZone,
        ),
        const SizedBox(height: 6),
        _CheckRow(
          label: 'Headlights and wipers confirmed at check zone.',
          ok: w.checkRequirementsMet,
        ),
        const SizedBox(height: 6),
        _CheckRow(
          label: 'Entered wet-road speed section.',
          ok: w.enteredSpeedZone,
        ),
        if (limit != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              'Speed limit in section: $limit (HUD units)',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 6),
        _CheckRow(
          label: 'Stayed within speed limit after check zone.',
          ok: !w.exceededSpeedInZone,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AmbulanceSummarySection extends StatelessWidget {
  const _AmbulanceSummarySection({required this.a});

  final AmbulanceAttemptSnapshot a;

  @override
  Widget build(BuildContext context) {
    String yn(bool v) => v ? 'Yes' : 'No';
    String side(bool? y) {
      if (y == null) return '—';
      return y ? 'Left safe strip' : 'Right safe strip';
    }

    String cpGate(double sec) {
      if (sec <= 0) return 'no per-CP limit';
      return '${sec.toStringAsFixed(0)} s to reach';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Level timer: ${a.elapsedSecs.toStringAsFixed(1)} s of '
          '${a.levelTimeoutSecs.toStringAsFixed(0)} s max (whole level timeout).',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (a.mapHasCp1) ...[
          _CheckRow(label: 'Reached Checkpoint 1 in time.', ok: a.cp1Cleared),
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Text(
              'CP1 time gate: ${cpGate(a.cp1TimeLimitSecs)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
        if (a.mapHasCp2) ...[
          _CheckRow(label: 'Reached Checkpoint 2 in time.', ok: a.cp2Cleared),
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Text(
              'CP2 time gate: ${cpGate(a.cp2TimeLimitSecs)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            a.mapHasCpf
                ? 'Map has a final gate (CPF): complete pull-over before crossing it.'
                : 'No CPF final gate on this map layout.',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        _CheckRow(
          label: 'Safe pull-over completed (Park + matching zone + correct signal).',
          ok: a.pullOverCompleted,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 4),
          child: Text(
            'Yield side: ${side(a.yieldLeftSide)}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        Text(
          'Ambulance AI at end: ${a.ambulanceAiState} · route completed: ${yn(a.ambulanceRouteCompleted)}',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
