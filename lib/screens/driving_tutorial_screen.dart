import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_launch_context.dart';
import '../models/tutorial_progress.dart';
import '../services/ui_sound_service.dart';
import '../widgets/assistant_button.dart';
import '../theme/swiss_theme.dart';
import '../utils/app_fonts.dart';
import '../widgets/control_gearbox.dart';
import '../widgets/pedals.dart';
import '../widgets/steeringWheel.dart';

/// Lists control tutorials as a non-tracked reference/practice area.
class DrivingTutorialScreen extends StatefulWidget {
  const DrivingTutorialScreen({super.key});

  @override
  State<DrivingTutorialScreen> createState() => _DrivingTutorialScreenState();
}

class _DrivingTutorialScreenState extends State<DrivingTutorialScreen> {
  Future<void> _openLesson(DrivingTutorialLesson lesson) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _DrivingTutorialLessonPage(lesson: lesson),
      ),
    );
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
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: const AssistantButton(
        heroTag: 'assistant_driving_tutorial_menu',
        launchContext: AssistantLaunchContext(
          screenTitle: 'Controls — driving tutorials',
          includeFullRoadSignCatalog: true,
        ),
      ),
      appBar: AppBar(
        backgroundColor: SwissTheme.backgroundWhite,
        foregroundColor: SwissTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_sharp),
          onPressed: () {
            UiSoundService().playMenuTap();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Controls', style: titleStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Text(
            'Use this page as a controls guide. Nothing here tracks progress.',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          for (final lesson in DrivingTutorialLesson.values)
            _LessonTile(
              lesson: lesson,
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
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
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
                  Icons.play_circle_outline,
                  color: SwissTheme.textPrimary,
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

  Future<void> _complete() async {}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_sharp),
          onPressed: () {
            UiSoundService().playMenuTap();
            Navigator.of(context).pop();
          },
        ),
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
  static const _gears = ['P', '1', '2', '3', '4', 'R'];
  int _currentGear = 1;
  void _onGear(int index) => setState(() => _currentGear = index);

  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      title: 'Gearbox',
      bullets: const [
        'P - Park: locks movement.',
        'R - Reverse: move backward.',
        '1-4 - Forward gears: move ahead.',
        'Lower gears (1-2): more pulling power, slower speed.',
        'Higher gears (3-4): less pull, smoother/faster cruising.',
      ],
      child: Center(
        child: ControlGearboxWidget(
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

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      title: 'Steering Wheel',
      bullets: const [
        'Turn left -> car goes left.',
        'Turn right -> car goes right.',
        'Keep wheel near center for straight driving.',
      ],
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: _rotation,
          builder: (context, rotation, _) {
            return SteeringWheelWidget(
              rotation: rotation,
              onPanStart: (_) {},
              onPanUpdate: (d) {
                _rotation.value = (_rotation.value + d.delta.dx * 0.05).clamp(-2.5, 2.5);
              },
              onPanEnd: (_) {
                _rotation.value = 0;
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
        });
        _startBlink();
      } else if (n >= 3) {
        setState(() {
          _rightTurnSignalOn = true;
          _leftTurnSignalOn = false;
        });
        _startBlink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      title: 'Turn Signals',
      bullets: const [
        'Double tap empty area -> LEFT signal.',
        'Triple tap empty area -> RIGHT signal.',
        'Single tap while signal is ON -> turn it OFF.',
      ],
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
  @override
  Widget build(BuildContext context) {
    return _LessonScaffold(
      title: 'Pedals',
      bullets: const [
        'Accelerator (green): speed up.',
        'Brake (red): slow down.',
        'Release both: car coasts.',
      ],
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: PedalsWidget(
            onAcceleratorDown: () {},
            onAcceleratorUp: () {},
            onBrakeDown: () {},
            onBrakeUp: () {},
          ),
        ),
      ),
    );
  }
}

class _LessonScaffold extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final Widget child;

  const _LessonScaffold({
    required this.title,
    required this.bullets,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
    final bulletStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
          height: 1.3,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white10,
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: headingStyle),
              const SizedBox(height: 8),
              for (final item in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item', style: bulletStyle),
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
