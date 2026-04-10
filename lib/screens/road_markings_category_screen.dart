import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_level.dart';
import '../services/driving_levels_service.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import 'level_selection_screen.dart';

/// First step under Road markings: pick lane lines (solid / dashed) or other markings.
class RoadMarkingsCategoryScreen extends StatefulWidget {
  const RoadMarkingsCategoryScreen({super.key});

  @override
  State<RoadMarkingsCategoryScreen> createState() =>
      _RoadMarkingsCategoryScreenState();
}

class _RoadMarkingsCategoryScreenState extends State<RoadMarkingsCategoryScreen> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
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

  static const List<_RoadMarkingsCategory> _categories = [
    _RoadMarkingsCategory(
      moduleId: DrivingLevelsService.roadMarkingsModuleLaneLines,
      title: 'Lane lines',
      description: 'Solid lines and dashed lines',
      icon: Icons.straighten,
    ),
    _RoadMarkingsCategory(
      moduleId: DrivingLevelsService.roadMarkingsModuleOther,
      title: 'Other markings',
      description:
          'Stop, yield, zebra, junction box; bus lanes & special zones — under development',
      icon: Icons.grid_view_outlined,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      UiSoundService().playMenuTap();
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_sharp,
                      color: SwissTheme.textPrimary,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'ROAD MARKINGS',
                      style: _headerStyle,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  cacheExtent: 200,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                    childAspectRatio: 0.70,
                  ),
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

  Widget _buildCard(_RoadMarkingsCategory c) {
    return GestureDetector(
      onTap: () {
        UiSoundService().playMenuTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LevelSelectionScreen(
              topic: DrivingTopic.RoadMarkings,
              roadMarkingsModuleId: c.moduleId,
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

class _RoadMarkingsCategory {
  final String moduleId;
  final String title;
  final String description;
  final IconData icon;

  const _RoadMarkingsCategory({
    required this.moduleId,
    required this.title,
    required this.description,
    required this.icon,
  });
}
