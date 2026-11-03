import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'pdf_text_extractor.dart';

class ParsedReceiptResult {
  final String title;
  final double amount;
  final DateTime date;
  final bool isFuel;
  final double? liters;
  final double? pricePerLiter;
  final int? odometer;
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
    this.pricePerLiter,
    this.odometer,
    required this.providerName,
    required this.rawText,
    this.invoiceNumber,
    this.items = const [],
  });
}

class FuelMathTriplet {
  final double pricePerLiter;
  final double liters;
  final double totalAmount;

  const FuelMathTriplet({
    required this.pricePerLiter,
    required this.liters,
    required this.totalAmount,
  });
}

class ReceiptOcrService {
  static const MethodChannel _shareChannel = MethodChannel('com.finance.spendo/share');

  /// High-reliability, 100% on-device offline OCR analyzer.
  /// Tier 1: Apple Vision on iOS (with native Hebrew support).
  /// Tier 2: Google Play Services ML Kit on Android (Latin numbers and symbols).
  static Future<ParsedReceiptResult?> analyzeReceiptImage(File imageFile) async {
    if (!imageFile.existsSync()) return null;

    if (Platform.isIOS || Platform.isAndroid) {
      try {
        final visionText = await _shareChannel.invokeMethod<String>(
          'extractImageText',
          imageFile.path,
        );
        if (visionText != null && visionText.trim().isNotEmpty) {
          final parsed = parseReceiptText(visionText);
          if (parsed.amount > 0 || parsed.liters != null) {
            return parsed;
          }
        }
      } catch (e) {
        debugPrint('>>> [ReceiptOcr] Native OCR error: $e');
      }
    }
    return null;
  }

  /// 100% offline analyzer for Israeli gas receipts & Yellow app PDFs.
  /// Step 1: Instant embedded JPEG extraction of Page 1 (< 3ms).
  /// Step 2: High-resolution rasterization of Page 1 ONLY (Scale 2.8x @ 200 DPI).
  /// Step 3: Direct digital text extraction for vector PDFs.
  static Future<ParsedReceiptResult?> analyzeReceiptPdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();

      // Step 1: Instant extraction of embedded JPEG (Yellow app Page 1 format, < 3ms)
      final embeddedJpeg = PdfTextExtractor.extractFirstEmbeddedJpeg(bytes);
      if (embeddedJpeg != null) {
        final tempJpg = File(
            '${pdfFile.parent.path}/embedded_page1_${DateTime.now().millisecondsSinceEpoch}.jpg');
        try {
          await tempJpg.writeAsBytes(embeddedJpeg);
          final res = await analyzeReceiptImage(tempJpg);
          if (res != null && (res.amount > 0 || res.liters != null)) {
            return res;
          }
        } finally {
          try {
            await tempJpg.delete();
          } catch (_) {}
        }
      }

      // Step 2: High-resolution rasterization of Page 1 ONLY (Scale 2.8x @ 200 DPI)
      try {
        await for (final page in Printing.raster(bytes, pages: const [0], dpi: 200)
            .timeout(const Duration(seconds: 4))) {
          final pngBytes = await page.toPng();
          final tempImg = File(
              '${pdfFile.parent.path}/pdf_page1_${DateTime.now().millisecondsSinceEpoch}.png');
          try {
            await tempImg.writeAsBytes(pngBytes);
            final res = await analyzeReceiptImage(tempImg);
            if (res != null && (res.amount > 0 || res.liters != null)) {
              return res;
            }
          } finally {
            try {
              await tempImg.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Step 3: On-device digital text extraction if PDF has selectable text
      final extractedText = await PdfTextExtractor.extractText(pdfFile);
      if (extractedText.trim().isNotEmpty) {
        final parsed = parseReceiptText(extractedText);
        if (parsed.amount > 0 || parsed.liters != null) {
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('>>> [ReceiptOcr] Error analyzing PDF receipt: $e');
    }
    return null;
  }

  /// Mathematical Triplet Search:
  /// (price per liter) * (liters) = (total amount) within 0.05 tolerance.
  /// Filters out octane numbers (95, 98), phone numbers, and barcodes.
  static FuelMathTriplet? findBestFuelTriplet(String text) {
    // Normalize commas inside decimal numbers to dots (e.g. 8,270 -> 8.270)
    final normalized = text.replaceAllMapped(
      RegExp(r'(\d+),(\d+)'),
      (m) => '${m[1]}.${m[2]}',
    );

    // Extract potential float numbers
    final floatMatches = RegExp(r'\b\d+\.\d+\b').allMatches(normalized);
    final candidates = <double>[];
    for (final m in floatMatches) {
      final val = double.tryParse(m.group(0)!);
      if (val != null && val > 0 && !candidates.contains(val)) {
        candidates.add(val);
      }
    }

    if (candidates.length < 2) return null;

    final triplets = <FuelMathTriplet>[];

    // Priority 1: Realistic Israeli fuel price range [5.00, 10.50]
    for (final price in candidates) {
      if (price < 5.0 || price > 10.50) continue;

      for (final liters in candidates) {
        if ((liters - price).abs() < 0.001) continue;
        if (liters < 0.5 || liters > 250.0) continue;

        final expectedTotal = price * liters;

        for (final total in candidates) {
          if ((total - price).abs() < 0.001 || (total - liters).abs() < 0.001) continue;
          if (total < 5.0 || total > 3000.0) continue;

          if ((expectedTotal - total).abs() <= 0.05) {
            triplets.add(FuelMathTriplet(
              pricePerLiter: price,
              liters: liters,
              totalAmount: total,
            ));
          }
        }
      }
    }

    // Priority 2: Extended price range fallback [4.00, 12.00]
    if (triplets.isEmpty) {
      for (final price in candidates) {
        if (price < 4.0 || price > 12.0) continue;

        for (final liters in candidates) {
          if ((liters - price).abs() < 0.001) continue;
          if (liters < 0.5 || liters > 250.0) continue;

          final expectedTotal = price * liters;

          for (final total in candidates) {
            if ((total - price).abs() < 0.001 || (total - liters).abs() < 0.001) continue;
            if (total < 5.0 || total > 3000.0) continue;

            if ((expectedTotal - total).abs() <= 0.05) {
              triplets.add(FuelMathTriplet(
                pricePerLiter: price,
                liters: liters,
                totalAmount: total,
              ));
            }
          }
        }
      }
    }

    if (triplets.isEmpty) return null;

    int scoreTriplet(FuelMathTriplet t) {
      int score = 0;
      final pStr = t.pricePerLiter.toString();
      final lStr = t.liters.toString();
      final escapedP = RegExp.escape(pStr);
      final escapedL = RegExp.escape(lStr);

      final priceNearKeyword = RegExp('(?:מחיר|price|לליטר|95)\\s*[:\\s-]*$escapedP', caseSensitive: false).hasMatch(normalized);
      if (priceNearKeyword) score += 20;

      final litersNearKeyword = RegExp('(?:כמות|ליטר|ליטרים|qty|liters?)\\s*[:\\s-]*$escapedL', caseSensitive: false).hasMatch(normalized);
      if (litersNearKeyword) score += 20;

      final litersInverted = RegExp('$escapedL\\s*(?:ליטר|ליטרים|כמות)', caseSensitive: false).hasMatch(normalized);
      if (litersInverted) score += 20;

      final firstL = RegExp.escape(lStr.split('.').first);
      final litersHas3Dec = RegExp('\\b$firstL\\.\\d{3}\\b').hasMatch(normalized);
      if (litersHas3Dec) score += 10;

      if (t.pricePerLiter >= 6.5 && t.pricePerLiter <= 9.5) score += 5;

      return score;
    }

    triplets.sort((a, b) {
      final scoreA = scoreTriplet(a);
      final scoreB = scoreTriplet(b);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return b.totalAmount.compareTo(a.totalAmount);
    });
    return triplets.first;
  }

  /// Smart Fuel Math & Heuristic Parser for Israeli Fuel Receipts.
  /// 100% offline, deterministic, and supports Hebrew and Latin ML Kit outputs.
  static ParsedReceiptResult parseReceiptText(String text) {
    final clean = text.replaceAll('\r', ' ');
    final lower = clean.toLowerCase();

    // 1. Detect if Fuel or Garage Maintenance
    final isFuel = clean.contains('פז') ||
        lower.contains('yellow') ||
        lower.contains('paz') ||
        lower.contains('sonol') ||
        lower.contains('delek') ||
        lower.contains('ten') ||
        lower.contains('dor alon') ||
        lower.contains('doralon') ||
        lower.contains('mika') ||
        clean.contains('ילאו') ||
        clean.contains('ילו') ||
        clean.contains('דלק') ||
        clean.contains('סונול') ||
        clean.contains('דור אלון') ||
        clean.contains('מיקה') ||
        clean.contains('אוקטן') ||
        clean.contains('תדלוק') ||
        clean.contains('משאבה') ||
        clean.contains('בנזין') ||
        clean.contains('סולר') ||
        RegExp(r'(?:^|\s)95\s+[:\s]*\d').hasMatch(clean);

    // 2. Run Smart Fuel Math Parser (price * liters = total)
    final mathTriplet = findBestFuelTriplet(clean);

    double? pricePerLiter = mathTriplet?.pricePerLiter;
    double? liters = mathTriplet?.liters;
    double amount = mathTriplet?.totalAmount ?? 0.0;

    // If mathematical triplet wasn't complete, fallback to heuristic extraction
    if (pricePerLiter == null) {
      final pricePatterns = [
        RegExp(r'מחיר\s*(?:לליטר|ליטר)?[:\s]*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d{1,3})?)\s*(?:ש"?ח|₪)?\s*(?:לליטר|מחיר)', caseSensitive: false),
        RegExp(r'(?:אוקטן|בנזין|octan[e]?|fuel|gas)?\s*95\s*[:\s-]+\s*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
        RegExp(r'(?:^|\s)95\s+[:\s]*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
        RegExp(r'(?:סולר|diesel)\s*[:\s-]+\s*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
      ];
      for (final p in pricePatterns) {
        final m = p.firstMatch(clean);
        if (m != null) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val >= 4.0 && val <= 15.0) {
            pricePerLiter = val;
            break;
          }
        }
      }
    }

    if (liters == null) {
      final litersPatterns = [
        RegExp(r'(?:כמות\s*\(?ליטרים?\)?|כמות)[:\s]*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d{1,3})?)\s*(?:ליטרים|ליטר|ל\b)(?!\s*(?:ש"?ח|שח|₪))', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d{1,3})?)\s*:\s*כמות', caseSensitive: false),
        RegExp(r'(?<!מחיר\s)(?<!ל)(?:ליטרים?|ל\b)\s*:\s*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
        RegExp(r'(?:בנזין|אוקטן)\s*95[^\d\n\r]*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
      ];

      for (final p in litersPatterns) {
        final m = p.firstMatch(clean);
        if (m != null) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val > 0 && val < 250 && (pricePerLiter == null || (val - pricePerLiter).abs() > 0.005)) {
            liters = val;
            break;
          }
        }
      }

      // Standalone 3-decimal meter reading
      if (liters == null) {
        final matches3Dec = RegExp(r'\b(\d{1,3}[.,]\d{3})\b').allMatches(clean);
        for (final m in matches3Dec) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val > 0.2 && val < 250) {
            if (pricePerLiter != null && (val - pricePerLiter).abs() <= 0.005) {
              continue;
            }
            liters = val;
            break;
          }
        }
      }
    }

    if (amount <= 0) {
      final totalPatterns = [
        RegExp(r'(?:סה"?כ\s*לתשלום|סה"?כ\s*דלקים|סכום\s*לתשלום|סכום\s*החיוב|סה"?כ\s*שולם|לתשלום)[:\s]*(?:ש"?ח|שח|₪|ILS)?\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*(?:ש"?ח|שח|₪|ILS)?\s*(?:סה"?כ\s*לתשלום|סה"?כ\s*דלקים|לתשלום|סכום\s*חיוב)', caseSensitive: false),
        RegExp(r'סה"?כ[:\s]*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*(?:ש"?ח|שח|₪)?\s*סה"?כ', caseSensitive: false),
        RegExp(r'(?:בסך|חיוב|סכום)[:\s]*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
        RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*:\s*(?:סה"?כ|לתשלום|חיוב)', caseSensitive: false),
        RegExp(r'(?:total|amount|payment)[:\s]*(?:₪|ILS)?\s*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
      ];

      for (final p in totalPatterns) {
        final m = p.firstMatch(clean);
        if (m != null) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val > 0) {
            amount = val;
            break;
          }
        }
      }

      if (amount <= 0) {
        final currencyRegex = RegExp(r'(\d{1,4}(?:[.,]\d{2}))\s*(?:ש"?ח|שח|₪|ILS)', caseSensitive: false);
        for (final m in currencyRegex.allMatches(clean)) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val > amount && val < 5000) {
            amount = val;
          }
        }
      }

      // Mathematical completion
      if (pricePerLiter != null && liters != null) {
        amount = double.parse((pricePerLiter * liters).toStringAsFixed(2));
      } else if (amount > 0 && pricePerLiter != null && liters == null && pricePerLiter > 0) {
        liters = double.parse((amount / pricePerLiter).toStringAsFixed(2));
      } else if (amount > 0 && liters != null && pricePerLiter == null && liters > 0) {
        pricePerLiter = double.parse((amount / liters).toStringAsFixed(3));
      }
    }

    // 3. Extract Provider / Station Branch
    String providerName = '';

    final cityBranches = [
      'בעינה', 'בענה', 'בית הכרם', 'טמרה', 'שפרעם', 'מגאר', 'סחנין', 'עכו', 'כרמיאל',
      'חיפה', 'נצרת', 'תל אביב', 'ירושלים', 'כפר כנא', 'קרית שמונה',
      'עפולה', 'טבריה', 'נתניה', 'אום אל פחם', 'רמله', 'באר שבע', 'דיר אל אסד', 'ירכא'
    ];

    for (final city in cityBranches) {
      if (clean.contains(city)) {
        if (clean.contains('פז') || lower.contains('yellow') || lower.contains('paz')) {
          providerName = 'פז $city';
        } else if (clean.contains('סונול') || lower.contains('sonol')) {
          providerName = 'סונול $city';
        } else if (clean.contains('דלק') || lower.contains('delek')) {
          providerName = 'דלק $city';
        } else if (clean.contains('דור אלון') || lower.contains('dor alon')) {
          providerName = 'דור אלון $city';
        } else {
          providerName = 'תחנת $city';
        }
        break;
      }
    }

    if (providerName.isEmpty) {
      if (lower.contains('yellow')) {
        providerName = clean.contains('365') || clean.contains('בעינה')
            ? 'פז בעינה 365'
            : 'פז Yellow';
      } else if (lower.contains('sonol')) {
        providerName = 'סונול';
      } else if (lower.contains('delek')) {
        providerName = 'דלק';
      } else if (lower.contains('dor alon') || lower.contains('doralon')) {
        providerName = 'דור אלון';
      } else if (lower.contains('ten')) {
        providerName = 'טן';
      } else if (lower.contains('paz')) {
        providerName = 'פז';
      } else if (lower.contains('mika')) {
        providerName = 'מיקה';
      }
    }

    if (providerName.isEmpty) {
      if (clean.contains('פז') || clean.contains('ילאו') || clean.contains('ילו')) {
        providerName = 'פז Yellow';
      } else if (clean.contains('סונול')) {
        providerName = 'סונול';
      } else if (clean.contains('דלק')) {
        providerName = 'דלק';
      } else if (clean.contains('דור אלון')) {
        providerName = 'דור אלון';
      } else if (clean.contains('מיקה')) {
        providerName = 'מיקה';
      } else if (clean.contains('365')) {
        providerName = 'פז בעינה 365';
      } else {
        providerName = isFuel ? 'تعبئة بنزين' : '';
      }
    }

    providerName = providerName
        .replaceAll('חברת נפט', '')
        .replaceAll('בע"מ', '')
        .trim();

    // 4. Extract Date & Time (dd/mm/yyyy, dd.mm.yy, dd-mm-yyyy)
    DateTime receiptDate = DateTime.now();
    final dateMatch = RegExp(r'(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})').firstMatch(clean);
    if (dateMatch != null) {
      final d = int.tryParse(dateMatch.group(1) ?? '') ?? 1;
      final m = int.tryParse(dateMatch.group(2) ?? '') ?? 1;
      var y = int.tryParse(dateMatch.group(3) ?? '') ?? DateTime.now().year;
      if (y < 100) y += 2000;

      int hour = DateTime.now().hour;
      int minute = DateTime.now().minute;
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(clean);
      if (timeMatch != null) {
        hour = int.tryParse(timeMatch.group(1) ?? '') ?? hour;
        minute = int.tryParse(timeMatch.group(2) ?? '') ?? minute;
      }
      receiptDate = DateTime(y, m, d, hour, minute);
    }

    // 5. Extract Odometer
    int? odometer;
    final odoMatch = RegExp(r"""(?:מד\s*אוץ|קילומטראז'?|ק"מ)[:\s]*(\d{3,7})""").firstMatch(clean);
    if (odoMatch != null) {
      odometer = int.tryParse(odoMatch.group(1) ?? '');
    }

    // 6. Extract Invoice / Receipt Number
    String? invoiceNumber;
    final sameLineInvMatch = RegExp(
      r"""(?:חשבונית(?:\s*מס(?:'?|פר)?)?(?:[\s\/]*קבלה)?|קבלה|אסמכתא|אישור)[^\d\n\r]{0,30}[:#]?\s*(\d{3,20})""",
      caseSensitive: false,
    ).firstMatch(clean);

    if (sameLineInvMatch != null) {
      invoiceNumber = sameLineInvMatch.group(1);
    } else {
      final multiLineInvMatch = RegExp(
        r"""(?:חשבונית(?:\s*מס(?:'?|פר)?)?(?:[\s\/]*קבלה)?|קבלה|אסמכתא|אישור)[\s\S]{0,30}?(\d{5,20})""",
        caseSensitive: false,
      ).firstMatch(clean);

      if (multiLineInvMatch != null) {
        invoiceNumber = multiLineInvMatch.group(1);
      } else {
        final codeMatch = RegExp(r"""(?:מספר|מס(?:'?|פר)?|קוד)[^\d\n\r]{0,10}[:#]?\s*(\d{3,16})""", caseSensitive: false).firstMatch(clean);
        if (codeMatch != null) {
          invoiceNumber = codeMatch.group(1);
        } else {
          // Standalone numeric line of 10 to 20 digits (e.g. 036509901116246)
          final standaloneInvMatch = RegExp(r'^\s*(\d{10,20})\s*$', multiLine: true).firstMatch(clean);
          if (standaloneInvMatch != null) {
            invoiceNumber = standaloneInvMatch.group(1);
          }
        }
      }
    }

    // 7. Extract Detected Items
    final detectedItems = <String>[];
    if (isFuel) {
      detectedItems.add('דלק 95 אוקטן');
      if (providerName.isNotEmpty) {
        detectedItems.add('תשלום $providerName');
      }
      if (liters != null) {
        detectedItems.add('כמות: $liters ליטר');
      }
      if (pricePerLiter != null) {
        detectedItems.add('מחיר לליטר: $pricePerLiter ₪');
      }
    } else {
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
    }

    // 8. Build Title
    String title;
    if (isFuel) {
      final litersStr = liters != null ? ' ($liters ליטר)' : '';
      if (providerName == 'تعبئة بنزين' || providerName.isEmpty) {
        title = 'تعبئة بنزين$litersStr';
      } else {
        final stationStr = providerName.startsWith('פז') ? providerName : 'פז $providerName';
        title = 'תדלוק $stationStr$litersStr';
      }
    } else {
      final invStr = invoiceNumber != null ? ' (חשבונית #$invoiceNumber)' : '';
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
      pricePerLiter: pricePerLiter,
      odometer: odometer,
      providerName: providerName.isNotEmpty ? providerName : 'תדלוק',
      rawText: text,
      invoiceNumber: invoiceNumber,
      items: detectedItems,
    );
  }
}
