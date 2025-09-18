import 'package:flutter/material.dart';

class PedalsWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Accelerator (Gas)
        _buildPedal(
          width: 50,
          height: 60,
          colors: [Colors.green[600]!, Colors.green[800]!],
          borderColor: Colors.green[400]!,
          imagePath: 'assets/images/Accelerator.png',
          label: 'GAS',
          onTapDown: onAcceleratorDown,
          onTapUp: onAcceleratorUp,
          marginRight: 8,
        ),
        
        // Brake
        _buildPedal(
          width: 50,
          height: 60,
          colors: [Colors.red[600]!, Colors.red[800]!],
          borderColor: Colors.red[400]!,
          imagePath: 'assets/images/Brake.png',
          label: 'BRAKE',
          onTapDown: onBrakeDown,
          onTapUp: onBrakeUp,
          labelFontSize: 8,
        ),
      ],
    );
  }

  Widget _buildPedal({
    required double width,
    required double height,
    required List<Color> colors,
    required Color borderColor,
    required String imagePath,
    required String label,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
    double marginRight = 0,
    double labelFontSize = 9,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      child: Container(
        width: width,
        height: height,
        margin: EdgeInsets.only(right: marginRight),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: 24,
              height: 24,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if image fails to load
                return Icon(
                  label == 'GAS' ? Icons.local_gas_station : Icons.stop,
                  color: Colors.white,
                  size: 24,
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}