import 'package:flutter/material.dart';

import '../../constants/media_assets.dart';
import '../../data/repositories/progress_repository.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';

/// Document-style introduction to the three-color traffic signal ([signal_light.png]).
class TrafficColorLightsIntroScreen extends StatelessWidget {
  final RoadSignsModule module;
  final String breadcrumb;

  const TrafficColorLightsIntroScreen({
    super.key,
    required this.module,
    required this.breadcrumb,
  });

  static const _imageAsset = MediaAssets.signalLight;

  static const _docLead =
      'Traffic lights are signals at junctions and crossings. They use a simple color code so everyone knows when to stop, when to prepare, and when it may be safe to move if the way is clear.';

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
              heroTag: 'assistant_traffic_color_lights_intro',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Traffic and signals — intro',
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
              child: ColoredBox(
                color: SwissTheme.backgroundLightGrey,
                child: LandscapeLayout.bodyMaxWidth(
                  child: Padding(
                    padding: LandscapeLayout.bodyPadding(context),
                    child: _ReferenceSheet(module: module),
                  ),
                ),
              ),
            ),
            Container(
              padding: LandscapeLayout.bodyPadding(context).copyWith(top: 12, bottom: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: SwissTheme.borderBlack, width: 1)),
              ),
              child: LandscapeLayout.bodyMaxWidth(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'When you have read this sheet, tap Done to unlock the MCQ for this track.',
                        style: AppFonts.pixelifySans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SwissTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 180,
                      child: TextButton(
                        onPressed: () async {
                          UiSoundService().playMenuTap();
                          await ProgressRepository.instance.markRoadSignsLearnModuleViewed(module.id);
                          if (context.mounted) Navigator.pop(context, true);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: SwissTheme.textPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceSheet extends StatelessWidget {
  final RoadSignsModule module;

  const _ReferenceSheet({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SwissTheme.backgroundWhite,
        border: Border.all(color: SwissTheme.borderBlack, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: _SignalFigure(),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'REFERENCE',
                    style: AppFonts.pixelifySans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: SwissTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Traffic lights',
                    style: AppFonts.pixelifySans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SwissTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    module.description,
                    style: AppFonts.pixelifySans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: SwissTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    TrafficColorLightsIntroScreen._docLead,
                    style: AppFonts.pixelifySans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SwissTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Colour meanings',
                    style: AppFonts.pixelifySans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SwissTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _Bullet(
                    title: 'Red (top)',
                    body:
                        'Stop before the stop line or crossing and wait until the phase changes, unless someone authorised directs you otherwise.',
                  ),
                  const SizedBox(height: 10),
                  const _Bullet(
                    title: 'Amber (middle)',
                    body:
                        'Prepare to stop — red is next. If you are already past the stop line or stopping would be unsafe, clear the junction carefully.',
                  ),
                  const SizedBox(height: 10),
                  const _Bullet(
                    title: 'Green (bottom)',
                    body:
                        'You may proceed only when the way ahead is safe; still watch for pedestrians, other vehicles, and any arrows or signs.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalFigure extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: SwissTheme.backgroundLightGrey,
        border: Border.all(color: SwissTheme.borderBlack.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Image.asset(
            TrafficColorLightsIntroScreen._imageAsset,
            height: 180,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Image not found: ${TrafficColorLightsIntroScreen._imageAsset}',
                textAlign: TextAlign.center,
                style: AppFonts.pixelifySans(fontSize: 12, color: SwissTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fig. 1 — Standard vertical signal (red, amber, green)',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SwissTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String title;
  final String body;

  const _Bullet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.pixelifySans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SwissTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: AppFonts.pixelifySans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: SwissTheme.textPrimary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
