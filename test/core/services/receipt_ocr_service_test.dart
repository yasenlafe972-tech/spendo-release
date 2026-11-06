import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/core/services/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrService.parseReceiptText', () {
    test('parses standard Paz Yellow receipt correctly', () {
      const sample = '''
פז חברת נפט בע"מ
תחנת פז בית הכרם
חשבונית מס קבלה תדלוק Yellow 417
תאריך: 28/10/2026 14:35
בנזין 95 אוקטן
כמות: 6.000 ליטר
מחיר לליטר: 7.77
סה"כ לתשלום: 46.62 ש"ח
תודה שבחרת Yellow
''';

      final result = ReceiptOcrService.parseReceiptText(sample);

      expect(result.isFuel, isTrue);
      expect(result.amount, equals(46.62));
      expect(result.liters, equals(6.0));
      expect(result.pricePerLiter, equals(7.77));
      expect(result.providerName, contains('פז בית הכרם'));
      expect(result.invoiceNumber, equals('417'));
      expect(result.date.year, equals(2026));
      expect(result.date.month, equals(10));
      expect(result.date.day, equals(28));
      expect(result.date.hour, equals(14));
      expect(result.date.minute, equals(35));
    });

    test('parses Paz Tamra with RTL / BiDi inverted text and odometer', () {
      const sample = '''
תחנת דלק פז טמרה
קבלה מספר 891234
15/10/2026 09:20
מד אוץ: 154200 ק"מ
אוקטן 95
18.50 ליטר
143.75 ש"ח סה"כ לתשלום
''';

      final result = ReceiptOcrService.parseReceiptText(sample);

      expect(result.isFuel, isTrue);
      expect(result.amount, equals(143.75));
      expect(result.liters, equals(18.5));
      expect(result.odometer, equals(154200));
      expect(result.providerName, contains('פז טמרה'));
      expect(result.invoiceNumber, equals('891234'));
    });

    test('mathematically deduces liters when liters field is absent', () {
      const sample = '''
פז Yellow כפר כנא
חשבונית 5543
תאריך 02/11/2026
מחיר לליטר: 7.50
סה"כ 150.00 ש"ח
''';

      final result = ReceiptOcrService.parseReceiptText(sample);

      expect(result.isFuel, isTrue);
      expect(result.amount, equals(150.0));
      expect(result.pricePerLiter, equals(7.50));
      expect(result.liters, equals(20.0)); // 150.0 / 7.50 = 20.0
      expect(result.providerName, contains('פז כפר כנא'));
    });

    test('parses Sonol gas station receipt cleanly', () {
      const sample = '''
סונול סחנין
אסמכתא: 778899
תאריך 25/09/2026
כמות ליטרים: 30.50
סה"כ: 236.38
''';

      final result = ReceiptOcrService.parseReceiptText(sample);

      expect(result.isFuel, isTrue);
      expect(result.amount, equals(236.38));
      expect(result.liters, equals(30.5));
      expect(result.providerName, contains('סונול סחנין'));
      expect(result.invoiceNumber, equals('778899'));
    });

    test('parses real Yellow receipt from Biina station', () {
      const sample = '''
מסמך ממוחשב
פז קמעונאות ואנרגיה בע"מ
איחוד עוסק 557100641
פז בעינה 365
כביש עכו צפת
טל 054-5246045

חשבונית מס/קבלה מקור
036509901116246
02/10/26 13:08
רכב: 55505403
משאבה: 06

אוקטן 95 8.270 ש"ח לליטר
כמות: 2.423 ליטרים
סה"כ דלקים: 20.04 ש"ח

סה"כ לפני מע"מ 16.98 ש"ח
מע"מ לחוץ רכב 3.06 ש"ח

סה"כ לתשלום 20.04 ש"ח
כולל מע"מ

Yellow Friends
שולם באפליקציה
שם לקוח yasen lafe
''';

      final result = ReceiptOcrService.parseReceiptText(sample);
      expect(result.isFuel, isTrue);
      expect(result.amount, equals(20.04));
      expect(result.liters, equals(2.423));
      expect(result.pricePerLiter, equals(8.27));
      expect(result.providerName, contains('פז בעינה'));
      expect(result.invoiceNumber, equals('036509901116246'));
      expect(result.date.day, equals(2));
      expect(result.date.month, equals(10));
      expect(result.date.year, equals(2026));
      expect(result.date.hour, equals(13));
      expect(result.date.minute, equals(8));
    });

    test('parses Latin-only MLKit output from real Yellow Paz receipt', () {
      const mlkitSample = '''
557100641
365
054-5246045
036509901116246
02/10/26 13:08
55505403
06
95 8.270
2.423
20.04
16.98
3.06
20.04
Yellow Friends
0.24
0.24
yasen lafe
2164
Yellow
''';

      final result = ReceiptOcrService.parseReceiptText(mlkitSample);
      expect(result.isFuel, isTrue);
      expect(result.amount, equals(20.04));
      expect(result.liters, equals(2.423));
      expect(result.pricePerLiter, equals(8.27));
      expect(result.providerName, contains('פז בעינה 365'));
      expect(result.invoiceNumber, equals('036509901116246'));
      expect(result.date.day, equals(2));
      expect(result.date.month, equals(10));
      expect(result.date.year, equals(2026));
      expect(result.date.hour, equals(13));
      expect(result.date.minute, equals(8));
    });

    test('Smart Fuel Math Parser picks largest total when before-tax and with-tax match', () {
      const sample = '''
      Paz Station
      Date: 12/05/2026 10:15
      Net price 7.00
      Gross price 8.26
      Quantity 10.000
      Net Total 70.00
      Total Payment 82.60
      ''';

      final result = ReceiptOcrService.parseReceiptText(sample);
      expect(result.isFuel, isTrue);
      expect(result.amount, equals(82.60));
      expect(result.liters, equals(10.0));
      expect(result.pricePerLiter, equals(8.26));
      expect(result.providerName, equals('פז'));
      expect(result.date.day, equals(12));
      expect(result.date.month, equals(5));
      expect(result.date.year, equals(2026));
    });

    test('defaults provider to تعبئة بنزين when no station name is recognized', () {
      const sample = '''
      05/04/2026
      Octan 95 8.00
      15.000
      120.00
      ''';

      final result = ReceiptOcrService.parseReceiptText(sample);
      expect(result.isFuel, isTrue);
      expect(result.amount, equals(120.0));
      expect(result.liters, equals(15.0));
      expect(result.pricePerLiter, equals(8.0));
      expect(result.providerName, equals('تعبئة بنزين'));
      expect(result.title, contains('تعبئة بنزين'));
    });

    test('handles empty or unrecognized text without throwing', () {
      final emptyResult = ReceiptOcrService.parseReceiptText('');
      expect(emptyResult.amount, equals(0.0));
      expect(emptyResult.liters, isNull);
      expect(emptyResult.isFuel, isFalse);
    });

    test('fuel receipt must not contain fuel metrics in items list', () {
      const sample = '''
פז בית הכרם
חשבונית מס קבלה 12345
תאריך 05/11/2026 10:00
בנזין 95 אוקטן
כמות 15.00 ליטר
מחיר לליטר 7.77 ש"ח
סה"כ 116.55 ש"ח
תשלום Yellow
''';
      final result = ReceiptOcrService.parseReceiptText(sample);
      expect(result.isFuel, isTrue);
      expect(result.amount, equals(116.55));
      expect(result.liters, equals(15.0));
      expect(result.pricePerLiter, equals(7.77));
      // Fuel metrics must NEVER be in items (items represents maintenance parts/services)
      expect(result.items, isEmpty);
    });

    test('maintenance receipt detects genuine parts and services in items', () {
      const sample = '''
מוסך מורשה כרמיאל
חשבונית מס 45678
החלפת דיסק בלם ורפידות קדמיות
שמן מנוע 4T
סה"כ לתשלום 650.00 ש"ח
''';
      final result = ReceiptOcrService.parseReceiptText(sample);
      expect(result.isFuel, isFalse);
      expect(result.amount, equals(650.0));
      expect(result.items, contains('דיסק בלם (צלחת)'));
      expect(result.items, contains('רפידות בלם'));
      expect(result.items, contains('שמן מנוע 4T מקורי'));
    });
  });
}
