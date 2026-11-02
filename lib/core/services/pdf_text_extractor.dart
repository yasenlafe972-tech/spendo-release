import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// High-performance on-device PDF text extractor.
/// Uses native Apple PDFKit on iOS for 100% font/CMap fidelity,
/// with a fast in-memory Dart stream decoder for Android and cross-platform fallbacks.
class PdfTextExtractor {
  PdfTextExtractor._();

  static const MethodChannel _shareChannel = MethodChannel('com.finance.spendo/share');

  /// Extracts all visible plain text from a digital PDF file on device without internet.
  static Future<String> extractText(File pdfFile) async {
    if (!pdfFile.existsSync()) return '';

    // 1. Try Native Apple PDFKit on iOS (100% accurate CMap and Hebrew Unicode decoding)
    if (Platform.isIOS) {
      try {
        final nativeText = await _shareChannel.invokeMethod<String>(
          'extractPdfText',
          pdfFile.path,
        );
        if (nativeText != null && nativeText.trim().isNotEmpty) {
          return nativeText.trim();
        }
      } catch (_) {}
    }

    // 2. Pure Dart in-memory stream parser (Decompresses Flate streams and extracts PDF text objects)
    try {
      final bytes = await pdfFile.readAsBytes();
      final dartText = extractTextFromBytes(bytes);
      if (dartText.trim().isNotEmpty) {
        return dartText.trim();
      }
    } catch (_) {}

    return '';
  }

  /// Parses raw PDF bytes and extracts text tokens from compressed and uncompressed streams
  static String extractTextFromBytes(Uint8List bytes) {
    final buffer = StringBuffer();

    // 1. Find all streams: "stream\r?\n ... endstream"
    final latin1Str = latin1.decode(bytes, allowInvalid: true);
    final streamRegex = RegExp(r'stream[\r\n]+([\s\S]*?)endstream', multiLine: true);

    for (final match in streamRegex.allMatches(latin1Str)) {
      final rawStream = match.group(1);
      if (rawStream == null || rawStream.isEmpty) continue;

      // Try raw stream text first
      final directText = _extractTjText(rawStream);
      if (directText.isNotEmpty) {
        buffer.writeln(directText);
      }

      // Try decompressing with zlib/inflate (FlateDecode)
      try {
        final streamBytes = Uint8List.fromList(latin1.encode(rawStream));
        final decompressed = zlib.decode(streamBytes);
        final decompressedStr = latin1.decode(decompressed, allowInvalid: true);
        final uncompressedText = _extractTjText(decompressedStr);
        if (uncompressedText.isNotEmpty) {
          buffer.writeln(uncompressedText);
        }
      } catch (_) {}
    }

    // 2. Also search top-level uncompressed text outside streams
    final direct = _extractTjText(latin1Str);
    if (direct.isNotEmpty) {
      buffer.writeln(direct);
    }

    return buffer.toString();
  }

  /// Extracts text from PDF text-showing operators: (text) Tj, [(t)(e)(x)(t)] TJ, etc.
  static String _extractTjText(String streamContent) {
    final result = StringBuffer();

    // Match TJ arrays: [ (text1) 120 (text2) ] TJ
    final tjArrayRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    for (final m in tjArrayRegex.allMatches(streamContent)) {
      final inner = m.group(1) ?? '';
      final strRegex = RegExp(r'\((.*?)\)');
      for (final sm in strRegex.allMatches(inner)) {
        final t = _unescapePdfString(sm.group(1) ?? '');
        if (t.isNotEmpty) result.write('$t ');
      }
      result.writeln();
    }

    // Match single (text) Tj or ' or "
    final singleTjRegex = RegExp(r"""\((.*?)\)\s*(?:Tj|['"])""");
    for (final m in singleTjRegex.allMatches(streamContent)) {
      final t = _unescapePdfString(m.group(1) ?? '');
      if (t.isNotEmpty) result.writeln(t);
    }

    return result.toString();
  }

  static String _unescapePdfString(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
  }
}
