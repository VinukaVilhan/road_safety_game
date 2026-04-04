import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tutorial_progress.dart';
import '../services/tutorial_progress_service.dart';
import '../services/ui_sound_service.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/gearbox.dart';
import '../widgets/pedals.dart';
import '../widgets/steeringWheel.dart';

/// Lists control tutorials and shows completion from [TutorialProgress].
class DrivingTutorialScreen extends StatefulWidget {
  const DrivingTutorialScreen({super.key});

  @override
  State<DrivingTutorialScreen> createState() => _DrivingTutorialScreenState();
}

class _DrivingTutorialScreenState extends State<DrivingTutorialScreen> {
  TutorialProgress _progress = const TutorialProgress();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await TutorialProgressService.load();
    if (!mounted) return;
    setState(() {
      _progress = p;
      _loading = false;
    });
  }

  Future<void> _openLesson(DrivingTutorialLesson lesson) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _DrivingTutorialLessonPage(lesson: lesson),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.pixelifySans(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    final bodyStyle = AppFonts.pixelifySans(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textSecondary,
    );

    return Scaffold(
      backgroundColor: SwissTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: SwissTheme.backgroundWhite,
        foregroundColor: SwissTheme.textPrimary,
        elevation: 0,
        title: Text('Driving controls', style: titleStyle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                Text(
                  'Practice each control once. Progress is saved to your profile.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress.completionFraction,
                  backgroundColor: SwissTheme.dividerBlack.withValues(alpha: 0.2),
                  color: SwissTheme.accentRed,
                ),
                const SizedBox(height: 24),
                for (final lesson in DrivingTutorialLesson.values)
                  _LessonTile(
                    lesson: lesson,
                    done: _progress.isComplete(lesson),
                    onTap: () {
                      UiSoundService().playMenuTap();
                      _openLesson(lesson);
                    },
                  ),
              ],
            ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final DrivingTutorialLesson lesson;
  final bool done;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.pixelifySans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: SwissTheme.textPrimary,
    );
    final subStyle = AppFonts.pixelifySans(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: SwissTheme.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: SwissTheme.backgroundWhite,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: SwissTheme.borderBlack),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.play_circle_outline,
                  color: done ? SwissTheme.accentGreen : SwissTheme.textPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: titleStyle),
                      const SizedBox(height: 4),
                      Text(lesson.shortDescription, style: subStyle),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: SwissTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrivingTutorialLessonPage extends StatefulWidget {
  final DrivingTutorialLesson lesson;

  const _DrivingTutorialLessonPage({required this.lesson});

  @override
  State<_DrivingTutorialLessonPage> createState() => _DrivingTutorialLessonPageState();
}

class _DrivingTutorialLessonPageState extends State<_DrivingTutorialLessonPage> {
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _complete() async {
    if (_finishing) return;
    _finishing = true;
    await TutorialProgressService.markLessonComplete(widget.lesson);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.lesson.title} — saved',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1a1a2e),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.lesson.title, style: theme.titleMedium?.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: switch (widget.lesson) {
          DrivingTutorialLesson.gearbox => _GearboxLessonBody(onComplete: _complete),
          DrivingTutorialLesson.steering => _SteeringLessonBody(onComplete: _complete),
          DrivingTutorialLesson.turnSignals => _TurnSignalsLessonBody(onComplete: _complete),
          DrivingTutorialLesson.pedals => _PedalsLessonBody(onComplete: _complete),
        },
      ),
    );
  }
}

class _GearboxLessonBody extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _GearboxLessonBody({required this.onComplete});

  @override
  State<_GearboxLessonBody> createState() => _GearboxLessonBodyState();
}

class _GearboxLessonBodyState extends State<_GearboxLessonBody> {
  static const _gears = ['P', '1', '2', '3', '4', '5', 'R'];
  int _currentGear = 1;
  int _step = 0;

  void _onGear(int index) {
    setState(() => _currentGear = index);
    if (_step == 0 && index == 0) {
      setState(() => _step = 1);
    } else if (_step == 1 && index == 1) {
      unawaited(widget.onComplete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = _step == 0
        ? 'Tap Park (P) at the bottom of the gear pattern.'
        : 'Now tap First gear (1) at the top-right.';
    return _LessonScaffold(
      hint: hint,
      child: Center(
        child: GearboxWidget(
          currentGear: _currentGear,
          gears: _gears,
          onGearSelected: _onGear,
        ),
      ),
    );
  }
}

class _SteeringLessonBody extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _SteeringLessonBody({required this.onComplete});

  @override
  State<_SteeringLessonBody> createState() => _SteeringLessonBodyState();
}

class _SteeringLessonBodyState extends State<_SteeringLessonBody> {
  final ValueNotifier<double> _rotation = ValueNotifier<double>(0);
  bool _left = false;
  bool _right = false;
  bool _done = false;

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  void _checkDone() {
    if (_done) return;
    if (_left && _right) {
      _done = true;
      unawaited(widget.onComplete());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      hint:
          'Drag the wheel: turn it clearly left, then clearly right. (${_left ? "✓" : "·"} left · ${_right ? "✓" : "·"} right)',
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: _rotation,
          builder: (context, rotation, _) {
            return SteeringWheelWidget(
              rotation: rotation,
              onPanStart: (_) {},
              onPanUpdate: (d) {
                _rotation.value = (_rotation.value + d.delta.dx * 0.05).clamp(-2.5, 2.5);
                if (_rotation.value < -1.0) _left = true;
                if (_rotation.value > 1.0) _right = true;
                _checkDone();
              },
              onPanEnd: (_) {
                _rotation.value = 0;
                _checkDone();
              },
            );
          },
        ),
      ),
    );
  }
}

class _TurnSignalsLessonBody extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _TurnSignalsLessonBody({required this.onComplete});

  @override
  State<_TurnSignalsLessonBody> createState() => _TurnSignalsLessonBodyState();
}

class _TurnSignalsLessonBodyState extends State<_TurnSignalsLessonBody> {
  final GlobalKey _excludeHudLeftKey = GlobalKey();
  final GlobalKey _excludeHudRightKey = GlobalKey();
  final GlobalKey _listenerKey = GlobalKey();

  Timer? _turnSignalTapTimer;
  int _turnSignalTapCount = 0;
  static const Duration _turnSignalTapWindow = Duration(milliseconds: 420);
  bool _leftTurnSignalOn = false;
  bool _rightTurnSignalOn = false;
  Timer? _turnSignalBlinkTimer;
  bool _turnSignalBlinkVisible = true;

  bool _sawLeft = false;
  bool _sawRight = false;
  bool _done = false;

  @override
  void dispose() {
    _turnSignalTapTimer?.cancel();
    _turnSignalBlinkTimer?.cancel();
    super.dispose();
  }

  bool _globalHitExcludes(Offset globalPosition) {
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

  void _startBlink() {
    _turnSignalBlinkTimer?.cancel();
    _turnSignalBlinkVisible = true;
    _turnSignalBlinkTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _turnSignalBlinkVisible = !_turnSignalBlinkVisible);
    });
  }

  void _stopBlink() {
    _turnSignalBlinkTimer?.cancel();
    _turnSignalBlinkTimer = null;
    _turnSignalBlinkVisible = true;
  }

  void _tryComplete() {
    if (_done) return;
    if (_sawLeft && _sawRight) {
      _done = true;
      unawaited(widget.onComplete());
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final listenerBox =
        _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (listenerBox == null || !listenerBox.attached) return;
    final global = listenerBox.localToGlobal(event.localPosition);
    if (_globalHitExcludes(global)) return;

    if (_leftTurnSignalOn || _rightTurnSignalOn) {
      _turnSignalTapTimer?.cancel();
      _turnSignalTapCount = 0;
      _stopBlink();
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
          _sawLeft = true;
        });
        _startBlink();
        _tryComplete();
      } else if (n >= 3) {
        setState(() {
          _rightTurnSignalOn = true;
          _leftTurnSignalOn = false;
          _sawRight = true;
        });
        _startBlink();
        _tryComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      hint:
          'Double-tap an empty area for left signal, triple-tap for right (same as in a level). ${_sawLeft ? "✓" : "·"} left · ${_sawRight ? "✓" : "·"} right',
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Listener(
              key: _listenerKey,
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: KeyedSubtree(
              key: _excludeHudLeftKey,
              child: Container(
                width: 160,
                height: 140,
                alignment: Alignment.topLeft,
                color: Colors.white10,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Pedals stay here in-game',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: KeyedSubtree(
              key: _excludeHudRightKey,
              child: Container(
                width: 140,
                height: 260,
                alignment: Alignment.center,
                color: Colors.white10,
                child: const Text(
                  'Gear & wheel',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (_leftTurnSignalOn || _rightTurnSignalOn)
            Positioned(
              top: 16,
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
    );
  }
}

class _PedalsLessonBody extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _PedalsLessonBody({required this.onComplete});

  @override
  State<_PedalsLessonBody> createState() => _PedalsLessonBodyState();
}

class _PedalsLessonBodyState extends State<_PedalsLessonBody> {
  Timer? _holdTimer;
  bool _done = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onAccelDown() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 450), () {
      if (_done || !mounted) return;
      _done = true;
      unawaited(widget.onComplete());
    });
  }

  void _onAccelUp() {
    _holdTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      hint: 'Hold the accelerator (green) for about half a second.',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: PedalsWidget(
            onAcceleratorDown: _onAccelDown,
            onAcceleratorUp: _onAccelUp,
            onBrakeDown: () {},
            onBrakeUp: () {},
          ),
        ),
      ),
    );
  }
}

class _LessonScaffold extends StatelessWidget {
  final String hint;
  final Widget child;

  const _LessonScaffold({required this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.3,
                ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
