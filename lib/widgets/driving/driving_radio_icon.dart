import 'package:flutter/material.dart';

import '../../constants/media_assets.dart';

/// In-game radio button icon with asset fallback.
class DrivingRadioIcon extends StatelessWidget {
  const DrivingRadioIcon({
    super.key,
    this.size = 32,
    this.fallbackColor = Colors.white,
  });

  static const String assetPath = MediaAssets.radioIcon;

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.radio,
        color: fallbackColor,
        size: size,
      ),
    );
  }
}
