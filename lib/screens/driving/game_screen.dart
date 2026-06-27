import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import '../../models/driving/game_level.dart';
import '../../game/effects/weather_effects_log.dart';
import '../../game/driving_game.dart';
import '../../utils/app_fonts.dart';
import '../../widgets/gearbox.dart';
import '../../widgets/steeringWheel.dart';
import '../../widgets/pedals.dart';
import '../../widgets/radio_tuner_sheet.dart';
import '../../services/progress/level_progress_service.dart';
import '../../services/progress/last_driving_report_service.dart';
import '../../services/progress/odometer_service.dart';
import '../../services/audio/music_service.dart';
import '../../services/audio/ui_sound_service.dart';
import '../../services/audio/weather_sfx_service.dart';
import '../../widgets/driving/driving_pause_dialog.dart';
import '../../widgets/driving/driving_radio_icon.dart';
import '../../widgets/last_driving_report_dialog.dart';
import '../../widgets/driving/level_briefing.dart';
import '../../widgets/driving/weather_precheck_dialog.dart';
import '../../widgets/driving/pedestrian_crossing_sign_hud.dart';

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
  bool _resultDialogVisible = false;
  bool _levelStoryShown = false;
  /// Gearbox and accelerator stay locked for [_startupControlsLockDuration] after level start.
  bool _gearboxEnabled = false;
  bool _acceleratorEnabled = false;
  static const Duration _startupControlsLockDuration = Duration(seconds: 4);
  /// Screenshot bytes captured when the game reports a non-fatal penalty.
  final List<({String description, Uint8List bytes})> _penaltyCaptures = [];

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

  bool _lessonExiting = false;
  bool _leaveInProgress = false;

  @override
  void initState() {
    super.initState();
    WeatherSfxService.instance.beginLesson();
    game = RealisticCarGame(
      mapAsset: widget.level.mapAsset,
      levelId: widget.level.id,
      scenarioId: widget.level.scenarioId,
      drivingRulesEnabled: widget.level.enableDrivingRules,
      onTestPassed: () => unawaited(_handleTestPassed()),
      onTestFailed: (message) => unawaited(_handleTestFailed(message)),
      onPenaltyRecorded: (description) => unawaited(_onPenaltyRecorded(description)),
      onWeatherCheckPrompt: (request) {
        if (!mounted) return;
        unawaited(
          showWeatherPrecheckDialog(context: context, request: request),
        );
      },
      onOdometerDeltaMeters: OdometerService.instance.recordSessionDelta,
      turnSignalLeft: _turnSignalLeftNotifier,
      turnSignalRight: _turnSignalRightNotifier,
    );
    WeatherEffectsLog.info(
      'GameScreen started level id=${widget.level.id} '
      'name=${widget.level.name} '
      'scenarioId=${widget.level.scenarioId ?? "(null)"} '
      'mapAsset=${widget.level.mapAsset ?? "(default)"}',
    );
    // Configure the game based on the level
    if (willShowLevelBriefing(widget.level)) {
      game.pauseEngine();
    } else {
      MusicService().beginDrivingLesson();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLevelBriefingIfNeeded();
    });
    _odometerFlushTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(OdometerService.instance.flushPendingToPersistence());
    });
  }

  void _resumeGameAfterBriefing() {
    if (!mounted) return;
    game.resumeEngine();
    MusicService().beginDrivingLesson();
    unawaited(_beginLevelStart());
  }

  Future<void> _beginLevelStart() async {
    if (!mounted) return;
    setState(() {
      _gearboxEnabled = false;
      _acceleratorEnabled = false;
    });
    game.car?.coast();
    unawaited(UiSoundService().playLevelEngineStart());
    await Future<void>.delayed(_startupControlsLockDuration);
    if (!mounted) return;
    setState(() {
      _gearboxEnabled = true;
      _acceleratorEnabled = true;
    });
  }

  void _showLevelBriefingIfNeeded() {
    if (!mounted || _levelStoryShown) return;
    if (!willShowLevelBriefing(widget.level)) {
      unawaited(_beginLevelStart());
      return;
    }
    _levelStoryShown = true;
    showLevelBriefingDialog(
      context: context,
      level: widget.level,
      onDismissed: _resumeGameAfterBriefing,
    );
  }

  void _syncTurnSignalsToGame() {
    _turnSignalLeftNotifier.value = _leftTurnSignalOn;
    _turnSignalRightNotifier.value = _rightTurnSignalOn;
  }

  Future<void> _leaveDrivingLesson() async {
    if (_lessonExiting) return;
    _lessonExiting = true;
    game.endLessonAudio();
    if (mounted) setState(() {});
    await WeatherSfxService.instance.endLesson();
    await MusicService().endDrivingLesson();
  }

  Future<void> _handleUserLeave() async {
    if (_leaveInProgress || _lessonExiting) return;
    _leaveInProgress = true;
    try {
      await _leaveDrivingLesson();
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaveInProgress = false;
    }
  }

  @override
  void deactivate() {
    if (!_lessonExiting) {
      game.endLessonAudio();
      unawaited(WeatherSfxService.instance.endLesson());
    }
    super.deactivate();
  }

  @override
  void dispose() {
    game.endLessonAudio();
    WeatherSfxService.instance.invalidate();
    unawaited(WeatherSfxService.instance.endLesson());
    unawaited(MusicService().endDrivingLesson());
    _odometerFlushTimer?.cancel();
    unawaited(OdometerService.instance.flushPendingToPersistence());
    _turnSignalTapTimer?.cancel();
    _turnSignalBlinkTimer?.cancel();
    _turnSignalAutoOffTimer?.cancel();
    _steeringRotation.dispose();
    _turnSignalLeftNotifier.dispose();
    _turnSignalRightNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Pixelify Sans for all text in the practical driving test
    final drivingTheme = Theme.of(context).copyWith(
      textTheme: AppFonts.drivingGameTextTheme,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleUserLeave());
      },
      child: Theme(
      data: drivingTheme,
      child: Scaffold(
      backgroundColor: Colors.black, // Match game background so letterboxing isn't jarring
      body: Stack(
        children: [
          // The game widget (RepaintBoundary enables failure-time screenshots)
          RepaintBoundary(
            key: _gameRepaintKey,
            child: _lessonExiting
                ? const ColoredBox(color: Colors.black)
                : GameWidget(game: game),
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
                              showDrivingPauseDialog(context: context, game: game);
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
                            icon: const DrivingRadioIcon(size: 32, fallbackColor: Colors.white),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      // Pedals row
                      PedalsWidget(
                        acceleratorEnabled: _acceleratorEnabled,
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

                // Wet-road advisory while inside Speed_Layer (adverse weather)
                ValueListenableBuilder<WeatherSpeedHudHint?>(
                  valueListenable: game.weatherSpeedHud,
                  builder: (context, hint, _) {
                    if (hint == null) {
                      return const SizedBox.shrink();
                    }
                    final theme = Theme.of(context).textTheme;
                    return Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hint.message,
                              style: theme.labelLarge!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Use ${_gearLabel(hint.recommendedGear)} gear',
                              style: theme.labelMedium!.copyWith(
                                color: Colors.amber.shade200,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                        enabled: _gearboxEnabled,
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
                ValueListenableBuilder<bool>(
                  valueListenable: game.pedestrianCrossingSignVisible,
                  builder: (context, visible, _) {
                    if (!visible) return const SizedBox.shrink();
                    return ValueListenableBuilder<int?>(
                      valueListenable: game.pedestrianCrossingDistanceMeters,
                      builder: (context, distanceMeters, _) {
                        return Positioned(
                          left: 20,
                          bottom: 20,
                          child: IgnorePointer(
                            child: PedestrianCrossingSignHud(
                              signAssetPath: game.spawnSignAssetPath,
                              distanceMeters: distanceMeters,
                            ),
                          ),
                        );
                      },
                    );
                  },
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

  String _gearLabel(int gear) {
    switch (gear) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      case 4:
        return '4th';
      default:
        return '$gear';
    }
  }

  // Gear selection handler
  void _onGearSelected(int gearIndex) {
    if (!_gearboxEnabled) return;
    final gearLabel = _gears[gearIndex];
    final blockReason = game.roadCrossingGearBlockReason(gearLabel);
    if (blockReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blockReason),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
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

    if (currentGearString != 'R') {
      game.cancelReverseAudio();
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
    if (!_acceleratorEnabled) return;
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

  Future<void> _handleTestPassed() async {
    if (!mounted || _resultDialogVisible) return;
    _resultDialogVisible = true;
    game.endLessonAudio();
    await MusicService().endDrivingLesson();
    final summary = game.getAttemptSummary();
    final penaltyPayload =
        List<({String description, Uint8List bytes})>.from(_penaltyCaptures);
    _penaltyCaptures.clear();
    if (summary.passed) {
      UiSoundService().playLevelPassed();
    } else {
      UiSoundService().playLevelFailed();
    }

    final report = await LastDrivingReportService.instance.recordAttempt(
      summary: summary,
      level: widget.level,
      penaltyCaptures: penaltyPayload,
    );

    if (!mounted) return;
    showDrivingEndReportDialog(
      context,
      report: report,
      onBackToLevels: () {
        unawaited(_completeLevelAndLeave(summary));
      },
    ).then((_) {
      if (mounted) _resultDialogVisible = false;
    });
  }

  Future<void> _completeLevelAndLeave(DrivingAttemptSummary summary) async {
    if (summary.passed ||
        (widget.level.isMarkingsDashedLevel && summary.reachedFinishZone)) {
      await LevelProgressService.markLevelCompleted(
        widget.level.id,
        moduleId: widget.level.moduleId,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(widget.level.id);
  }

  Future<void> _handleTestFailed(String message) async {
    if (!mounted || _resultDialogVisible) return;
    _resultDialogVisible = true;
    game.endLessonAudio();
    await MusicService().endDrivingLesson();
    final screenshotBytes = await _captureGameScreenshot();
    UiSoundService().playLevelFailed();
    final summary = game.getAttemptSummary(passed: false, failureMessage: message);
    final penaltyPayload =
        List<({String description, Uint8List bytes})>.from(_penaltyCaptures);
    _penaltyCaptures.clear();
    final report = await LastDrivingReportService.instance.recordAttempt(
      summary: summary,
      level: widget.level,
      screenshotBytes: screenshotBytes,
      penaltyCaptures: penaltyPayload,
    );

    if (!mounted) return;
    showDrivingEndReportDialog(
      context,
      report: report,
      onRetry: () {
        game.restartLevel();
        _penaltyCaptures.clear();
        _steeringRotation.value = 0.0;
        setState(() => _currentGear = 1);
        _applyGearChange();
        MusicService().beginDrivingLesson();
        unawaited(_beginLevelStart());
        _resultDialogVisible = false;
      },
      onBackToLevels: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    ).then((_) {
      if (mounted) _resultDialogVisible = false;
    });
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
                      child: const DrivingRadioIcon(size: 28, fallbackColor: Colors.white70),
                    ),
                  ),
                  title: Text('Radio', style: theme.bodyLarge!.copyWith(color: Colors.white)),
                  subtitle: Text(
                    'Stream stations in-app via API',
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
}