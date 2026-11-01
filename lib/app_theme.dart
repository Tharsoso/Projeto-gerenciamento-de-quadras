import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const green = Color(0xFF1B5E20);
  static const greenDark = Color(0xFF0F3D14);
  static const greenMid = Color(0xFF2E7D32);
  static const greenTint = Color(0xFFE8F5E9);
  static const greenTint2 = Color(0xFFC8E6C9);
  static const ball = Color(0xFFD8F31A);
  static const ballDark = Color(0xFFB5CC0A);
  static const ink = Color(0xFF0E1A10);
  static const muted = Color(0xFF587060);
  static const line = Color(0xFFDCE5DD);
  static const bg = Color(0xFFFFFFFF);
  static const surf = Color(0xFFF5F8F4);
  static const paper = Color(0xFFF3F2F0);

  static const red = Color(0xFFC62828);
  static const redTint = Color(0xFFFDECEA);
  static const brown = Color(0xFF6D4C41);
  static const brownTint = Color(0xFFEFEBE9);
  static const orange = Color(0xFFE65100);
  static const orangeTint = Color(0xFFFFF1DE);
  static const gray = Color(0xFF8E978F);
  static const grayTint = Color(0xFFECEFEC);
  static const clay = Color(0xFFC4572D);
}

class AppTheme {
  static TextStyle display({
    double size = 48,
    FontWeight weight = FontWeight.w900,
    Color? color,
    double letterSpacing = 0.5,
    double height = 0.85,
  }) =>
      GoogleFonts.bigShouldersDisplay(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle serif({
    double size = 32,
    Color? color,
    FontStyle style = FontStyle.italic,
  }) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        fontStyle: style,
        color: color,
        height: 1,
      );

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 1.8,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: AppColors.green,
        onPrimary: Colors.white,
        secondary: AppColors.ball,
        onSecondary: AppColors.ink,
        surface: Colors.white,
        onSurface: AppColors.ink,
        error: AppColors.red,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        color: Colors.white,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        labelStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: const StadiumBorder(),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
