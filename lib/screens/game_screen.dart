import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../models/game_level.dart';
import '../game/realistic_car_game.dart';

class GameScreen extends StatefulWidget {
  final GameLevel level;
  
  const GameScreen({super.key, required this.level});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  late RealisticCarGame game;
  int _currentGear = 1; // Track current gear (P=0, 1,2,3,4,5,R=-1)
  final List<String> _gears = ['P', '1', '2', '3', '4', '5', 'R'];
  double _steeringRotation = 0.0;

  @override
  void initState() {
    super.initState();
    game = RealisticCarGame();
    // Configure the game based on the level
    _configureGameForLevel();
  }

  void _configureGameForLevel() {
    // Customize game settings based on level difficulty
    switch (widget.level.difficulty) {
      case LevelDifficulty.Easy:
        game.roadSpeed = 150.0;
        break;
      case LevelDifficulty.Medium:
        game.roadSpeed = 200.0;
        break;
      case LevelDifficulty.Hard:
        game.roadSpeed = 250.0;
        break;
      case LevelDifficulty.Extreme:
        game.roadSpeed = 300.0;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The game widget
          GameWidget(game: game),
          
          // UI overlay (pause button, score, etc.)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Top UI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side controls column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pause/Back button
                          IconButton(
                            onPressed: () {
                              _showPauseDialog();
                            },
                            icon: const Icon(
                              Icons.pause,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // Pedals row
                          _buildPedalsRow(),
                          
                          const SizedBox(height: 15),
                          
                          // Gearbox
                          _buildGearbox(),
                        ],
                      ),
                      
                      // Level info (center)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '${widget.level.name} - Level ${widget.level.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Steering Wheel in top right
                      _buildSteeringWheel(),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Bottom - Speed Display (centered)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Speed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          StreamBuilder<double>(
                            stream: _getSpeedStream(),
                            builder: (context, snapshot) {
                              final speed = snapshot.data ?? 0;
                              return Text(
                                '${speed.toInt()}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text('Target', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('${widget.level.number * 500}', 
                              style: const TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
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

  Stream<double> _getSpeedStream() async* {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield game.car.getCurrentSpeed();
    }
  }

  Widget _buildSteeringWheel() {
    return GestureDetector(
      onPanStart: (details) {
        _handleSteeringStart(details);
      },
      onPanUpdate: (details) {
        _handleSteeringUpdate(details);
      },
      onPanEnd: (details) {
        _handleSteeringEnd();
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: _steeringRotation, // Apply the rotation
          child: ClipOval(
            child: Image.asset(
              'assets/images/SteeringWheel.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPedalsRow() {
    return Row(
      children: [
        // Accelerator (Gas)
        GestureDetector(
          onTapDown: (_) => _startAccelerating(),
          onTapUp: (_) => _stopAccelerating(),
          onTapCancel: () => _stopAccelerating(),
          child: Container(
            width: 50,
            height: 60,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green[600]!,
                  Colors.green[800]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[400]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 18,
                ),
                Text(
                  'GAS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Brake
        GestureDetector(
          onTapDown: (_) => _startBraking(),
          onTapUp: (_) => _stopBraking(),
          onTapCancel: () => _stopBraking(),
          child: Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.red[600]!,
                  Colors.red[800]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[400]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 18,
                ),
                Text(
                  'BRAKE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGearbox() {
    return Container(
      width: 110,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[600]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gearbox header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
              ),
            ),
            child: const Text(
              'GEAR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Current gear display
          Expanded(
            child: Center(
              child: Text(
                _gears[_currentGear],
                style: TextStyle(
                  color: _currentGear == 0 ? Colors.orange : // Park
                         _currentGear == 6 ? Colors.red :    // Reverse
                         Colors.green,                       // Forward gears
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Gear shift buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gear down button
              GestureDetector(
                onTap: _shiftDown,
                child: Container(
                  width: 35,
                  height: 30,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[500]!, width: 1),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              
              // Gear up button
              GestureDetector(
                onTap: _shiftUp,
                child: Container(
                  width: 35,
                  height: 30,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[500]!, width: 1),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Gear shifting methods
  void _shiftUp() {
    setState(() {
      if (_currentGear < _gears.length - 1) {
        _currentGear++;
        _applyGearChange();
      }
    });
  }

  void _shiftDown() {
    setState(() {
      if (_currentGear > 0) {
        _currentGear--;
        _applyGearChange();
      }
    });
  }

  void _applyGearChange() {
    // Apply gear change to the game
    String currentGearString = _gears[_currentGear];
    
    if (currentGearString == 'P') {
      // Park - disable movement
      game.car.currentGear = 0;
      game.car.isInPark = true;
    } else if (currentGearString == 'R') {
      // Reverse
      game.car.currentGear = -1;
      game.car.isInPark = false;
    } else {
      // Forward gears (1-5)
      game.car.currentGear = int.parse(currentGearString);
      game.car.isInPark = false;
    }
  }

  // Steering wheel control methods
  void _handleSteeringStart(DragStartDetails details) {
    // Handle steering start
  }

  void _handleSteeringUpdate(DragUpdateDetails details) {
    setState(() {
      // Calculate rotation based on horizontal drag
      final deltaX = details.delta.dx;
      _steeringRotation += deltaX * 0.02; // Adjust sensitivity as needed
      
      // Limit rotation to realistic range (e.g., -1.5 to 1.5 radians)
      _steeringRotation = _steeringRotation.clamp(-1.5, 1.5);
    });
    
    // Apply steering to car
    if (details.delta.dx > 2) {
      game.car.steerRight();
    } else if (details.delta.dx < -2) {
      game.car.steerLeft();
    }
  }

  void _handleSteeringEnd() {
    setState(() {
      // Gradually return steering wheel to center
      _steeringRotation = 0.0;
    });
    game.car.resetSteering();
  }

  // Pedal control methods
  void _startAccelerating() {
    game.car.accelerate();
  }

  void _stopAccelerating() {
    game.car.coast();
  }

  void _startBraking() {
    game.car.brake();
  }

  void _stopBraking() {
    game.car.coast();
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Game Paused',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'What would you like to do?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Resume game
              child: const Text(
                'Resume',
                style: TextStyle(color: Colors.green),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to level selection
              },
              child: const Text(
                'Quit',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}