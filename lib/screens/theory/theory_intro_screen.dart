import 'package:flutter/material.dart';

import '../../data/repositories/progress_repository.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../models/theory/theory_category_curriculum.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/landscape_layout.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';

/// Theory category intro — carousel (per-scenario image + text) or single reference sheet.
class TheoryIntroScreen extends StatelessWidget {
  final TheoryCategory category;
  final TheoryCategoryModule module;

  const TheoryIntroScreen({
    super.key,
    required this.category,
    required this.module,
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
                category.title.toUpperCase(),
                style: AppFonts.pixelifySans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: SwissTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onBack: () {
                UiSoundService().playMenuTap();
                Navigator.pop(context);
              },
              heroTag: 'assistant_theory_intro_${module.id}',
              launchContext: AssistantLaunchContext(
                screenTitle: '${category.title} — intro',
                theoryTestName: module.title,
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: ColoredBox(
                color: SwissTheme.backgroundLightGrey,
                child: LandscapeLayout.bodyMaxWidth(
                  child: Padding(
                    padding: LandscapeLayout.bodyPadding(context),
                    child: category.hasIntroCarousel
                        ? _IntroCarousel(
                            category: category,
                            module: module,
                            onComplete: () => _markViewedAndLeave(context, module.id),
                          )
                        : _ReferenceSheet(category: category, module: module),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _markViewedAndLeave(BuildContext context, String moduleId) async {
    await ProgressRepository.instance.markRoadSignsLearnModuleViewed(moduleId);
    if (context.mounted) Navigator.pop(context, true);
  }
}

class _IntroCarousel extends StatefulWidget {
  final TheoryCategory category;
  final TheoryCategoryModule module;
  final VoidCallback onComplete;

  const _IntroCarousel({
    required this.category,
    required this.module,
    required this.onComplete,
  });

  @override
  State<_IntroCarousel> createState() => _IntroCarouselState();
}

class _IntroCarouselState extends State<_IntroCarousel> {
  late final PageController _pageController;
  int _pageIndex = 0;

  List<TheoryIntroSlide> get _slides => widget.category.introSlides;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _pageIndex >= _slides.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category.introHeading,
                        style: AppFonts.pixelifySans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SwissTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.category.introLead,
                        style: AppFonts.pixelifySans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SwissTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _pageIndex = i),
                    itemBuilder: (context, i) => _SlidePage(slide: _slides[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: i == _pageIndex ? 10 : 7,
                          height: i == _pageIndex ? 10 : 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _pageIndex
                                ? SwissTheme.textPrimary
                                : SwissTheme.textSecondary.withValues(alpha: 0.35),
                            border: Border.all(
                              color: SwissTheme.borderBlack.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_pageIndex > 0)
              Expanded(
                child: _FooterButton(
                  label: 'BACK',
                  filled: false,
                  onPressed: () {
                    UiSoundService().playMenuTap();
                    _goToPage(_pageIndex - 1);
                  },
                ),
              ),
            if (_pageIndex > 0) const SizedBox(width: 10),
            Expanded(
              child: _FooterButton(
                label: isLast ? 'DONE' : 'NEXT',
                filled: true,
                onPressed: () {
                  UiSoundService().playMenuTap();
                  if (isLast) {
                    widget.onComplete();
                  } else {
                    _goToPage(_pageIndex + 1);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SlidePage extends StatelessWidget {
  final TheoryIntroSlide slide;

  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: _IntroFigure(imageAsset: slide.imageAsset),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    style: AppFonts.pixelifySans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SwissTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slide.body,
                    style: AppFonts.pixelifySans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SwissTheme.textPrimary,
                      height: 1.45,
                    ),
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

class _FooterButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onPressed;

  const _FooterButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: filled ? SwissTheme.textPrimary : SwissTheme.backgroundWhite,
        foregroundColor: filled ? Colors.white : SwissTheme.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: SwissTheme.borderBlack, width: 1),
        ),
      ),
      child: Text(
        label,
        style: AppFonts.pixelifySans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : SwissTheme.textPrimary,
        ),
      ),
    );
  }
}

class _ReferenceSheet extends StatelessWidget {
  final TheoryCategory category;
  final TheoryCategoryModule module;

  const _ReferenceSheet({required this.category, required this.module});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: SwissTheme.backgroundWhite,
              border: Border.all(color: SwissTheme.borderBlack, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  child: _IntroFigure(imageAsset: category.introImageAsset),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          category.introHeading,
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
                          category.introLead,
                          style: AppFonts.pixelifySans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: SwissTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Key points',
                          style: AppFonts.pixelifySans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: SwissTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < category.bullets.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _Bullet(
                            title: category.bullets[i].title,
                            body: category.bullets[i].body,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FooterButton(
          label: 'DONE',
          filled: true,
          onPressed: () => TheoryIntroScreen._markViewedAndLeave(context, module.id),
        ),
      ],
    );
  }
}

class _IntroFigure extends StatelessWidget {
  final String imageAsset;

  const _IntroFigure({required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: SwissTheme.backgroundLightGrey,
        border: Border.all(color: SwissTheme.borderBlack.withValues(alpha: 0.35)),
      ),
      child: imageAsset.isNotEmpty
          ? Image.asset(
              imageAsset,
              height: 180,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _Placeholder(imageAsset: imageAsset),
            )
          : const _Placeholder(imageAsset: ''),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String imageAsset;

  const _Placeholder({required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.image_outlined, size: 48, color: SwissTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            imageAsset.isEmpty ? 'Intro image pending' : 'Add image:\n$imageAsset',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 11, color: SwissTheme.textSecondary, height: 1.35),
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
