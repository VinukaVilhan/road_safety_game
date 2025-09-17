import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game.dart'; // Your existing game file
import 'menu_screen.dart';
import 'models/game_level.dart';

class GameScreen extends StatefulWidget {
  final GameLevel? selectedLevel;
  
  GameScreen({this.selectedLevel});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late RealisticCarGame _game;
  double _steeringAngle = 0.0; // Track steering wheel rotation

  @override
  void initState() {
    super.initState();
    // Force landscape orientation when this screen loads
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _game = RealisticCarGame();
  }

  @override
  void dispose() {
    // Optional: Reset to all orientations when leaving game screen
    // SystemChrome.setPreferredOrientations([
    //   DeviceOrientation.portraitUp,
    //   DeviceOrientation.portraitDown,
    //   DeviceOrientation.landscapeLeft,
    //   DeviceOrientation.landscapeRight,
    // ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your Flame game
          GameWidget(game: _game),
          
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
          
          // Steering Wheel - Top Right Corner
          Positioned(
            top: 20,
            right: 20,
            child: _buildSteeringWheel(),
          ),
          
          // Game stats overlay (optional) - adjusted for landscape
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width / 2 - 60,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Speed: 0 km/h  ',
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
                  if (widget.selectedLevel != null)
                    Text(
                      '  Level: ${widget.selectedLevel!.number}',
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
  
  Widget _buildSteeringWheel() {
    return GestureDetector(
      onPanStart: (details) {
        // Handle steering start
      },
      onPanUpdate: (details) {
        // Calculate steering angle based on pan delta
        setState(() {
          // Adjust sensitivity by changing the multiplier
          _steeringAngle += details.delta.dx * 2.0;
          
          // Limit steering angle (-180 to 180 degrees)
          _steeringAngle = _steeringAngle.clamp(-180.0, 180.0);
        });
        
        // Apply steering to the car
        if (_steeringAngle > 10) {
          _game.car.steerRight();
        } else if (_steeringAngle < -10) {
          _game.car.steerLeft();
        } else {
          _game.car.resetSteering();
        }
      },
      onPanEnd: (details) {
        // Gradually return steering wheel to center
        _returnSteeringToCenter();
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(60),
        ),
        child: Transform.rotate(
          angle: _steeringAngle * (3.14159 / 180), // Convert degrees to radians
          child: Container(
            margin: EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
            ),
            child: Image.asset(
              'assets/images/SteeringWheel.png', // Your steering wheel image path
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  void _returnSteeringToCenter() {
    // Animate steering wheel back to center
    const duration = Duration(milliseconds: 500);
    const steps = 30;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    
    double startAngle = _steeringAngle;
    int currentStep = 0;
    
    Timer.periodic(stepDuration, (timer) {
      currentStep++;
      
      setState(() {
        // Smooth interpolation back to 0
        _steeringAngle = startAngle * (1.0 - (currentStep / steps));
      });
      
      // Reset car steering when wheel is centered
      if (_steeringAngle.abs() < 5) {
        _game.car.resetSteering();
      }
      
      if (currentStep >= steps) {
        setState(() {
          _steeringAngle = 0.0;
        });
        _game.car.resetSteering();
        timer.cancel();
      }
    });
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