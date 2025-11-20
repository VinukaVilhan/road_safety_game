import 'package:flutter/material.dart';

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
          normalImagePath: 'assets/images/rescaled/gas_normal.png',
          pressedImagePath: 'assets/images/rescaled/gas_pressed.png',
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
          offset: const Offset(-15, 0),
          child: _buildPedal(
            normalImagePath: 'assets/images/rescaled/brake_normal.png',
            pressedImagePath: 'assets/images/rescaled/brake_pressed.png',
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
        width: 90,  // Increased width for larger touch area
        height: 80,
        alignment: Alignment.centerLeft,
        child: Image.asset(
          imagePath,
          width: 70,  // Image stays at 70, but container is 90 for larger touch area
          height: 80,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (context, error, stackTrace) {
            // Debug: Show error info to help diagnose
            debugPrint('Failed to load image: $imagePath');
            debugPrint('Error: $error');
            // Return a placeholder container with error indicator
            return Container(
              width: 50,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.error_outline, color: Colors.red),
            );
          },
        ),
      ),
    );
  }
}