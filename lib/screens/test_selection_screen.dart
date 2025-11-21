import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import 'level_selection_screen.dart';

class TestSelectionScreen extends StatefulWidget {
  const TestSelectionScreen({super.key});

  @override
  State<TestSelectionScreen> createState() => _TestSelectionScreenState();
}

class _TestSelectionScreenState extends State<TestSelectionScreen> {
  // Cache font styles to avoid recreating them on every build
  late final TextStyle _headerStyle;
  late final TextStyle _titleStyle;
  late final TextStyle _descriptionStyle;
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
    _titleStyle = AppFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
    _descriptionStyle = AppFonts.inter(
      fontSize: 14,
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
                    'SELECT MODE',
                    style: _headerStyle,
                  ),
                ],
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),

            // Test Options - Two vertical blocks - Optimized with RepaintBoundary
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Block 1: THEORY TEST (MCQ) - White background, black border
                    Expanded(
                      child: RepaintBoundary(
                        child: _buildTestOption(
                          title: 'THEORY TEST',
                          icon: Icons.crop_square, // Geometric square icon
                          description: 'Test your knowledge with multiple choice questions',
                          isBlackBackground: false,
                          onTap: () => _startMCQTest(context),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 1), // 1px spacing between blocks
                    
                    // Block 2: DRIVING TEST (Practical) - Black background, white text
                    Expanded(
                      child: RepaintBoundary(
                        child: _buildTestOption(
                          title: 'DRIVING TEST',
                          icon: Icons.radio_button_unchecked, // Geometric circle icon
                          description: 'Practice driving through different levels',
                          isBlackBackground: true,
                          onTap: () => _startPracticalTest(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestOption({
    required String title,
    required IconData icon,
    required String description,
    required bool isBlackBackground,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isBlackBackground ? SwissTheme.textPrimary : SwissTheme.backgroundWhite;
    final textColor = isBlackBackground ? SwissTheme.backgroundWhite : SwissTheme.textPrimary;
    final iconColor = isBlackBackground ? SwissTheme.backgroundWhite : SwissTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero, // Sharp corners
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: SwissTheme.borderBlack,
              width: 2,
            ),
            borderRadius: BorderRadius.zero, // Sharp corners
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top section: Icon and title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Small geometric icon
                  Icon(
                    icon,
                    size: 32,
                    color: iconColor,
                  ),
                  const SizedBox(width: 16),
                  // Title in uppercase, bold
                  Expanded(
                    child: Text(
                      title,
                      style: _titleStyle.copyWith(color: textColor),
                    ),
                  ),
                ],
              ),
              
              // Bottom section: Description aligned bottom-left
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  description,
                  style: _descriptionStyle.copyWith(color: textColor.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startMCQTest(BuildContext context) {
    // TODO: Navigate to MCQ test screen when implemented
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'MCQ Test feature coming soon!',
          style: _snackbarStyle,
        ),
        backgroundColor: SwissTheme.accentBlue,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _startPracticalTest(BuildContext context) {
    // Use MaterialPageRoute for better performance
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LevelSelectionScreen(),
      ),
    );
  }
}
