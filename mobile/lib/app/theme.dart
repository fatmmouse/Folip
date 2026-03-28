import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color dominant = Color(0xFFFAF9F5);
  static const Color secondary = Color(0xFFE8E6DC);
  static const Color accent = Color(0xFFD97757);
  static const Color destructive = Color(0xFFC53030);
  static const Color success = Color(0xFF788C5D);
  static const Color textPrimary = Color(0xFF141413);
  static const Color textSecondary = Color(0xFFB0AEA5);
  static const Color loginBg = Color(0xFF141413);
  static const Color loginText = Color(0xFFFAF9F5);
  static const Color loginInputBg = Color(0xFF2A2A29);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.dominant,
      onSurface: AppColors.textPrimary,
      error: AppColors.destructive,
    ),
    scaffoldBackgroundColor: AppColors.dominant,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.0,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.sourceSerif4(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.dominant,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.sourceSerif4(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.secondary,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
  );
}
