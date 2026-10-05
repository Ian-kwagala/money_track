import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Helpers for money text fields: live thousand separators while typing,
/// parsing that tolerates the separators, and prefill formatting.
///
/// Usage:
/// ```dart
/// TextField(
///   keyboardType: MoneyInput.keyboardType,
///   inputFormatters: MoneyInput.formatters,
/// )
/// final amount = MoneyInput.parse(ctrl.text);
/// ```
class MoneyInput {
  static const keyboardType = TextInputType.numberWithOptions(decimal: true);

  static const List<TextInputFormatter> formatters = [ThousandsSeparatorInputFormatter()];

  /// Parses user input such as "1,250,000.50". Returns null when empty/invalid.
  static double? parse(String text) => double.tryParse(text.replaceAll(',', '').trim());

  /// Formats a stored amount for prefilling a field, e.g. 2500000 -> "2,500,000".
  /// Zero becomes an empty string so the hint shows instead.
  static String text(double value, {bool emptyIfZero = true}) {
    if (emptyIfZero && value == 0) return '';
    return NumberFormat('#,##0.##').format(value);
  }

  /// Adds separators to a plain digit string (used by the quick-add keypad).
  static String group(String digits) {
    final dot = digits.indexOf('.');
    final intPart = dot == -1 ? digits : digits.substring(0, dot);
    final frac = dot == -1 ? '' : digits.substring(dot);
    return '${_groupInt(intPart)}$frac';
  }

  static String _groupInt(String intPart) {
    final sb = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) sb.write(',');
      sb.write(intPart[i]);
    }
    return sb.toString();
  }
}

/// Formats numeric input as "1,234,567.89" while the user types, keeping the
/// cursor next to the digit it was beside.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final int decimalDigits;

  const ThousandsSeparatorInputFormatter({this.decimalDigits = 2});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    var cursor = newValue.selection.end.clamp(0, text.length);

    // Backspacing over a separator: delete the digit before it instead,
    // otherwise the separator would just be re-inserted and nothing happens.
    final old = oldValue.text;
    if (old.length == text.length + 1 &&
        cursor < old.length &&
        old[cursor] == ',' &&
        old.replaceRange(cursor, cursor + 1, '') == text &&
        cursor > 0) {
      text = text.replaceRange(cursor - 1, cursor, '');
      cursor -= 1;
    }

    // Keep digits and a single decimal point (limited decimals), counting
    // how many kept characters sit before the cursor.
    final kept = StringBuffer();
    var seenDot = false;
    var decimals = 0;
    var keptBeforeCursor = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      final code = ch.codeUnitAt(0);
      var keep = false;
      if (code >= 48 && code <= 57) {
        if (!seenDot) {
          keep = true;
        } else if (decimals < decimalDigits) {
          decimals++;
          keep = true;
        }
      } else if (ch == '.' && !seenDot && decimalDigits > 0) {
        seenDot = true;
        keep = true;
      }
      if (keep) {
        kept.write(ch);
        if (i < cursor) keptBeforeCursor++;
      }
    }

    final cleaned = kept.toString();
    if (cleaned.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    final dot = cleaned.indexOf('.');
    var intPart = dot == -1 ? cleaned : cleaned.substring(0, dot);
    final fracPart = dot == -1 ? '' : cleaned.substring(dot);

    // Drop leading zeros ("007" -> "7"), but keep a single "0" before ".".
    var stripped = 0;
    while (intPart.length > 1 && intPart.startsWith('0')) {
      intPart = intPart.substring(1);
      stripped++;
    }
    keptBeforeCursor = (keptBeforeCursor - stripped).clamp(0, cleaned.length);
    if (intPart.isEmpty) {
      intPart = '0';
      if (keptBeforeCursor > 0) keptBeforeCursor++;
    }

    final formatted = '${MoneyInput._groupInt(intPart)}$fracPart';

    // Map the cursor back, skipping over inserted separators.
    var pos = 0;
    var count = 0;
    while (pos < formatted.length && count < keptBeforeCursor) {
      if (formatted[pos] != ',') count++;
      pos++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}
