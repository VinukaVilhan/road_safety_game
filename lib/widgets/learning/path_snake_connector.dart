import 'package:flutter/material.dart';

import '../../theme/swiss_theme.dart';

/// Curved vertical segment between snake-path nodes (alternating left / right).
class PathSnakeConnector extends StatelessWidget {
  final bool fromLeft;
  final bool toLeft;
  final bool done;

  const PathSnakeConnector({
    super.key,
    required this.fromLeft,
    required this.toLeft,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: CustomPaint(
        painter: _PathSnakeConnectorPainter(
          fromLeft: fromLeft,
          toLeft: toLeft,
          done: done,
        ),
      ),
    );
  }
}

class _PathSnakeConnectorPainter extends CustomPainter {
  final bool fromLeft;
  final bool toLeft;
  final bool done;

  _PathSnakeConnectorPainter({
    required this.fromLeft,
    required this.toLeft,
    required this.done,
  });

  static const _nodeHalfWidth = 80.0;
  static const _sideInset = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = done ? SwissTheme.accentGreen : SwissTheme.dividerBlack
      ..strokeWidth = done ? 2.5 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = fromLeft ? _sideInset + _nodeHalfWidth : size.width - _sideInset - _nodeHalfWidth;
    final endX = toLeft ? _sideInset + _nodeHalfWidth : size.width - _sideInset - _nodeHalfWidth;

    final path = Path()
      ..moveTo(startX, 0)
      ..cubicTo(
        startX,
        size.height * 0.45,
        endX,
        size.height * 0.55,
        endX,
        size.height,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathSnakeConnectorPainter oldDelegate) {
    return oldDelegate.fromLeft != fromLeft ||
        oldDelegate.toLeft != toLeft ||
        oldDelegate.done != done;
  }
}
