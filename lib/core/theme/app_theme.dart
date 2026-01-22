import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette inspired by vintage telegraph equipment
/// and warm brass/copper tones of old radio equipment
class AppColors {
  // Primary palette - warm brass and copper tones
  static const Color brass = Color(0xFFD4A84B);
  static const Color copper = Color(0xFFB87333);
  static const Color bronze = Color(0xFF8B6914);
  
  // Background palette - dark wood and bakelite tones
  static const Color darkWood = Color(0xFF1A1512);
  static const Color bakelite = Color(0xFF2D2420);
  static const Color mahogany = Color(0xFF3D2B1F);
  
  // Accent colors
  static const Color signalGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFA726);
  static const Color errorRed = Color(0xFFE53935);
  
  // Text colors
  static const Color textPrimary = Color(0xFFF5E6D3);
  static const Color textSecondary = Color(0xFFB8A590);
  static const Color textMuted = Color(0xFF7A6B5A);
  
  // UI element colors
  static const Color cardBackground = Color(0xFF2A2118);
  static const Color divider = Color(0xFF4A3F35);
  static const Color inputBackground = Color(0xFF1F1A15);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkWood,
      
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brass,
        secondary: AppColors.copper,
        surface: AppColors.bakelite,
        error: AppColors.errorRed,
        onPrimary: AppColors.darkWood,
        onSecondary: AppColors.darkWood,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      
      textTheme: GoogleFonts.sourceCodeProTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
          displayMedium: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 2,
          ),
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.brass,
            letterSpacing: 1.5,
          ),
        ),
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.brass),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 2,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brass,
          foregroundColor: AppColors.darkWood,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brass,
          side: const BorderSide(color: AppColors.brass, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      iconTheme: const IconThemeData(
        color: AppColors.brass,
        size: 24,
      ),
      
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brass,
        linearTrackColor: AppColors.mahogany,
      ),
    );
  }
}
