import 'package:flutter/material.dart';

import '../constants/media_assets.dart';

class PedalsWidget extends StatefulWidget {
  final VoidCallback onAcceleratorDown;
  final VoidCallback onAcceleratorUp;
  final VoidCallback onBrakeDown;
  final VoidCallback onBrakeUp;
  final bool acceleratorEnabled;
  final bool brakeEnabled;

  const PedalsWidget({
    super.key,
    required this.onAcceleratorDown,
    required this.onAcceleratorUp,
    required this.onBrakeDown,
    required this.onBrakeUp,
    this.acceleratorEnabled = true,
    this.brakeEnabled = true,
  });

  @override
  State<PedalsWidget> createState() => _PedalsWidgetState();
}

class _PedalsWidgetState extends State<PedalsWidget> {
  bool _isAcceleratorPressed = false;
  bool _isBrakePressed = false;

  @override
  void didUpdateWidget(PedalsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.acceleratorEnabled && !widget.acceleratorEnabled) {
      if (_isAcceleratorPressed) {
        _isAcceleratorPressed = false;
        widget.onAcceleratorUp();
      }
    }
    if (oldWidget.brakeEnabled && !widget.brakeEnabled) {
      if (_isBrakePressed) {
        _isBrakePressed = false;
        widget.onBrakeUp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        // Accelerator (Gas)
        _buildPedal(
          normalImagePath: MediaAssets.gasNormalRescaled,
          pressedImagePath: MediaAssets.gasPressedRescaled,
          isPressed: _isAcceleratorPressed,
          enabled: widget.acceleratorEnabled,
          onTapDown: () {
            if (!widget.acceleratorEnabled) return;
            setState(() => _isAcceleratorPressed = true);
            widget.onAcceleratorDown();
          },
          onTapUp: () {
            if (!widget.acceleratorEnabled) return;
            setState(() => _isAcceleratorPressed = false);
            widget.onAcceleratorUp();
          },
        ),

        // Brake - negative margin to bring closer
        Transform.translate(
          offset: const Offset(-50, 0),
          child: _buildPedal(
            normalImagePath: MediaAssets.brakeNormalRescaled,
            pressedImagePath: MediaAssets.brakePressedRescaled,
            isPressed: _isBrakePressed,
            enabled: widget.brakeEnabled,
            onTapDown: () {
              if (!widget.brakeEnabled) return;
              setState(() => _isBrakePressed = true);
              widget.onBrakeDown();
            },
            onTapUp: () {
              if (!widget.brakeEnabled) return;
              setState(() => _isBrakePressed = false);
              widget.onBrakeUp();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPedal({
    required String normalImagePath,
    required String pressedImagePath,
    required bool isPressed,
    required bool enabled,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
  }) {
    final imagePath = isPressed ? pressedImagePath : normalImagePath;

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: GestureDetector(
          onTapDown: (_) => onTapDown(),
          onTapUp: (_) => onTapUp(),
          onTapCancel: () => onTapUp(),
          child: Container(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            width: 120,
            height: 110,
            alignment: Alignment.centerLeft,
            child: Image.asset(
              imagePath,
              width: 100,
              height: 110,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Failed to load image: $imagePath');
                debugPrint('Error: $error');
                return Container(
                  width: 70,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error_outline, color: Colors.red),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
