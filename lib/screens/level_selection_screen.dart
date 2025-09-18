import 'package:flutter/material.dart';
import '../models/game_level.dart';
import 'game_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  LevelSelectionScreenState createState() => LevelSelectionScreenState();
}

class LevelSelectionScreenState extends State<LevelSelectionScreen> {
  final List<GameLevel> levels = [
    GameLevel(1, "City Drive", "Navigate through busy city streets with moderate traffic.", LevelDifficulty.Easy, true),
    GameLevel(2, "Highway Rush", "High-speed highway driving with fast-moving vehicles.", LevelDifficulty.Medium, true),
    GameLevel(3, "Mountain Pass", "Winding mountain roads with sharp turns and steep drops.", LevelDifficulty.Hard, false),
    GameLevel(4, "Storm Chase", "Drive through severe weather conditions with limited visibility.", LevelDifficulty.Extreme, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
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
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Level',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Level Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: levels.length,
                    itemBuilder: (context, index) {
                      final level = levels[index];
                      return _buildLevelCard(level);
                    },
                  ),
                ),
              ),

              // Tips Section
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💡 Pro Tips:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Complete earlier levels to unlock new challenges\n'
                      '• Each level has unique obstacles and traffic patterns\n'
                      '• Higher difficulty levels offer better rewards',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
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

  Widget _buildLevelCard(GameLevel level) {
    final bool isLocked = !level.isUnlocked;
    
    return GestureDetector(
      onTap: () {
        if (!isLocked) {
          // Navigate to game - you'll need to implement this properly
          _startGame(level);
        } else {
          _showLockedLevelDialog(level);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLocked 
              ? [Colors.grey.withValues(alpha: 0.3), Colors.grey.withValues(alpha: 0.1)]
              : [
                  _getDifficultyColor(level.difficulty).withValues(alpha: 0.8),
                  _getDifficultyColor(level.difficulty).withValues(alpha: 0.4),
                ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked 
              ? Colors.grey.withValues(alpha: 0.3)
              : _getDifficultyColor(level.difficulty),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isLocked 
                ? Colors.black.withValues(alpha: 0.2)
                : _getDifficultyColor(level.difficulty).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Lock overlay
            if (isLocked)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

            // Level content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Level number and difficulty
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Level ${level.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(level.difficulty),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          level.difficulty.toString().split('.').last,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Level name
                  Text(
                    level.name,
                    style: TextStyle(
                      color: isLocked ? Colors.grey : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Expanded(
                    child: Text(
                      level.description,
                      style: TextStyle(
                        color: isLocked ? Colors.grey : Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Target score
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${level.number * 500} pts',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  void _startGame(GameLevel level) {
    // Navigate to the game screen with the selected level
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(level: level),
      ),
    );
  }


  void _showLockedLevelDialog(GameLevel level) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Level Locked',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Complete the previous levels to unlock "${level.name}".',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getDifficultyColor(LevelDifficulty difficulty) {
    switch (difficulty) {
      case LevelDifficulty.Easy:
        return const Color(0xFF4CAF50);
      case LevelDifficulty.Medium:
        return const Color(0xFFFF9800);
      case LevelDifficulty.Hard:
        return const Color(0xFFe94560);
      case LevelDifficulty.Extreme:
        return const Color(0xFF9C27B0);
    }
  }
}