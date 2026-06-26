import 'package:flutter/material.dart';

import '../../game/driving_game.dart';

/// Popup when the player enters the yellow **Check_Layer** on adverse weather maps.
Future<void> showWeatherPrecheckDialog({
  required BuildContext context,
  required WeatherCheckPromptRequest request,
}) {
  var headlights = false;
  var windshield = false;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final canContinue = (!request.requireHeadlights || headlights) &&
              (!request.requireWindshield || windshield);

          return AlertDialog(
            backgroundColor: const Color(0xFF1A2332),
            title: Text(
              request.title,
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    request.message,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: headlights,
                    onChanged: (v) => setState(() => headlights = v),
                    title: const Text(
                      'Headlights',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Low beams for rain visibility',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  SwitchListTile(
                    value: windshield,
                    onChanged: (v) => setState(() => windshield = v),
                    title: const Text(
                      'Windshield wipers',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Clears rain on the windscreen',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: canContinue
                    ? () {
                        Navigator.of(ctx).pop();
                        request.onSubmit(
                          headlights: headlights,
                          windshield: windshield,
                        );
                      }
                    : null,
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );
}
