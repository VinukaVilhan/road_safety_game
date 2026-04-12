import 'package:flutter/material.dart';

import '../data/repositories/progress_repository.dart';
import '../models/assistant_launch_context.dart';
import '../models/road_signs_curriculum.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/assistant_button.dart';

/// Introduction to the three-color traffic signal (uses [signal_light.png] art).
class TrafficColorLightsIntroScreen extends StatelessWidget {
  final RoadSignsModule module;
  final String breadcrumb;

  const TrafficColorLightsIntroScreen({
    super.key,
    required this.module,
    required this.breadcrumb,
  });

  static const _imageAsset = 'assets/images/signal_light.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        mini: true,
        heroTag: 'assistant_traffic_color_intro_${module.id}',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Traffic lights — intro',
          theoryTestName: module.title,
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
                  ),
                ],
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      module.description,
                      style: SwissTheme.monospacedText.copyWith(
                        fontSize: 12,
                        color: SwissTheme.textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Image.asset(
                      _imageAsset,
                      height: 200,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Image not found: $_imageAsset',
                          textAlign: TextAlign.center,
                          style: AppFonts.pixelifySans(fontSize: 13, color: SwissTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'WHAT EACH COLOR MEANS',
                        style: AppFonts.pixelifySans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: SwissTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Bullet(
                      title: 'Red (top)',
                      body:
                          'Stop before the stop line or crosswalk and wait. Stay stopped until the signal changes (unless an authorised person directs you otherwise).',
                    ),
                    const SizedBox(height: 14),
                    _Bullet(
                      title: 'Amber / yellow (middle)',
                      body:
                          'The light is about to turn red. Slow down and be ready to stop. If you have already crossed the stop line or stopping sharply would be unsafe, clear the junction with care.',
                    ),
                    const SizedBox(height: 14),
                    _Bullet(
                      title: 'Green (bottom)',
                      body:
                          'You may go when it is safe: check the way ahead, watch for pedestrians and other traffic, and follow any arrows or signs that still apply.',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'When you have read this, tap Done to unlock the MCQ for this track.',
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
          title.toUpperCase(),
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
