import 'package:flutter/material.dart';
import '../../models/assistant/assistant_launch_context.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../theme/swiss_theme.dart';
import '../../theme/landscape_layout.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/browse_screen_header.dart';
import '../driving/level_selection_screen.dart' show HatchingPainter;
import '../road_signs/road_signs_hub_screen.dart';
import 'theory_test_selection_screen.dart' hide HatchingPainter;

class TheoryTestCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnderDevelopment;

  TheoryTestCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnderDevelopment = false,
  });
}

class TheoryTestCategoriesScreen extends StatefulWidget {
  const TheoryTestCategoriesScreen({super.key});

  @override
  State<TheoryTestCategoriesScreen> createState() => _TheoryTestCategoriesScreenState();
}

class _TheoryTestCategoriesScreenState extends State<TheoryTestCategoriesScreen> {
  // Cache font styles to avoid recreating them on every build
  late final TextStyle _headerStyle;
  late final TextStyle _categoryTitleStyle;
  late final TextStyle _categoryDescriptionStyle;
  late final TextStyle _dialogTitleStyle;
  late final TextStyle _dialogBodyStyle;
  late final TextStyle _dialogButtonStyle;

  @override
  void initState() {
    super.initState();
    
    // Cache font styles once during initialization
    _headerStyle = AppFonts.pixelifySans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: SwissTheme.textPrimary,
    );
    _categoryTitleStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    _categoryDescriptionStyle = AppFonts.pixelifySans(
      fontSize: 11,
      fontWeight: FontWeight.w400,
    );
    _dialogTitleStyle = AppFonts.pixelifySans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    _dialogBodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textPrimary,
    );
    _dialogButtonStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SwissTheme.accentBlue,
    );
  }

  // Theory test categories
  final List<TheoryTestCategory> categories = [
    TheoryTestCategory(
      id: 'road_signs',
      title: 'ROAD SIGNS',
      description: 'Learn traffic signs and their meanings',
      icon: Icons.traffic,
    ),
    TheoryTestCategory(
      id: 'best_practices',
      title: 'BEST PRACTICES',
      description: 'Essential driving rules and safety tips',
      icon: Icons.check_circle_outline,
      isUnderDevelopment: true,
    ),
    TheoryTestCategory(
      id: 'traffic_rules',
      title: 'TRAFFIC RULES',
      description: 'Sri Lankan traffic regulations and laws',
      icon: Icons.gavel,
      isUnderDevelopment: true,
    ),
    TheoryTestCategory(
      id: 'parking',
      title: 'PARKING',
      description: 'Parking rules, zones, and restrictions',
      icon: Icons.local_parking,
      isUnderDevelopment: true,
    ),
    TheoryTestCategory(
      id: 'vehicle_control',
      title: 'VEHICLE CONTROL',
      description: 'Steering, braking, and gear operations',
      icon: Icons.settings,
      isUnderDevelopment: true,
    ),
    TheoryTestCategory(
      id: 'safety_procedures',
      title: 'SAFETY PROCEDURES',
      description: 'Emergency situations and safe responses',
      icon: Icons.warning_amber_rounded,
      isUnderDevelopment: true,
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
              title: 'THEORY TEST',
              titleStyle: _headerStyle,
              onBack: () => Navigator.pop(context),
              heroTag: 'assistant_theory_categories',
              launchContext: const AssistantLaunchContext(
                screenTitle: 'Theory test categories',
                includeFullRoadSignCatalog: true,
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),

            // Category Grid - Optimized for performance
            Expanded(
              child: Padding(
                padding: LandscapeLayout.bodyPadding(context),
                child: GridView.builder(
                  cacheExtent: 200,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  gridDelegate: LandscapeLayout.selectionGridDelegate(context),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return RepaintBoundary(
                      child: _buildCategoryCard(category),
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

  Widget _buildCategoryCard(TheoryTestCategory category) {
    final isUnlocked = !category.isUnderDevelopment;
    return GestureDetector(
      onTap: () {
        UiSoundService().playMenuTap();
        if (category.isUnderDevelopment) {
          _showUnderDevelopmentCategoryDialog(category);
          return;
        }
        _startCategoryTest(category);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? SwissTheme.backgroundWhite : SwissTheme.backgroundLightGrey,
          border: Border.all(
            color: SwissTheme.borderBlack,
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!isUnlocked)
              Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: HatchingPainter(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        category.icon,
                        size: 36,
                        color: isUnlocked
                            ? SwissTheme.textPrimary
                            : SwissTheme.textSecondary.withOpacity(0.5),
                      ),
                      if (!isUnlocked)
                        const Icon(
                          Icons.lock_outline,
                          color: SwissTheme.textPrimary,
                          size: 28,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.title,
                        style: _categoryTitleStyle.copyWith(
                          color: isUnlocked
                              ? SwissTheme.textPrimary
                              : SwissTheme.textSecondary.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.description,
                        style: _categoryDescriptionStyle.copyWith(
                          color: isUnlocked
                              ? SwissTheme.textSecondary
                              : SwissTheme.textSecondary.withOpacity(0.4),
                        ),
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.clip,
                      ),
                      if (category.isUnderDevelopment) ...[
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnderDevelopmentCategoryDialog(TheoryTestCategory category) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
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
                  style: _dialogTitleStyle,
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  '"${category.title}" is under development.',
                  style: _dialogBodyStyle,
                ),
                const SizedBox(height: 32),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      UiSoundService().playMenuTap();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: SwissTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'OK',
                      style: _dialogButtonStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startCategoryTest(TheoryTestCategory category) {
    if (category.id == 'road_signs') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RoadSignsHubScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TheoryTestSelectionScreen(categoryId: category.id),
      ),
    );
  }
}
