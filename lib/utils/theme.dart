import 'package:flutter/material.dart';

class AppColors {
  // Strict minimal palette
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray = Color(0xFF808080);
  
  // Semantic colors for specific use cases
  static const Color border = Color(0xFF808080);
  static const Color divider = Color(0xFF404040);
  static const Color cardBackground = Color(0xFF0A0A0A);
  static const Color success = Color(0xFFFFFFFF);
  static const Color error = Color(0xFF808080);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      primaryColor: AppColors.white,
      fontFamily: 'Inter',
      
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.white,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.white,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.white, width: 1),
        ),
        labelStyle: const TextStyle(color: AppColors.gray),
        hintStyle: const TextStyle(color: AppColors.gray),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.white, size: 20),
      ),
    );
  }
}

// Minimal container wrapper (no glow effects)
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double? blurRadius;
  final double? spreadRadius;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor,
    this.blurRadius,
    this.spreadRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Return child directly without any effects for minimal design
    return child;
  }
}
