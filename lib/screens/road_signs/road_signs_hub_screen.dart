import 'package:flutter/material.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/theory/road_signs_curriculum.dart';
import '../../services/content/road_signs_curriculum_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../theme/landscape_layout.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import '../driving/level_selection_screen.dart' show HatchingPainter;
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
    _load();
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrowseScreenHeader(
              title: 'ROAD SIGNS',
              titleStyle: AppFonts.pixelifySans(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: SwissTheme.textPrimary,
              ),
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_road_signs_hub',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Road signs — categories',
                includeFullRoadSignCatalog: true,
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
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: LandscapeLayout.bodyPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < c.groups.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _GroupCard(
                  group: c.groups[i],
                  leadingIcon: _groupLeadingIcon(c.groups[i]),
                  onTap: () => _onGroupTap(context, c.groups[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onGroupTap(BuildContext context, RoadSignsGroup g) {
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
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          leadingIcon,
                          size: 26,
                          color: unlocked
                              ? SwissTheme.textPrimary
                              : SwissTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                        const Spacer(),
                        if (dev)
                          const Icon(Icons.lock_outline, size: 20, color: SwissTheme.textPrimary)
                        else
                          const Icon(Icons.chevron_right, size: 20, color: SwissTheme.textPrimary),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      group.title.toUpperCase(),
                      style: AppFonts.pixelifySans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: unlocked
                            ? SwissTheme.textPrimary
                            : SwissTheme.textSecondary.withValues(alpha: 0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dev) ...[
                      const SizedBox(height: 4),
                      Text(
                        'UNDER DEVELOPMENT',
                        style: AppFonts.pixelifySans(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: SwissTheme.accentOrange,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      group.description,
                      style: SwissTheme.monospacedText.copyWith(
                        fontSize: 10,
                        height: 1.25,
                        color: unlocked
                            ? SwissTheme.textSecondary
                            : SwissTheme.textSecondary.withValues(alpha: 0.45),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle.toUpperCase(),
                      style: SwissTheme.monospacedText.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: unlocked
                            ? SwissTheme.textSecondary
                            : SwissTheme.textSecondary.withValues(alpha: 0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
