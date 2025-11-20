import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/swiss_theme.dart';
import '../models/game_level.dart';
import 'game_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  LevelSelectionScreenState createState() => LevelSelectionScreenState();
}

class LevelSelectionScreenState extends State<LevelSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Force portrait orientation for level selection
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
  
  final List<GameLevel> levels = [
    GameLevel(1, "City Drive", "Navigate through busy city streets with moderate traffic.", LevelDifficulty.Easy, true),
    GameLevel(2, "Highway Rush", "High-speed highway driving with fast-moving vehicles.", LevelDifficulty.Medium, true),
    GameLevel(3, "Mountain Pass", "Winding mountain roads with sharp turns and steep drops.", LevelDifficulty.Hard, false),
    GameLevel(4, "Storm Chase", "Drive through severe weather conditions with limited visibility.", LevelDifficulty.Extreme, false),
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
                    'SELECT MODE',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: SwissTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: SwissTheme.dividerBlack, thickness: 1, height: 1),
            
            // Level Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Outer padding
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 1, // Thin 1px spacing
                    mainAxisSpacing: 1, // Thin 1px spacing
                    childAspectRatio: 0.75, // 3:4 rectangle
                  ),
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    return _buildLevelCard(level);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(GameLevel level) {
    final bool isLocked = !level.isUnlocked;
    
    return GestureDetector(
      onTap: () {
        if (!isLocked) {
          _startGame(level);
        } else {
          _showLockedLevelDialog(level);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isLocked ? SwissTheme.backgroundLightGrey : SwissTheme.backgroundWhite,
          border: Border.all(
            color: SwissTheme.borderBlack,
            width: 1,
          ),
          borderRadius: BorderRadius.zero, // Sharp corners
        ),
        child: Stack(
          children: [
            // Locked overlay pattern
            if (isLocked)
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
                  // Top row: Level number and difficulty indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Giant level number (top left)
                      Text(
                        level.number.toString().padLeft(2, '0'),
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: isLocked 
                            ? SwissTheme.textSecondary.withOpacity(0.3)
                            : SwissTheme.textSecondary.withOpacity(0.5),
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                      
                      // Difficulty circle (top right) - only for unlocked levels
                      if (!isLocked)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(level.difficulty),
                            shape: BoxShape.circle,
                          ),
                        ),
                      
                      // Lock icon (center) - only for locked levels
                      if (isLocked)
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
                  
                  // Title (bottom left)
                  Text(
                    level.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLocked 
                        ? SwissTheme.textSecondary.withOpacity(0.5)
                        : SwissTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Target Score (monospaced, technical data style)
                  Text(
                    'PTS: ${level.number * 5000}',
                    style: SwissTheme.monospacedText.copyWith(
                      fontSize: 10,
                      color: isLocked
                        ? SwissTheme.textSecondary.withOpacity(0.4)
                        : SwissTheme.textSecondary,
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

  Color _getDifficultyColor(LevelDifficulty difficulty) {
    switch (difficulty) {
      case LevelDifficulty.Easy:
        return SwissTheme.accentGreen;
      case LevelDifficulty.Medium:
        return SwissTheme.accentOrange;
      case LevelDifficulty.Hard:
        return SwissTheme.accentRed;
      case LevelDifficulty.Extreme:
        return SwissTheme.accentRed;
    }
  }

  void _startGame(GameLevel level) {
    // Navigate to the game screen with the selected level
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(level: level),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showLockedLevelDialog(GameLevel level) {
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
                  'LEVEL LOCKED',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: SwissTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 24),
                Text(
                  'Complete the previous levels to unlock "${level.name}".',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: SwissTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: SwissTheme.dividerBlack, thickness: 1),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: SwissTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SwissTheme.accentBlue,
                      ),
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

/// Custom painter for hatching pattern on locked levels
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
