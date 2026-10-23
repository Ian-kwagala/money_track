import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's design tokens: colours, shadows, corner radii, gradients, and decorations.
///
/// Restyled to match the dark navy and glowing sky-blue aesthetic:
/// - Main Background: Dark navy blue (`0B101D` to `0E1726`) with a subtle top-center radial gradient glow in soft sky blue (`1A2C4E`).
/// - Card Containers: Translucent deep blue (`141E30` with ~0.85-0.9 opacity) with diagonal gradient (`18263E` to `0F172A`).
/// - Primary Text: Crisp white (`FFFFFF`).
/// - Secondary / Subtitle Text: Soft muted sky-blue (`8EA2C6` / `94A3B8`).
/// - Positive Indicators / Badges: Neon mint green text (`34D399`) inside translucent light-blue pill badges (`223555` / `1E3A5F`).
/// - Corner Radii: 22 across cards/containers, 30 for pills/badges.
/// - Borders: Subtle 1px outer stroke (`Colors.white.withOpacity(0.12)` or `2A3C5A`).
/// - Shadows: Very soft blue-tinted drop shadows.
class AppColors {
  // Main Background: Dark navy blue (0B101D to 0E1726)
  static const bg = Color(0xFF0B101D);
  static const bgSecondary = Color(0xFF0E1726);
  static const bgGlow = Color(0xFF1A2C4E);

  // Card Containers: Translucent deep blue (141E30 with 0.85-0.9 opacity)
  static const card = Color(0xE6141E30);
  static const cardSolid = Color(0xFF141E30);
  static const elevated = Color(0xFF18263E);

  // Gradient stops for cards: 18263E to 0F172A
  static const cardGradientStart = Color(0xFF18263E);
  static const cardGradientEnd = Color(0xFF0F172A);

  // Primary / Glowing Accent
  static const primary = Color(0xFF38BDF8); // Glowing sky blue
  static const primaryForeground = Colors.white;
  static const primaryDark = Color(0xFF0F172A);

  // Muted & Secondary Text
  static const muted = Color(0xFF1E2D4A);
  static const mutedForeground = Color(0xFF8EA2C6); // Soft muted sky-blue
  static const textSecondary = Color(0xFF8EA2C6);
  static const textMuted = Color(0xFF94A3B8);

  // Primary Text: Crisp white
  static const textPrimary = Color(0xFFFFFFFF);

  // Positive Indicators / Badges: Neon mint green text (34D399) inside translucent light-blue pill badges (223555 or 1E3A5F)
  static const success = Color(0xFF34D399); // Neon mint green
  static const income = Color(0xFF34D399);  // Neon mint green
  static const badgeMintText = Color(0xFF34D399);
  static const badgeBg = Color(0xFF1E3A5F);
  static const badgeBgLight = Color(0x66223555);

  // Status & Accents
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171); // Crisp coral/red
  static const info = Color(0xFF38BDF8);
  static const accent = Color(0xFF38BDF8);

  // Borders & Dividers: Subtle 1px outer stroke
  static const border = Color(0xFF2A3C5A);
  static const borderLight = Color(0x1FFFFFFF); // Colors.white.withOpacity(0.12)
  static const divider = Color(0xFF2A3C5A);

  // Interactive Elements & Chips
  static const chipUnselected = Color(0xFF141E30);
  static const chipSelected = Color(0xFF1E3A5F);

  // Visualizations & Charts
  // Bar Charts: Dark navy bottom segment, glowing sky-blue top segment
  static const chartNavy = Color(0xFF1E2D4A);
  static const chartNavyDark = Color(0xFF141E30);
  static const chartSkyBlue = Color(0xFF38BDF8);
  static const chartSkyBlueGlow = Color(0xFF7DD3FC);

  // Navigation Bar: Translucent dark navy bottom navigation bar
  static const navBarBg = Color(0xDE0E1726);
  static const navInactive = Color(0xFF8EA2C6); // Muted grey-blue inactive
  static const navActive = Color(0xFFFFFFFF);   // Glowing white / sky-blue active

  // Category colors adapted for dark luxury palette
  static const catFood = Color(0xFFF59E0B);
  static const catTransport = Color(0xFF38BDF8);
  static const catRent = Color(0xFF818CF8);
  static const catPower = Color(0xFFFBBF24);
  static const catWater = Color(0xFF60A5FA);
  static const catFuel = Color(0xFFF87171);
  static const catHealth = Color(0xFF34D399);
  static const catFun = Color(0xFFF472B6);
  static const catSanitary = Color(0xFF2DD4BF);
  static const catAirtime = Color(0xFF4ADE80);

  // Radius scale
  // Border Radius: 22 across all cards, containers, and dialogs
  // Badges / Chips: 30
  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 18.0;
  static const radiusXl = 22.0;
  static const radius2xl = 22.0;
  static const radius3xl = 30.0;
  static const radiusPill = 30.0;

  // Shadows: Very soft blue-tinted drop shadows
  static const shadowSoft = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
  ];
  static const shadowLift = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x141A2C4E), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const shadowGlow = [
    BoxShadow(color: Color(0x3338BDF8), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // Gradients
  // Diagonal LinearGradient (from 18263E to 0F172A)
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF18263E), Color(0xFF0F172A)],
  );

  // Main Background: Dark navy blue with subtle top-center radial gradient glow in soft sky blue (1A2C4E)
  static const backgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.9),
    radius: 1.2,
    colors: [
      Color(0xFF1A2C4E), // soft sky blue glow
      Color(0xFF0E1726), // navy
      Color(0xFF0B101D), // dark navy
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// Helper for consistent card decorations
  static BoxDecoration cardDecoration({
    BorderRadius? borderRadius,
    Border? border,
    Gradient? gradient,
    List<BoxShadow>? boxShadow,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? card,
      gradient: gradient ?? cardGradient,
      borderRadius: borderRadius ?? BorderRadius.circular(radiusXl),
      border: border ?? Border.all(color: borderLight, width: 1),
      boxShadow: boxShadow ?? shadowSoft,
    );
  }

  /// Helper for soft pill-shaped badges (BorderRadius.circular(30)) with light translucent background fill
  static BoxDecoration pillBadgeDecoration({
    Color? color,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? badgeBg,
      borderRadius: BorderRadius.circular(radiusPill),
      border: border ?? Border.all(color: borderLight, width: 1),
    );
  }

  // Dark theme aliases
  static const darkBg = bg;
  static const darkCard = card;
  static const darkElevated = elevated;
  static const darkPrimary = primary;
}

/// Builds the Material light and dark themes using [AppColors].
/// Both variants apply the dark navy & glowing sky-blue aesthetic.
class AppTheme {
  static const primary = AppColors.primary;
  static const primaryDark = AppColors.primaryDark;
  static const accent = AppColors.accent;

  static ThemeData light({bool googleFonts = true}) => _buildTheme(googleFonts: googleFonts);

  static ThemeData dark({bool googleFonts = true}) => _buildTheme(googleFonts: googleFonts);

  static ThemeData _buildTheme({bool googleFonts = true}) {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = googleFonts ? GoogleFonts.manropeTextTheme(baseTextTheme) : baseTextTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: googleFonts ? GoogleFonts.manrope().fontFamily : null,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      cardColor: AppColors.cardSolid,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.success,
        surface: AppColors.cardSolid,
        error: AppColors.danger,
        onPrimary: AppColors.primaryDark,
        onSecondary: AppColors.primaryDark,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.mutedForeground,
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
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        shadowColor: const Color(0x1A000000),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardGradientEnd,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.mutedForeground,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.cardGradientEnd,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.navActive,
        unselectedItemColor: AppColors.navInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.navActive),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.navInactive),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSolid,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        labelStyle: const TextStyle(color: AppColors.mutedForeground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cardGradientStart,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
            side: const BorderSide(color: AppColors.borderLight, width: 1),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        backgroundColor: AppColors.cardSolid,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
