import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flame/game.dart';
import '../models/game_level.dart';
import '../game/realistic_car_game.dart';
import '../widgets/gearbox.dart';
import '../widgets/steeringWheel.dart';
import '../widgets/pedals.dart';

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
  final ValueNotifier<double> _steeringRotation = ValueNotifier<double>(0.0);
  DateTime? _lastSteeringUpdate;

  @override
  void initState() {
    super.initState();
    game = RealisticCarGame();
    // Configure the game based on the level
    _configureGameForLevel();
  }

  @override
  void dispose() {
    _steeringRotation.dispose();
    super.dispose();
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
          
          // UI overlay - Using Positioned widgets for better control
          SafeArea(
            child: Stack(
              children: [
                // Top-left: Controls (Pause, Pedals, Gearbox)
                Positioned(
                  top: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                      PedalsWidget(
                        onAcceleratorDown: _startAccelerating,
                        onAcceleratorUp: _stopAccelerating,
                        onBrakeDown: _startBraking,
                        onBrakeUp: _stopBraking,
                      ),
                      
                      const SizedBox(height: 15),
                      
                      // Gearbox
                      GearboxWidget(
                        currentGear: _currentGear,
                        gears: _gears,
                        onGearSelected: _onGearSelected,
                      ),
                    ],
                  ),
                ),
                
                // Top-center: Level info
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
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
                  ),
                ),
                
                // Top-right: Steering Wheel
                Positioned(
                  top: 20,
                  right: 20,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _steeringRotation,
                    builder: (context, rotation, child) {
                      return SteeringWheelWidget(
                        rotation: rotation,
                        onPanStart: _handleSteeringStart,
                        onPanUpdate: _handleSteeringUpdate,
                        onPanEnd: _handleSteeringEnd,
                      );
                    },
                  ),
                ),
                
                // Bottom-right: Speed/Score section
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Speed section
                        const Text(
                          'SPEED',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<double>(
                          stream: _getSpeedStream(),
                          builder: (context, snapshot) {
                            final speed = snapshot.data ?? 0;
                            return Text(
                              '${speed.toInt()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const Text(
                          'km/h',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Divider
                        Container(
                          width: 60,
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Target section
                        const Text(
                          'TARGET',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.level.number * 500}',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'km/h',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

  // Gear selection handler
  void _onGearSelected(int gearIndex) {
    setState(() {
      _currentGear = gearIndex;
      _applyGearChange();
    });
  }

  // Enhanced gear change application with smooth transitions
  void _applyGearChange() {
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
      int gear = int.parse(currentGearString);
      game.car.currentGear = gear;
      game.car.isInPark = false;
    }
  }

  // Steering wheel control methods
  void _handleSteeringStart(DragStartDetails details) {
    // Handle steering start - you can add initialization logic here
  }

  void _handleSteeringUpdate(DragUpdateDetails details) {
    // Update visual rotation without setState (using ValueNotifier)
    // This only rebuilds the steering wheel widget, not the entire screen
    final deltaX = details.delta.dx;
    _steeringRotation.value = (_steeringRotation.value + deltaX * 0.02).clamp(-1.5, 1.5);
    
    // Throttle car steering updates to avoid lag (max once every 16ms ~ 60fps)
    final now = DateTime.now();
    if (_lastSteeringUpdate == null || 
        now.difference(_lastSteeringUpdate!).inMilliseconds >= 16) {
      _lastSteeringUpdate = now;
      
      // Apply proportional steering to car (smooth control)
      // Convert drag delta to steering angle (proportional control)
      final steeringInput = deltaX.clamp(-10.0, 10.0);
      if (steeringInput.abs() > 0.5) {
        // Proportional steering: map drag delta to steering angle
        final proportionalAngle = steeringInput * (game.car.maxSteerAngle / 10.0);
        game.car.steerAngle = proportionalAngle.clamp(-game.car.maxSteerAngle, game.car.maxSteerAngle);
      }
    }
  }

  void _handleSteeringEnd(DragEndDetails details) {
    // Gradually return steering wheel to center
    _steeringRotation.value = 0.0;
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