import 'package:flutter/material.dart';

/// Spacing and grid tuning for the landscape-only app.
abstract final class LandscapeLayout {
  static const double horizontalGutter = 24;
  static const double verticalGutter = 16;
  static const double sectionGap = 16;
  static const double menuItemGap = 12;

  static EdgeInsets headerPadding(BuildContext context) {
    return const EdgeInsets.fromLTRB(24, 16, 24, 12);
  }

  static EdgeInsets bodyPadding(BuildContext context) {
    return const EdgeInsets.fromLTRB(16, 8, 16, 16);
  }

  static EdgeInsets screenPadding(BuildContext context) {
    return const EdgeInsets.fromLTRB(24, 16, 24, 16);
  }

  static EdgeInsets authPadding(BuildContext context) {
    return const EdgeInsets.fromLTRB(24, 16, 24, 16);
  }

  static int selectionGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 960) return 4;
    if (w >= 640) return 3;
    return 2;
  }

  static double selectionGridAspectRatio(BuildContext context) {
    final cols = selectionGridColumns(context);
    if (cols >= 4) return 1.35;
    if (cols >= 3) return 1.2;
    return 1.05;
  }

  static SliverGridDelegate selectionGridDelegate(BuildContext context) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: selectionGridColumns(context),
      crossAxisSpacing: 1,
      mainAxisSpacing: 1,
      childAspectRatio: selectionGridAspectRatio(context),
    );
  }

  static int listCardGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 800) return 3;
    return 2;
  }

  static SliverGridDelegate listCardGridDelegate(BuildContext context) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: listCardGridColumns(context),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.8,
    );
  }

  static Widget bodyMaxWidth({
    required Widget child,
    double maxWidth = 1100,
    Alignment alignment = Alignment.topCenter,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
