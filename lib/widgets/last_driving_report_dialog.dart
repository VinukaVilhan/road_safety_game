import 'dart:io';

import 'package:flutter/material.dart';

import '../models/last_driving_report.dart';
import '../services/ui_sound_service.dart';

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

/// Read-only session report shown from the level card (document-style layout).
void showLastDrivingReportDialog(BuildContext context, LastDrivingReport report) {
  final maxH = MediaQuery.sizeOf(context).height * 0.72;
  final maxW = 420.0;

  showDialog<void>(
    context: context,
    barrierColor: Colors.black45,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            child: _DrivingReportDocument(
              report: report,
              onClose: () {
                UiSoundService().playMenuTap();
                Navigator.of(dialogContext).pop();
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

  const _DrivingReportDocument({
    required this.report,
    required this.onClose,
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
                    padding: const EdgeInsets.fromLTRB(18, 18, 14, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 28,
                          color: _DocTheme.inkMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PRACTICAL SESSION REPORT', style: _DocTheme.title),
                              const SizedBox(height: 6),
                              Text(report.levelName, style: _DocTheme.heading),
                              const SizedBox(height: 4),
                              Text(_whenLocal(), style: _DocTheme.small),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: _DocTheme.rule),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DocRow(
                            label: 'Outcome',
                            value: outcome,
                            valueColor: outcomeColor,
                            valueWeight: FontWeight.w600,
                          ),
                          _DocRow(
                            label: 'Score',
                            value: '${report.score} / 100',
                          ),
                          _DocRow(
                            label: 'Checklist correct',
                            value: '${report.correctMoves} of $total',
                          ),
                          _DocRow(
                            label: 'Time on attempt',
                            value: _formatDurationMs(report.timeSpentMs),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Checklist findings',
                            style: _DocTheme.label.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _DocTheme.ink,
                            ),
                          ),
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
                            const SizedBox(height: 16),
                            Text(
                              'Screenshot at failure',
                              style: _DocTheme.label.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _DocTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220),
                                child: _FailureScreenshotImage(report: report),
                              ),
                            ),
                          ],
                          if (report.failureMessage != null &&
                              report.failureMessage!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Examiner note',
                              style: _DocTheme.label.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _DocTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              report.failureMessage!.trim(),
                              style: _DocTheme.body.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: _DocTheme.rule),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
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
                  ),
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
  final Color? valueColor;
  final FontWeight? valueWeight;

  const _DocRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: _DocTheme.label),
          ),
          Expanded(
            child: Text(
              value,
              style: _DocTheme.body.copyWith(
                color: valueColor ?? _DocTheme.ink,
                fontWeight: valueWeight ?? FontWeight.w500,
              ),
            ),
          ),
        ],
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
