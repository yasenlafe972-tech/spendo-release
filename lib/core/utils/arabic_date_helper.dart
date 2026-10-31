import 'package:intl/intl.dart';

/// Comprehensive Arabic Date & Weekday Utility for Spendo.
///
/// Converts any [DateTime] or ISO date string into Arabic weekday names,
/// relative day descriptions ("اليوم - الخميس", "أمس - الأربعاء"),
/// and unified localized date labels ("الخميس • 22/10/2026").
class ArabicDateHelper {
  ArabicDateHelper._();

  /// Mapping from Dart's [DateTime.weekday] (1..7, where Monday = 1, Sunday = 7)
  /// to localized Arabic day names.
  static const Map<int, String> arabicWeekdays = {
    1: 'الإثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
    7: 'الأحد',
  };

  /// Arabic month names (Gregorian / Levantine)
  static const Map<int, String> arabicMonths = {
    1: 'يناير',
    2: 'فبراير',
    3: 'مارس',
    4: 'أبريل',
    5: 'مايو',
    6: 'يونيو',
    7: 'يوليو',
    8: 'أغسطس',
    9: 'سبتمبر',
    10: 'أكتوبر',
    11: 'نوفمبر',
    12: 'ديسمبر',
  };

  /// Computes the exact Arabic day name from [date].
  ///
  /// Examples:
  /// - Monday (1) -> 'الإثنين'
  /// - Thursday (4) -> 'الخميس'
  /// - Sunday (7) -> 'الأحد'
  static String getArabicWeekday(DateTime date) {
    return arabicWeekdays[date.weekday] ?? '';
  }

  /// Returns the Arabic day name directly from an ISO date string
  /// (e.g. "2026-10-22", "2026-10-22T20:35:36Z").
  ///
  /// Falls back to empty string if parsing fails.
  static String getWeekdayFromDateString(String dateStr) {
    if (dateStr.trim().isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr);
      return getArabicWeekday(parsed);
    } catch (_) {
      try {
        final parsed = DateFormat('yyyy-MM-dd').parseLoose(dateStr);
        return getArabicWeekday(parsed);
      } catch (_) {
        return '';
      }
    }
  }

  /// Formats date with weekday prefix:
  /// e.g. "الخميس • 22/10/2026"
  static String formatArabicDateWithWeekday(DateTime date, {String separator = '•'}) {
    final weekday = getArabicWeekday(date);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$weekday $separator $day/$month/$year';
  }

  /// Formats date from an ISO string with weekday prefix:
  /// e.g. "الخميس • 22/10/2026"
  static String formatArabicDateWithWeekdayFromString(String dateStr, {String separator = '•'}) {
    if (dateStr.trim().isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr);
      return formatArabicDateWithWeekday(parsed, separator: separator);
    } catch (_) {
      return dateStr;
    }
  }

  /// Returns a human-friendly relative day description:
  /// - If today: "اليوم - الخميس"
  /// - If yesterday: "أمس - الأربعاء"
  /// - If tomorrow: "غداً - الجمعة"
  /// - Otherwise: "الخميس 22/10"
  static String getRelativeDayDescription(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final dayName = getArabicWeekday(date);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    final differenceInDays = target.difference(today).inDays;

    if (differenceInDays == 0) {
      return 'اليوم - $dayName';
    } else if (differenceInDays == -1) {
      return 'أمس - $dayName';
    } else if (differenceInDays == 1) {
      return 'غداً - $dayName';
    } else {
      return '$dayName $day/$month';
    }
  }

  /// Returns a relative day description directly from a date string:
  static String getRelativeDayDescriptionFromString(String dateStr) {
    if (dateStr.trim().isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr);
      return getRelativeDayDescription(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  /// Formats year and month numbers into Arabic month name and year (e.g. 2026, 10 -> 'أكتوبر 2026')
  static String formatMonthYear(int year, int month) {
    final monthName = arabicMonths[month] ?? month.toString();
    return '$monthName $year';
  }

  /// Formats a 'YYYY-MM' key into Arabic month and year (e.g. '2026-10' -> 'أكتوبر 2026')
  static String formatMonthYearKey(String key) {
    final parts = key.split('-');
    if (parts.length >= 2) {
      final y = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (y > 0 && m > 0) {
        return formatMonthYear(y, m);
      }
    }
    return key;
  }

  /// Checks if [date] is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Checks if [date] is yesterday.
  static bool isYesterday(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  /// Checks if [date] is tomorrow.
  static bool isTomorrow(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }
}

/// Ergonomic extensions on [DateTime] for Arabic date formatting.
extension ArabicDateTimeExtension on DateTime {
  /// Arabic weekday name (e.g. 'الخميس')
  String get arabicWeekday => ArabicDateHelper.getArabicWeekday(this);

  /// Relative description (e.g. 'اليوم - الخميس', 'أمس - الأربعاء', 'الخميس 22/10')
  String get relativeDescription => ArabicDateHelper.getRelativeDayDescription(this);

  /// Formatted date with weekday (e.g. 'الخميس • 22/10/2026')
  String formatArabicWithWeekday({String separator = '•'}) =>
      ArabicDateHelper.formatArabicDateWithWeekday(this, separator: separator);

  /// Whether this date is today.
  bool get isToday => ArabicDateHelper.isToday(this);

  /// Whether this date is yesterday.
  bool get isYesterday => ArabicDateHelper.isYesterday(this);
}
