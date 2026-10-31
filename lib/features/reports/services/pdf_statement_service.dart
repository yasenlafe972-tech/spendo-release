import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:arabic_reshaper/arabic_reshaper.dart';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/models/workplace_payment_model.dart';
import 'package:sanad_app/features/work_logs/models/work_log_model.dart';
import 'package:sanad_app/features/finance/models/payment_model.dart';

class PdfStatementService {
  static final PdfStatementService instance = PdfStatementService._internal();
  PdfStatementService._internal();

  /// Reshaper configured with supportLigatures: false to prevent the known RangeError
  /// crash in package:bidi when decomposing compound ligatures (such as Lam-Alef "لا"),
  /// while properly connecting Arabic letters and keeping natural RTL rendering.
  final ArabicReshaper _reshaper = ArabicReshaper(
    configuration: const ArabicReshaperConfig(
      supportLigatures: false,
    ),
  );

  /// Formats Arabic RTL text with proper glyph shaping (connecting letters).
  /// The pdf package (v3.13.1) with textDirection: rtl handles Bidi character ordering automatically.
  String _ar(String text) {
    if (text.isEmpty) return '';
    try {
      return _reshaper.reshape(text);
    } catch (_) {
      return text;
    }
  }

  // =========================================================================
  // 1. WORKPLACE / EMPLOYER STATEMENT PDF (كشف حساب المشغّل / المقاول)
  // =========================================================================

  Future<Uint8List> generateWorkplaceStatementPdf({
    required WorkplaceModel workplace,
    required List<WorkLogModel> workLogs,
    required List<WorkplacePaymentModel> payments,
    String? periodTitle,
    PersonModel? contractor,
    bool includeFinancials = false,
  }) async {
    final pdf = pw.Document();

    pw.Font ttf;
    try {
      ttf = await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    final boldFont = await PdfGoogleFonts.cairoBold().catchError((_) => ttf);
    final hebrewRegular = await PdfGoogleFonts.notoSansHebrewRegular().catchError((_) => ttf);
    final hebrewBold = await PdfGoogleFonts.notoSansHebrewBold().catchError((_) => boldFont);

    // Compute metrics
    final totalDays = workLogs.length;
    final totalEarned = workLogs.fold(0.0, (sum, l) => sum + l.totalEarned);
    final totalPaymentsOnAccount = payments.fold(0.0, (sum, p) => sum + p.amount);
    final totalShiftCollected = workLogs.fold(0.0, (sum, l) => sum + l.amountCollected);
    final totalPaid = totalPaymentsOnAccount > 0 ? totalPaymentsOnAccount : totalShiftCollected;
    final balance = totalEarned - totalPaid;

    final generatedDate = DateTime.now().toIso8601String().split('T').first;
    final periodDisplay = periodTitle ?? 'كافة الأشهر والورديات المسجلة';

    final reportTitle = includeFinancials
        ? 'Spendo • كشف حساب مشغّل معتمد'
        : 'Spendo • كشف أيام العمل';
    final reportSubtitle = includeFinancials
        ? 'تقرير ساعات وأيام العمل والدفعات والمستحقات المالية'
        : 'توثيق رسمي لأيام وتواريخ ومواقع العمل المنجزة';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldFont,
          fontFallback: [
            hebrewRegular,
            hebrewBold,
          ],
        ),
        build: (context) => [
          // 1. Spendo Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF10B981), width: 2.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _ar(reportTitle),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 19,
                        color: const PdfColor.fromInt(0xFF10B981),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _ar(reportSubtitle),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _ar('تاريخ الإصدار: $generatedDate'),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF4F4F5),
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE4E4E7)),
                      ),
                      child: pw.Text(
                        _ar('معتمد رسمياً'),
                        style: pw.TextStyle(font: boldFont, fontSize: 8, color: const PdfColor.fromInt(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. Workplace & Employer Information Card
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF9FAFB),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          _ar('المشغّل / صاحب العمل: '),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          _ar(workplace.name),
                          style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.black),
                        ),
                      ],
                    ),
                    if (contractor != null) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _ar('المقاول المسؤول: ${contractor.name}'),
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                      ),
                    ],
                    if (workplace.city.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _ar('المدينة / المنطقة: ${workplace.city}'),
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                      ),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _ar('الفترة المعتمدة: $periodDisplay'),
                      style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey800),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _ar('إجمالي أيام العمل: $totalDays يوم'),
                      style: pw.TextStyle(font: boldFont, fontSize: 10, color: const PdfColor.fromInt(0xFF10B981)),
                    ),
                    if (includeFinancials && workplace.dailyRate > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        _ar('سعر اليومية: ${workplace.dailyRate.toStringAsFixed(0)} ₪'),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 3. KPI Summary Cards (يظهر فقط في الكشف المالي التفصيلي)
          if (includeFinancials) ...[
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryBox(
                    title: _ar('إجمالي المستحق للعمل'),
                    value: '${totalEarned.toStringAsFixed(0)} ₪',
                    color: const PdfColor.fromInt(0xFF10B981),
                    font: boldFont,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryBox(
                    title: _ar('إجمالي المدفوع والمقبوض'),
                    value: '${totalPaid.toStringAsFixed(0)} ₪',
                    color: const PdfColor.fromInt(0xFF3B82F6),
                    font: boldFont,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSummaryBox(
                    title: _ar('صافي الرصيد المتبقي'),
                    value: balance <= 0 ? _ar('خالص (0 ₪)') : '${balance.toStringAsFixed(0)} ₪',
                    color: balance > 0
                        ? const PdfColor.fromInt(0xFFEF4444)
                        : const PdfColor.fromInt(0xFF10B981),
                    font: boldFont,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // 4. Work Shifts Table
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  includeFinancials
                      ? _ar('جدول تفاصيل أيام وساعات ومواقع العمل:')
                      : _ar('جدول تفاصيل أيام ومواقع العمل:'),
                  style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.black),
                ),
                pw.Text(
                  _ar('العدد: $totalDays يوم'),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          if (workLogs.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Center(
                child: pw.Text(
                  _ar('لا توجد أيام عمل مسجلة في هذه الفترة'),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            )
          else if (includeFinancials)
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE4E4E7), width: 0.8),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF18181B)),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.center,
              headers: [
                _ar('المستحق'),
                _ar('اليومية'),
                _ar('الموقع / الملاحظات'),
                _ar('الدوام'),
                _ar('اليوم'),
                _ar('التاريخ'),
                _ar('#'),
              ],
              data: List.generate(workLogs.length, (index) {
                final l = workLogs[index];
                final dayName = ArabicDateHelper.getWeekdayFromDateString(l.date);
                final shiftDesc = l.rateType == 'daily'
                    ? (l.dayFraction == 1.0 ? 'يوم كامل' : '${l.dayFraction} يوم')
                    : '${l.hoursWorked ?? 0} س';
                final loc = l.notes != null && l.notes!.isNotEmpty
                    ? (l.city.isNotEmpty ? '${l.city} - ${l.notes}' : l.notes!)
                    : (l.city.isNotEmpty ? l.city : '-');

                return [
                  '${l.totalEarned.toStringAsFixed(0)} ₪',
                  '${l.rateApplied.toStringAsFixed(0)} ₪',
                  _ar(loc),
                  _ar(shiftDesc),
                  _ar(dayName),
                  l.date,
                  '${index + 1}',
                ];
              }),
            )
          else
            // Pure Attendance Table (يتضمن فقط: الرقم، التاريخ، اليوم، مكان العمل والورشة / الملاحظات)
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE4E4E7), width: 0.8),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF18181B)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FlexColumnWidth(4.5),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(0.6),
              },
              headers: [
                _ar('مكان العمل / الملاحظات'),
                _ar('اليوم'),
                _ar('التاريخ'),
                _ar('#'),
              ],
              data: List.generate(workLogs.length, (index) {
                final l = workLogs[index];
                final dayName = ArabicDateHelper.getWeekdayFromDateString(l.date);
                final loc = l.notes != null && l.notes!.isNotEmpty
                    ? (l.city.isNotEmpty ? '${l.city} - ${l.notes}' : l.notes!)
                    : (l.city.isNotEmpty ? l.city : '-');

                return [
                  _ar(loc),
                  _ar(dayName),
                  l.date,
                  '${index + 1}',
                ];
              }),
            ),
          pw.SizedBox(height: 18),

          // 5. Payments on Account Table (سجل الدفعات المستلمة على الحساب - يظهر فقط في الكشف المالي)
          if (includeFinancials) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    _ar('جدول الدفعات والمقبوضات المستلمة على الحساب:'),
                    style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.black),
                  ),
                  pw.Text(
                    _ar('إجمالي المقبوض: ${totalPaid.toStringAsFixed(0)} ₪'),
                    style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: const PdfColor.fromInt(0xFF10B981)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            if (payments.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: const PdfColor.fromInt(0xFFFAFAFA),
                ),
                child: pw.Center(
                  child: pw.Text(
                    totalShiftCollected > 0
                        ? _ar('تم قبض مقبوضات يومية بقيمة ${totalShiftCollected.toStringAsFixed(0)} ₪ مسجلة بالورديات')
                        : _ar('لا توجد دفعات على الحساب مسجلة لهذه الفترة'),
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE4E4E7), width: 0.8),
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF27272A)),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.center,
                headers: [
                  _ar('ملاحظات وبيان الدفعة'),
                  _ar('طريقة القبض'),
                  _ar('المبلغ المقبوض'),
                  _ar('التاريخ'),
                  _ar('#'),
                ],
                data: List.generate(payments.length, (index) {
                  final p = payments[index];
                  return [
                    _ar(p.notes ?? '-'),
                    _ar(p.paymentMethod),
                    '${p.amount.toStringAsFixed(0)} ₪',
                    p.date,
                    '${index + 1}',
                  ];
                }),
              ),
            pw.SizedBox(height: 24),
          ],

          // 6. Verification and Signature Box (يظهر فقط في الكشف المالي التفصيلي)
          if (includeFinancials) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF9FAFB),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _ar('إقرار وتأكيد الحساب:'),
                        style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _ar('الرصيد النهائي المستحق بذمة المشغّل: ${balance <= 0 ? 'خالص بالكامل' : '${balance.toStringAsFixed(0)} ₪'}'),
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 9,
                          color: balance > 0
                              ? const PdfColor.fromInt(0xFFEF4444)
                              : const PdfColor.fromInt(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(_ar('توقيع المشغّل / المستلم:'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 20),
                      pw.Container(
                        width: 110,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
          ],

          // 7. Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Center(
              child: pw.Text(
                includeFinancials
                    ? _ar('تم استخراج هذا الكشف وتدقيقه آلياً عبر نظام Spendo لإدارة المشاريع والأعمال • وثيقة رسمية')
                    : _ar('تم استخراج كشف أيام العمل وتوثيقه آلياً عبر نظام Spendo لإدارة المشاريع والأعمال • وثيقة رسمية'),
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Print or show direct print preview for Workplace Statement
  Future<void> printWorkplaceStatement({
    required WorkplaceModel workplace,
    required List<WorkLogModel> workLogs,
    required List<WorkplacePaymentModel> payments,
    String? periodTitle,
    PersonModel? contractor,
    bool includeFinancials = false,
  }) async {
    final pdfBytes = await generateWorkplaceStatementPdf(
      workplace: workplace,
      workLogs: workLogs,
      payments: payments,
      periodTitle: periodTitle,
      contractor: contractor,
      includeFinancials: includeFinancials,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Spendo_WorkDays_${workplace.name}.pdf',
    );
  }

  /// Share Workplace Statement PDF directly (WhatsApp, Email, Drive, etc.)
  Future<void> shareWorkplaceStatement({
    required WorkplaceModel workplace,
    required List<WorkLogModel> workLogs,
    required List<WorkplacePaymentModel> payments,
    String? periodTitle,
    PersonModel? contractor,
    bool includeFinancials = false,
  }) async {
    final pdfBytes = await generateWorkplaceStatementPdf(
      workplace: workplace,
      workLogs: workLogs,
      payments: payments,
      periodTitle: periodTitle,
      contractor: contractor,
      includeFinancials: includeFinancials,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Spendo_WorkDays_${workplace.name}.pdf',
    );
  }

  // =========================================================================
  // 2. PERSON / CONTRACTOR STATEMENT PDF (Legacy & Person-specific)
  // =========================================================================

  Future<Uint8List> generateStatementPdf({
    required PersonModel person,
    required List<WorkLogModel> workLogs,
    required List<PaymentModel> payments,
  }) async {
    final pdf = pw.Document();

    pw.Font ttf;
    try {
      ttf = await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      ttf = pw.Font.helvetica();
    }

    final boldFont = await PdfGoogleFonts.cairoBold().catchError((_) => ttf);
    final hebrewRegular = await PdfGoogleFonts.notoSansHebrewRegular().catchError((_) => ttf);
    final hebrewBold = await PdfGoogleFonts.notoSansHebrewBold().catchError((_) => boldFont);

    final totalEarned = workLogs.fold(0.0, (sum, l) => sum + l.totalEarned);
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    final balance = totalEarned - totalPaid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: boldFont,
          fontFallback: [
            hebrewRegular,
            hebrewBold,
          ],
        ),
        build: (context) => [
          // 1. Spendo Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF10B981), width: 2.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _ar('Spendo • كشف حساب مالي'),
                      style: pw.TextStyle(font: boldFont, fontSize: 20, color: const PdfColor.fromInt(0xFF10B981)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _ar('تقرير ساعات العمل والدفعات والمستحقات الرسمية'),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(_ar('تاريخ التقرير: ${DateTime.now().toIso8601String().split('T').first}'),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text(_ar('نظام إدارة المشاريع Spendo'),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // 2. Personal Information Card
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF4F4F5),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFE4E4E7)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_ar('الاسم: ${person.name}'),
                        style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.black)),
                    if (person.nationalId != null)
                      pw.Text(_ar('رقم الهوية: ${person.nationalId}'),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (person.phone != null)
                      pw.Text(_ar('الهاتف: ${person.phone}'),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    if (person.email != null)
                      pw.Text(_ar('الإيميل: ${person.email}'),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // 3. Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryBox(
                  title: _ar('إجمالي المستحق'),
                  value: '${totalEarned.toStringAsFixed(1)} ₪',
                  color: const PdfColor.fromInt(0xFF10B981),
                  font: boldFont,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryBox(
                  title: _ar('إجمالي المدفوع'),
                  value: '${totalPaid.toStringAsFixed(1)} ₪',
                  color: const PdfColor.fromInt(0xFF3B82F6),
                  font: boldFont,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryBox(
                  title: _ar('الرصيد المتبقي'),
                  value: '${balance.toStringAsFixed(1)} ₪',
                  color: balance > 0
                      ? const PdfColor.fromInt(0xFFEF4444)
                      : const PdfColor.fromInt(0xFF10B981),
                  font: boldFont,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // 4. Work Logs Table
          pw.Text(_ar('سجل أيام العمل والورشات:'), style: pw.TextStyle(font: boldFont, fontSize: 12)),
          pw.SizedBox(height: 6),
          if (workLogs.isEmpty)
            pw.Text(_ar('لا توجد أيام عمل مسجلة في هذه الفترة'),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE4E4E7)),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF18181B)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
              headers: [_ar('المتبقي'), _ar('المقبوض'), _ar('المستحق'), _ar('الأجر المطبق'), _ar('النوع'), _ar('مكان العمل والبلد'), _ar('التاريخ')],
              data: workLogs.map((l) {
                final typeText = l.rateType == 'daily'
                    ? (l.dayFraction == 1.0 ? 'يوم كامل' : l.dayFraction == 0.5 ? 'نصف يوم' : 'إضافي')
                    : '${l.hoursWorked} ساعة';
                final placeAndCity = l.city.isNotEmpty
                    ? '${l.workplaceName} (${l.city})'
                    : l.workplaceName;
                return [
                  '${l.remainingToCollect.toStringAsFixed(0)} ₪',
                  '${l.amountCollected.toStringAsFixed(0)} ₪',
                  '${l.totalEarned.toStringAsFixed(0)} ₪',
                  '${l.rateApplied.toStringAsFixed(0)} ₪',
                  _ar(typeText),
                  _ar(placeAndCity),
                  l.date,
                ];
              }).toList(),
            ),
          pw.SizedBox(height: 20),

          // 5. Payments Table
          pw.Text(_ar('سجل الدفعات والمقبوضات:'), style: pw.TextStyle(font: boldFont, fontSize: 12)),
          pw.SizedBox(height: 6),
          if (payments.isEmpty)
            pw.Text(_ar('لا توجد دفعات مسجلة'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE4E4E7)),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF27272A)),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
              headers: [_ar('ملاحظات'), _ar('نوع الدفعة'), _ar('المبلغ'), _ar('التاريخ')],
              data: payments.map((p) {
                return [
                  _ar(p.notes ?? '-'),
                  _ar(p.type),
                  '${p.amount.toStringAsFixed(0)} ₪',
                  p.date,
                ];
              }).toList(),
            ),
          pw.SizedBox(height: 30),

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Center(
              child: pw.Text(
                _ar('تم استخراج هذا التقرير آلياً عبر تطبيق Spendo لإدارة الأعمال والمشاريع'),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryBox({
    required String title,
    required String value,
    required PdfColor color,
    required pw.Font font,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
        color: const PdfColor.fromInt(0xFFFAFAFA),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  /// Print or show direct print preview
  Future<void> printStatement({
    required PersonModel person,
    required List<WorkLogModel> workLogs,
    required List<PaymentModel> payments,
  }) async {
    final pdfBytes = await generateStatementPdf(
      person: person,
      workLogs: workLogs,
      payments: payments,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Spendo_Statement_${person.name}.pdf',
    );
  }

  /// Share PDF directly (WhatsApp, Telegram, Email, Drive)
  Future<void> shareStatement({
    required PersonModel person,
    required List<WorkLogModel> workLogs,
    required List<PaymentModel> payments,
  }) async {
    final pdfBytes = await generateStatementPdf(
      person: person,
      workLogs: workLogs,
      payments: payments,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Spendo_Statement_${person.name}.pdf',
    );
  }
}
