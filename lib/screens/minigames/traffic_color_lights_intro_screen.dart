import 'package:flutter/material.dart';

import '../../data/repositories/progress_repository.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';

/// Document-style introduction to the three-color traffic signal ([signal_light.png]).
class TrafficColorLightsIntroScreen extends StatelessWidget {
  final RoadSignsModule module;
  final String breadcrumb;

  const TrafficColorLightsIntroScreen({
    super.key,
    required this.module,
    required this.breadcrumb,
  });

  static const _imageAsset = 'assets/images/signal_light.png';

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
              child: ColoredBox(
                color: SwissTheme.backgroundLightGrey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Container(
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
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
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
                      const SizedBox(height: 14),
                      Text(
                        module.description,
                        style: AppFonts.pixelifySans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SwissTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _docLead,
                        style: AppFonts.pixelifySans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: SwissTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: SwissTheme.backgroundLightGrey,
                            border: Border.all(color: SwissTheme.borderBlack.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                _imageAsset,
                                height: 220,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Image not found: $_imageAsset',
                                    textAlign: TextAlign.center,
                                    style: AppFonts.pixelifySans(fontSize: 12, color: SwissTheme.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
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
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Colour meanings',
                        style: AppFonts.pixelifySans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: SwissTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Bullet(
                        title: 'Red (top)',
                        body:
                            'Stop before the stop line or crossing and wait until the phase changes, unless someone authorised directs you otherwise.',
                      ),
                      const SizedBox(height: 12),
                      _Bullet(
                        title: 'Amber (middle)',
                        body:
                            'Prepare to stop — red is next. If you are already past the stop line or stopping would be unsafe, clear the junction carefully.',
                      ),
                      const SizedBox(height: 12),
                      _Bullet(
                        title: 'Green (bottom)',
                        body:
                            'You may proceed only when the way ahead is safe; still watch for pedestrians, other vehicles, and any arrows or signs.',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'When you have read this sheet, tap Done below to unlock the MCQ for this track.',
                        style: AppFonts.pixelifySans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SwissTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
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
