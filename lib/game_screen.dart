import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'game.dart'; // Your existing game file
import 'menu_screen.dart';
import 'models/game_level.dart';

class GameScreen extends StatelessWidget {
  final GameLevel? selectedLevel;
  
  GameScreen({this.selectedLevel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your Flame game
          GameWidget(game: RealisticCarGame()),
          
          // Back button overlay
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MenuScreen()),
                ),
                icon: Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
          
          // Level info overlay
          if (selectedLevel != null)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedLevel!.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    // Difficulty stars
                    ...List.generate(selectedLevel!.difficulty.index + 1, (index) => 
                      Icon(
                        Icons.star,
                        color: _getDifficultyColor(selectedLevel!.difficulty),
                        size: 14,
                      )
                    ),
                  ],
                ),
              ),
            ),
          
          // Game stats overlay (optional)
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speed: 0 km/h',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Score: 0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  if (selectedLevel != null)
                    Text(
                      'Level: ${selectedLevel!.number}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
}