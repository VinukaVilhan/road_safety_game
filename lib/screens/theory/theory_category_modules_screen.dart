import 'package:flutter/material.dart';

import '../../data/repositories/progress_repository.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../models/theory/theory_category_curriculum.dart';
import '../../services/content/theory_curriculum_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import '../driving/level_selection_screen.dart' show HatchingPainter;
import '../road_signs/roadsign_mcq_screen.dart';
import 'theory_intro_screen.dart';

/// Lists intro + MCQ modules for a theory category (best practices, parking, …).
class TheoryCategoryModulesScreen extends StatefulWidget {
  final String categoryId;

  const TheoryCategoryModulesScreen({super.key, required this.categoryId});

  @override
  State<TheoryCategoryModulesScreen> createState() => _TheoryCategoryModulesScreenState();
}

class _TheoryCategoryModulesScreenState extends State<TheoryCategoryModulesScreen> {
  TheoryCategory? _category;
  Object? _loadError;
  Set<String> _passedMcqIds = {};
  Set<String> _viewedIntroIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _refreshProgress();
  }

  Future<void> _load() async {
    try {
      TheoryCurriculumService.instance.clearCache();
      final c = await TheoryCurriculumService.instance.loadCurriculum();
      if (!mounted) return;
      setState(() {
        _category = c.categoryById(widget.categoryId);
        _loadError = _category == null ? 'Category not found: ${widget.categoryId}' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _refreshProgress() async {
    final passed = await ProgressRepository.instance.getCompletedTestIds();
    final viewed = await ProgressRepository.instance.getRoadSignsLearnViewedModuleIds();
    if (!mounted) return;
    setState(() {
      _passedMcqIds = passed;
      _viewedIntroIds = viewed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrowseScreenHeader(
              title: (category?.title ?? 'THEORY').toUpperCase(),
              titleStyle: AppFonts.pixelifySans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: SwissTheme.textPrimary,
              ),
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_theory_modules_${widget.categoryId}',
              launchContext: AssistantLaunchContext(
                screenTitle: '${category?.title ?? 'Theory'} — modules',
                theoryTestName: category?.title,
              ),
            ),
            if (category != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  category.description,
                  style: AppFonts.pixelifySans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SwissTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(child: _buildBody(category)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TheoryCategory? category) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load modules.\n$_loadError',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 13, color: SwissTheme.textSecondary),
          ),
        ),
      );
    }
    if (category == null) {
      return const Center(child: CircularProgressIndicator(color: SwissTheme.textPrimary));
    }
    final modules = category.modulesSorted;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = modules[i];
        final unlocked = TheoryCurriculumService.isModuleUnlocked(m, _passedMcqIds, _viewedIntroIds);
        final isMcq = m.kind == TheoryCategoryModuleKind.mcq;
        final done = isMcq ? _passedMcqIds.contains(m.id) : _viewedIntroIds.contains(m.id);
        return _ModuleTile(
          module: m,
          unlocked: unlocked,
          done: done,
          onTap: () => _onModuleTap(category, m, unlocked),
        );
      },
    );
  }

  Future<void> _onModuleTap(TheoryCategory category, TheoryCategoryModule m, bool unlocked) async {
    UiSoundService().playMenuTap();
    if (!unlocked) {
      _showLockedDialog(m);
      return;
    }
    if (m.kind == TheoryCategoryModuleKind.intro) {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TheoryIntroScreen(category: category, module: m),
        ),
      );
      if (changed == true) await _refreshProgress();
      return;
    }
    final test = m.toTheoryTest(categoryId: category.id);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoadSignMcqScreen(test: test)),
    );
    await _refreshProgress();
  }

  void _showLockedDialog(TheoryCategoryModule m) {
    final reqs = m.unlockRequirementIds;
    var msg = 'Finish the previous step in this track to unlock this module.';
    if (reqs.isNotEmpty) {
      msg = 'Complete required module(s): ${reqs.join(', ')}.';
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(side: BorderSide(color: SwissTheme.borderBlack)),
        title: Text('LOCKED', style: AppFonts.pixelifySans(fontSize: 20, fontWeight: FontWeight.w800)),
        content: Text(msg, style: AppFonts.pixelifySans(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.pop(ctx);
            },
            child: Text('OK', style: TextStyle(color: SwissTheme.accentBlue)),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final TheoryCategoryModule module;
  final bool unlocked;
  final bool done;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.module,
    required this.unlocked,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMcq = module.kind == TheoryCategoryModuleKind.mcq;
    final icon = isMcq ? Icons.quiz_outlined : Icons.menu_book_outlined;
    final kindLabel = isMcq ? '${module.questionCount} questions' : 'Intro';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? SwissTheme.backgroundWhite : SwissTheme.backgroundLightGrey,
          border: Border.all(color: SwissTheme.borderBlack, width: 1),
        ),
        child: Stack(
          children: [
            if (!unlocked)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.45,
                  child: CustomPaint(painter: HatchingPainter()),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: SwissTheme.textPrimary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                module.title.toUpperCase(),
                                style: AppFonts.pixelifySans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: unlocked
                                      ? SwissTheme.textPrimary
                                      : SwissTheme.textSecondary.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            if (!unlocked)
                              const Icon(Icons.lock_outline, size: 22, color: SwissTheme.textPrimary),
                            if (unlocked && done)
                              Icon(Icons.check_circle, size: 22, color: SwissTheme.accentGreen),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          module.description,
                          style: SwissTheme.monospacedText.copyWith(
                            fontSize: 10,
                            color: unlocked
                                ? SwissTheme.textSecondary
                                : SwissTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kindLabel,
                          style: SwissTheme.monospacedText.copyWith(
                            fontSize: 9,
                            color: SwissTheme.textSecondary.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
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
