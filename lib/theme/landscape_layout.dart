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

  /// Left chat-history rail on assistant chat.
  static double chatSidebarWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 960) return 300;
    if (w >= 720) return 260;
    return 220;
  }

  static const double chatSidebarRailWidth = 40;

  /// Width of the message column for the given sidebar state.
  static double chatMessagePaneWidth(BuildContext context, {required bool sidebarExpanded}) {
    final total = MediaQuery.sizeOf(context).width;
    final rail = sidebarExpanded ? chatSidebarWidth(context) : chatSidebarRailWidth;
    return (total - rail - 1).clamp(280.0, total);
  }

  /// Max width for a single chat bubble in the message column.
  static double chatBubbleMaxWidth(
    BuildContext context, {
    required bool sidebarExpanded,
  }) {
    return chatMessagePaneWidth(context, sidebarExpanded: sidebarExpanded).clamp(280.0, 520.0) *
        0.72;
  }

  /// Practical driving session report — uses most of the landscape viewport.
  static EdgeInsets drivingReportDialogInsetPadding(BuildContext context) {
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  }

  static BoxConstraints drivingReportDialogConstraints(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return BoxConstraints(
      maxWidth: (size.width * 0.94).clamp(640.0, 960.0),
      maxHeight: size.height * 0.9,
    );
  }
}
