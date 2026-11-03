import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/israel_gov_api_service.dart';
import '../../../../core/services/receipt_ocr_service.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../home/services/daily_expense_service.dart';
import '../../models/vehicle_model.dart';
import 'fuel_expense_sheet.dart';

/// Bottom sheet dialog for reviewing and importing multiple invoices extracted from a single PDF/export.
class MultiFuelImportSheet extends StatefulWidget {
  final List<ParsedReceiptResult> receipts;
  final String? sourceFileName;
  final VoidCallback? onSaved;

  const MultiFuelImportSheet({
    super.key,
    required this.receipts,
    this.sourceFileName,
    this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<ParsedReceiptResult> receipts,
    String? sourceFileName,
    VoidCallback? onSaved,
  }) {
    const surfaceMain = Color(0xFF121413);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      barrierColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MultiFuelImportSheet(
        receipts: receipts,
        sourceFileName: sourceFileName,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<MultiFuelImportSheet> createState() => _MultiFuelImportSheetState();
}

class _MultiFuelImportSheetState extends State<MultiFuelImportSheet> {
  late Set<int> _selectedIndices;
  late Set<int> _duplicateIndices;
  bool _isLoading = true;
  bool _isSaving = false;
  VehicleDataState _state = VehicleDataState.initial();
  double _officialFuelPrice = 7.25;

  static const surfaceMain = Color(0xFF121413);
  static const surfaceField = Color(0xFF171A19);
  static const surfaceBorder = Color(0xFF242927);
  static const brandGreen = Color(0xFF00A86B);
  static const brandYellow = Color(0xFFEAB308);
  static const textMuted = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _selectedIndices = <int>{};
    _duplicateIndices = <int>{};
    _loadStateAndCheckDuplicates();
  }

  Future<void> _loadStateAndCheckDuplicates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(FuelExpenseSheet.storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _state = VehicleDataState.fromJson(raw);
      } catch (_) {}
    }

    _officialFuelPrice = await IsraelGovApiService.getCachedFuel95Price();

    final duplicates = <int>{};
    final selected = <int>{};

    for (int i = 0; i < widget.receipts.length; i++) {
      final r = widget.receipts[i];
      final dup = _state.findDuplicate(
        date: r.date,
        amount: r.amount,
        category: r.isFuel ? ExpenseCategory.fuel : ExpenseCategory.maintenance,
      );
      if (dup != null) {
        duplicates.add(i);
      }
      // All receipts selected by default so the user clearly sees all invoices found
      selected.add(i);
    }

    if (mounted) {
      setState(() {
        _duplicateIndices = duplicates;
        _selectedIndices = selected;
        _isLoading = false;
      });
    }
  }

  void _toggleSelectAll() {
    SpendoHaptics.selection();
    setState(() {
      if (_selectedIndices.length == widget.receipts.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = List.generate(widget.receipts.length, (i) => i).toSet();
      }
    });
  }

  double get _totalSelectedAmount {
    double sum = 0.0;
    for (final idx in _selectedIndices) {
      if (idx < widget.receipts.length) {
        sum += widget.receipts[idx].amount;
      }
    }
    return sum;
  }

  double get _totalSelectedLiters {
    double sum = 0.0;
    for (final idx in _selectedIndices) {
      if (idx < widget.receipts.length) {
        sum += widget.receipts[idx].liters ?? 0.0;
      }
    }
    return sum;
  }

  Future<void> _commitImport() async {
    if (_selectedIndices.isEmpty || _isSaving) return;

    setState(() {
      _isSaving = true;
    });
    SpendoHaptics.medium();

    try {
      final prefs = await SharedPreferences.getInstance();
      final newRecords = <VehicleExpenseRecord>[];

      // Process selected receipts
      for (final idx in _selectedIndices) {
        if (idx >= widget.receipts.length) continue;
        final r = widget.receipts[idx];

        final stationTitle = r.providerName.isNotEmpty
            ? r.providerName
            : (r.isFuel ? 'תדלוק Yellow פז' : 'Yellow חנות נוחות');

        final computedLiters = r.isFuel
            ? (r.liters ??
                (_officialFuelPrice > 0
                    ? double.parse((r.amount / _officialFuelPrice).toStringAsFixed(2))
                    : null))
            : null;

        final rec = VehicleExpenseRecord(
          id: '${r.date.millisecondsSinceEpoch}_${r.amount.toStringAsFixed(2)}_$idx',
          title: stationTitle,
          amount: r.amount,
          odometer: r.odometer ?? _state.currentOdometer,
          date: r.date,
          category: r.isFuel ? ExpenseCategory.fuel : ExpenseCategory.maintenance,
          invoiceNumber: r.invoiceNumber,
          provider: r.providerName.isNotEmpty ? r.providerName : 'Yellow פז',
          liters: computedLiters,
          pricePerLiter: r.isFuel ? (r.pricePerLiter ?? _officialFuelPrice) : null,
          notes: r.isFuel ? 'استيراد وقود Yellow' : 'مشتريات متجر Yellow',
          items: r.items.isNotEmpty
              ? r.items
              : [
                  if (computedLiters != null) 'בנזין 95 אוקטן ($computedLiters ליטר)',
                  r.isFuel ? 'תשלום Yellow פז' : 'مشتريات Yellow',
                ],
        );
        newRecords.add(rec);

        // Sync store purchases directly to daily expenses (Shopping)
        if (!r.isFuel) {
          try {
            await DailyExpenseService.addExpense(
              merchantName: r.providerName.isNotEmpty ? r.providerName : 'Yellow חנות נוחות',
              amount: r.amount,
              explicitCategory: 'shopping',
              source: 'yellow_store',
              date: r.date,
              notes: 'مشتريات متجر Yellow (صفحة ${r.pageNumber ?? (idx + 1)})',
            );
          } catch (_) {}
        }
      }

      final updatedHistory = [...newRecords, ..._state.history];
      final updatedState = _state.copyWith(history: updatedHistory);
      await prefs.setString(FuelExpenseSheet.storageKey, updatedState.toJson());
      DailyExpenseService.expensesChangedNotifier.value++;

      SpendoHaptics.success();
      widget.onSaved?.call();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: surfaceField,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: brandGreen, width: 1),
            ),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'تم استيراد ${newRecords.length} فواتير بنجاح إلى سجل المركبة.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomNavPadding = media.padding.bottom > 0
        ? media.padding.bottom
        : media.viewPadding.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: surfaceMain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: brandYellow.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brandYellow.withAlpha(100), width: 1.2),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: brandYellow,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'استيراد فواتير متعددة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            () {
                              final totalPages = widget.receipts.firstOrNull?.totalPages ?? widget.receipts.length;
                              final fuelCnt = widget.receipts.where((r) => r.isFuel).length;
                              final storeCnt = widget.receipts.length - fuelCnt;
                              if (storeCnt > 0) {
                                return 'تم فحص $totalPages صفحات بالملف وعُثر على ${widget.receipts.length} فواتير ($fuelCnt وقود • $storeCnt مشتريات)';
                              }
                              return 'تم فحص $totalPages صفحات بالملف وعُثر على ${widget.receipts.length} فواتير وقود';
                            }(),
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(color: surfaceBorder, height: 1),

              // Summary bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                color: surfaceField,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedIndices.length} من ${widget.receipts.length} فاتورة محددة',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_totalSelectedLiters > 0) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(color: textMuted),
                                ),
                                Text(
                                  '${_totalSelectedLiters.toStringAsFixed(2)} لتر',
                                  style: const TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الإجمالي: ${_totalSelectedAmount.toStringAsFixed(2)} ₪',
                            style: const TextStyle(
                              color: brandGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _toggleSelectAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: surfaceBorder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _selectedIndices.length == widget.receipts.length
                              ? 'إلغاء التحديد'
                              : 'تحديد الكل',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: surfaceBorder, height: 1),

              // Invoices List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: brandGreen,
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: widget.receipts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final r = widget.receipts[idx];
                            final isSelected = _selectedIndices.contains(idx);
                            final isDuplicate = _duplicateIndices.contains(idx);

                            return InkWell(
                              onTap: () {
                                SpendoHaptics.selection();
                                setState(() {
                                  if (isSelected) {
                                    _selectedIndices.remove(idx);
                                  } else {
                                    _selectedIndices.add(idx);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? surfaceField
                                      : surfaceField.withAlpha(120),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? brandGreen.withAlpha(150)
                                        : surfaceBorder,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected ? brandGreen : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? brandGreen : textMuted,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: Colors.black,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),

                                    // Fuel vs Store Icon
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: (r.isFuel ? brandGreen : brandYellow).withAlpha(25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        r.isFuel
                                            ? Icons.local_gas_station_rounded
                                            : Icons.shopping_bag_outlined,
                                        size: 18,
                                        color: r.isFuel ? brandGreen : brandYellow,
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                  // Station & Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r.providerName.isNotEmpty
                                                    ? r.providerName
                                                    : 'تعبئة وقود פז',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (r.pageNumber != null)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withAlpha(15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.white24,
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  'صفحة ${r.pageNumber}',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            if (isDuplicate)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: brandYellow.withAlpha(30),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: brandYellow.withAlpha(100),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'مسجلة مسبقاً',
                                                  style: TextStyle(
                                                    color: brandYellow,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              ArabicDateHelper.formatArabicDateWithWeekday(r.date),
                                              style: const TextStyle(
                                                color: textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (r.liters != null && r.liters! > 0) ...[
                                              const Text(
                                                '•',
                                                style: TextStyle(color: textMuted, fontSize: 10),
                                              ),
                                              Text(
                                                '${r.liters!.toStringAsFixed(2)} لتر',
                                                style: const TextStyle(
                                                  color: textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (r.pricePerLiter != null) ...[
                                                const Text(
                                                  '•',
                                                  style: TextStyle(color: textMuted, fontSize: 10),
                                                ),
                                                Text(
                                                  '${r.pricePerLiter!.toStringAsFixed(2)} ₪/ل',
                                                  style: const TextStyle(
                                                    color: textMuted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Amount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${r.amount.toStringAsFixed(2)} ₪',
                                        style: TextStyle(
                                          color: isSelected ? brandGreen : textMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              ),

              // Bottom buttons
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
                decoration: const BoxDecoration(
                  color: surfaceMain,
                  border: Border(top: BorderSide(color: surfaceBorder, width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _selectedIndices.isNotEmpty && !_isSaving
                              ? _commitImport
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            disabledBackgroundColor: brandGreen.withAlpha(60),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  _selectedIndices.isEmpty
                                      ? 'يرجى تحديد فاتورة واحدة على الأقل'
                                      : 'استيراد ${_selectedIndices.length} فواتير (${_totalSelectedAmount.toStringAsFixed(2)} ₪)',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textMuted,
                          side: const BorderSide(color: surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
