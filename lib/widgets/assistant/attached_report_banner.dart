import 'package:flutter/material.dart';

import '../../models/driving/last_driving_report.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';

/// Minimal “this chat is tied to a saved run” hint (full report stays in the model context).
class AttachedReportBanner extends StatelessWidget {
  const AttachedReportBanner({super.key, required this.report});

  final LastDrivingReport report;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwissTheme.backgroundLightGrey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.description_outlined, size: 20, color: SwissTheme.accentBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ATTACHED RUN',
                    style: AppFonts.pixelifySans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: SwissTheme.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.levelName,
                    style: AppFonts.pixelifySans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SwissTheme.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
