import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/driving/level_briefing.dart';
import '../../services/audio/ui_sound_service.dart';

/// Paginated pre-level tips — swipe or use Back / Next / Start Level.
class LevelBriefingDialog extends StatefulWidget {
  final LevelBriefing briefing;

  const LevelBriefingDialog({
    super.key,
    required this.briefing,
  });

  @override
  State<LevelBriefingDialog> createState() => _LevelBriefingDialogState();
}

class _LevelBriefingDialogState extends State<LevelBriefingDialog> {
  late final PageController _pageController;
  int _pageIndex = 0;

  List<LevelBriefingSlide> get _slides => widget.briefing.slides;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width * 0.62;
    final boxW = math.min(440.0, w);
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.briefing.headline,
              style: theme.titleLarge!.copyWith(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white60,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Skip',
              style: theme.labelLarge!.copyWith(color: Colors.white60),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: boxW,
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: theme.titleSmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.body,
                          style: theme.bodyMedium!.copyWith(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _pageIndex ? Colors.white : Colors.white30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_pageIndex > 0)
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              _pageController.previousPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            },
            child: Text(
              'Back',
              style: theme.labelLarge!.copyWith(color: Colors.white70),
            ),
          ),
        TextButton(
          onPressed: () {
            UiSoundService().playMenuTap();
            if (_pageIndex < _slides.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            _pageIndex < _slides.length - 1 ? 'Next' : 'Start Level',
            style: theme.labelLarge!.copyWith(color: Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}
