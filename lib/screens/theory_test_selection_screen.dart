import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/assistant_launch_context.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/assistant_button.dart';
import '../data/repositories/progress_repository.dart';
import '../models/theory_test.dart';
import '../services/theory_tests_service.dart';
import 'road_signs_hub_screen.dart';
import 'roadsign_mcq_screen.dart';

class TheoryTestSelectionScreen extends StatefulWidget {
  final String categoryId; // Which category of tests to show
  
  const TheoryTestSelectionScreen({super.key, required this.categoryId});

  @override
  State<TheoryTestSelectionScreen> createState() => _TheoryTestSelectionScreenState();
}

class _TheoryTestSelectionScreenState extends State<TheoryTestSelectionScreen> {
  // Cache font styles to avoid recreating them on every build
  late final TextStyle _headerStyle;
  late final TextStyle _testNumberStyle;
  late final TextStyle _testTitleStyle;
  late final TextStyle _dialogTitleStyle;
  late final TextStyle _dialogBodyStyle;
  late final TextStyle _dialogButtonStyle;

  // Track completed tests (TODO: Get from Firebase/local storage)
  Set<String> completedTestIds = {};

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
    _testNumberStyle = AppFonts.pixelifySans(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      height: 1.0,
      letterSpacing: -1.0,
    );
    _testTitleStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
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
    
    // Defer orientation change to avoid blocking UI initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
    _loadCompletedTests();
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

  // Get tests for the current category
  List<TheoryTest> get tests => TheoryTestsService.getTestsForCategory(widget.categoryId);

  Future<void> _loadCompletedTests() async {
    try {
      final ids = await ProgressRepository.instance.getCompletedTestIds();
      if (!mounted) return;
      setState(() {
        completedTestIds = ids;
      });
    } catch (_) {
      // Keep UI usable if progress loading fails.
    }
  }

  // Get category display name
  String get categoryDisplayName {
    switch (widget.categoryId) {
      case 'road_signs':
        return 'ROAD SIGNS';
      case 'best_practices':
        return 'BEST PRACTICES';
      case 'traffic_rules':
        return 'TRAFFIC RULES';
      case 'parking':
        return 'PARKING';
      case 'vehicle_control':
        return 'VEHICLE CONTROL';
      case 'safety_procedures':
        return 'SAFETY PROCEDURES';
      default:
        return 'THEORY TEST';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: AssistantButton(
        heroTag: 'assistant_theory_tests_${widget.categoryId}',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Theory tests — $categoryDisplayName',
          includeFullRoadSignCatalog: true,
        ),
      ),
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
                      categoryDisplayName,
                      style: _headerStyle,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            
            // Test Grid - Optimized for performance
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: tests.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: widget.categoryId == 'road_signs'
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Road signs use the curriculum hub',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.pixelifySans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: SwissTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Open Traffic and signals for the traffic-light intro, MCQ, and mini game.',
                                      textAlign: TextAlign.center,
                                      style: AppFonts.pixelifySans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: SwissTheme.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextButton(
                                      onPressed: () {
                                        UiSoundService().playMenuTap();
                                        Navigator.push<void>(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => const RoadSignsHubScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'OPEN ROAD SIGNS HUB',
                                        style: AppFonts.pixelifySans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: SwissTheme.accentBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'No tests available',
                                  style: AppFonts.pixelifySans(
                                    fontSize: 14,
                                    color: SwissTheme.textSecondary,
                                  ),
                                ),
                        ),
                      )
                    : GridView.builder(
                        cacheExtent: 200,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 1,
                          mainAxisSpacing: 1,
                          childAspectRatio: 0.70, // Slightly taller to accommodate text
                        ),
                        itemCount: tests.length,
                        itemBuilder: (context, index) {
                          final test = tests[index];
                          // Check unlock status based on completed tests
                          final isUnlocked = TheoryTestsService.isTestUnlocked(
                            test,
                            completedTestIds,
                          );
                          return RepaintBoundary(
                            child: _buildTestCard(test, isUnlocked),
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

  Widget _buildTestCard(TheoryTest test, bool isUnlocked) {
    return GestureDetector(
      onTap: () {
        UiSoundService().playMenuTap();
        if (isUnlocked) {
          _startTest(test);
        } else {
          _showLockedTestDialog(test);
        }
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
          children: [
            // Locked overlay pattern
            if (!isUnlocked)
              Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: HatchingPainter(),
                ),
              ),
            
            // Card content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Test number and difficulty indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Giant test number (top left)
                      Text(
                        test.testNumber.toString().padLeft(2, '0'),
                        style: _testNumberStyle.copyWith(
                          color: isUnlocked 
                            ? SwissTheme.textSecondary.withOpacity(0.5)
                            : SwissTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      
                      // Difficulty circle (top right) - only for unlocked tests
                      if (isUnlocked)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(test.difficulty),
                            shape: BoxShape.circle,
                          ),
                        ),
                      
                      // Lock icon (center) - only for locked tests
                      if (!isUnlocked)
                        Expanded(
                          child: Center(
                            child: Icon(
                              Icons.lock_outline,
                              color: SwissTheme.textPrimary,
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Title and description (bottom left)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        test.name.toUpperCase(),
                        style: _testTitleStyle.copyWith(
                          color: isUnlocked 
                            ? SwissTheme.textPrimary
                            : SwissTheme.textSecondary.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Description (smaller text)
                      Text(
                        test.description,
                        style: SwissTheme.monospacedText.copyWith(
                          fontSize: 10,
                          color: isUnlocked
                            ? SwissTheme.textSecondary
                            : SwissTheme.textSecondary.withOpacity(0.4),
                        ),
                        softWrap: true,
                        maxLines: null, // Allow unlimited lines
                        overflow: TextOverflow.clip,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Question count
                      Text(
                        '${test.questionCount} Questions',
                        style: SwissTheme.monospacedText.copyWith(
                          fontSize: 9,
                          color: isUnlocked
                            ? SwissTheme.textSecondary.withOpacity(0.7)
                            : SwissTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
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

  Color _getDifficultyColor(TestDifficulty difficulty) {
    switch (difficulty) {
      case TestDifficulty.Easy:
        return SwissTheme.accentGreen;
      case TestDifficulty.Medium:
        return SwissTheme.accentOrange;
      case TestDifficulty.Hard:
        return SwissTheme.accentRed;
    }
  }

  Future<void> _startTest(TheoryTest test) async {
    if (widget.categoryId == 'road_signs') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoadSignMcqScreen(test: test),
        ),
      );
      await _loadCompletedTests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Starting ${test.name}... (Coming soon)',
            style: AppFonts.pixelifySans(
              fontSize: 14,
              color: SwissTheme.backgroundWhite,
            ),
          ),
          backgroundColor: SwissTheme.accentBlue,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  void _showLockedTestDialog(TheoryTest test) {
    String unlockMessage = 'Complete the previous tests to unlock "${test.name}".';
    
    if (test.unlockRequirementIds.isNotEmpty) {
      // Get names of required tests
      final requiredTests = tests
          .where((t) => test.unlockRequirementIds.contains(t.id))
          .map((t) => t.name)
          .toList();
      
      if (requiredTests.isNotEmpty) {
        unlockMessage = 'Complete "${requiredTests.join('" and "')}" to unlock this test.';
      }
    }

    showDialog(
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
                  'TEST LOCKED',
                  style: _dialogTitleStyle,
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  unlockMessage,
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
}

/// Custom painter for hatching pattern on locked tests
class HatchingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SwissTheme.textSecondary.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw diagonal hatching lines
    const spacing = 8.0;
    final diagonalLength = (size.width + size.height);
    
    for (double i = -diagonalLength; i < diagonalLength; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
