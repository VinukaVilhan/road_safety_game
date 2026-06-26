import 'package:flutter/material.dart';

import '../constants/media_assets.dart';

class PedalsWidget extends StatefulWidget {
  final VoidCallback onAcceleratorDown;
  final VoidCallback onAcceleratorUp;
  final VoidCallback onBrakeDown;
  final VoidCallback onBrakeUp;

  const PedalsWidget({
    super.key,
    required this.onAcceleratorDown,
    required this.onAcceleratorUp,
    required this.onBrakeDown,
    required this.onBrakeUp,
  });

  @override
  State<PedalsWidget> createState() => _PedalsWidgetState();
}

class _PedalsWidgetState extends State<PedalsWidget> {
  bool _isAcceleratorPressed = false;
  bool _isBrakePressed = false;

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
          onTapDown: () {
            setState(() => _isAcceleratorPressed = true);
            widget.onAcceleratorDown();
          },
          onTapUp: () {
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
            onTapDown: () {
              setState(() => _isBrakePressed = true);
              widget.onBrakeDown();
            },
            onTapUp: () {
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
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
  }) {
    final imagePath = isPressed ? pressedImagePath : normalImagePath;
    
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      child: Container(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        width: 120,  // Increased from 90 (33% larger for better touch area)
        height: 110, // Increased from 80 (37.5% larger)
        alignment: Alignment.centerLeft,
        child: Image.asset(
          imagePath,
          width: 100,  // Increased from 70 (43% larger for better visibility)
          height: 110, // Increased from 80 (37.5% larger)
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (context, error, stackTrace) {
            // Debug: Show error info to help diagnose
            debugPrint('Failed to load image: $imagePath');
            debugPrint('Error: $error');
            // Return a placeholder container with error indicator
            return Container(
              width: 70,  // Increased from 50
              height: 80,  // Increased from 60
              color: Colors.grey[300],
              child: const Icon(Icons.error_outline, color: Colors.red),
            );
          },
        ),
      ),
    );
  }
}