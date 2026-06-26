import 'package:flutter/material.dart';
import '../../data/repositories/progress_repository.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';

/// Placeholder “study” flow: short guidance; marks curriculum module viewed on Done.
class RoadSignsLearnScreen extends StatelessWidget {
  final RoadSignsModule module;
  final String breadcrumb;

  const RoadSignsLearnScreen({
    super.key,
    required this.module,
    required this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrowseScreenHeader(
              titleWidget: Text(
                breadcrumb.toUpperCase(),
                style: AppFonts.pixelifySans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: SwissTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_road_signs_learn_${module.id}',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Road signs — study',
                theoryTestName: module.title,
                includeFullRoadSignCatalog: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                module.title.toUpperCase(),
                style: AppFonts.pixelifySans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SwissTheme.textPrimary,
                ),
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.description,
                      style: AppFonts.pixelifySans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: SwissTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'When you are ready, tap Done below. That unlocks the next module in this track (for example the MCQ test) if the curriculum lists one.',
                      style: SwissTheme.monospacedText.copyWith(
                        fontSize: 12,
                        color: SwissTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: SwissTheme.borderBlack, width: 1)),
              ),
              child: TextButton(
                onPressed: () async {
                  UiSoundService().playMenuTap();
                  await ProgressRepository.instance.markRoadSignsLearnModuleViewed(module.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
                style: TextButton.styleFrom(
                  backgroundColor: SwissTheme.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'DONE',
                  style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
