import 'package:flutter/material.dart';

import '../models/last_driving_report.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../services/ui_sound_service.dart';

/// Brief read-only summary of the last finished attempt on a level (from level card).
void showLastDrivingReportDialog(BuildContext context, LastDrivingReport report) {
  final titleStyle = AppFonts.pixelifySans(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: SwissTheme.textPrimary,
  );
  final bodyStyle = AppFonts.pixelifySans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SwissTheme.textPrimary,
  );
  final buttonStyle = AppFonts.pixelifySans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: SwissTheme.accentBlue,
  );

  String formatDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String whenLocal() {
    final l = report.recordedAt.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final mo = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    final h = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  final total = report.correctMoves + report.mistakes;
  final outcome = report.passed ? 'Passed' : 'Failed';
  final maxBodyHeight = MediaQuery.sizeOf(context).height * 0.45;

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: SwissTheme.borderBlack, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LAST RUN', style: titleStyle),
              const SizedBox(height: 24),
              const Divider(color: SwissTheme.dividerBlack, thickness: 1),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.levelName,
                        style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text('Result: $outcome', style: bodyStyle),
                      const SizedBox(height: 8),
                      Text('Score: ${report.score}/100', style: bodyStyle),
                      const SizedBox(height: 8),
                      Text(
                        'Correct moves: ${report.correctMoves} of $total',
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 8),
                      Text('Mistakes (checklist): ${report.mistakes}', style: bodyStyle),
                      const SizedBox(height: 8),
                      Text(
                        'Time in attempt: ${formatDurationMs(report.timeSpentMs)}',
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Recorded: ${whenLocal()}',
                        style: bodyStyle.copyWith(color: SwissTheme.textSecondary),
                      ),
                      if (!report.passed &&
                          report.failureMessage != null &&
                          report.failureMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                        const SizedBox(height: 12),
                        Text(report.failureMessage!, style: bodyStyle),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: SwissTheme.dividerBlack, thickness: 1),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    UiSoundService().playMenuTap();
                    Navigator.of(dialogContext).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: SwissTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('CLOSE', style: buttonStyle),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
