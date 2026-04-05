import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/fm_radio_service.dart';
import '../services/music_service.dart';

/// FM-style tuner: user opens the device FM app, tunes hardware, then matches
/// this dial to the shown target frequency (game cannot read the hardware tuner).
class RadioTunerSheet extends StatefulWidget {
  const RadioTunerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const RadioTunerSheet(),
    );
  }

  @override
  State<RadioTunerSheet> createState() => _RadioTunerSheetState();
}

class _RadioTunerSheetState extends State<RadioTunerSheet> {
  static const double _minMhz = 87.5;
  static const double _maxMhz = 108.0;
  /// How close the dial must be to count as "tuned" (typical FM step ~0.1–0.2).
  static const double _lockToleranceMhz = 0.15;

  late final double _targetMhz;
  double _dialMhz = 98.0;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    final steps = ((_maxMhz - _minMhz) * 10).round();
    _targetMhz = _minMhz + rng.nextInt(steps + 1) / 10.0;
    _dialMhz = _minMhz + rng.nextInt(steps + 1) / 10.0;
  }

  bool get _locked =>
      (_dialMhz - _targetMhz).abs() <= _lockToleranceMhz;

  Future<void> _openFmApp(BuildContext context) async {
    final ok = await FmRadioService.openDeviceFmRadioApp();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Opened FM Radio app. Use wired headphones as the antenna if prompted.'
              : 'No built-in FM app found. Use Internet radio below or your phone\'s store.',
        ),
        backgroundColor: const Color(0xFF1a1a2e),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final music = MusicService();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FM radio',
              style: theme.titleMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Tap “Open phone FM” and tune your device to a station.\n'
              '2. Move the dial below to the same MHz until it locks.',
              style: theme.bodySmall!.copyWith(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Target channel',
                  style: theme.bodyMedium!.copyWith(color: Colors.white70),
                ),
                Text(
                  '${_targetMhz.toStringAsFixed(1)} MHz',
                  style: theme.titleLarge!.copyWith(
                    color: const Color(0xFF7CFC00),
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your dial',
                  style: theme.bodyMedium!.copyWith(color: Colors.white70),
                ),
                Text(
                  '${_dialMhz.toStringAsFixed(1)} MHz',
                  style: theme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Slider(
              value: _dialMhz.clamp(_minMhz, _maxMhz),
              min: _minMhz,
              max: _maxMhz,
              divisions: ((_maxMhz - _minMhz) * 10).round(),
              label: '${_dialMhz.toStringAsFixed(1)} MHz',
              activeColor: _locked ? const Color(0xFF7CFC00) : Colors.amber,
              onChanged: (v) => setState(() => _dialMhz = v),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _locked
                  ? Padding(
                      key: const ValueKey('locked'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Locked — matches target (same as your phone tuner)',
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium!.copyWith(
                          color: const Color(0xFF7CFC00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('open'), height: 12),
            ),
            FilledButton.icon(
              onPressed: () => _openFmApp(context),
              icon: const Icon(Icons.radio),
              label: const Text('Open phone FM'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await music.openRadioUrl('https://www.internet-radio.com/');
              },
              icon: const Icon(Icons.cloud, color: Colors.white54),
              label: const Text('Internet radio (browser)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
