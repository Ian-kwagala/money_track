import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The dashboard's colours: navy from the MoneyTrack logo for the frame,
/// the app's green for actions, and soft tints for status.
abstract final class AdminColors {
  static const navy = Color(0xFF141A42);
  static const navyRaised = Color(0xFF1D2560);
  static const navyLine = Color(0xFF2A3378);
  static const navyText = Color(0xFFB9C0E6);

  static const green = Color(0xFF0B8457);
  static const greenSoft = Color(0xFFE4F4EC);
  static const amber = Color(0xFFFFC107);

  static const canvas = Color(0xFFF4F6FA);
  static const field = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E7EF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFEF3C7);
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFE3ECFF);
  static const violet = Color(0xFF7C3AED);
  static const violetSoft = Color(0xFFEFE7FE);
}

/// Inter for the interface. Tests pass `googleFonts: false` since they
/// can't download fonts.
ThemeData adminTheme({bool googleFonts = true}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AdminColors.green,
    primary: AdminColors.green,
    surface: Colors.white,
    error: AdminColors.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AdminColors.canvas);
  final text = (googleFonts ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme)
      .apply(bodyColor: AdminColors.text, displayColor: AdminColors.text);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  // From the text theme, so buttons get the same font as everything else.
  final buttonText = text.labelLarge!.copyWith(fontWeight: FontWeight.w600, fontSize: 14);
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color, width: width));

  return base.copyWith(
    textTheme: text,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(AdminColors.border),
      enabledBorder: outline(AdminColors.border),
      focusedBorder: outline(AdminColors.green, 1.6),
      errorBorder: outline(AdminColors.danger),
      focusedErrorBorder: outline(AdminColors.danger, 1.6),
      labelStyle: const TextStyle(color: AdminColors.muted),
      hintStyle: const TextStyle(color: AdminColors.muted),
      prefixIconColor: AdminColors.muted,
      suffixIconColor: AdminColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: rounded,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: AdminColors.text,
        side: const BorderSide(color: AdminColors.border),
        shape: rounded,
        textStyle: buttonText.copyWith(fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.green,
        shape: rounded,
        textStyle: buttonText.copyWith(fontSize: 13),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AdminColors.border, space: 1, thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AdminColors.text,
      width: 440,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AdminColors.text, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}
