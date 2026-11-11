import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Centralized utility for consistent and BiDi-safe number and currency formatting.
class NumberFormatter {
  NumberFormatter._();

  static final NumberFormat _currencyFormat = NumberFormat('#,##0.##', 'en_US');
  static final NumberFormat _integerFormat = NumberFormat('#,##0', 'en_US');

  /// Formats amount into clean string with commas (e.g. 10,957.50)
  static String formatAmount(num amount, {bool trimZeroDecimals = true}) {
    if (trimZeroDecimals && amount == amount.roundToDouble()) {
      return _integerFormat.format(amount);
    }
    return _currencyFormat.format(amount);
  }

  /// Parses a string that may contain thousand-separator commas into a double.
  static double? tryParse(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Formats currency with shekel sign safely without BiDi inversion (e.g. "10,957 ₪" or "-500 ₪")
  static String formatShekel(num amount, {bool isNegative = false}) {
    final formatted = formatAmount(amount.abs());
    final sign = (amount < 0 || isNegative) ? '-' : '';
    // Use Left-to-Right Mark (\u200E) and Non-Breaking Space to keep sign, number and ₪ together
    return '\u200E$sign$formatted ₪';
  }
}

/// Live input formatter that inserts thousand-separator commas while typing numbers (e.g. 10000 -> 10,000).
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) {
      return oldValue;
    }

    final parts = raw.split('.');
    final intPart = parts[0];
    final formattedInt =
        intPart.isEmpty
            ? ''
            : NumberFormat('#,###', 'en_US').format(int.parse(intPart));
    final formatted =
        parts.length > 1 ? '$formattedInt.${parts[1]}' : formattedInt;

    final selectionEnd = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor =
        newValue.text
            .substring(0, selectionEnd)
            .replaceAll(RegExp(r'[^0-9.]'), '')
            .length;

    var newCursorIndex = 0;
    var digitsSeen = 0;
    while (newCursorIndex < formatted.length &&
        digitsSeen < digitsBeforeCursor) {
      final ch = formatted[newCursorIndex];
      if (ch != ',') {
        digitsSeen++;
      }
      newCursorIndex++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }
}
