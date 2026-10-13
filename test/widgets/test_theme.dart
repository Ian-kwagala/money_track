import 'package:flutter/material.dart';
import 'package:money_track/ui/theme/app_theme.dart';

/// The app's real theme (button sizes, colours, shapes) without its Google
/// font, which tests can't download (real_fonts.dart loads Roboto instead).
/// Widget tests should use this rather than a default theme: a plain theme
/// once hid that the app's filled buttons can't sit in a Row.
ThemeData testAppTheme() => AppTheme.light(googleFonts: false);
