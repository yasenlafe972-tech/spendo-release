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

  /// Formats currency with shekel sign safely without BiDi inversion (e.g. "10,957 ₪" or "-500 ₪")
  static String formatShekel(num amount, {bool isNegative = false}) {
    final formatted = formatAmount(amount.abs());
    final sign = (amount < 0 || isNegative) ? '-' : '';
    // Use Left-to-Right Mark (\u200E) and Non-Breaking Space to keep sign, number and ₪ together
    return '\u200E$sign$formatted ₪';
  }
}
