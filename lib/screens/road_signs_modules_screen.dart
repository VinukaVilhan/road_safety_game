import 'package:flutter/material.dart';

import '../data/repositories/progress_repository.dart';
import '../models/assistant_launch_context.dart';
import '../models/road_signs_curriculum.dart';
import '../services/road_signs_curriculum_service.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/assistant_button.dart';
import 'road_signs_learn_screen.dart';
import 'roadsign_mcq_screen.dart';
import 'theory_test_selection_screen.dart';

/// Lists curriculum modules (study, MCQ, …) for a warning group or a control subgroup.
class RoadSignsModulesScreen extends StatefulWidget {
  final RoadSignsGroup group;
  final RoadSignsSubgroup? subgroup;

  const RoadSignsModulesScreen({
    super.key,
    required this.group,
    this.subgroup,
  });

  @override
  State<RoadSignsModulesScreen> createState() => _RoadSignsModulesScreenState();
}

class _RoadSignsModulesScreenState extends State<RoadSignsModulesScreen> {
  Set<String> _passedMcqIds = {};
  Set<String> _viewedLearnIds = {};

  @override
  void initState() {
    super.initState();
    _refreshProgress();
  }

  Future<void> _refreshProgress() async {
    final passed = await ProgressRepository.instance.getCompletedTestIds();
    final viewed = await ProgressRepository.instance.getRoadSignsLearnViewedModuleIds();
    if (!mounted) return;
    setState(() {
      _passedMcqIds = passed;
      _viewedLearnIds = viewed;
    });
  }

  List<RoadSignsModule> get _modules {
    final raw = widget.subgroup != null ? widget.subgroup!.modules : widget.group.modules;
    return List<RoadSignsModule>.from(raw)..sort((a, b) => a.order.compareTo(b.order));
  }

  String get _breadcrumb {
    if (widget.subgroup != null) {
      return '${widget.group.title} › ${widget.subgroup!.title}';
    }
    return widget.group.title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        heroTag: 'assistant_road_signs_modules_${widget.group.id}_${widget.subgroup?.id ?? 'root'}',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Road signs — modules',
          includeFullRoadSignCatalog: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 24, 8),
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
                      _breadcrumb.toUpperCase(),
                      style: AppFonts.pixelifySans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: SwissTheme.textSecondary,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'MODULES',
                style: AppFonts.pixelifySans(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: SwissTheme.textPrimary,
                ),
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = _modules[i];
                  final unlocked = RoadSignsCurriculumService.isModuleUnlocked(
                    m,
                    _passedMcqIds,
                    _viewedLearnIds,
                  );
                  return _ModuleTile(
                    module: m,
                    unlocked: unlocked,
                    passedMcq: _passedMcqIds.contains(m.id),
                    learnViewed: _viewedLearnIds.contains(m.id),
                    onTap: () => _onModuleTap(m, unlocked),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onModuleTap(RoadSignsModule m, bool unlocked) async {
    UiSoundService().playMenuTap();
    if (!unlocked) {
      _showLockedDialog(m);
      return;
    }
    if (m.kind == RoadSignsModuleKind.learn) {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RoadSignsLearnScreen(module: m, breadcrumb: _breadcrumb),
        ),
      );
      if (changed == true) await _refreshProgress();
      return;
    }
    if (m.kind == RoadSignsModuleKind.mcq) {
      final test = m.toTheoryTest(categoryId: 'road_signs');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoadSignMcqScreen(test: test)),
      );
      await _refreshProgress();
    }
  }

  void _showLockedDialog(RoadSignsModule m) {
    final reqs = m.unlockRequirementIds;
    String msg = 'Finish the previous step in this track to unlock this module.';
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
  final RoadSignsModule module;
  final bool unlocked;
  final bool passedMcq;
  final bool learnViewed;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.module,
    required this.unlocked,
    required this.passedMcq,
    required this.learnViewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMcq = module.kind == RoadSignsModuleKind.mcq;
    final done = isMcq ? passedMcq : learnViewed;
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
              Opacity(
                opacity: 0.45,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: HatchingPainter(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isMcq ? Icons.quiz_outlined : Icons.menu_book_outlined,
                    color: SwissTheme.textPrimary,
                    size: 28,
                  ),
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
                                      : SwissTheme.textSecondary.withOpacity(0.6),
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
                                : SwissTheme.textSecondary.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isMcq ? '${module.questionCount} questions' : 'Study',
                          style: SwissTheme.monospacedText.copyWith(
                            fontSize: 9,
                            color: SwissTheme.textSecondary.withOpacity(0.75),
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
