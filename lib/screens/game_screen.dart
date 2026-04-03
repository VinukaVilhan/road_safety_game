import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flame/game.dart';
import '../models/game_level.dart';
import '../game/realistic_car_game.dart';
import '../utils/app_fonts.dart';
import '../widgets/gearbox.dart';
import '../widgets/steeringWheel.dart';
import '../widgets/pedals.dart';
import '../services/music_service.dart';
import '../services/level_progress_service.dart';

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
  final MusicService _musicService = MusicService();
  bool _resultDialogVisible = false;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation for game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    game = RealisticCarGame(
      mapAsset: widget.level.mapAsset,
      scenarioId: widget.level.scenarioId,
      onTestPassed: _handleTestPassed,
      onTestFailed: _handleTestFailed,
    );
    // Configure the game based on the level
    _configureGameForLevel();
  }

  @override
  void dispose() {
    _steeringRotation.dispose();
    // Restore portrait orientation when leaving game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
    // Use Pixelify Sans for all text in the practical driving test
    final drivingTheme = Theme.of(context).copyWith(
      textTheme: AppFonts.drivingGameTextTheme,
    );
    return Theme(
      data: drivingTheme,
      child: Scaffold(
      backgroundColor: Colors.black, // Match game background so letterboxing isn't jarring
      body: Stack(
        children: [
          // The game widget
          GameWidget(game: game),
          
          // UI overlay - Using Positioned widgets for better control
          SafeArea(
            child: Stack(
              children: [
                // Top-left: Controls (Pause, Pedals)
                Positioned(
                  top: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pause and Radio buttons row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          IconButton(
                            onPressed: () {
                              _showMusicSheet();
                            },
                            icon: const Icon(
                              Icons.radio,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Pedals row
                      PedalsWidget(
                        onAcceleratorDown: _startAccelerating,
                        onAcceleratorUp: _stopAccelerating,
                        onBrakeDown: _startBraking,
                        onBrakeUp: _stopBraking,
                      ),
                    ],
                  ),
                ),
                
                // Top-center: Level info (REMOVED per user request)
                // Positioned(
                //   top: 20,
                //   left: 0,
                //   right: 0,
                //   child: Center(
                //     child: Container(
                //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //       decoration: BoxDecoration(
                //         color: Colors.black.withValues(alpha: 0.6),
                //         borderRadius: BorderRadius.circular(15),
                //       ),
                //       child: Text(
                //         '${widget.level.name} - Level ${widget.level.number}',
                //         style: const TextStyle(
                //           color: Colors.white,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
                
                // Top right: Speed (fixed layout for 1–3 digits, no wrap)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: StreamBuilder<double>(
                      stream: _getSpeedStream(),
                      builder: (context, snapshot) {
                        final speed = snapshot.data ?? 0;
                        final theme = Theme.of(context).textTheme;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Speed',
                              style: theme.labelSmall!.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${speed.toInt()}',
                                style: theme.titleSmall!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                
                // Bottom-right: Gearbox above Steering Wheel
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Gearbox above steering wheel
                      GearboxWidget(
                        currentGear: _currentGear,
                        gears: _gears,
                        onGearSelected: _onGearSelected,
                      ),
                      const SizedBox(height: 15),
                      // Steering Wheel
                      ValueListenableBuilder<double>(
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

  Stream<double> _getSpeedStream() async* {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield game.car?.getCurrentSpeed() ?? 0.0;
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
    final car = game.car;
    if (car == null) return; // Guard against null car
    
    String currentGearString = _gears[_currentGear];
    
    if (currentGearString == 'P') {
      // Park - disable movement
      car.currentGear = 0;
      car.isInPark = true;
    } else if (currentGearString == 'R') {
      // Reverse
      car.currentGear = -1;
      car.isInPark = false;
    } else {
      // Forward gears (1-5)
      int gear = int.parse(currentGearString);
      car.currentGear = gear;
      car.isInPark = false;
    }
  }

  // Steering wheel control methods
  void _handleSteeringStart(DragStartDetails details) {
    // Mark that steering is active
    game.car?.isSteering = true;
  }

  void _handleSteeringUpdate(DragUpdateDetails details) {
    final car = game.car;
    if (car == null) return; // Guard against null car
    
    // Update visual rotation without setState (using ValueNotifier)
    // Increased sensitivity for more responsive steering (0.05 instead of 0.02)
    final deltaX = details.delta.dx;
    _steeringRotation.value = (_steeringRotation.value + deltaX * 0.05).clamp(-2.5, 2.5);
    
    // Map steering wheel rotation to car steering angle continuously
    // Increased rotation range for more responsiveness: -2.5 to 2.5 radians
    final normalizedRotation = _steeringRotation.value / 2.5; // Normalize to -1.0 to 1.0
    final steeringAngle = normalizedRotation * car.maxSteerAngle;
    
    // Apply steering angle continuously - car will turn as long as wheel is turned
    car.setSteeringAngle(steeringAngle);
  }

  void _handleSteeringEnd(DragEndDetails details) {
    // Gradually return steering wheel to center
    _steeringRotation.value = 0.0;
    game.car?.resetSteering();
  }

  // Pedal control methods
  void _startAccelerating() {
    game.car?.accelerate();
  }

  void _stopAccelerating() {
    game.car?.coast();
  }

  void _startBraking() {
    game.car?.brake();
  }

  void _stopBraking() {
    game.car?.coast();
  }

  void _showPauseDialog() {
    final theme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Game Paused',
            style: theme.titleLarge!.copyWith(color: Colors.white),
          ),
          content: Text(
            'What would you like to do?',
            style: theme.bodyLarge!.copyWith(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Resume game
              child: Text(
                'Resume',
                style: theme.labelLarge!.copyWith(color: Colors.green),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to level selection
              },
              child: Text(
                'Quit',
                style: theme.labelLarge!.copyWith(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleTestPassed() {
    if (!mounted || _resultDialogVisible) return;
    _resultDialogVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Test Passed!', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Great drive. You followed the route correctly.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await LevelProgressService.markLevelCompleted(
                  widget.level.id,
                  moduleId: widget.level.moduleId,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop(widget.level.id);
              },
              child: const Text('Back to Levels'),
            ),
          ],
        );
      },
    ).then((_) => _resultDialogVisible = false);
  }

  void _handleTestFailed(String message) {
    if (!mounted || _resultDialogVisible) return;
    _resultDialogVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Test Failed', style: TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => GameScreen(level: widget.level),
                  ),
                );
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Levels'),
            ),
          ],
        );
      },
    ).then((_) => _resultDialogVisible = false);
  }

  void _showMusicSheet() {
    final theme = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Music',
                  style: theme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.radio, color: Colors.white70),
                  title: Text('Radio', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text('Open radio in browser or app', style: theme.bodySmall!.copyWith(color: Colors.white54)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _musicService.openRadioUrl('https://www.internet-radio.com/');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.white70),
                  title: Text('Spotify', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text('Open Spotify app or web', style: theme.bodySmall!.copyWith(color: Colors.white54)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _musicService.openSpotify();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.library_music, color: Colors.white70),
                  title: Text('Phone music folder', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text(
                    MusicService.musicFolderPath != null && MusicService.musicFolderPath!.isNotEmpty
                        ? 'Play from: ${MusicService.musicFolderPath}'
                        : 'Set musicFolderPath in MusicService',
                    style: theme.bodySmall!.copyWith(color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (MusicService.musicFolderPath == null || MusicService.musicFolderPath!.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Set MusicService.musicFolderPath to your music folder path first.'),
                            backgroundColor: Color(0xFF1a1a2e),
                          ),
                        );
                      }
                      return;
                    }
                    await _musicService.playLocal();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Playing from phone music folder'),
                          backgroundColor: Color(0xFF1a1a2e),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}