import 'dart:io';

import 'package:flutter/material.dart';

import '../models/assistant/assistant_launch_context.dart';
import '../models/driving/last_driving_report.dart';
import '../screens/assistant/assistant_chat_screen.dart';
import '../services/assistant/instructor_chat_sessions_service.dart';
import '../services/audio/ui_sound_service.dart';
import '../theme/landscape_layout.dart';

/// Paper-like colours and typography for the session report (distinct from game HUD).
class _DocTheme {
  static const Color paper = Color(0xFFFDF8F2);
  static const Color paperEdge = Color(0xFFE8DFD4);
  static const Color marginLine = Color(0xFFB85C5C);
  static const Color ink = Color(0xFF1E1A16);
  static const Color inkMuted = Color(0xFF5C5650);
  static const Color rule = Color(0xFFD4CCC2);

  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w600,
    color: inkMuted,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: ink,
  );

  static const TextStyle small = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: inkMuted,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: inkMuted,
  );
}

String _ambulanceTimeGateLabel(double sec) {
  if (sec <= 0) return 'No per-CP limit';
  return '${sec.toStringAsFixed(0)} s to reach';
}

List<Widget> _ambulanceReportRows(AmbulanceAttemptSnapshot a, {double labelWidth = 118}) {
  String yn(bool v) => v ? 'Yes' : 'No';
  String side(bool? y) {
    if (y == null) return '—';
    return y ? 'Left safe strip' : 'Right safe strip';
  }

  return [
    _DocRow(
      label: 'Elapsed / level timeout',
      value:
          '${a.elapsedSecs.toStringAsFixed(1)} s / ${a.levelTimeoutSecs.toStringAsFixed(0)} s max',
      labelWidth: labelWidth,
    ),
    _DocRow(label: 'CP1 on map', value: yn(a.mapHasCp1), labelWidth: labelWidth),
    if (a.mapHasCp1) ...[
      _DocRow(label: 'CP1 cleared', value: yn(a.cp1Cleared), labelWidth: labelWidth),
      _DocRow(label: 'CP1 time gate', value: _ambulanceTimeGateLabel(a.cp1TimeLimitSecs), labelWidth: labelWidth),
    ],
    _DocRow(label: 'CP2 on map', value: yn(a.mapHasCp2), labelWidth: labelWidth),
    if (a.mapHasCp2) ...[
      _DocRow(label: 'CP2 cleared', value: yn(a.cp2Cleared), labelWidth: labelWidth),
      _DocRow(label: 'CP2 time gate', value: _ambulanceTimeGateLabel(a.cp2TimeLimitSecs), labelWidth: labelWidth),
    ],
    _DocRow(label: 'Final gate (CPF) on map', value: yn(a.mapHasCpf), labelWidth: labelWidth),
    _DocRow(label: 'Pull-over done (P + zone + signal)', value: yn(a.pullOverCompleted), labelWidth: labelWidth),
    _DocRow(label: 'Yield side', value: side(a.yieldLeftSide), labelWidth: labelWidth),
    _DocRow(label: 'Ambulance AI (end)', value: a.ambulanceAiState, labelWidth: labelWidth),
    _DocRow(label: 'Ambulance route finished', value: yn(a.ambulanceRouteCompleted), labelWidth: labelWidth),
  ];
}

bool _hasFailureScreenshot(LastDrivingReport report) {
  final u = report.screenshotUrl?.trim();
  if (u != null && u.isNotEmpty) return true;
  final p = report.screenshotPath?.trim();
  return p != null && p.isNotEmpty;
}

/// Prefers remote screenshot URL; falls back to local file path.
class _FailureScreenshotImage extends StatelessWidget {
  final LastDrivingReport report;

  const _FailureScreenshotImage({required this.report});

  @override
  Widget build(BuildContext context) {
    final url = report.screenshotUrl?.trim();
    final path = report.screenshotPath?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          if (path != null && path.isNotEmpty) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, e, s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Screenshot unavailable.', style: _DocTheme.small),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Screenshot could not be loaded.',
              style: _DocTheme.small,
            ),
          );
        },
      );
    }
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Screenshot file is no longer available.',
              style: _DocTheme.small,
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

bool _hasPenaltyScreenshot(PenaltyRecord record) {
  final u = record.screenshotUrl?.trim();
  if (u != null && u.isNotEmpty) return true;
  final p = record.screenshotPath?.trim();
  return p != null && p.isNotEmpty;
}

/// Prefers remote screenshot URL; falls back to local file path.
class _PenaltyScreenshotImage extends StatelessWidget {
  final PenaltyRecord record;

  const _PenaltyScreenshotImage({required this.record});

  @override
  Widget build(BuildContext context) {
    final url = record.screenshotUrl?.trim();
    final path = record.screenshotPath?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          if (path != null && path.isNotEmpty) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, e, s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Screenshot unavailable.', style: _DocTheme.small),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Screenshot could not be loaded.',
              style: _DocTheme.small,
            ),
          );
        },
      );
    }
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Screenshot file is no longer available.',
              style: _DocTheme.small,
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

/// Full session report when a practical level ends (pass or fail).
Future<void> showDrivingEndReportDialog(
  BuildContext context, {
  required LastDrivingReport report,
  required VoidCallback onBackToLevels,
  VoidCallback? onRetry,
}) {
  final constraints = LandscapeLayout.drivingReportDialogConstraints(context);
  final navigator = Navigator.of(context);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: LandscapeLayout.drivingReportDialogInsetPadding(context),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: constraints,
            child: _DrivingReportDocument(
              report: report,
              onClose: () {
                UiSoundService().playMenuTap();
                Navigator.of(dialogContext).pop();
                onBackToLevels();
              },
              onAskFromAi: () {
                UiSoundService().playMenuTap();
                Navigator.of(dialogContext).pop();
                navigator.push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => AssistantChatScreen(
                      launchContext: AssistantLaunchContext(
                        screenTitle: 'Last run report — ${report.levelName}',
                        lastReport: report,
                        assistantSessionId:
                            InstructorChatSessionsService.sessionIdForReport(report),
                      ),
                    ),
                  ),
                );
              },
              onRetry: onRetry == null
                  ? null
                  : () {
                      UiSoundService().playMenuTap();
                      Navigator.of(dialogContext).pop();
                      onRetry();
                    },
              onBackToLevels: () {
                UiSoundService().playMenuTap();
                Navigator.of(dialogContext).pop();
                onBackToLevels();
              },
            ),
          ),
        ),
      );
    },
  );
}

/// Read-only session report shown from the level card (document-style layout).
void showLastDrivingReportDialog(BuildContext context, LastDrivingReport report) {
  final constraints = LandscapeLayout.drivingReportDialogConstraints(context);
  final navigator = Navigator.of(context);

  showDialog<void>(
    context: context,
    barrierColor: Colors.black45,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: LandscapeLayout.drivingReportDialogInsetPadding(context),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: constraints,
            child: _DrivingReportDocument(
              report: report,
              onClose: () {
                UiSoundService().playMenuTap();
                Navigator.of(dialogContext).pop();
              },
              onAskFromAi: () {
                UiSoundService().playMenuTap();
                Navigator.of(dialogContext).pop();
                navigator.push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => AssistantChatScreen(
                      launchContext: AssistantLaunchContext(
                        screenTitle: 'Last run report — ${report.levelName}',
                        lastReport: report,
                        assistantSessionId: InstructorChatSessionsService.sessionIdForReport(report),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _DrivingReportDocument extends StatelessWidget {
  final LastDrivingReport report;
  final VoidCallback onClose;
  final VoidCallback onAskFromAi;
  final VoidCallback? onRetry;
  final VoidCallback? onBackToLevels;

  const _DrivingReportDocument({
    required this.report,
    required this.onClose,
    required this.onAskFromAi,
    this.onRetry,
    this.onBackToLevels,
  });

  String _formatDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _whenLocal() {
    final l = report.recordedAt.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final mo = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    final h = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d · $h:$mi';
  }

  /// Lines shown inside the expandable block (includes legacy placeholder text).
  List<String> _mistakeLinesForUi() {
    if (report.mistakeDetails.isNotEmpty) return report.mistakeDetails;
    if (report.mistakes > 0) {
      return const [
        'This record was saved before per-item notes were available. '
        'Run the level once more to regenerate a full checklist breakdown.',
      ];
    }
    return const [];
  }

  bool get _isLegacyMistakePlaceholder =>
      report.mistakeDetails.isEmpty && report.mistakes > 0;

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: _DocTheme.label.copyWith(
        fontWeight: FontWeight.w600,
        color: _DocTheme.ink,
      ),
    );
  }

  Widget _buildSummaryColumn(int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Session summary'),
          const SizedBox(height: 8),
          _DocRow(
            label: 'Score',
            value: '${report.score} / 100',
            labelWidth: 132,
          ),
          _DocRow(
            label: 'Checklist correct',
            value: '${report.correctMoves} of $total',
            labelWidth: 132,
          ),
          _DocRow(
            label: 'Time on attempt',
            value: _formatDurationMs(report.timeSpentMs),
            labelWidth: 132,
          ),
          if (report.ambulance != null) ...[
            const SizedBox(height: 12),
            _sectionTitle('Ambulance checkpoints'),
            const SizedBox(height: 8),
            ..._ambulanceReportRows(report.ambulance!, labelWidth: 132),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsColumn(List<String> lines, bool hasExpandableFindings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Checklist findings'),
          const SizedBox(height: 6),
          if (hasExpandableFindings)
            _MistakesExpansion(
              mistakeCount: report.mistakes,
              lines: lines,
              isLegacyPlaceholder: _isLegacyMistakePlaceholder,
            )
          else
            Text(
              'No checklist deductions on file for this attempt.',
              style: _DocTheme.small,
            ),
          if (_hasFailureScreenshot(report)) ...[
            const SizedBox(height: 12),
            _sectionTitle('Screenshot at failure'),
            const SizedBox(height: 6),
            _ReportScreenshotTile(
              caption: null,
              child: _FailureScreenshotImage(report: report),
            ),
          ],
          if (report.penaltyRecords.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle('Penalty screenshots'),
            const SizedBox(height: 8),
            _PenaltyScreenshotStrip(records: report.penaltyRecords),
          ],
          if (report.failureMessage != null &&
              report.failureMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionTitle('Examiner note'),
            const SizedBox(height: 6),
            Text(
              report.failureMessage!.trim(),
              style: _DocTheme.body.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onAskFromAi,
            style: TextButton.styleFrom(
              foregroundColor: _DocTheme.ink,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: Icon(Icons.smart_toy_outlined, size: 20, color: _DocTheme.marginLine),
            label: Text(
              'Ask from AI',
              style: _DocTheme.body.copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _DocTheme.inkMuted,
              ),
            ),
          ),
          const Spacer(),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: _DocTheme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                'Retry',
                style: _DocTheme.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          if (onBackToLevels != null)
            TextButton(
              onPressed: onBackToLevels,
              style: TextButton.styleFrom(
                foregroundColor: _DocTheme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Back to Levels',
                style: _DocTheme.body.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _DocTheme.inkMuted,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(
                foregroundColor: _DocTheme.ink,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Close',
                style: _DocTheme.body.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _DocTheme.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = report.correctMoves + report.mistakes;
    final outcome = report.passed ? 'Passed' : 'Did not pass';
    final outcomeColor = report.passed ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    final lines = _mistakeLinesForUi();
    final hasExpandableFindings = lines.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _DocTheme.paper,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _DocTheme.paperEdge, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: _DocTheme.marginLine),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 26,
                          color: _DocTheme.inkMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PRACTICAL SESSION REPORT', style: _DocTheme.title),
                              const SizedBox(height: 4),
                              Text(
                                report.levelName,
                                style: _DocTheme.heading.copyWith(fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: outcomeColor, width: 1.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                outcome.toUpperCase(),
                                style: _DocTheme.small.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: outcomeColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_whenLocal(), style: _DocTheme.small),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: _DocTheme.rule),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildSummaryColumn(total),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: _DocTheme.rule),
                        Expanded(
                          flex: 3,
                          child: _buildDetailsColumn(lines, hasExpandableFindings),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: _DocTheme.rule),
                  _buildActionBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const _DocRow({
    required this.label,
    required this.value,
    this.labelWidth = 118,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: _DocTheme.label),
          ),
          Expanded(
            child: Text(
              value,
              style: _DocTheme.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportScreenshotTile extends StatelessWidget {
  final String? caption;
  final Widget child;

  const _ReportScreenshotTile({
    required this.child,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null && caption!.isNotEmpty) ...[
          Text(caption!, style: _DocTheme.small, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _PenaltyScreenshotStrip extends StatelessWidget {
  final List<PenaltyRecord> records;

  const _PenaltyScreenshotStrip({required this.records});

  @override
  Widget build(BuildContext context) {
    final withImages = records.where(_hasPenaltyScreenshot).toList();
    if (withImages.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rec in records) ...[
            Text(rec.description, style: _DocTheme.body),
            const SizedBox(height: 4),
            Text('No image on file for this penalty.', style: _DocTheme.small),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final rec = records[index];
          return SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.description,
                  style: _DocTheme.small,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _hasPenaltyScreenshot(rec)
                        ? _PenaltyScreenshotImage(record: rec)
                        : ColoredBox(
                            color: const Color(0xFFF5EFE8),
                            child: Center(
                              child: Text(
                                'No image',
                                style: _DocTheme.small,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MistakesExpansion extends StatefulWidget {
  final int mistakeCount;
  final List<String> lines;
  final bool isLegacyPlaceholder;

  const _MistakesExpansion({
    required this.mistakeCount,
    required this.lines,
    required this.isLegacyPlaceholder,
  });

  @override
  State<_MistakesExpansion> createState() => _MistakesExpansionState();
}

class _MistakesExpansionState extends State<_MistakesExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.isLegacyPlaceholder
        ? 'Summary notes (legacy record)'
        : '${widget.mistakeCount} checklist issue${widget.mistakeCount == 1 ? '' : 's'}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _DocTheme.rule),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (open) => setState(() => _expanded = open),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 22,
                color: _DocTheme.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  summary,
                  style: _DocTheme.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _expanded ? 'Hide detail' : 'Show detail',
                style: _DocTheme.small.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: _DocTheme.inkMuted,
                ),
              ),
            ],
          ),
          children: [
            for (var i = 0; i < widget.lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: _DocTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _DocTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.lines[i],
                      style: _DocTheme.body.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
