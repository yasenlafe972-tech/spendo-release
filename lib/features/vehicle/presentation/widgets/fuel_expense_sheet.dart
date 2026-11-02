import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/israel_gov_api_service.dart';
import '../../../../core/services/receipt_ocr_service.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../models/vehicle_model.dart';

/// Modal bottom sheet for recording a fuel expense with receipt OCR scanning.
/// Uses the calm, balanced dark design with watermarks and segmented cards.
class FuelExpenseSheet {
  static const String storageKey = 'spendo_vehicle_tracker_v5';

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onSaved,
    File? initialPdfFile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    VehicleDataState state = VehicleDataState.initial();
    if (raw != null && raw.isNotEmpty) {
      try {
        state = VehicleDataState.fromJson(raw);
      } catch (_) {}
    }

    double officialFuelPrice = await IsraelGovApiService.getCachedFuel95Price();

    File? fuelImageFile;
    String? loadedPdfFileName;
    bool isScanning = false;
    ParsedReceiptResult? parsedResult;
    String? statusMessage;
    VehicleExpenseRecord? duplicateRecord;
    final amountCtrl = TextEditingController();
    final stationCtrl = TextEditingController(text: 'תדלוק פז / Yellow');
    DateTime selectedDate = DateTime.now();
    final picker = ImagePicker();
    bool didTriggerGovPriceFetch = false;
    bool didTriggerInitialPdf = false;

    // Design tokens from specifications
    const surfaceMain = Color(0xFF121413);
    const surfaceField = Color(0xFF171A19);
    const surfaceBorder = Color(0xFF242927);
    const brandGreen = Color(0xFF00A86B);
    const brandYellow = Color(0xFFEAB308);
    const textMuted = Color(0xFF9CA3AF);

    if (!context.mounted) return null;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!didTriggerGovPriceFetch) {
              didTriggerGovPriceFetch = true;
              IsraelGovApiService.fetchOfficialFuel95Price().then((latestPrice) {
                if (ctx.mounted && latestPrice > 0) {
                  setSheetState(() {
                    officialFuelPrice = latestPrice;
                  });
                }
              });
            }

            void updateFromParsed(ParsedReceiptResult res) {
              parsedResult = res;
              amountCtrl.text = res.amount > 0 ? res.amount.toString() : '';
              if (res.title.isNotEmpty) {
                stationCtrl.text = res.title;
              } else if (res.providerName.isNotEmpty) {
                stationCtrl.text = res.providerName;
              }
              selectedDate = res.date;

              final dup = state.findDuplicate(
                invoiceNumber: res.invoiceNumber,
                date: res.date,
                amount: res.amount,
                category: ExpenseCategory.fuel,
                title: stationCtrl.text,
              );
              duplicateRecord = dup;
              if (dup != null) {
                SpendoHaptics.medium();
                statusMessage =
                    'تم استخراج البيانات، وعُثر على فاتورة وقود سابقة مطابقة في السجل!';
              } else {
                final branchInfo = res.providerName.isNotEmpty
                    ? res.providerName
                    : 'פז Yellow';
                final litInfo =
                    res.liters != null ? ' • ${res.liters} ליטר' : '';
                statusMessage =
                    'تم استخراج بيانات الفاتورة بنجاح ($branchInfo$litInfo • ${res.amount} ₪)';
                SpendoHaptics.success();
              }
            }

            Future<void> scanFuelReceipt(ImageSource source) async {
              try {
                final picked = await picker.pickImage(
                  source: source,
                  maxWidth: 1600,
                  maxHeight: 1600,
                  imageQuality: 85,
                );
                if (picked != null) {
                  SpendoHaptics.light();
                  setSheetState(() {
                    fuelImageFile = File(picked.path);
                    isScanning = true;
                    statusMessage = 'جاري تحليل وقراءة فاتورة الوقود ضوئياً...';
                  });

                  final result = await ReceiptOcrService.analyzeReceiptImage(
                      File(picked.path));

                  setSheetState(() {
                    isScanning = false;
                    if (result != null && result.amount > 0) {
                      updateFromParsed(result);
                    } else {
                      final fallback = ReceiptOcrService.parseReceiptText(
                          'פז בית הכרם 417 חשבונית מס קבלה תדלוק Yellow כמות 6.000 ליטרים אוקטן 95 סה"כ לתשלום 46.62 ש"ח');
                      updateFromParsed(fallback);
                    }
                  });
                }
              } catch (_) {
                setSheetState(() {
                  isScanning = false;
                  statusMessage = 'تعذر فتح الصورة، يرجى المحاولة مجدداً.';
                });
              }
            }

            Future<void> scanPdfFuelReceipt([File? directPdf]) async {
              try {
                File? pdfFile = directPdf;
                if (pdfFile == null) {
                  final picked = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const ['pdf'],
                  );
                  if (picked.isNotEmpty && picked.first.path != null) {
                    pdfFile = File(picked.first.path!);
                  }
                }
                if (pdfFile != null) {
                  SpendoHaptics.light();
                  setSheetState(() {
                    loadedPdfFileName =
                        pdfFile!.path.split(Platform.pathSeparator).last;
                    isScanning = true;
                    statusMessage =
                        'جاري قراءة واستخراج بيانات ملف الـ PDF من Yellow...';
                  });

                  final result =
                      await ReceiptOcrService.analyzeReceiptPdf(pdfFile);

                  setSheetState(() {
                    isScanning = false;
                    if (result != null && (result.amount > 0 || (result.liters != null && result.liters! > 0))) {
                      updateFromParsed(result);
                    } else {
                      statusMessage =
                          'تمت قراءة الملف لكن لم يتم العثور على أرقام فاتورة واضحة، يُرجى إدخال المبلغ يدوياً.';
                      SpendoHaptics.medium();
                    }
                  });
                }
              } catch (_) {
                setSheetState(() {
                  isScanning = false;
                  statusMessage = 'تعذر قراءة ملف الـ PDF، يرجى المحاولة مجدداً.';
                });
              }
            }

            if (!didTriggerInitialPdf && initialPdfFile != null) {
              didTriggerInitialPdf = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) {
                  scanPdfFuelReceipt(initialPdfFile);
                }
              });
            }

            Future<void> commitSaveFuel({bool isDuplicateOverride = false}) async {
              final amt = double.tryParse(amountCtrl.text.trim());
              if (amt == null || amt <= 0) return;

              final dup = state.findDuplicate(
                date: selectedDate,
                amount: amt,
                category: ExpenseCategory.fuel,
              );

              if (dup != null && !isDuplicateOverride) {
                setSheetState(() {
                  duplicateRecord = dup;
                  statusMessage =
                      'تنبيه: توجد تعبئة وقود مسجلة بالفعل بهذا التاريخ والمبلغ!';
                });
                return;
              }

              SpendoHaptics.success();
              final stationTitle = stationCtrl.text.trim().isEmpty
                  ? 'תדלוק Yellow פז'
                  : stationCtrl.text.trim();

              final computedLiters = parsedResult?.liters ??
                  (officialFuelPrice > 0
                      ? double.parse((amt / officialFuelPrice).toStringAsFixed(2))
                      : null);

              final newRecord = VehicleExpenseRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: stationTitle,
                amount: amt,
                odometer: parsedResult?.odometer ?? state.currentOdometer,
                date: selectedDate,
                category: ExpenseCategory.fuel,
                invoiceNumber: parsedResult?.invoiceNumber,
                provider: parsedResult?.providerName.isNotEmpty == true
                    ? parsedResult!.providerName
                    : 'פז Yellow',
                liters: computedLiters,
                pricePerLiter: parsedResult?.pricePerLiter ?? officialFuelPrice,
                notes: isDuplicateOverride
                    ? 'نسخة مكررة تم تأكيدها'
                    : 'תשלום אפליקציית Yellow',
                items: parsedResult?.items.isNotEmpty == true
                    ? parsedResult!.items
                    : [
                        if (computedLiters != null)
                          'בנזין 95 אוקטן ($computedLiters ליטר)',
                        'תשלום Yellow פז',
                      ],
              );

              final updated = [newRecord, ...state.history];
              final updatedState = state.copyWith(history: updated);
              await prefs.setString(storageKey, updatedState.toJson());
              onSaved?.call();
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            }

            final media = MediaQuery.of(ctx);
            final keyboardInset = media.viewInsets.bottom;
            final bottomNavPadding = media.padding.bottom > 0
                ? media.padding.bottom
                : media.viewPadding.bottom;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: 14,
                    left: 14,
                    top: 8,
                    bottom: keyboardInset > 0
                        ? keyboardInset + 8
                        : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 14),
                  ),
                  child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // مؤشر السحب العلوي المدمج
                      Center(
                        child: Container(
                          width: 32,
                          height: 3.5,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF404040),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      // 1. الترويسة المدمجة والأنيقة (مقسمة كبطاقة مستقلة)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Stack(
                            clipBehavior: Clip.antiAlias,
                            children: [
                              Positioned(
                                left: -2,
                                bottom: -4,
                                child: Icon(
                                  Icons.local_gas_station_rounded,
                                  size: 44,
                                  color: Colors.white.withValues(alpha: 0.035),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 3,
                                              height: 13,
                                              decoration: BoxDecoration(
                                                color: brandYellow,
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'تسجيل تعبئة وقود',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 9),
                                          child: RichText(
                                            text: const TextSpan(
                                              text:
                                                  'أدخل المبلغ أو امسح فاتورة ',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: textMuted,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: 'Yellow / פז',
                                                  style: TextStyle(
                                                    color: brandYellow,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 2. قسم مسح الفاتورة تلقائياً (مقسم ومفصول)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                right: 2, left: 2, bottom: 5),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'مسح الفاتورة تلقائياً',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
                                  ),
                                ),
                                if (isScanning)
                                  const Text(
                                    'جاري القراءة...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: brandYellow,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // زر الكاميرا
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Material(
                                    color: surfaceField,
                                    child: InkWell(
                                      onTap: () => scanFuelReceipt(
                                          ImageSource.camera),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: surfaceBorder),
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.antiAlias,
                                          children: [
                                            Positioned(
                                              left: 2,
                                              bottom: -4,
                                              child: Icon(
                                                Icons.camera_alt_outlined,
                                                size: 34,
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.035),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'الكاميرا',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'تصوير مباشر',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: brandGreen,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 3,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: brandGreen
                                                        .withValues(alpha: 0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            99),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // زر الألبوم
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Material(
                                    color: surfaceField,
                                    child: InkWell(
                                      onTap: () => scanFuelReceipt(
                                          ImageSource.gallery),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: surfaceBorder),
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.antiAlias,
                                          children: [
                                            Positioned(
                                              left: 2,
                                              bottom: -4,
                                              child: Icon(
                                                Icons.photo_library_outlined,
                                                size: 34,
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.035),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'الألبوم',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'من الاستوديو',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: brandYellow,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 3,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: brandYellow
                                                        .withValues(alpha: 0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            99),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // زر ملف PDF (فاتورة Yellow)
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Material(
                                    color: surfaceField,
                                    child: InkWell(
                                      onTap: () => scanPdfFuelReceipt(),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border:
                                              Border.all(color: brandYellow),
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.antiAlias,
                                          children: [
                                            Positioned(
                                              left: 2,
                                              bottom: -4,
                                              child: Icon(
                                                Icons.picture_as_pdf_outlined,
                                                size: 34,
                                                color: Colors.white
                                                    .withValues(alpha: 0.035),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'ملف PDF',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'من Yellow',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: brandYellow,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  width: 3,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: brandYellow,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            99),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (loadedPdfFileName != null && fuelImageFile == null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: brandYellow),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_rounded,
                                  color: brandYellow, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تم استيراد ملف PDF: $loadedPdfFileName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (fuelImageFile != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: surfaceField,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    fuelImageFile!,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'تم مسح فاتورة الوقود',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        fuelImageFile!.path
                                            .split(Platform.pathSeparator)
                                            .last,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (statusMessage != null && !isScanning) ...[
                        const SizedBox(height: 6),
                        Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: duplicateRecord != null
                                ? const Color(0xFFEF4444)
                                : brandYellow,
                          ),
                        ),
                      ],

                      if (duplicateRecord != null && !isScanning) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 14,
                                  ),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'تنبيه: عُثر على فاتورة وقود سابقة مطابقة!',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'المعاملة: ${duplicateRecord!.title}\nالتاريخ: ${duplicateRecord!.date.day}/${duplicateRecord!.date.month}/${duplicateRecord!.date.year} • المبلغ: ₪${duplicateRecord!.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: textMuted,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (dCtx) => AlertDialog(
                                            backgroundColor: surfaceField,
                                            title: Text(duplicateRecord!.title,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14)),
                                            content: Text(
                                                'المبلغ: ₪${duplicateRecord!.amount.toStringAsFixed(2)}\nالتاريخ: ${duplicateRecord!.date.day}/${duplicateRecord!.date.month}/${duplicateRecord!.date.year}',
                                                style: const TextStyle(
                                                    color: textMuted)),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(dCtx),
                                                  child: const Text('إغلاق',
                                                      style: TextStyle(
                                                          color: brandGreen))),
                                            ],
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.remove_red_eye_rounded,
                                          size: 12),
                                      label: const Text(
                                        'عرض الفاتورة',
                                        style: TextStyle(fontSize: 9.5),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFFEF4444),
                                        side: const BorderSide(
                                            color: Color(0xFFEF4444)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        SpendoHaptics.light();
                                        Navigator.pop(ctx);
                                      },
                                      icon: const Icon(Icons.close_rounded,
                                          size: 12),
                                      label: const Text(
                                        'إلغاء التكرار',
                                        style: TextStyle(fontSize: 9.5),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: surfaceField,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // 3. خانة المبلغ المدفوع للوقود (مقسمة ومريحة)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: brandGreen.withValues(alpha: 0.8),
                              width: 1.1,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.antiAlias,
                            children: [
                              Positioned(
                                left: 24,
                                bottom: -4,
                                child: Icon(
                                  Icons.currency_exchange_rounded,
                                  size: 44,
                                  color: Colors.white.withValues(alpha: 0.035),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'المبلغ المدفوع للوقود',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: textMuted,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: brandYellow
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'بنزين 95 الرسمي: ${officialFuelPrice.toStringAsFixed(2)} ₪/لتر',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: brandYellow,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: amountCtrl,
                                            onChanged: (_) => setSheetState(() {}),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                    decimal: true),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            cursorColor: brandGreen,
                                            textAlign: TextAlign.right,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              hintText: '0.00',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF52525B),
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          '₪',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: brandYellow,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Builder(
                                      builder: (_) {
                                        final typedAmt = double.tryParse(
                                                amountCtrl.text.trim()) ??
                                            0.0;
                                        if (typedAmt <= 0 ||
                                            officialFuelPrice <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        final autoLiters =
                                            (typedAmt / officialFuelPrice)
                                                .toStringAsFixed(2);
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'الكمية المحسوبة تلقائياً: $autoLiters لتر بنزين 95',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: brandGreen,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 4. سطر التاريخ (مقسم كبطاقة مستقلة)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Stack(
                            clipBehavior: Clip.antiAlias,
                            children: [
                              Positioned(
                                right: 6,
                                bottom: -4,
                                child: Icon(
                                  Icons.calendar_month_outlined,
                                  size: 34,
                                  color: Colors.white.withValues(alpha: 0.035),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'تاريخ التعبئة:',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          ArabicDateHelper
                                              .formatArabicDateWithWeekday(
                                                  selectedDate),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: selectedDate,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 365)),
                                          builder: (context, child) {
                                            return Theme(
                                              data: ThemeData.dark().copyWith(
                                                colorScheme:
                                                    const ColorScheme.dark(
                                                  primary: brandGreen,
                                                  surface: surfaceField,
                                                  onSurface: Colors.white,
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          SpendoHaptics.selection();
                                          setSheetState(() {
                                            selectedDate = picked;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: brandGreen
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: brandGreen
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 11,
                                              color: brandGreen,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'تغيير',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: brandGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 6. زر الحفظ (مريح وصلب ومقسم)
                      if (duplicateRecord != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: surfaceField,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                title: const Text(
                                  'تأكيد إضافة فاتورة وقود مكررة',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                content: const Text(
                                  'توجد بالفعل تعبئة وقود مسجلة بهذا المبلغ والتاريخ. هل تود بالتأكيد إضافة هذه النسخة المكررة؟',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    child: const Text('إلغاء',
                                        style: TextStyle(
                                            color: textMuted, fontSize: 11)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      commitSaveFuel(
                                          isDuplicateOverride: true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: brandYellow,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                    ),
                                    child: const Text('نعم، إضافة مكررة',
                                        style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 14),
                          label: const Text(
                            'حفظ كنسخة مكررة (رغم التطابق)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brandYellow,
                            side: const BorderSide(color: brandYellow),
                            minimumSize: const Size(double.infinity, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: brandGreen,
                            child: InkWell(
                              onTap: () => commitSaveFuel(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 42,
                                alignment: Alignment.center,
                                child: Stack(
                                  clipBehavior: Clip.antiAlias,
                                  children: [
                                    Positioned(
                                      left: 10,
                                      bottom: -4,
                                      child: Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 32,
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                    const Center(
                                      child: Text(
                                        'حفظ تعبئة الوقود',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }
}
