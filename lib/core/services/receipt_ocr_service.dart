import 'dart:convert';
import 'dart:io';
import 'package:printing/printing.dart';

class ParsedReceiptResult {
  final String title;
  final double amount;
  final DateTime date;
  final bool isFuel;
  final double? liters;
  final String providerName;
  final String rawText;
  final String? invoiceNumber;
  final List<String> items;

  const ParsedReceiptResult({
    required this.title,
    required this.amount,
    required this.date,
    required this.isFuel,
    this.liters,
    required this.providerName,
    required this.rawText,
    this.invoiceNumber,
    this.items = const [],
  });
}

class ReceiptOcrService {
  /// Open-tier free OCR API key for OCR.space
  static const String _apiKey = 'K87899142388957';
  static const String _ocrEndpoint = 'https://api.ocr.space/parse/image';

  /// Performs OCR on an image file and parses Hebrew Israeli fuel/garage receipts.
  static Future<ParsedReceiptResult?> analyzeReceiptImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);

      final uri = Uri.parse(_ocrEndpoint);
      final request = await client.postUrl(uri);
      request.headers.set('apikey', _apiKey);
      request.headers.set(
          'content-type', 'application/x-www-form-urlencoded; charset=utf-8');

      final body = Uri(queryParameters: {
        'base64Image': base64Image,
        'language': 'heb',
        'isOverlayRequired': 'false',
        'scale': 'true',
        'detectOrientation': 'true',
      }).query;

      request.write(body);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;

        if (json['IsErroredOnProcessing'] != true &&
            json['ParsedResults'] is List &&
            (json['ParsedResults'] as List).isNotEmpty) {
          final firstResult = json['ParsedResults'][0] as Map<String, dynamic>;
          final parsedText = firstResult['ParsedText'] as String? ?? '';
          if (parsedText.trim().isNotEmpty) {
            return parseReceiptText(parsedText);
          }
        }
      }
    } catch (_) {
      // Offline fallback or network error handled by caller
    }
    return null;
  }

  /// يحلل ملف PDF لفاتورة Yellow أو كراج (إما مباشرة عبر OCR.space PDF أو بتحويل الصفحة الأولى لصورة PNG عالية الدقة)
  static Future<ParsedReceiptResult?> analyzeReceiptPdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();

      // 1. محاولة قراءة ملف ה-PDF مباشرة باللغة العبرية
      final base64Pdf = 'data:application/pdf;base64,${base64Encode(bytes)}';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(Uri.parse(_ocrEndpoint));
      request.headers.set('apikey', _apiKey);
      request.headers.set(
          'content-type', 'application/x-www-form-urlencoded; charset=utf-8');
      request.write(Uri(queryParameters: {
        'base64Image': base64Pdf,
        'filetype': 'PDF',
        'language': 'heb',
        'isOverlayRequired': 'false',
        'scale': 'true',
      }).query);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        if (json['IsErroredOnProcessing'] != true &&
            json['ParsedResults'] is List &&
            (json['ParsedResults'] as List).isNotEmpty) {
          final firstResult = json['ParsedResults'][0] as Map<String, dynamic>;
          final parsedText = firstResult['ParsedText'] as String? ?? '';
          if (parsedText.trim().isNotEmpty) {
            return parseReceiptText(parsedText);
          }
        }
      }

      // 2. إذا كان الـ PDF ممسوحاً كصورة، نحول الصفحة الأولى إلى PNG عبر Printing.raster ثم نقرأها
      await for (final page in Printing.raster(bytes, pages: const [0], dpi: 200)) {
        final pngBytes = await page.toPng();
        final tempImg = File(
            '${pdfFile.parent.path}/pdf_page_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempImg.writeAsBytes(pngBytes);
        final res = await analyzeReceiptImage(tempImg);
        try {
          await tempImg.delete();
        } catch (_) {}
        if (res != null) return res;
      }
    } catch (_) {}
    return null;
  }

  /// Heuristic parsing of Israeli garage invoices and Paz/Yellow fuel receipts.
  static ParsedReceiptResult parseReceiptText(String text) {
    final clean = text.replaceAll('\r', '');

    // 1. Detect if Fuel or Maintenance
    final isFuel = clean.contains('פז') ||
        clean.contains('Yellow') ||
        clean.contains('דלק') ||
        clean.contains('אוקטן') ||
        clean.contains('תדלוק') ||
        clean.contains('משאבה');

    // 2. Extract Amount
    double amount = 0.0;
    // Look specifically for total patterns (סה"כ לתשלום, סה"כ דלקים, סה"כ)
    final totalPatterns = [
      RegExp(r'סה"?כ\s*לתשלום[:\s]*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'סה"?כ\s*דלקים[:\s]*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'לתשלום[:\s]*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'סה"?כ[:\s]*(\d+\.?\d*)', caseSensitive: false),
    ];

    for (final p in totalPatterns) {
      final m = p.firstMatch(clean);
      if (m != null) {
        final val = double.tryParse(m.group(1) ?? '');
        if (val != null && val > 0) {
          amount = val;
          break;
        }
      }
    }

    // 3. Extract Liters
    double? liters;
    final litersMatch =
        RegExp(r'(\d+\.?\d*)\s*(?:ליטרים|ליטר)').firstMatch(clean);
    if (litersMatch != null) {
      liters = double.tryParse(litersMatch.group(1) ?? '');
    }

    // 4. Extract Provider / Station Branch / Garage dynamically from invoice text
    String providerName = '';
    if (clean.contains('אור אמנוני')) {
      providerName = 'מוסך אור אמנוני';
    } else if (clean.contains('בית הכרם')) {
      providerName = 'פז בית הכרם';
    } else {
      final stationBranchMatch = RegExp(
        r'(?:תחנת\s*דלק\s*|תחנת\s*)?(פז\s+[^\n\r,0-9:]{2,22}|סונול\s+[^\n\r,0-9:]{2,22}|דור\s*אלון\s+[^\n\r,0-9:]{2,22}|דלק\s+[^\n\r,0-9:]{2,22}|טן\s+[^\n\r,0-9:]{2,22}|מיקה\s+[^\n\r,0-9:]{2,22}|מוסך\s+[^\n\r,0-9:]{2,25})',
      ).firstMatch(clean);
      if (stationBranchMatch != null) {
        providerName = stationBranchMatch.group(1)?.trim() ?? '';
      } else if (clean.contains('פז') || clean.contains('Yellow')) {
        providerName = 'פז Yellow';
      }
    }

    // 5. Extract Date
    DateTime receiptDate = DateTime.now();
    final dateMatch =
        RegExp(r'(\d{1,2})[\/\.](\d{1,2})[\/\.](\d{2,4})').firstMatch(clean);
    if (dateMatch != null) {
      final d = int.tryParse(dateMatch.group(1) ?? '') ?? 1;
      final m = int.tryParse(dateMatch.group(2) ?? '') ?? 1;
      var y = int.tryParse(dateMatch.group(3) ?? '') ?? DateTime.now().year;
      if (y < 100) y += 2000;
      receiptDate = DateTime(y, m, d);
    }

    // 6. Extract Invoice / Receipt Number
    String? invoiceNumber;
    final invMatch = RegExp(
      r'(?:חשבונית(?:\s*מס)?(?:\s*קבלה)?|קבלה)\s*[:#]?\s*(\d{3,20})',
      caseSensitive: false,
    ).firstMatch(clean);
    if (invMatch != null) {
      invoiceNumber = invMatch.group(1);
    } else {
      final codeMatch =
          RegExp(r'(?:מספר|מס|קוד)\s*[:#]?\s*(\d{4,16})').firstMatch(clean);
      if (codeMatch != null) {
        invoiceNumber = codeMatch.group(1);
      }
    }

    // 7. Extract Detected Items
    final detectedItems = <String>[];
    if (clean.contains('דיסק')) detectedItems.add('דיסק בלם (צלחת)');
    if (clean.contains('רפיד')) detectedItems.add('רפידות בלם');
    if (clean.contains('טיימינג')) detectedItems.add('רצועת טיימינג');
    if (clean.contains('צמיג')) detectedItems.add('צמיג קדמי 110/90-13');
    if (clean.contains('שמן מנוע') || clean.contains('שמן 4T')) {
      detectedItems.add('שמן מנוע 4T מקורי');
    } else if (clean.contains('שמן')) {
      detectedItems.add('שמן מנוע / גיר');
    }
    if (clean.contains('מסכת') || clean.contains('מגן')) {
      detectedItems.add('פלסטיקה ומגן גחון');
    }
    if (isFuel) {
      detectedItems.add('דלק 95 אוקטן');
      detectedItems.add('חיוב אפליקציית Yellow');
    }

    // 8. Build Title in Authentic Hebrew
    String title;
    if (isFuel) {
      final litersStr = liters != null ? ' ($liters ליטר אוקטן 95)' : '';
      final stationStr =
          providerName.isNotEmpty ? ' $providerName' : ' פז Yellow';
      title = 'תדלוק Yellow$stationStr$litersStr';
    } else {
      final invStr =
          invoiceNumber != null ? ' (חשבונית #$invoiceNumber)' : '';
      title = providerName.isNotEmpty
          ? 'טיפול / חלפים ($providerName)$invStr'
          : 'טיפול / חלפים (מוסך)$invStr';
    }

    return ParsedReceiptResult(
      title: title,
      amount: amount,
      date: receiptDate,
      isFuel: isFuel,
      liters: liters,
      providerName: providerName,
      rawText: text,
      invoiceNumber: invoiceNumber,
      items: detectedItems,
    );
  }
}
