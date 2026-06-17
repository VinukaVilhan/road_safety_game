import 'package:flutter/material.dart';

import '../services/audio/fm_radio_service.dart';

/// API-only FM launcher: opens the device FM app via platform channel.
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
  Future<void> _openFmApp(BuildContext context) async {
    final ok = await FmRadioService.openDeviceFmRadioApp();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Opened FM Radio app. Use wired headphones as the antenna if prompted.'
              : 'No built-in FM app found on this device.',
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
              'Tap the button below to launch your phone FM app using the API integration.',
              style: theme.bodySmall!.copyWith(color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openFmApp(context),
              icon: const Icon(Icons.radio),
              label: const Text('Open phone FM'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
