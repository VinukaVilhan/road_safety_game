import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'models/game_level.dart';

class LevelSelectionScreen extends StatefulWidget {
  @override
  _LevelSelectionScreenState createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // Level data - you can expand this
  final List<GameLevel> levels = [
    GameLevel(1, "Junctions", "The hardest junctions you have ever faced", LevelDifficulty.Easy, true),
    GameLevel(2, "Highway Rush", "Fast-paced highway racing", LevelDifficulty.Medium, true),
    GameLevel(3, "Mountain Pass", "Challenging mountain curves", LevelDifficulty.Medium, false),
    GameLevel(4, "Desert Storm", "Survive the desert heat", LevelDifficulty.Hard, false),
    GameLevel(5, "Night Race", "Race through the dark city", LevelDifficulty.Hard, false),
    GameLevel(6, "Championship", "Ultimate racing challenge", LevelDifficulty.Extreme, false),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            'SELECT LEVEL',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Level Grid
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: levels.length,
                        itemBuilder: (context, index) {
                          return _buildLevelCard(levels[index]);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom info
              Padding(
                padding: EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Complete levels to unlock new challenges!',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(GameLevel level) {
    Color cardColor = level.isUnlocked ? _getDifficultyColor(level.difficulty) : Colors.grey.shade700;
    Color textColor = level.isUnlocked ? Colors.white : Colors.grey.shade500;
    
    return GestureDetector(
      onTap: level.isUnlocked ? () => _startLevel(level) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: level.isUnlocked 
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cardColor.withOpacity(0.8),
                  cardColor.withOpacity(0.6),
                ],
              )
            : null,
          color: level.isUnlocked ? null : Colors.grey.shade700,
          boxShadow: [
            if (level.isUnlocked)
              BoxShadow(
                color: cardColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Level number
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: level.isUnlocked ? Colors.white.withOpacity(0.2) : Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    '${level.number}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              
              // Level info
              Column(
                children: [
                  Text(
                    level.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    level.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  _buildDifficultyIndicator(level.difficulty, level.isUnlocked),
                ],
              ),
              
              // Lock indicator
              if (!level.isUnlocked)
                Icon(
                  Icons.lock,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyIndicator(LevelDifficulty difficulty, bool isUnlocked) {
    int stars = difficulty.index + 1;
    Color starColor = isUnlocked ? _getDifficultyColor(difficulty) : Colors.grey.shade600;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: starColor,
          size: 16,
        );
      }),
    );
  }

  Color _getDifficultyColor(LevelDifficulty difficulty) {
    switch (difficulty) {
      case LevelDifficulty.Easy:
        return Color(0xFF4CAF50);
      case LevelDifficulty.Medium:
        return Color(0xFFFF9800);
      case LevelDifficulty.Hard:
        return Color(0xFFe94560);
      case LevelDifficulty.Extreme:
        return Color(0xFF9C27B0);
    }
  }

  void _startLevel(GameLevel level) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1a1a2e),
          title: Text(
            level.name,
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.description,
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Difficulty: ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  _buildDifficultyIndicator(level.difficulty, true),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameScreen(selectedLevel: level),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getDifficultyColor(level.difficulty),
              ),
              child: Text(
                'START RACE',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}