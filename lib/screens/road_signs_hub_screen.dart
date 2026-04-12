import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_launch_context.dart';
import '../models/road_signs_curriculum.dart';
import '../services/road_signs_curriculum_service.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/assistant_button.dart';
import 'level_selection_screen.dart' show HatchingPainter;
import 'road_signs_modules_screen.dart';
import 'road_signs_subgroups_screen.dart';

/// Top level: Warning signs vs Control signs (with subcategories).
class RoadSignsHubScreen extends StatefulWidget {
  const RoadSignsHubScreen({super.key});

  @override
  State<RoadSignsHubScreen> createState() => _RoadSignsHubScreenState();
}

class _RoadSignsHubScreenState extends State<RoadSignsHubScreen> {
  RoadSignsCurriculum? _curriculum;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      RoadSignsCurriculumService.instance.clearCache();
      final c = await RoadSignsCurriculumService.instance.loadCurriculum();
      if (!mounted) return;
      setState(() {
        _curriculum = c;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        heroTag: 'assistant_road_signs_hub',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Road signs — categories',
          includeFullRoadSignCatalog: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 24, 16),
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
                      'ROAD SIGNS',
                      style: AppFonts.pixelifySans(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: SwissTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Pick a track, then open each module in order. Traffic lights (intro, quiz, mini game) are under Traffic and signals.',
                style: SwissTheme.monospacedText.copyWith(fontSize: 12, color: SwissTheme.textSecondary),
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load road signs curriculum.\n$_loadError',
            textAlign: TextAlign.center,
            style: AppFonts.pixelifySans(fontSize: 13, color: SwissTheme.textSecondary),
          ),
        ),
      );
    }
    final c = _curriculum;
    if (c == null) {
      return const Center(child: CircularProgressIndicator(color: SwissTheme.textPrimary));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: c.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final g = c.groups[i];
        return _GroupCard(
          group: g,
          leadingIcon: _groupLeadingIcon(g),
          onTap: () {
            UiSoundService().playMenuTap();
            if (g.isUnderDevelopment) {
              _showUnderDevelopmentDialog(context, g);
              return;
            }
            if (g.hasSubgroups) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoadSignsSubgroupsScreen(group: g)),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoadSignsModulesScreen(group: g)),
              );
            }
          },
        );
      },
    );
  }

  void _showUnderDevelopmentDialog(BuildContext context, RoadSignsGroup group) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SwissTheme.backgroundWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: SwissTheme.borderBlack, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MODULE LOCKED',
                style: AppFonts.pixelifySans(fontSize: 24, fontWeight: FontWeight.w600, color: SwissTheme.textPrimary),
              ),
              const SizedBox(height: 24),
              const Divider(color: SwissTheme.dividerBlack, thickness: 1),
              const SizedBox(height: 24),
              Text(
                '"${group.title}" is under development.',
                style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w400, color: SwissTheme.textPrimary),
              ),
              const SizedBox(height: 32),
              const Divider(color: SwissTheme.dividerBlack, thickness: 1),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    UiSoundService().playMenuTap();
                    Navigator.of(ctx).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: SwissTheme.accentBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'OK',
                    style: AppFonts.pixelifySans(fontSize: 14, fontWeight: FontWeight.w600, color: SwissTheme.accentBlue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _groupLeadingIcon(RoadSignsGroup g) {
  if (g.hasSubgroups) return Icons.account_tree_outlined;
  switch (g.id) {
    case 'traffic_and_signals':
      return Icons.traffic_outlined;
    default:
      return Icons.warning_amber_outlined;
  }
}

class _GroupCard extends StatelessWidget {
  final RoadSignsGroup group;
  final IconData leadingIcon;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.leadingIcon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dev = group.isUnderDevelopment;
    final unlocked = !dev;
    final subtitle = group.hasSubgroups
        ? '${group.subgroups.length} subcategories'
        : '${group.modules.length} modules';
    return Material(
      color: unlocked ? SwissTheme.backgroundWhite : SwissTheme.backgroundLightGrey,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: SwissTheme.borderBlack, width: 1),
          ),
          child: Stack(
            children: [
              if (dev)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.45,
                    child: CustomPaint(painter: HatchingPainter()),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      leadingIcon,
                      size: 36,
                      color: unlocked
                          ? SwissTheme.textPrimary
                          : SwissTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title.toUpperCase(),
                            style: AppFonts.pixelifySans(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: unlocked
                                  ? SwissTheme.textPrimary
                                  : SwissTheme.textSecondary.withValues(alpha: 0.55),
                            ),
                          ),
                          if (dev) ...[
                            const SizedBox(height: 6),
                            Text(
                              'UNDER DEVELOPMENT',
                              style: AppFonts.pixelifySans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: SwissTheme.accentOrange,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            group.description,
                            style: SwissTheme.monospacedText.copyWith(
                              fontSize: 11,
                              color: unlocked
                                  ? SwissTheme.textSecondary
                                  : SwissTheme.textSecondary.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: SwissTheme.monospacedText.copyWith(
                              fontSize: 10,
                              color: unlocked
                                  ? SwissTheme.textSecondary
                                  : SwissTheme.textSecondary.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dev)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 2),
                        child: Icon(Icons.lock_outline, size: 24, color: SwissTheme.textPrimary),
                      )
                    else
                      const Icon(Icons.chevron_right, color: SwissTheme.textPrimary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
