import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's design tokens: colours, shadows and corner radii, converted
/// from the original web design (the CSS variable names are noted beside
/// each value).
///
/// These are compile-time constants, not theme lookups. A widget that uses
/// `AppColors.textPrimary` directly keeps that colour in dark mode too; use
/// `Theme.of(context).colorScheme` where a widget must follow the theme.
class AppColors {
  // Light theme (Lovable exact oklch -> hex)
  static const bg = Color(0xFFEAF2EE);           // --background: oklch(0.978 0.008 150)
  static const card = Colors.white;               // --card: oklch(1 0 0)
  static const cardSolid = Colors.white;          // Solid card surface
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
  static const borderLight = Color(0xFFE5E7EB);   // Subtle border line
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

  // Dark theme tokens
  static const darkBg = Color(0xFF0E1418);
  static const darkCard = Color(0xFF162026);
  static const darkElevated = Color(0xFF1E2B33);
  static const darkBorder = Color(0xFF283742);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkPrimary = Color(0xFF10B981);
}

/// Theme-aware palette so every screen and widget automatically adapts when
/// dark mode is enabled, while preserving the exact light-mode design tokens.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color card;
  final Color cardSolid;
  final Color elevated;
  final Color muted;
  final Color mutedForeground;
  final Color border;
  final Color borderLight;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color chipUnselected;
  final Color primary;

  const AppPalette({
    required this.bg,
    required this.card,
    required this.cardSolid,
    required this.elevated,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.borderLight,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.chipUnselected,
    required this.primary,
  });

  static const light = AppPalette(
    bg: AppColors.bg,
    card: AppColors.card,
    cardSolid: AppColors.cardSolid,
    elevated: AppColors.elevated,
    muted: AppColors.muted,
    mutedForeground: AppColors.mutedForeground,
    border: AppColors.border,
    borderLight: AppColors.borderLight,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    chipUnselected: AppColors.chipUnselected,
    primary: AppColors.primary,
  );

  static const dark = AppPalette(
    bg: AppColors.darkBg,
    card: AppColors.darkCard,
    cardSolid: AppColors.darkCard,
    elevated: AppColors.darkElevated,
    muted: AppColors.darkElevated,
    mutedForeground: AppColors.darkTextSecondary,
    border: AppColors.darkBorder,
    borderLight: AppColors.darkBorder,
    divider: Color(0xFF24323C),
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    chipUnselected: AppColors.darkElevated,
    primary: AppColors.darkPrimary,
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? card,
    Color? cardSolid,
    Color? elevated,
    Color? muted,
    Color? mutedForeground,
    Color? border,
    Color? borderLight,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? chipUnselected,
    Color? primary,
  }) =>
      AppPalette(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        cardSolid: cardSolid ?? this.cardSolid,
        elevated: elevated ?? this.elevated,
        muted: muted ?? this.muted,
        mutedForeground: mutedForeground ?? this.mutedForeground,
        border: border ?? this.border,
        borderLight: borderLight ?? this.borderLight,
        divider: divider ?? this.divider,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        chipUnselected: chipUnselected ?? this.chipUnselected,
        primary: primary ?? this.primary,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardSolid: Color.lerp(cardSolid, other.cardSolid, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      chipUnselected: Color.lerp(chipUnselected, other.chipUnselected, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }
}

/// Convenience accessor (`context.colors`) for the active light/dark [AppPalette].
extension AppPaletteContext on BuildContext {
  AppPalette get colors {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
  }
}

/// Builds the Material light and dark themes from [AppColors]. main.dart
/// picks one from the user's dark-mode setting.
class AppTheme {
  // Shortcuts kept for older call sites.
  static const primary = AppColors.primary;
  static const primaryDark = Color(0xFF0F5B3F);
  static const accent = AppColors.accent;

  /// Uses the system Latin font by default so offline or partial font loads
  /// never fall back to CJK system glyphs on Android.
  static ThemeData light({bool googleFonts = false}) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: googleFonts ? GoogleFonts.manrope().fontFamily : null,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
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
      extensions: const [AppPalette.light],
      textTheme: googleFonts ? GoogleFonts.manropeTextTheme() : null,
    );
  }

  /// Dark variant with high-contrast charcoal surfaces, crisp typography, and
  /// emerald accents.
  static ThemeData dark({bool googleFonts = false}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: googleFonts ? GoogleFonts.manrope().fontFamily : null,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        secondary: AppColors.success,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        error: AppColors.danger,
        outline: AppColors.darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppColors.radiusXl)),
          side: BorderSide(color: AppColors.darkBorder.withValues(alpha: 0.55)),
        ),
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkElevated,
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusMd)),
        backgroundColor: AppColors.darkElevated,
        contentTextStyle: const TextStyle(color: AppColors.darkTextPrimary),
      ),
      extensions: const [AppPalette.dark],
      textTheme: googleFonts ? GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme) : null,
    );
  }
}