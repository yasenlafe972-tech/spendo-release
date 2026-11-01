import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/core/utils/number_formatter.dart';

void main() {
  group('NumberFormatter Unit Tests', () {
    test('formatAmount formats whole numbers without decimals', () {
      expect(NumberFormatter.formatAmount(10957), '10,957');
      expect(NumberFormatter.formatAmount(0), '0');
      expect(NumberFormatter.formatAmount(500), '500');
    });

    test('formatAmount formats fractional numbers with decimals', () {
      expect(NumberFormatter.formatAmount(10957.5), '10,957.5');
      expect(NumberFormatter.formatAmount(350.25), '350.25');
    });

    test('formatShekel prefixes LTR mark and attaches shekel sign', () {
      final res = NumberFormatter.formatShekel(3850);
      expect(res.contains('3,850'), isTrue);
      expect(res.contains('₪'), isTrue);
      expect(res.startsWith('\u200E'), isTrue);
    });

    test('formatShekel formats negative amounts with minus sign intact', () {
      final res = NumberFormatter.formatShekel(-450);
      expect(res.contains('-450'), isTrue);
      expect(res.contains('₪'), isTrue);
      expect(res.startsWith('\u200E-'), isTrue);
    });
  });
}
