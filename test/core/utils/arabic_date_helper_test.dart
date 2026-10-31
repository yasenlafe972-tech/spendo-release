import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';

void main() {
  group('ArabicDateHelper', () {
    test('Weekdays map exactly matches 1..7 Arabic names', () {
      expect(ArabicDateHelper.arabicWeekdays[1], 'الإثنين');
      expect(ArabicDateHelper.arabicWeekdays[2], 'الثلاثاء');
      expect(ArabicDateHelper.arabicWeekdays[3], 'الأربعاء');
      expect(ArabicDateHelper.arabicWeekdays[4], 'الخميس');
      expect(ArabicDateHelper.arabicWeekdays[5], 'الجمعة');
      expect(ArabicDateHelper.arabicWeekdays[6], 'السبت');
      expect(ArabicDateHelper.arabicWeekdays[7], 'الأحد');
    });

    test('getArabicWeekday returns exact day name for dates', () {
      // 2026-10-22 is Thursday (4)
      final thursday = DateTime(2026, 10, 22);
      expect(ArabicDateHelper.getArabicWeekday(thursday), 'الخميس');

      // 2026-10-23 is Friday (5)
      final friday = DateTime(2026, 10, 23);
      expect(ArabicDateHelper.getArabicWeekday(friday), 'الجمعة');

      // 2026-10-24 is Saturday (6)
      final saturday = DateTime(2026, 10, 24);
      expect(ArabicDateHelper.getArabicWeekday(saturday), 'السبت');

      // 2026-10-25 is Sunday (7)
      final sunday = DateTime(2026, 10, 25);
      expect(ArabicDateHelper.getArabicWeekday(sunday), 'الأحد');

      // 2026-10-26 is Monday (1)
      final monday = DateTime(2026, 10, 26);
      expect(ArabicDateHelper.getArabicWeekday(monday), 'الإثنين');

      // 2026-10-27 is Tuesday (2)
      final tuesday = DateTime(2026, 10, 27);
      expect(ArabicDateHelper.getArabicWeekday(tuesday), 'الثلاثاء');

      // 2026-10-28 is Wednesday (3)
      final wednesday = DateTime(2026, 10, 28);
      expect(ArabicDateHelper.getArabicWeekday(wednesday), 'الأربعاء');
    });

    test('formatArabicDateWithWeekday formats date correctly', () {
      final date = DateTime(2026, 10, 22);
      final formatted = ArabicDateHelper.formatArabicDateWithWeekday(date);
      expect(formatted, 'الخميس • 22/10/2026');
    });

    test('getWeekdayFromDateString parses ISO and date strings correctly', () {
      expect(ArabicDateHelper.getWeekdayFromDateString('2026-10-22'), 'الخميس');
      expect(ArabicDateHelper.getWeekdayFromDateString('2026-10-22T20:35:36Z'), 'الخميس');
      expect(ArabicDateHelper.getWeekdayFromDateString('2026-10-23'), 'الجمعة');
      expect(ArabicDateHelper.getWeekdayFromDateString('invalid'), '');
      expect(ArabicDateHelper.getWeekdayFromDateString(''), '');
    });

    test('getRelativeDayDescription returns relative label or weekday + date', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      expect(
        ArabicDateHelper.getRelativeDayDescription(today),
        'اليوم - ${ArabicDateHelper.getArabicWeekday(today)}',
      );
      expect(
        ArabicDateHelper.getRelativeDayDescription(yesterday),
        'أمس - ${ArabicDateHelper.getArabicWeekday(yesterday)}',
      );
      expect(
        ArabicDateHelper.getRelativeDayDescription(tomorrow),
        'غداً - ${ArabicDateHelper.getArabicWeekday(tomorrow)}',
      );

      final otherDate = DateTime(2025, 5, 14); // Wednesday
      expect(
        ArabicDateHelper.getRelativeDayDescription(otherDate),
        'الأربعاء 14/05',
      );
    });

    test('DateTime extension methods work correctly', () {
      final date = DateTime(2026, 10, 22);
      expect(date.arabicWeekday, 'الخميس');
      expect(date.formatArabicWithWeekday(), 'الخميس • 22/10/2026');
    });
  });
}
