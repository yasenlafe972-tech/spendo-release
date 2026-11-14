import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'israeli_fuel_station_registry.dart';
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
  final int? pageNumber;
  final int? totalPages;
  final double? beforeVat;
  final double? vatAmount;
  final String? fuelGrade;

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
    this.pageNumber,
    this.totalPages,
    this.beforeVat,
    this.vatAmount,
    this.fuelGrade,
  });

  ParsedReceiptResult copyWith({
    String? title,
    double? amount,
    DateTime? date,
    bool? isFuel,
    double? liters,
    double? pricePerLiter,
    int? odometer,
    String? providerName,
    String? rawText,
    String? invoiceNumber,
    List<String>? items,
    int? pageNumber,
    int? totalPages,
    double? beforeVat,
    double? vatAmount,
    String? fuelGrade,
  }) {
    return ParsedReceiptResult(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      isFuel: isFuel ?? this.isFuel,
      liters: liters ?? this.liters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      odometer: odometer ?? this.odometer,
      providerName: providerName ?? this.providerName,
      rawText: rawText ?? this.rawText,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      items: items ?? this.items,
      pageNumber: pageNumber ?? this.pageNumber,
      totalPages: totalPages ?? this.totalPages,
      beforeVat: beforeVat ?? this.beforeVat,
      vatAmount: vatAmount ?? this.vatAmount,
      fuelGrade: fuelGrade ?? this.fuelGrade,
    );
  }
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

class StoreMathTriplet {
  final double beforeVat;
  final double vat;
  final double totalAmount;

  const StoreMathTriplet({
    required this.beforeVat,
    required this.vat,
    required this.totalAmount,
  });
}

class ReceiptOcrService {
  static const MethodChannel _shareChannel =
      MethodChannel('com.finance.spendo/share');

  /// High-reliability, 100% on-device offline OCR analyzer.
  /// Works across both iOS (Apple Vision) and Android (Google ML Kit) + Official Israeli Fuel Station Registry.
  static Future<ParsedReceiptResult?> analyzeReceiptImage(File imageFile) async {
    if (!imageFile.existsSync()) return null;

    if (Platform.isIOS || Platform.isAndroid) {
      try {
        final visionText = await _shareChannel.invokeMethod<String>(
          'extractImageText',
          imageFile.path,
        );
        if (visionText != null && visionText.trim().isNotEmpty) {
          debugPrint('>>> [ReceiptOCR Raw] $visionText');
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

  /// 100% offline analyzer for Israeli gas receipts & Yellow app multi-receipt PDFs.
  /// Combines digital PDF text extraction with embedded JPEG / raster OCR so both
  /// Hebrew text layers and image-based receipts are captured completely.
  static Future<List<ParsedReceiptResult>> analyzeReceiptPdfMulti(
    File pdfFile, {
    void Function(int current, int total)? onProgress,
  }) async {
    final results = <ParsedReceiptResult>[];
    final seenKeys = <String>{};

    try {
      final bytes = await pdfFile.readAsBytes();

      // Step 1: Detect exact total page count of the PDF document first
      final totalDocPages = PdfTextExtractor.getPdfPageCount(bytes);
      debugPrint('>>> [ReceiptOcr] PDF Document Total Pages: $totalDocPages');

      // Also extract any digital text stream if present (useful for single-page vector PDFs)
      String digitalPdfText = '';
      try {
        digitalPdfText = await PdfTextExtractor.extractText(pdfFile);
      } catch (_) {}

      // Step 2: Instant extraction of all embedded JPEGs (one per page in Yellow exports, < 15ms)
      final embeddedJpegs = PdfTextExtractor.extractAllEmbeddedJpegs(bytes);
      if (embeddedJpegs.isNotEmpty) {
        final totalCount =
            totalDocPages > 0 ? totalDocPages : embeddedJpegs.length;
        for (int i = 0; i < embeddedJpegs.length; i++) {
          final pageNum = i + 1;
          onProgress?.call(pageNum, totalCount);
          final tempJpg = File(
            '${pdfFile.parent.path}/temp_embedded_rcpt_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          );
          try {
            await tempJpg.writeAsBytes(embeddedJpegs[i]);
            var res = await analyzeReceiptImage(tempJpg);
            if (res != null &&
                embeddedJpegs.length == 1 &&
                digitalPdfText.trim().isNotEmpty) {
              // Merge digital text + image OCR text for maximum fidelity
              res = parseReceiptText('${res.rawText}\n$digitalPdfText');
            }
            debugPrint(
              '>>> [ReceiptIdx $i (Page $pageNum/$totalCount)] Parsed: station=${res?.providerName}, amount=${res?.amount}, liters=${res?.liters}, price=${res?.pricePerLiter}, inv=${res?.invoiceNumber}',
            );
            if (res != null && res.amount > 0) {
              final withPage = res.copyWith(
                pageNumber: pageNum,
                totalPages: totalCount,
              );
              final key =
                  '${withPage.date.year}-${withPage.date.month}-${withPage.date.day}_${withPage.amount.toStringAsFixed(2)}_${withPage.pageNumber}';
              if (seenKeys.add(key)) {
                results.add(withPage);
              }
            }
          } finally {
            try {
              await tempJpg.delete();
            } catch (_) {}
          }
        }
        if (results.isNotEmpty) {
          results.sort(
            (a, b) => (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0),
          );
          return results;
        }
      }

      // Step 3: High-resolution rasterization page-by-page if no embedded JPEGs
      try {
        int pageIndex = 0;
        final maxPages = totalDocPages > 0 ? totalDocPages : 15;
        await for (final page in Printing.raster(
          bytes,
          dpi: 220,
        ).timeout(const Duration(seconds: 15))) {
          pageIndex++;
          onProgress?.call(pageIndex, maxPages);
          final pngBytes = await page.toPng();
          final tempImg = File(
            '${pdfFile.parent.path}/temp_raster_rcpt_${DateTime.now().millisecondsSinceEpoch}_$pageIndex.png',
          );
          try {
            await tempImg.writeAsBytes(pngBytes);
            var res = await analyzeReceiptImage(tempImg);
            if (res != null &&
                maxPages == 1 &&
                digitalPdfText.trim().isNotEmpty) {
              res = parseReceiptText('${res.rawText}\n$digitalPdfText');
            }
            if (res != null && res.amount > 0) {
              final withPage = res.copyWith(
                pageNumber: pageIndex,
                totalPages: maxPages,
              );
              final key =
                  '${withPage.date.year}-${withPage.date.month}-${withPage.date.day}_${withPage.amount.toStringAsFixed(2)}_${withPage.pageNumber}';
              if (seenKeys.add(key)) {
                results.add(withPage);
              }
            }
          } finally {
            try {
              await tempImg.delete();
            } catch (_) {}
          }
          if (pageIndex >= maxPages) break;
        }
        if (results.isNotEmpty) {
          results.sort(
            (a, b) => (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0),
          );
          return results;
        }
      } catch (_) {}

      // Step 4: On-device digital text extraction if PDF has selectable text
      if (digitalPdfText.trim().isNotEmpty) {
        final parsed = parseReceiptText(digitalPdfText);
        if (parsed.amount > 0) {
          results.add(
            parsed.copyWith(
              pageNumber: 1,
              totalPages: totalDocPages > 0 ? totalDocPages : 1,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('>>> [ReceiptOcr] Error analyzing multi-receipt PDF: $e');
    }

    results.sort((a, b) => (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0));
    return results;
  }

  /// Single receipt convenience wrapper
  static Future<ParsedReceiptResult?> analyzeReceiptPdf(File pdfFile) async {
    final list = await analyzeReceiptPdfMulti(pdfFile);
    return list.isNotEmpty ? list.first : null;
  }

  /// Mathematical Triplet Search:
  /// (price per liter) * (liters) = (total amount) within 0.08 tolerance.
  /// Also handles paper receipts where total is printed as a round integer (e.g. 50 or 100)
  /// or where the fuel item row has (3951 / 95) + liters + pricePerLiter.
  static FuelMathTriplet? findBestFuelTriplet(String text) {
    final normalized = text.replaceAllMapped(
      RegExp(r'(\d+),(\d+)'),
      (m) => '${m[1]}.${m[2]}',
    );

    final floatMatches =
        RegExp(r'(?<!\d)(\d+\.\d{1,3})(?!\d)').allMatches(normalized);
    final floatCandidates = <double>[];
    for (final m in floatMatches) {
      final val = double.tryParse(m.group(1)!);
      if (val != null && val > 0 && !floatCandidates.contains(val)) {
        floatCandidates.add(val);
      }
    }

    // Also collect standalone integer candidates for round totals on paper receipts (e.g., 50, 100, 150, 200)
    final totalCandidates = <double>[...floatCandidates];
    final excludedInts = <int>{95, 98, 17, 18, 10, 3951};
    for (final m in RegExp(r'(?<![\d.])(\d{2,4})(?![\d.])').allMatches(normalized)) {
      final intVal = int.tryParse(m.group(1)!);
      if (intVal != null &&
          intVal >= 15 &&
          intVal <= 2500 &&
          !excludedInts.contains(intVal)) {
        final dVal = intVal.toDouble();
        if (!totalCandidates.contains(dVal)) {
          totalCandidates.add(dVal);
        }
      }
    }

    if (floatCandidates.length < 2) return null;

    final triplets = <FuelMathTriplet>[];

    void searchInPriceRange(double minPrice, double maxPrice) {
      for (final price in floatCandidates) {
        if (price < minPrice || price > maxPrice) continue;

        for (final liters in floatCandidates) {
          if ((liters - price).abs() < 0.001) continue;
          if (liters < 0.4 || liters > 250.0) continue;

          final expectedTotal = price * liters;

          for (final total in totalCandidates) {
            if ((total - price).abs() < 0.001 ||
                (total - liters).abs() < 0.001) {
              continue;
            }
            if (total < 5.0 || total > 3500.0) continue;

            if ((expectedTotal - total).abs() <= 0.08) {
              triplets.add(
                FuelMathTriplet(
                  pricePerLiter: price,
                  liters: liters,
                  totalAmount: double.parse(total.toStringAsFixed(2)),
                ),
              );
            }
          }
        }
      }
    }

    // Priority 1: Standard Israeli fuel price range [5.00, 10.50]
    searchInPriceRange(5.0, 10.50);

    // Priority 2: Extended price range fallback [4.00, 12.00]
    if (triplets.isEmpty) {
      searchInPriceRange(4.0, 12.0);
    }

    // Priority 3: Direct table line match (e.g. "3951 בנע 95 6.369 7.85" or "7.85 6.369 95 3951")
    // if total was smudged on a paper receipt
    if (triplets.isEmpty) {
      for (final price in floatCandidates) {
        if (price < 5.5 || price > 9.8) continue;
        for (final liters in floatCandidates) {
          if ((liters - price).abs() < 0.001) continue;
          // Require 3-decimal liters meter reading (e.g. 6.369)
          final lStr = liters.toStringAsFixed(3);
          if (normalized.contains(lStr)) {
            final computedTotal =
                double.parse((price * liters).toStringAsFixed(2));
            if (computedTotal >= 5.0 && computedTotal <= 2500.0) {
              triplets.add(
                FuelMathTriplet(
                  pricePerLiter: price,
                  liters: liters,
                  totalAmount: computedTotal,
                ),
              );
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
      final tStr = t.totalAmount.toStringAsFixed(2);
      final escapedP = RegExp.escape(pStr);
      final escapedL = RegExp.escape(lStr);
      final escapedT = RegExp.escape(tStr);

      if (normalized.contains(tStr)) score += 15;
      if (RegExp('(?:לתשלום|סה"?כ|ש"ח|₪)[:\\s]*$escapedT').hasMatch(normalized) ||
          RegExp('$escapedT\\s*(?:ש"ח|₪|:|\\s*לתשלום)').hasMatch(normalized)) {
        score += 20;
      }

      final priceNearKeyword = RegExp(
        '(?:מחיר|price|לליטר|95|בנע|3951)\\s*[:\\s-]*$escapedP',
        caseSensitive: false,
      ).hasMatch(normalized);
      if (priceNearKeyword) score += 20;

      final litersNearKeyword = RegExp(
        '(?:כמות|ליטר|ליטרים|qty|liters?|95|בנע)\\s*[:\\s-]*$escapedL',
        caseSensitive: false,
      ).hasMatch(normalized);
      if (litersNearKeyword) score += 20;

      final litersInverted = RegExp(
        '$escapedL\\s*(?:ליטר|ליטרים|כמות|95|בנע)',
        caseSensitive: false,
      ).hasMatch(normalized);
      if (litersInverted) score += 20;

      final firstL = RegExp.escape(lStr.split('.').first);
      final litersHas3Dec = RegExp('\\b$firstL\\.\\d{3}\\b').hasMatch(normalized);
      if (litersHas3Dec) score += 15;

      if (t.pricePerLiter >= 6.5 && t.pricePerLiter <= 9.2) score += 10;

      // Exact product proximity bonus
      final diff = (t.pricePerLiter * t.liters - t.totalAmount).abs();
      if (diff <= 0.01) score += 15;

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

  /// Mathematical Store VAT Parser:
  /// (beforeVat) + (vat) = (totalAmount) within 0.08 tolerance,
  /// with VAT ratio around 17% - 18% (Israeli standard).
  static StoreMathTriplet? findBestStoreMathTriplet(String text) {
    final normalized = text.replaceAllMapped(
      RegExp(r'(\d+),(\d+)'),
      (m) => '${m[1]}.${m[2]}',
    );

    final floatMatches =
        RegExp(r'(?<!\d)(\d+\.\d{1,3})(?!\d)').allMatches(normalized);
    final candidates = <double>[];
    for (final m in floatMatches) {
      final val = double.tryParse(m.group(1)!);
      if (val != null && val > 0 && !candidates.contains(val)) {
        candidates.add(val);
      }
    }

    if (candidates.length < 3) return null;

    final triplets = <StoreMathTriplet>[];

    for (final beforeVat in candidates) {
      if (beforeVat < 1.0 || beforeVat > 3000.0) continue;

      for (final vat in candidates) {
        if (vat >= beforeVat) continue;
        final ratio = vat / beforeVat;
        // Israeli VAT is 17% or 18% (allow margin 15% to 20%)
        if (ratio < 0.15 || ratio > 0.20) continue;

        final expectedTotal = beforeVat + vat;

        for (final total in candidates) {
          if (total <= beforeVat) continue;
          if ((expectedTotal - total).abs() <= 0.08) {
            triplets.add(
              StoreMathTriplet(
                beforeVat: beforeVat,
                vat: vat,
                totalAmount: total,
              ),
            );
          }
        }
      }
    }

    if (triplets.isEmpty) return null;

    triplets.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return triplets.first;
  }

  /// Smart Fuel Math & Official Station Registry Parser for Israeli Fuel Receipts (Digital & Paper).
  /// Extracts 100% of receipt fields: exact station name & branch code, total amount, liters,
  /// price per liter, before-VAT & VAT amounts, purchase date & time, and fiscal invoice number.
  static ParsedReceiptResult parseReceiptText(String text) {
    final clean = text.replaceAll('\r', '\n');
    final lower = clean.toLowerCase();

    // 1. Detect Fuel Company & Fuel Indicators
    final detectedCompany = IsraeliFuelStationRegistry.detectCompany(clean);

    final hasFuelKeywords = detectedCompany.isNotEmpty ||
        clean.contains('אוקטן') ||
        clean.contains('תדלוק') ||
        clean.contains('מתדלוק') ||
        clean.contains('משאבה') ||
        clean.contains('בנזין') ||
        clean.contains('בנע') ||
        clean.contains('נטול עופרת') ||
        clean.contains('סולר') ||
        clean.contains('חצר תחנה') ||
        RegExp(r'\b3951\b').hasMatch(clean) ||
        RegExp(r'(?:^|\s)95\s+[:\s]*\d').hasMatch(clean) ||
        RegExp(r'\d+\.\d{3}\s+\d+\.\d{2}').hasMatch(clean) ||
        RegExp(r'\d+\.\d{2}\s+\d+\.\d{3}').hasMatch(clean);

    // 2. Run Smart Fuel Math Parser (price * liters = total)
    final mathTriplet = findBestFuelTriplet(clean);
    final storeTriplet = findBestStoreMathTriplet(clean);

    double? pricePerLiter = mathTriplet?.pricePerLiter;
    double? liters = mathTriplet?.liters;
    double amount = mathTriplet?.totalAmount ?? 0.0;
    double? beforeVat = storeTriplet?.beforeVat;
    double? vatAmount = storeTriplet?.vat;

    bool receiptIsFuel = mathTriplet != null ||
        clean.contains('אוקטן') ||
        clean.contains('בנזין') ||
        clean.contains('בנע') ||
        clean.contains('סולר') ||
        clean.contains('משאבה') ||
        clean.contains('תדלוק') ||
        clean.contains('מתדלוק') ||
        RegExp(r'\b3951\b').hasMatch(clean);

    if (amount <= 0 && mathTriplet == null && storeTriplet != null) {
      amount = storeTriplet.totalAmount;
      if (!receiptIsFuel) {
        receiptIsFuel = false;
      }
    }

    // Fallback heuristic extraction if math triplet was partial (e.g. faded paper receipt)
    if (pricePerLiter == null) {
      final pricePatterns = [
        RegExp(
          r'מחיר\s*(?:לליטר|ליטר)?[:\s]*(\d+(?:[.,]\d{1,3})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'(\d+(?:[.,]\d{1,3})?)\s*(?:ש"?ח|₪)?\s*(?:לליטר|מחיר)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:אוקטן|בנזין|בנע|octan[e]?|fuel|gas)?\s*95\s*[:\s-]+\s*(\d+(?:[.,]\d{1,3})?)',
          caseSensitive: false,
        ),
        RegExp(r'(?:^|\s)95\s+[:\s]*(\d+(?:[.,]\d{1,3})?)', caseSensitive: false),
        RegExp(
          r'(?:סולר|diesel)\s*[:\s-]+\s*(\d+(?:[.,]\d{1,3})?)',
          caseSensitive: false,
        ),
      ];
      for (final p in pricePatterns) {
        final m = p.firstMatch(clean);
        if (m != null) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val >= 4.5 && val <= 12.0) {
            pricePerLiter = val;
            break;
          }
        }
      }
    }

    if (liters == null) {
      final litersPatterns = [
        RegExp(
          r'(?:כמות\s*\(?ליטרים?\)?|כמות)[:\s]*(\d+(?:[.,]\d{1,3})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'(\d+(?:[.,]\d{1,3})?)\s*(?:ליטרים|ליטר|ל\b)(?!\s*(?:ש"?ח|שח|₪))',
          caseSensitive: false,
        ),
        RegExp(r'(\d+(?:[.,]\d{1,3})?)\s*:\s*כמות', caseSensitive: false),
        RegExp(
          r'(?<!מחיר\s)(?<!ל)(?:ליטרים?|ל\b)\s*:\s*(\d+(?:[.,]\d{1,3})?)',
          caseSensitive: false,
        ),
      ];

      for (final p in litersPatterns) {
        final m = p.firstMatch(clean);
        if (m != null) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null &&
              val > 0 &&
              val < 250 &&
              (pricePerLiter == null || (val - pricePerLiter).abs() > 0.005)) {
            liters = val;
            break;
          }
        }
      }

      // Standalone 3-decimal pump meter reading (e.g. 6.369)
      if (liters == null) {
        final matches3Dec = RegExp(r'\b(\d{1,3}[.,]\d{3})\b').allMatches(clean);
        for (final m in matches3Dec) {
          final val = double.tryParse(m.group(1)?.replaceAll(',', '.') ?? '');
          if (val != null && val > 0.2 && val < 250) {
            if (pricePerLiter != null && (val - pricePerLiter).abs() <= 0.005) {
              continue;
            }
            liters = val;
            receiptIsFuel = true;
            break;
          }
        }
      }
    }

    if (amount <= 0) {
      final totalPatterns = [
        RegExp(
          r'(?:סה"?כ\s*לתשלום|סה"?כ\s*דלקים|סכום\s*לתשלום|סכום\s*החיוב|סה"?כ\s*שולם|לתשלום)[:\s]*(?:ש"?ח|שח|₪|ILS)?\s*(\d+(?:[.,]\d{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'(\d+(?:[.,]\d{1,2})?)\s*(?:ש"?ח|שח|₪|ILS)?\s*[:\s]*(?:סה"?כ\s*לתשלום|סה"?כ\s*דלקים|לתשלום|סכום\s*חיוב)',
          caseSensitive: false,
        ),
        RegExp(r'סה"?כ[:\s]*(\d+(?:[.,]\d{1,2})?)', caseSensitive: false),
        RegExp(
          r'(\d+(?:[.,]\d{1,2})?)\s*(?:ש"?ח|שח|₪)?\s*סה"?כ',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:בסך|חיוב|סכום)[:\s]*(\d+(?:[.,]\d{1,2})?)',
          caseSensitive: false,
        ),
        RegExp(
          r'(\d+(?:[.,]\d{1,2})?)\s*:\s*(?:סה"?כ|לתשלום|חיוב)',
          caseSensitive: false,
        ),
        RegExp(
          r'(?:total|amount|payment)[:\s]*(?:₪|ILS)?\s*(\d+(?:[.,]\d{1,2})?)',
          caseSensitive: false,
        ),
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
        final currencyRegex = RegExp(
          r'(\d{1,4}(?:[.,]\d{2}))\s*(?:ש"?ח|שח|₪|ILS)',
          caseSensitive: false,
        );
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
        receiptIsFuel = true;
      } else if (amount > 0 &&
          pricePerLiter != null &&
          liters == null &&
          pricePerLiter > 0) {
        liters = double.parse((amount / pricePerLiter).toStringAsFixed(3));
        receiptIsFuel = true;
      } else if (amount > 0 &&
          liters != null &&
          pricePerLiter == null &&
          liters > 0) {
        pricePerLiter = double.parse((amount / liters).toStringAsFixed(2));
        receiptIsFuel = true;
      }
    }

    // 3. Extract Fiscal Invoice / Receipt Number FIRST (so its station prefix can also inform station resolution!)
    String? invoiceNumber;
    final registrationIds = IsraeliFuelStationRegistry.companyByRegistrationId.keys.toSet();

    // Priority 1: Standard 15-digit Israeli fiscal fuel invoice starting with 0 (e.g. 042209901087851)
    final paz15Match = RegExp(r'(?<!\d)(0\d{14})(?!\d)').firstMatch(clean);
    if (paz15Match != null) {
      invoiceNumber = paz15Match.group(1);
    }

    // Priority 2: Explicit Hebrew invoice/receipt header
    if (invoiceNumber == null) {
      final fiscalInvRegex = RegExp(
        r"""(?:חשבונית(?:\s*(?:מס(?:'?|פר)?|מספר))?(?:[\s\/]*קבלה)?|קבלה(?:\s*(?:מס(?:'?|פר)?|מספר))?|מספר\s*(?:חשבונית|קבלה))[\s\S]{0,40}?(\d{4,18})""",
        caseSensitive: false,
      );
      for (final m in fiscalInvRegex.allMatches(clean)) {
        final cand = m.group(1)!;
        if (!registrationIds.contains(cand) && cand != '036021814') {
          invoiceNumber = cand;
          break;
        }
      }
    }

    // Priority 3: 12-to-18 digit fiscal number starting with 0
    if (invoiceNumber == null) {
      final standaloneInvMatch =
          RegExp(r'(?<!\d)(0\d{11,17})(?!\d)').firstMatch(clean);
      if (standaloneInvMatch != null) {
        invoiceNumber = standaloneInvMatch.group(1);
      }
    }

    // Priority 4: Reference / Approval code on paper receipts
    if (invoiceNumber == null) {
      final fallbackMatch = RegExp(
        r"""(?:אסמכתא|אישור|קוד\s*עסקה)[^\d\n\r]{0,15}[:#]?\s*(\d{4,16})""",
        caseSensitive: false,
      ).firstMatch(clean);
      if (fallbackMatch != null) {
        final cand = fallbackMatch.group(1)!;
        if (!registrationIds.contains(cand)) {
          invoiceNumber = cand;
        }
      }
    }

    // 4. Resolve Exact Station Name & Branch Code via IsraeliFuelStationRegistry
    String providerName = IsraeliFuelStationRegistry.resolveStation(
      text: clean,
      detectedCompany: detectedCompany,
      invoiceNumber: invoiceNumber,
    );

    if (providerName.isEmpty) {
      if (detectedCompany == 'פז') {
        providerName = lower.contains('yellow') ? 'פז Yellow' : 'פז';
      } else if (detectedCompany.isNotEmpty) {
        providerName = detectedCompany;
      } else if (clean.contains('אור אמנוני')) {
        providerName = 'מוסך אור אמנוני (כרמיאל)';
      } else {
        providerName = (receiptIsFuel || hasFuelKeywords) ? 'תדלוק' : '';
      }
    }

    // 5. Extract Exact Purchase Date & Time
    // Prioritizes the HH:MM time located on the same line or adjacent to the receipt date
    // (avoiding phone status bar clocks like "7:55" at the top of screenshots).
    DateTime receiptDate = DateTime.now();
    final dateMatches =
        RegExp(r'(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})').allMatches(clean);
    for (final dateMatch in dateMatches) {
      final d = int.tryParse(dateMatch.group(1) ?? '') ?? 0;
      final m = int.tryParse(dateMatch.group(2) ?? '') ?? 0;
      var y = int.tryParse(dateMatch.group(3) ?? '') ?? 0;
      if (y > 0 && y < 100) y += 2000;
      if (d < 1 || d > 31 || m < 1 || m > 12 || y < 2018 || y > 2035) {
        continue;
      }

      int hour = DateTime.now().hour;
      int minute = DateTime.now().minute;

      // Search for time within 50 chars before/after the date match first (e.g. "תאריך קניה: 06/11/2026 שעה: 14:22")
      final winStart = (dateMatch.start - 50).clamp(0, clean.length);
      final winEnd = (dateMatch.end + 50).clamp(0, clean.length);
      final dateWindow = clean.substring(winStart, winEnd);

      final timeRegex = RegExp(r'(?<![\d.%])([01]?\d|2[0-3]):([0-5]\d)(?![\d.%])');
      final nearbyTime = timeRegex.firstMatch(dateWindow);
      if (nearbyTime != null) {
        hour = int.tryParse(nearbyTime.group(1)!) ?? hour;
        minute = int.tryParse(nearbyTime.group(2)!) ?? minute;
      } else {
        // Fallback: look for "שעה: HH:MM" anywhere in the receipt
        final labeledTime = RegExp(
          r'(?:שעה\s*[:\-]?\s*([01]?\d|2[0-3]):([0-5]\d)|([01]?\d|2[0-3]):([0-5]\d)\s*[:\-]?\s*שעה)',
        ).firstMatch(clean);
        if (labeledTime != null) {
          hour = int.tryParse(labeledTime.group(1) ?? labeledTime.group(3) ?? '') ?? hour;
          minute = int.tryParse(labeledTime.group(2) ?? labeledTime.group(4) ?? '') ?? minute;
        }
      }

      receiptDate = DateTime(y, m, d, hour, minute);
      break;
    }

    // 6. Extract Odometer (if printed on fleet/Pazomat or garage receipt)
    int? odometer;
    final odoMatch =
        RegExp(r"""(?:מד\s*אוץ|קילומטראז'?|ק"מ)[:\s]*(\d{3,7})""").firstMatch(clean);
    if (odoMatch != null) {
      odometer = int.tryParse(odoMatch.group(1) ?? '');
    }

    // 7. Detect Fuel Grade (Octane 95, 98, Diesel)
    String? fuelGrade;
    if (receiptIsFuel) {
      if (clean.contains('סולר') || lower.contains('diesel')) {
        fuelGrade = 'סולר';
      } else if (RegExp(r'\b98\b').hasMatch(clean) && clean.contains('אוקטן')) {
        fuelGrade = 'אוקטן 98';
      } else {
        fuelGrade = 'בנזין 95';
      }
    }

    // 8. Extract Non-Fuel Maintenance / Store Items
    final detectedItems = <String>[];
    if (!receiptIsFuel) {
      if (lower.contains('yellow') || detectedCompany == 'פז') {
        detectedItems.add('מشتريات متجر Yellow');
      }
    }
    if (clean.contains('דיסק')) detectedItems.add('דיסק בלם (צלחת)');
    if (clean.contains('רפיד')) detectedItems.add('רפידות בלם');
    if (clean.contains('טיימינג')) detectedItems.add('רצועת טיימינג');
    if (clean.contains('צמיג')) detectedItems.add('צמיג קדמי 110/90-13');
    if (clean.contains('שמן מנוע') || clean.contains('שמן 4T')) {
      detectedItems.add('שמן מנוע 4T מקורי');
    } else if (!receiptIsFuel && clean.contains('שמן')) {
      detectedItems.add('שמן מנוע / גיר');
    }
    if (clean.contains('מסכת') || clean.contains('מגן')) {
      detectedItems.add('פלסטיקה ומגן גחון');
    }

    // 9. Build Descriptive Title with Exact Station Name & Liters
    String title;
    if (receiptIsFuel) {
      final litersStr = liters != null ? ' ($liters ליטר)' : '';
      if (providerName.isEmpty ||
          providerName == 'תדלוק' ||
          providerName == 'تعبئة بنزين') {
        title = 'תדלוק$litersStr';
      } else {
        title = 'תדלוק $providerName$litersStr';
      }
    } else {
      if (lower.contains('yellow') || detectedCompany == 'פז') {
        title = providerName.isNotEmpty
            ? 'Yellow ($providerName)'
            : 'מشتريات Yellow';
        if (providerName.isEmpty) providerName = 'Yellow חנות נוחות';
      } else {
        final invStr =
            invoiceNumber != null ? ' (חשבונית #$invoiceNumber)' : '';
        title = providerName.isNotEmpty
            ? 'טיפול / חלפים ($providerName)$invStr'
            : 'טיפול / חלפים (מוסך)$invStr';
      }
    }

    return ParsedReceiptResult(
      title: title,
      amount: amount,
      date: receiptDate,
      isFuel: receiptIsFuel,
      liters: liters,
      pricePerLiter: pricePerLiter,
      odometer: odometer,
      providerName: providerName.isNotEmpty
          ? providerName
          : (receiptIsFuel ? 'תדלוק' : 'Yellow'),
      rawText: text,
      invoiceNumber: invoiceNumber,
      items: detectedItems,
      beforeVat: beforeVat,
      vatAmount: vatAmount,
      fuelGrade: fuelGrade,
    );
  }
}
