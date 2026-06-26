import 'package:flutter/material.dart';

import '../../models/assistant/assistant_launch_context.dart';
import '../../models/driving/game_level.dart';
import '../../services/content/driving_levels_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../theme/landscape_layout.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import 'level_selection_screen.dart';

/// First step under Junctions: pick T-junctions (left/right), cross junctions, or roundabouts.
class JunctionsCategoryScreen extends StatefulWidget {
  const JunctionsCategoryScreen({super.key});

  @override
  State<JunctionsCategoryScreen> createState() => _JunctionsCategoryScreenState();
}

class _JunctionsCategoryScreenState extends State<JunctionsCategoryScreen> {
  late final TextStyle _headerStyle;
  late final TextStyle _titleStyle;
  late final TextStyle _descStyle;

  @override
  void initState() {
    super.initState();
    _headerStyle = AppFonts.pixelifySans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: SwissTheme.textPrimary,
    );
    _titleStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    _descStyle = AppFonts.pixelifySans(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    );
  }

  static const List<_JunctionCategory> _categories = [
    _JunctionCategory(
      moduleId: DrivingLevelsService.junctionModuleTJunction,
      title: 'T-Junctions',
      description: 'Left turn and right turn',
      icon: Icons.turn_left,
    ),
    _JunctionCategory(
      moduleId: DrivingLevelsService.junctionModuleCross,
      title: 'Cross junctions',
      description: 'Four-way crossings',
      icon: Icons.grid_4x4_outlined,
    ),
    _JunctionCategory(
      moduleId: DrivingLevelsService.junctionModuleRoundabout,
      title: 'Roundabouts',
      description: 'Single- and multi-lane roundabouts',
      icon: Icons.roundabout_left,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrowseScreenHeader(
              title: 'JUNCTIONS',
              titleStyle: _headerStyle,
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_junctions_categories',
              launchContext: AssistantLaunchContext(
                screenTitle: 'Junctions — choose category',
                drivingTopic: DrivingTopic.Junctions,
                includeFullRoadSignCatalog: true,
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: Padding(
                padding: LandscapeLayout.bodyPadding(context),
                child: GridView.builder(
                  cacheExtent: 200,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  gridDelegate: LandscapeLayout.selectionGridDelegate(context),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    return RepaintBoundary(
                      child: _buildCard(c),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_JunctionCategory c) {
    return GestureDetector(
      onTap: () {
        UiSoundService().playMenuTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LevelSelectionScreen(
              topic: DrivingTopic.Junctions,
              junctionsModuleId: c.moduleId,
              headerTitleOverride: c.title.toUpperCase(),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: SwissTheme.backgroundWhite,
          border: Border.all(
            color: SwissTheme.borderBlack,
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                c.icon,
                size: 36,
                color: SwissTheme.textPrimary,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.title.toUpperCase(),
                    style: _titleStyle.copyWith(color: SwissTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.description,
                    style: _descStyle.copyWith(color: SwissTheme.textSecondary),
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JunctionCategory {
  final String moduleId;
  final String title;
  final String description;
  final IconData icon;

  const _JunctionCategory({
    required this.moduleId,
    required this.title,
    required this.description,
    required this.icon,
  });
}
