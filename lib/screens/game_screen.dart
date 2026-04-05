import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import '../models/game_level.dart';
import '../game/realistic_car_game.dart';
import '../utils/app_fonts.dart';
import '../widgets/gearbox.dart';
import '../widgets/steeringWheel.dart';
import '../widgets/pedals.dart';
import '../widgets/radio_tuner_sheet.dart';
import '../services/music_service.dart';
import '../services/level_progress_service.dart';
import '../services/ui_sound_service.dart';

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

  static const String _radioIconAsset = 'assets/images/Radio.png';

  Widget _radioIconWidget({double size = 32, Color fallbackColor = Colors.white}) {
    return Image.asset(
      _radioIconAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.radio,
        color: fallbackColor,
        size: size,
      ),
    );
  }

  /// Hit-test exclusion for pause/radio/pedals (left) and gearbox/steering (right).
  final GlobalKey _excludeHudLeftKey = GlobalKey();
  final GlobalKey _excludeHudRightKey = GlobalKey();
  final GlobalKey _turnSignalHitLayerKey = GlobalKey();

  /// Double-tap → left turn signal; triple-tap → right; single tap while on → off.
  Timer? _turnSignalTapTimer;
  int _turnSignalTapCount = 0;
  static const Duration _turnSignalTapWindow = Duration(milliseconds: 420);
  bool _leftTurnSignalOn = false;
  bool _rightTurnSignalOn = false;
  Timer? _turnSignalBlinkTimer;
  bool _turnSignalBlinkVisible = true;

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
    _turnSignalTapTimer?.cancel();
    _turnSignalBlinkTimer?.cancel();
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
                // Behind HUD: multi-tap turn signals (does not steal hits from controls above).
                Positioned.fill(
                  key: _turnSignalHitLayerKey,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onTurnSignalPointerDown,
                  ),
                ),
                // Top-left: Controls (Pause, Pedals)
                Positioned(
                  top: 20,
                  left: 20,
                  child: KeyedSubtree(
                    key: _excludeHudLeftKey,
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
                            onPressed: _showMusicSheet,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              fixedSize: const Size(48, 48),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            padding: EdgeInsets.zero,
                            icon: _radioIconWidget(size: 32, fallbackColor: Colors.white),
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
                  child: KeyedSubtree(
                    key: _excludeHudRightKey,
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
                ),

                // Turn signal indicators (ignore pointer so taps pass to layer below / game).
                if (_leftTurnSignalOn || _rightTurnSignalOn)
                  Positioned(
                    top: 24,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_leftTurnSignalOn)
                              Opacity(
                                opacity: _turnSignalBlinkVisible ? 1.0 : 0.2,
                                child: const Icon(
                                  Icons.keyboard_double_arrow_left,
                                  color: Color(0xFFFF9500),
                                  size: 36,
                                ),
                              ),
                            if (_rightTurnSignalOn)
                              Opacity(
                                opacity: _turnSignalBlinkVisible ? 1.0 : 0.2,
                                child: const Icon(
                                  Icons.keyboard_double_arrow_right,
                                  color: Color(0xFFFF9500),
                                  size: 36,
                                ),
                              ),
                          ],
                        ),
                      ),
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

  bool _globalHitExcludesTurnSignal(Offset globalPosition) {
    bool inside(GlobalKey key) {
      final ctx = key.currentContext;
      if (ctx == null) return false;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) return false;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);
      return rect.contains(globalPosition);
    }

    return inside(_excludeHudLeftKey) || inside(_excludeHudRightKey);
  }

  void _startTurnSignalBlink() {
    _turnSignalBlinkTimer?.cancel();
    _turnSignalBlinkVisible = true;
    _turnSignalBlinkTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _turnSignalBlinkVisible = !_turnSignalBlinkVisible);
    });
  }

  void _stopTurnSignalBlink() {
    _turnSignalBlinkTimer?.cancel();
    _turnSignalBlinkTimer = null;
    _turnSignalBlinkVisible = true;
  }

  void _onTurnSignalPointerDown(PointerDownEvent event) {
    if (_resultDialogVisible) return;
    final layerBox =
        _turnSignalHitLayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (layerBox == null || !layerBox.attached) return;
    final global = layerBox.localToGlobal(event.localPosition);
    if (_globalHitExcludesTurnSignal(global)) return;

    if (_leftTurnSignalOn || _rightTurnSignalOn) {
      _turnSignalTapTimer?.cancel();
      _turnSignalTapCount = 0;
      _stopTurnSignalBlink();
      setState(() {
        _leftTurnSignalOn = false;
        _rightTurnSignalOn = false;
      });
      return;
    }

    _turnSignalTapCount++;
    _turnSignalTapTimer?.cancel();
    _turnSignalTapTimer = Timer(_turnSignalTapWindow, () {
      final n = _turnSignalTapCount;
      _turnSignalTapCount = 0;
      if (!mounted) return;
      if (n == 2) {
        setState(() {
          _leftTurnSignalOn = true;
          _rightTurnSignalOn = false;
        });
        _startTurnSignalBlink();
      } else if (n >= 3) {
        setState(() {
          _rightTurnSignalOn = true;
          _leftTurnSignalOn = false;
        });
        _startTurnSignalBlink();
      }
    });
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
    UiSoundService().playLevelPassed();

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
    UiSoundService().playLevelFailed();

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
                // Restart in place so this route is not disposed (dispose forces
                // portrait and races with the new GameScreen on pushReplacement).
                game.restartLevel();
                _steeringRotation.value = 0.0;
                setState(() => _currentGear = 1);
                _applyGearChange();
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
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).padding.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
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
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: _radioIconWidget(size: 28, fallbackColor: Colors.white70),
                    ),
                  ),
                  title: Text('Radio', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text(
                    'Phone FM + tune dial to match',
                    style: theme.bodySmall!.copyWith(color: Colors.white54),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    RadioTunerSheet.show(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note, color: Colors.white70),
                  title: Text('Spotify', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text('Open Spotify app or web', style: theme.bodySmall!.copyWith(color: Colors.white54)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _musicService.openSpotify();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.library_music, color: Colors.white70),
                  title: Text('Phone music folder', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text(
                    MusicService.musicFolderPath != null && MusicService.musicFolderPath!.isNotEmpty
                        ? 'Play from: ${MusicService.musicFolderPath}'
                        : 'Menu → Options → Music folder',
                    style: theme.bodySmall!.copyWith(color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (MusicService.musicFolderPath == null || MusicService.musicFolderPath!.isEmpty) {
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Set your music folder: pause, go to Menu → Options → Music folder.',
                          ),
                          backgroundColor: Color(0xFF1a1a2e),
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    final err = await _musicService.playLocal();
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          err ??
                              'Playing from phone music folder (first track found)',
                        ),
                        backgroundColor: const Color(0xFF1a1a2e),
                        duration: Duration(seconds: err != null ? 5 : 2),
                      ),
                    );
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