import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light theme (Lovable exact oklch -> hex)
  static const bg = Color(0xFFEAF2EE);           // --background: oklch(0.978 0.008 150)
  static const card = Colors.white;               // --card: oklch(1 0 0)
  static const elevated = Color(0xFFEDF5F0);      // --elevated: oklch(0.965 0.012 160)
  static const primary = Color(0xFF0B8457);       // --primary: oklch(0.56 0.12 172)
  static const primaryForeground = Color(0xFFF8FFF9); // --primary-foreground
  static const muted = Color(0xFFEAF2EE);         // --muted: oklch(0.955 0.01 160)
  static const mutedForeground = Color(0xFF7A8A8E);   // --muted-foreground: oklch(0.55 0.02 190)
  static const success = Color(0xFF16A34A);       // --success: oklch(0.62 0.15 155)
  static const warning = Color(0xFFF59E0B);       // --warning: oklch(0.75 0.15 75)
  static const danger = Color(0xFFDC2626);        // --danger: oklch(0.6 0.19 25)
  static const info = Color(0xFF3B82F6);          // --info: oklch(0.6 0.13 240)
  static const border = Color(0xFFE5E7EB);        // --border: oklch(0.9 0.012 170)
  static const divider = Color(0xFFE5E7EB);       // alias for BorderSide usage
  static const textPrimary = Color(0xFF1C2B2E);   // --foreground: oklch(0.22 0.03 175)
  static const textSecondary = Color(0xFF7A8A8E); // --muted-foreground
  static const chipUnselected = Color(0xFFF3F4F6);
  static const accent = Color(0xFFF59E0B);       // amber
  static const income = Color(0xFF0F9D58);       // income green
  static const primaryDark = Color(0xFF0F5B3F);  // darker primary for gradients

  // Category colors (--cat-*)
  static const catFood = Color(0xFFF59E0B);       // --cat-food: oklch(0.68 0.16 45)
  static const catTransport = Color(0xFF3B82F6);  // --cat-transport: oklch(0.62 0.14 240)
  static const catRent = Color(0xFF8B5CF6);       // --cat-rent: oklch(0.55 0.15 300)
  static const catPower = Color(0xFFF59E0B);      // --cat-power: oklch(0.75 0.15 90)
  static const catWater = Color(0xFF3B82F6);      // --cat-water: oklch(0.66 0.12 220)
  static const catFuel = Color(0xFFDC2626);       // --cat-fuel: oklch(0.6 0.15 20)
  static const catHealth = Color(0xFF16A34A);     // --cat-health: oklch(0.65 0.14 155)
  static const catFun = Color(0xFFEC4899);        // --cat-fun: oklch(0.62 0.16 330)
  static const catSanitary = Color(0xFF3B82F6);   // --cat-sanitary: oklch(0.68 0.1 190)
  static const catAirtime = Color(0xFF0F9D58);    // --cat-airtime: oklch(0.7 0.14 120)

  // Shadows
  static const shadowSoft = [
    BoxShadow(color: Color(0x0F666666), blurRadius: 2, offset: Offset(0, 1)),      // 0 1px 2px 6%
    BoxShadow(color: Color(0x2E666666), blurRadius: 24, offset: Offset(0, 8)),      // 0 8px 24px -12px 18%
  ];
  static const shadowLift = [
    BoxShadow(color: Color(0x52666666), blurRadius: 32, offset: Offset(0, 12)),     // 0 12px 32px -12px 32%
  ];

  // Radius scale (1rem = 16dp base)
  static const radiusSm = 10.0;
  static const radiusMd = 13.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radius2xl = 26.0;
  static const radius3xl = 32.0;

  // Dark theme (kept similar to existing)
  static const darkBg = Color(0xFF12141F);
  static const darkCard = Color(0xFF1D2030);
  static const darkElevated = Color(0xFF272B3A);
  static const darkPrimary = Color(0xFF0B8457);
}

class AppTheme {
  static const primary = AppColors.primary;
  static const primaryDark = Color(0xFF0F5B3F);
  static const accent = AppColors.accent;

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.manrope().fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.success,
        surface: AppColors.card,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusXl)),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedForeground,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        backgroundColor: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.manropeTextTheme(),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.manrope().fontFamily,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusXl)),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF7A8A8E),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
      ),
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
    );
  }
}