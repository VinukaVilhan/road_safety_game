import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font helper utility that uses bundled fonts when available,
/// with fallback to Google Fonts for optimal performance.
/// 
/// Industry-standard approach: Bundle fonts for best performance,
/// but keep Google Fonts as fallback for development.
class AppFonts {
  // Font family names - match pubspec.yaml
  static const String interFamily = 'Inter';
  static const String robotoMonoFamily = 'RobotoMono';
  static const String pixelifySansFamily = 'PixelifySans';
  
  // Check if bundled fonts are available
  // We check by trying to load the font - if it's not available,
  // Flutter will fall back to system fonts, so we use Google Fonts instead
  static bool _hasBundledFonts = false;
  static bool _checkedBundledFonts = false;
  
  static bool get hasBundledFonts {
    if (!_checkedBundledFonts) {
      // Fonts are bundled as assets in pubspec.yaml
      // Variable fonts support all weights automatically
      _hasBundledFonts = true;
      _checkedBundledFonts = true;
    }
    return _hasBundledFonts;
  }
  
  /// Call this method after fonts are confirmed to be bundled
  static void enableBundledFonts() {
    _hasBundledFonts = true;
    _checkedBundledFonts = true;
  }
  
  /// Get Inter font with specified properties
  /// Uses bundled font if available, otherwise Google Fonts
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    if (_hasBundledFonts) {
      return TextStyle(
        fontFamily: interFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );
    }
    
    // Fallback to Google Fonts
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
  
  /// Get Roboto Mono font with specified properties
  /// Uses bundled font if available, otherwise Google Fonts
  static TextStyle robotoMono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    if (_hasBundledFonts) {
      return TextStyle(
        fontFamily: robotoMonoFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    
    // Fallback to Google Fonts
    return GoogleFonts.robotoMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
  
  /// Pixelify Sans — used for the practical driving test game UI.
  static TextStyle pixelifySans({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: pixelifySansFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: fontFeatures,
    );
  }

  /// Text theme using Pixelify Sans for the driving test screen.
  static TextTheme get drivingGameTextTheme {
    return TextTheme(
      displayLarge: pixelifySans(fontSize: 80, fontWeight: FontWeight.w900),
      displayMedium: pixelifySans(fontSize: 48, fontWeight: FontWeight.w900),
      displaySmall: pixelifySans(fontSize: 32, fontWeight: FontWeight.w700),
      headlineLarge: pixelifySans(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium: pixelifySans(fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: pixelifySans(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: pixelifySans(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: pixelifySans(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: pixelifySans(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: pixelifySans(fontSize: 14, fontWeight: FontWeight.w400),
      bodyMedium: pixelifySans(fontSize: 12, fontWeight: FontWeight.w400),
      bodySmall: pixelifySans(fontSize: 10, fontWeight: FontWeight.w400),
      labelLarge: pixelifySans(fontSize: 12, fontWeight: FontWeight.w600),
      labelMedium: pixelifySans(fontSize: 10, fontWeight: FontWeight.w600),
      labelSmall: pixelifySans(fontSize: 10, fontWeight: FontWeight.w500),
    );
  }

  /// Get Inter text theme (for theme configuration)
  static TextTheme get interTextTheme {
    if (_hasBundledFonts) {
      return TextTheme(
        displayLarge: inter(fontSize: 80, fontWeight: FontWeight.w900),
        displayMedium: inter(fontSize: 48, fontWeight: FontWeight.w900),
        displaySmall: inter(fontSize: 32, fontWeight: FontWeight.w700),
        headlineMedium: inter(fontSize: 24, fontWeight: FontWeight.w600),
        bodyLarge: inter(fontSize: 14, fontWeight: FontWeight.w400),
        bodyMedium: inter(fontSize: 12, fontWeight: FontWeight.w400),
        bodySmall: inter(fontSize: 10, fontWeight: FontWeight.w400),
      );
    }
    
    return GoogleFonts.interTextTheme();
  }
}

