import 'package:flutter/material.dart';

/// Animated HUD sign shown during road-crossing levels after spawn-sign entry.
class PedestrianCrossingSignHud extends StatelessWidget {
  const PedestrianCrossingSignHud({
    super.key,
    required this.signAssetPath,
    this.distanceMeters,
  });

  final String signAssetPath;
  final int? distanceMeters;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final clamped = t.clamp(0.0, 1.0);
        return Transform.scale(
          scale: clamped,
          alignment: Alignment.bottomLeft,
          child: Opacity(opacity: clamped, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              signAssetPath,
              width: 88,
              height: 88,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_walk,
                color: Colors.white,
                size: 72,
              ),
            ),
            if (distanceMeters != null) ...[
              const SizedBox(height: 4),
              Text(
                '${distanceMeters}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
