import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import '../models/game_level.dart';
import '../game/realistic_car_game.dart';
import '../utils/app_fonts.dart';
import '../widgets/gearbox.dart';
import '../widgets/steeringWheel.dart';
import '../widgets/pedals.dart';
import '../widgets/radio_tuner_sheet.dart';
import '../services/progress/level_progress_service.dart';
import '../services/progress/last_driving_report_service.dart';
import '../services/progress/odometer_service.dart';
import '../services/audio/ui_sound_service.dart';
import '../models/assistant_launch_context.dart';
import '../widgets/assistant_button.dart';

class GameScreen extends StatefulWidget {
  final GameLevel level;
  
  const GameScreen({super.key, required this.level});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  final ValueNotifier<bool> _turnSignalLeftNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _turnSignalRightNotifier = ValueNotifier<bool>(false);
  late RealisticCarGame game;
  int _currentGear = 1; // Track current gear (P=0, 1,2,3,4,R=-1)
  final List<String> _gears = ['P', '1', '2', '3', '4', 'R'];
  final ValueNotifier<double> _steeringRotation = ValueNotifier<double>(0.0);
  DateTime? _lastSteeringUpdate;
  bool _resultDialogVisible = false;
  bool _levelStoryShown = false;
  /// Screenshot bytes captured when the game reports a non-fatal penalty.
  final List<({String description, Uint8List bytes})> _penaltyCaptures = [];

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
  final GlobalKey _gameRepaintKey = GlobalKey();

  /// Double-tap → left turn signal; triple-tap → right; single tap while on → off.
  Timer? _turnSignalTapTimer;
  int _turnSignalTapCount = 0;
  static const Duration _turnSignalTapWindow = Duration(milliseconds: 420);
  bool _leftTurnSignalOn = false;
  bool _rightTurnSignalOn = false;
  Timer? _turnSignalBlinkTimer;
  Timer? _turnSignalAutoOffTimer;
  bool _turnSignalBlinkVisible = true;
  static const Duration _turnSignalHoldDuration = Duration(seconds: 4);

  Timer? _odometerFlushTimer;

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
      onTestFailed: (message) => unawaited(_handleTestFailed(message)),
      onPenaltyRecorded: (description) => unawaited(_onPenaltyRecorded(description)),
      onOdometerDeltaMeters: OdometerService.instance.recordSessionDelta,
      turnSignalLeft: _turnSignalLeftNotifier,
      turnSignalRight: _turnSignalRightNotifier,
    );
    // Configure the game based on the level
    _configureGameForLevel();
    if (_willShowLevelBriefing()) {
      game.pauseEngine();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLevelStoryIfAvailable();
    });
    _odometerFlushTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(OdometerService.instance.flushPendingToPersistence());
    });
  }

  String? _levelStoryText() {
    switch (widget.level.scenarioId) {
      case 'markings_zebra_crossing':
        return 'Road Crossing Story\n\n'
            'You are driving through a busy school-zone crossing. '
            'A pedestrian may step onto the zebra crossing at any moment.\n\n'
            'Your mission:\n'
            '- Slow down and enter the approach zone safely.\n'
            '- Stop fully and wait before the crossing.\n'
            '- Continue only when it is safe and finish the route.';
      default:
        return null;
    }
  }

  bool _willShowLevelBriefing() {
    if (widget.level.scenarioId == 'emergency_ambulance') return true;
    final story = _levelStoryText();
    return story != null && story.trim().isNotEmpty;
  }

  void _resumeGameAfterBriefing() {
    if (!mounted) return;
    game.resumeEngine();
    UiSoundService().playLevelEngineStart();
  }

  void _showLevelStoryIfAvailable() {
    if (!mounted) return;
    if (_levelStoryShown) return;

    if (widget.level.scenarioId == 'emergency_ambulance') {
      _levelStoryShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const _AmbulanceBriefingCarouselDialog(),
      ).then((_) {
        if (mounted) _resumeGameAfterBriefing();
      });
      return;
    }

    final story = _levelStoryText();
    if (story == null || story.trim().isEmpty) {
      UiSoundService().playLevelEngineStart();
      return;
    }
    _levelStoryShown = true;
    final theme = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            'Level Briefing',
            style: theme.titleLarge!.copyWith(color: Colors.white),
          ),
          content: Text(
            story,
            style: theme.bodyMedium!.copyWith(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                UiSoundService().playMenuTap();
                Navigator.of(context).pop();
              },
              child: const Text('Start Level'),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) _resumeGameAfterBriefing();
    });
  }

  void _syncTurnSignalsToGame() {
    _turnSignalLeftNotifier.value = _leftTurnSignalOn;
    _turnSignalRightNotifier.value = _rightTurnSignalOn;
  }

  @override
  void dispose() {
    if (game.paused) {
      game.resumeEngine();
    }
    _odometerFlushTimer?.cancel();
    unawaited(OdometerService.instance.flushPendingToPersistence());
    _turnSignalTapTimer?.cancel();
    _turnSignalBlinkTimer?.cancel();
    _turnSignalAutoOffTimer?.cancel();
    _steeringRotation.dispose();
    _turnSignalLeftNotifier.dispose();
    _turnSignalRightNotifier.dispose();
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
          // The game widget (RepaintBoundary enables failure-time screenshots)
          RepaintBoundary(
            key: _gameRepaintKey,
            child: GameWidget(game: game),
          ),
          
          // UI overlay - Using Positioned widgets for better control
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
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
                              UiSoundService().playMenuTap();
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
                              UiSoundService().playMenuTap();
                              _showMusicSheet();
                            },
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
                      
                      const SizedBox(height: 12),
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

                // AI instructor (below speed readout)
                Positioned(
                  top: 78,
                  right: 20,
                  child: AssistantButton(
                    mini: true,
                    heroTag: 'assistant_game_${widget.level.id}',
                    tooltip: 'AI instructor',
                    launchContext: AssistantLaunchContext(
                      screenTitle: 'Practical driving test',
                      level: widget.level,
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

                ValueListenableBuilder<int?>(
                  valueListenable: game.roadCrossingCountdown,
                  builder: (context, secondsLeft, _) {
                    if (secondsLeft == null) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              'Pedestrian crossing: wait $secondsLeft',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: game.roadCrossingApproachHint,
                  builder: (context, hint, _) {
                    if (hint == null || hint.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: 72,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              hint,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

  void _scheduleTurnSignalAutoOff() {
    _turnSignalAutoOffTimer?.cancel();
    _turnSignalAutoOffTimer = Timer(_turnSignalHoldDuration, () {
      if (!mounted) return;
      if (!_leftTurnSignalOn && !_rightTurnSignalOn) return;
      _stopTurnSignalBlink();
      setState(() {
        _leftTurnSignalOn = false;
        _rightTurnSignalOn = false;
      });
      _syncTurnSignalsToGame();
    });
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
      _turnSignalAutoOffTimer?.cancel();
      _stopTurnSignalBlink();
      setState(() {
        _leftTurnSignalOn = false;
        _rightTurnSignalOn = false;
      });
      _syncTurnSignalsToGame();
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
        _syncTurnSignalsToGame();
        _startTurnSignalBlink();
        _scheduleTurnSignalAutoOff();
      } else if (n >= 3) {
        setState(() {
          _rightTurnSignalOn = true;
          _leftTurnSignalOn = false;
        });
        _syncTurnSignalsToGame();
        _startTurnSignalBlink();
        _scheduleTurnSignalAutoOff();
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
      // Forward gears (1-4)
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
    showDialog<void>(
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
              onPressed: () {
                UiSoundService().playMenuTap();
                Navigator.of(context).pop(); // Resume game
              },
              child: Text(
                'Resume',
                style: theme.labelLarge!.copyWith(color: Colors.green),
              ),
            ),
            TextButton(
              onPressed: () {
                UiSoundService().playMenuTap();
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
    ).then((_) {
      if (!mounted) return;
      game.resumeAmbientAudioAfterUiOverlay();
    });
  }

  Future<Uint8List?> _captureGameScreenshot() async {
    try {
      final boundary =
          _gameRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.attached) return null;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPenaltyRecorded(String description) async {
    if (!mounted) return;
    final bytes = await _captureGameScreenshot();
    if (bytes == null || bytes.isEmpty) return;
    if (!mounted) return;
    _penaltyCaptures.add((description: description, bytes: bytes));
  }

  bool get _isMarkingsDashedLevel {
    if (widget.level.scenarioId == 'emergency_ambulance') return false;
    final a = (widget.level.mapAsset ?? '').toLowerCase();
    return a.contains('lane-markings-dashed') ||
        widget.level.scenarioId == 'markings_dashed';
  }

  void _handleTestPassed() {
    if (!mounted || _resultDialogVisible) return;
    _resultDialogVisible = true;
    final summary = game.getAttemptSummary();
    final penaltyPayload =
        List<({String description, Uint8List bytes})>.from(_penaltyCaptures);
    _penaltyCaptures.clear();
    if (summary.passed) {
      UiSoundService().playLevelPassed();
    } else {
      UiSoundService().playLevelFailed();
    }
    unawaited(
      LastDrivingReportService.instance.recordAttempt(
        summary: summary,
        level: widget.level,
        penaltyCaptures: penaltyPayload,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final title = summary.passed
            ? 'Test Passed!'
            : 'Attempt not passed';
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: _buildAttemptSummaryContent(summary),
          actions: [
            TextButton(
              onPressed: () async {
                UiSoundService().playMenuTap();
                // Dashed-lines: reaching the green finish unlocks the level even if penalties
                // prevented a "pass" on the report.
                if (summary.passed ||
                    (_isMarkingsDashedLevel && summary.reachedFinishZone)) {
                  await LevelProgressService.markLevelCompleted(
                    widget.level.id,
                    moduleId: widget.level.moduleId,
                  );
                }
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

  Future<void> _handleTestFailed(String message) async {
    if (!mounted || _resultDialogVisible) return;
    _resultDialogVisible = true;
    final screenshotBytes = await _captureGameScreenshot();
    UiSoundService().playLevelFailed();
    final summary = game.getAttemptSummary(passed: false, failureMessage: message);
    final penaltyPayload =
        List<({String description, Uint8List bytes})>.from(_penaltyCaptures);
    _penaltyCaptures.clear();
    await LastDrivingReportService.instance.recordAttempt(
      summary: summary,
      level: widget.level,
      screenshotBytes: screenshotBytes,
      penaltyCaptures: penaltyPayload,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Test Failed', style: TextStyle(color: Colors.white)),
          content: _buildAttemptSummaryContent(summary),
          actions: [
            TextButton(
              onPressed: () {
                UiSoundService().playMenuTap();
                Navigator.of(context).pop();
                if (!mounted) return;
                // Restart in place so this route is not disposed (dispose forces
                // portrait and races with the new GameScreen on pushReplacement).
                game.restartLevel();
                _penaltyCaptures.clear();
                _steeringRotation.value = 0.0;
                setState(() => _currentGear = 1);
                _applyGearChange();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                UiSoundService().playMenuTap();
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
                    'Open phone FM via API',
                    style: theme.bodySmall!.copyWith(color: Colors.white54),
                  ),
                  onTap: () {
                    UiSoundService().playMenuTap();
                    Navigator.pop(sheetContext);
                    RadioTunerSheet.show(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _signalLabel(String expected) {
    switch (expected) {
      case 'left':
        return 'Left signal';
      case 'right':
        return 'Right signal';
      default:
        return 'Turn signal';
    }
  }

  Widget _buildCheckRow(String label, bool ok) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.greenAccent : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildAttemptSummaryContent(DrivingAttemptSummary summary) {
    final isRoadCrossingLevel =
        (widget.level.mapAsset ?? '').toLowerCase().contains('road-crossing');
    final signalName = _signalLabel(summary.expectedTurnSignal);
    final midTurnLabel = _isMarkingsDashedLevel
        ? 'Kept $signalName on throughout the purple turn zone.'
        : 'Kept $signalName while turning.';
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!summary.passed && summary.failureMessage != null) ...[
            Text(
              summary.failureMessage!,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
          ],
          if (summary.penalties.isNotEmpty) ...[
            Text(
              'Penalties (${summary.penalties.length})',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...summary.penalties.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $p',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Screenshots for each penalty are saved in your driving report.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
          if (isRoadCrossingLevel) ...[
            _buildCheckRow('Entered speed limit zone (yellow).', summary.enteredApproachZone),
            const SizedBox(height: 6),
            _buildCheckRow(
              'Stopped in Park and completed zebra crossing wait (grey zig-zag zone).',
              summary.waitedAtRoadCrossing,
            ),
            const SizedBox(height: 6),
            _buildCheckRow('Reached finish zone (green).', summary.reachedFinishZone),
          ] else if (_isMarkingsDashedLevel) ...[
            _buildCheckRow(
              'Right turn signal used in approach zone (yellow).',
              summary.signaledCorrectlyInApproachZone,
            ),
            const SizedBox(height: 6),
            _buildCheckRow('Entered turn execution zone (purple).', summary.enteredMidTurnZone),
            const SizedBox(height: 6),
            _buildCheckRow(
              midTurnLabel,
              summary.hadCorrectSignalInMidTurnZone,
            ),
            const SizedBox(height: 6),
            _buildCheckRow('Reached finish zone (green).', summary.reachedFinishZone),
          ] else if (widget.level.scenarioId == 'emergency_ambulance') ...[
            if (summary.ambulance != null) ...[
              Builder(
                builder: (context) {
                  final a = summary.ambulance!;
                  String yn(bool v) => v ? 'Yes' : 'No';
                  String side(bool? y) {
                    if (y == null) return '—';
                    return y ? 'Left safe strip' : 'Right safe strip';
                  }

                  String cpGate(double sec) {
                    if (sec <= 0) return 'no per-CP limit';
                    return '${sec.toStringAsFixed(0)} s to reach';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level timer: ${a.elapsedSecs.toStringAsFixed(1)} s of '
                        '${a.levelTimeoutSecs.toStringAsFixed(0)} s max (whole level timeout).',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (a.mapHasCp1) ...[
                        _buildCheckRow('Reached Checkpoint 1 in time.', a.cp1Cleared),
                        Padding(
                          padding: const EdgeInsets.only(left: 26, bottom: 4),
                          child: Text(
                            'CP1 time gate: ${cpGate(a.cp1TimeLimitSecs)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      ],
                      if (a.mapHasCp2) ...[
                        _buildCheckRow('Reached Checkpoint 2 in time.', a.cp2Cleared),
                        Padding(
                          padding: const EdgeInsets.only(left: 26, bottom: 4),
                          child: Text(
                            'CP2 time gate: ${cpGate(a.cp2TimeLimitSecs)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          a.mapHasCpf
                              ? 'Map has a final gate (CPF): complete pull-over before crossing it.'
                              : 'No CPF final gate on this map layout.',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      _buildCheckRow(
                        'Safe pull-over completed (Park + matching zone + correct signal).',
                        a.pullOverCompleted,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 26, bottom: 4),
                        child: Text(
                          'Yield side: ${side(a.yieldLeftSide)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      Text(
                        'Ambulance AI at end: ${a.ambulanceAiState} · route completed: ${yn(a.ambulanceRouteCompleted)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ],
            _buildCheckRow(
              'Ambulance reached the finish area while you stayed correctly yielded.',
              summary.reachedFinishZone && summary.passed,
            ),
          ] else ...[
            _buildCheckRow('Entered approach zone (yellow).', summary.enteredApproachZone),
            const SizedBox(height: 6),
            _buildCheckRow(
              'Used $signalName in approach zone.',
              summary.signaledCorrectlyInApproachZone,
            ),
            const SizedBox(height: 6),
            _buildCheckRow('Entered turn execution zone (purple).', summary.enteredMidTurnZone),
            const SizedBox(height: 6),
            _buildCheckRow(
              midTurnLabel,
              summary.hadCorrectSignalInMidTurnZone,
            ),
            const SizedBox(height: 6),
            _buildCheckRow('Reached finish zone (green).', summary.reachedFinishZone),
          ],
          const SizedBox(height: 6),
          _buildCheckRow(
            'Minor obstacle bumps (non-crash): ${summary.nonCrashBumpCount}',
            summary.nonCrashBumpCount == 0,
          ),
          const SizedBox(height: 12),
          Text(
            'Time spent: ${_formatDuration(summary.timeSpent)}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Score: ${summary.score}/100',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbulanceBriefingSlide {
  final String title;
  final String body;
  const _AmbulanceBriefingSlide(this.title, this.body);
}

/// Swipe or use Next/Back; one short tip per page for the emergency ambulance level.
class _AmbulanceBriefingCarouselDialog extends StatefulWidget {
  const _AmbulanceBriefingCarouselDialog();

  @override
  State<_AmbulanceBriefingCarouselDialog> createState() =>
      _AmbulanceBriefingCarouselDialogState();
}

class _AmbulanceBriefingCarouselDialogState
    extends State<_AmbulanceBriefingCarouselDialog> {
  static const List<_AmbulanceBriefingSlide> _slides = [
    _AmbulanceBriefingSlide(
      'Sirens on the way',
      'An ambulance can appear while you drive. Slow down and be ready to yield safely.',
    ),
    _AmbulanceBriefingSlide(
      'Hit the early checkpoints',
      'Reach Checkpoint 1 and Checkpoint 2 within the time limits.',
    ),
    _AmbulanceBriefingSlide(
      'Signals and side',
      'Left safe strip: left indicator only. Right strip: right indicator only.',
    ),
    _AmbulanceBriefingSlide(
      'Three steps to yield',
      'After Checkpoint 2, in order:\n'
      '1) Overlap the matching safe zone with the correct signal on (you may still be moving).\n'
      '2) Bring both wheels on that side fully inside the zone.\n'
      '3) Shift to Park (P). The ambulance will only pass after all three are done.',
    ),
    _AmbulanceBriefingSlide(
      'When to pull over',
      'After you clear Checkpoint 2, finish your pull-over before you cross the final gate (CPF).',
    ),
    _AmbulanceBriefingSlide(
      'While it passes',
      'Stay slow and yielded. The ambulance will pass you and follow its route.',
    ),
    _AmbulanceBriefingSlide(
      'How you pass',
      'You complete the level when the ambulance reaches the success area and you remain correctly stopped and yielded.',
    ),
  ];

  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width * 0.62;
    final boxW = math.min(440.0, w);
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Ambulance — briefing',
              style: theme.titleLarge!.copyWith(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white60,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Skip',
              style: theme.labelLarge!.copyWith(color: Colors.white60),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: boxW,
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: theme.titleSmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.body,
                          style: theme.bodyMedium!.copyWith(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _pageIndex ? Colors.white : Colors.white30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_pageIndex > 0)
          TextButton(
            onPressed: () {
              UiSoundService().playMenuTap();
              _pageController.previousPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            },
            child: Text(
              'Back',
              style: theme.labelLarge!.copyWith(color: Colors.white70),
            ),
          ),
        TextButton(
          onPressed: () {
            UiSoundService().playMenuTap();
            if (_pageIndex < _slides.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            _pageIndex < _slides.length - 1 ? 'Next' : 'Start Level',
            style: theme.labelLarge!.copyWith(color: Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}