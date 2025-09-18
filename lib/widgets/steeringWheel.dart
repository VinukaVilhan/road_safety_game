import 'package:flutter/material.dart';

class SteeringWheelWidget extends StatelessWidget {
  final double rotation;
  final Function(DragStartDetails) onPanStart;
  final Function(DragUpdateDetails) onPanUpdate;
  final Function(DragEndDetails) onPanEnd;

  const SteeringWheelWidget({
    super.key,
    required this.rotation,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: rotation,
          child: ClipOval(
            child: Image.asset(
              'assets/images/SteeringWheel.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback UI if image fails to load
                return _buildFallbackSteeringWheel();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackSteeringWheel() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.grey[700]!,
            Colors.grey[900]!,
          ],
        ),
        border: Border.all(color: Colors.grey[600]!, width: 3),
      ),
      child: Stack(
        children: [
          // Center hub
          Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                border: Border.all(color: Colors.grey[500]!, width: 2),
              ),
              child: Icon(
                Icons.center_focus_strong,
                color: Colors.grey[400],
                size: 16,
              ),
            ),
          ),
          // Spokes
          ...List.generate(4, (index) {
            return Transform.rotate(
              angle: (index * 3.14159 / 2),
              child: Center(
                child: Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}