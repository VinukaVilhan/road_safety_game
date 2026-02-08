import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import 'theory_test_selection_screen.dart';

class TheoryTestCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  TheoryTestCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
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
  late final TextStyle _snackbarStyle;

  @override
  void initState() {
    super.initState();
    
    // Cache font styles once during initialization
    _headerStyle = AppFonts.inter(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: SwissTheme.textPrimary,
    );
    _categoryTitleStyle = AppFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    _categoryDescriptionStyle = AppFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
    );
    _snackbarStyle = AppFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.backgroundWhite,
    );
    
    // Defer orientation change to avoid blocking UI initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  @override
  void dispose() {
    // Allow all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
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
    ),
    TheoryTestCategory(
      id: 'traffic_rules',
      title: 'TRAFFIC RULES',
      description: 'Sri Lankan traffic regulations and laws',
      icon: Icons.gavel,
    ),
    TheoryTestCategory(
      id: 'parking',
      title: 'PARKING',
      description: 'Parking rules, zones, and restrictions',
      icon: Icons.local_parking,
    ),
    TheoryTestCategory(
      id: 'vehicle_control',
      title: 'VEHICLE CONTROL',
      description: 'Steering, braking, and gear operations',
      icon: Icons.settings,
    ),
    TheoryTestCategory(
      id: 'safety_procedures',
      title: 'SAFETY PROCEDURES',
      description: 'Emergency situations and safe responses',
      icon: Icons.warning_amber_rounded,
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_sharp,
                      color: SwissTheme.textPrimary,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'THEORY TEST',
                    style: _headerStyle,
                  ),
                ],
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),

            // Category Grid - Optimized for performance
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Outer padding
                child: GridView.builder(
                  cacheExtent: 200, // Cache only 200px outside viewport
                  addAutomaticKeepAlives: false, // Don't keep off-screen items alive
                  addRepaintBoundaries: true, // Isolate repaints per item
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 1, // Thin 1px spacing
                    mainAxisSpacing: 1, // Thin 1px spacing
                    childAspectRatio: 0.70, // Slightly taller to accommodate more text
                  ),
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
    return GestureDetector(
      onTap: () => _startCategoryTest(category),
      child: Container(
        decoration: BoxDecoration(
          color: SwissTheme.backgroundWhite,
          border: Border.all(
            color: SwissTheme.borderBlack,
            width: 1,
          ),
          borderRadius: BorderRadius.zero, // Sharp corners
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top section: Icon
              Icon(
                category.icon,
                size: 40,
                color: SwissTheme.textPrimary,
              ),
              
              const Spacer(),
              
              // Bottom section: Title and description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: _categoryTitleStyle.copyWith(
                      color: SwissTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: _categoryDescriptionStyle.copyWith(
                      color: SwissTheme.textSecondary,
                    ),
                    softWrap: true,
                    maxLines: null, // Allow unlimited lines
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

  void _startCategoryTest(TheoryTestCategory category) {
    // Navigate to test selection screen for this category
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TheoryTestSelectionScreen(categoryId: category.id),
      ),
    );
  }
}
