import 'package:flutter/material.dart';

import '../../services/audio/ui_sound_service.dart';
import '../../services/progress/last_driving_report_service.dart';
import '../../theme/swiss_theme.dart';
import '../../widgets/last_driving_report_dialog.dart';

/// Document icon for a practical level card when a last-run report exists.
class DrivingLevelReportIconButton extends StatelessWidget {
  final String levelId;
  final bool passed;
  final double iconSize;

  const DrivingLevelReportIconButton({
    super.key,
    required this.levelId,
    required this.passed,
    this.iconSize = 18,
  });

  Color get _accent => passed ? SwissTheme.accentGreen : SwissTheme.accentOrange;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: passed ? 'Last run — passed' : 'Last run — did not pass',
      child: Material(
        color: SwissTheme.backgroundWhite,
        shape: CircleBorder(
          side: BorderSide(color: _accent, width: 1.5),
        ),
        elevation: 1,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            UiSoundService().playMenuTap();
            final report =
                await LastDrivingReportService.instance.loadReportForLevel(levelId);
            if (!context.mounted || report == null) return;
            showLastDrivingReportDialog(context, report);
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.description_outlined,
              size: iconSize,
              color: _accent,
            ),
          ),
        ),
      ),
    );
  }
}
