// Data classes for level management
class GameLevel {
  final int number;
  final String name;
  final String description;
  final LevelDifficulty difficulty;
  final bool isUnlocked;

  GameLevel(this.number, this.name, this.description, this.difficulty, this.isUnlocked);
  
  // You can add more properties like:
  // final String backgroundImage;
  // final double targetTime;
  // final int targetScore;
  // final List<String> obstacles;
  // final double roadSpeed;
  // final Color themeColor;
}

enum LevelDifficulty { Easy, Medium, Hard, Extreme }