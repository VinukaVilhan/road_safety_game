import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swiss Design (International Typographic Style) Theme
/// 
/// A minimalist, grid-based, typographic-led design system inspired by
/// mid-20th century Swiss graphic design principles.

class SwissTheme {
  // Color Palette
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundLightGrey = Color(0xFFF8F9FA);
  
  static const Color textPrimary = Color(0xFF111111); // Jet Black
  static const Color textSecondary = Color(0xFF555555); // Dark Grey
  
  // Accent Colors
  static const Color accentRed = Color(0xFFFF3B30); // Swiss Red
  static const Color accentGreen = Color(0xFF00C853); // Traffic Green
  static const Color accentBlue = Color(0xFF0055FF); // International Blue
  static const Color accentOrange = Color(0xFFFF9500); // Signal Orange
  
  // Functional Colors
  static const Color dividerBlack = Color(0xFF000000);
  static const Color borderBlack = Color(0xFF000000);
  
  /// Main theme data for the application
  static ThemeData get themeData {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 80,
        fontWeight: FontWeight.w900,
        height: 0.9, // Tight line height
        letterSpacing: -1.0,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        height: 0.9,
        letterSpacing: -1.0,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
    );
    
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundWhite,
      primaryColor: accentRed,
      
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: accentRed,
        secondary: accentBlue,
        surface: backgroundWhite,
        background: backgroundWhite,
        error: accentRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: Colors.white,
      ),
      
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: backgroundWhite,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: borderBlack, width: 2),
        ),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerBlack,
        thickness: 1,
        space: 1,
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: backgroundWhite,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: borderBlack, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
      ),
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }
  
  /// Get monospaced font for technical data display
  static TextStyle get monospacedText {
    return GoogleFonts.robotoMono(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: textSecondary,
    );
  }
}

