import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/models/workplace_payment_model.dart';
import 'package:sanad_app/core/widgets/spendo_date_picker.dart';

class RecordWorkplacePaymentSheet extends StatefulWidget {
  final WorkplaceModel workplace;
  final WorkplacePaymentModel? existingPayment;
  final double? remainingDue;
  final Function(WorkplacePaymentModel payment) onSave;

  const RecordWorkplacePaymentSheet({
    super.key,
    required this.workplace,
    this.existingPayment,
    this.remainingDue,
    required this.onSave,
  });

  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain =>
      _isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF);
  static Color get surfaceField =>
      _isDark ? const Color(0xFF171A19) : const Color(0xFFF9FAFB);
  static Color get surfaceHover =>
      _isDark ? const Color(0xFF1D211F) : const Color(0xFFF1F3F5);
  static Color get surfaceBorder =>
      _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF0F766E);
  static Color get brandYellow => AppColors.warningFor(_isDark);
  static Color get textPrimary =>
      _isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  static Color get textMuted =>
      _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textWhite =>
      _isDark ? Colors.white : const Color(0xFF111827);

  static Future<void> show(
    BuildContext context, {
    required WorkplaceModel workplace,
    WorkplacePaymentModel? existingPayment,
    double? remainingDue,
    required Function(WorkplacePaymentModel payment) onSave,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder:
          (_) => RecordWorkplacePaymentSheet(
            workplace: workplace,
            existingPayment: existingPayment,
            remainingDue: remainingDue,
            onSave: onSave,
          ),
    );
  }

  @override
  State<RecordWorkplacePaymentSheet> createState() =>
      _RecordWorkplacePaymentSheetState();
}

class _RecordWorkplacePaymentSheetState
    extends State<RecordWorkplacePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'كاش';

  final List<Map<String, dynamic>> _methods = const [
    {'name': 'كاش', 'icon': Remix.cash_line},
    {'name': 'Bit', 'icon': Remix.smartphone_line},
    {'name': 'شيك', 'icon': Remix.coupon_2_line},
    {'name': 'حوالة', 'icon': Remix.bank_line},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingPayment != null) {
      final p = widget.existingPayment!;
      _amountController.text = p.amount.toStringAsFixed(0);
      _notesController.text = p.notes ?? '';
      _paymentMethod = p.paymentMethod;
      try {
        _selectedDate = DateTime.parse(p.date);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await SpendoDatePicker.pickDate(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'اختر تاريخ الدفعة',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addQuickAmount(double addition) {
    SpendoHaptics.selection();
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final updated = current + addition;
    setState(() {
      _amountController.text = updated.toStringAsFixed(0);
    });
  }

  void _setFullRemaining() {
    SpendoHaptics.selection();
    final rem = widget.remainingDue ?? 0.0;
    if (rem > 0) {
      setState(() {
        _amountController.text = rem.toStringAsFixed(0);
      });
    }
  }

  void _clearAmount() {
    SpendoHaptics.selection();
    setState(() {
      _amountController.clear();
    });
  }

  Future<void> _handleSave() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      SpendoHaptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RecordWorkplacePaymentSheet.surfaceField,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.redAccent),
          ),
          content: Row(
            children: [
              const Icon(
                Remix.error_warning_line,
                color: Colors.redAccent,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'الرجاء إدخال مبلغ الدفعة أولاً',
                style: TextStyle(
                  color: RecordWorkplacePaymentSheet.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    SpendoHaptics.success();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final payment = WorkplacePaymentModel(
      id: widget.existingPayment?.id ?? const Uuid().v4(),
      workplaceId: widget.workplace.id,
      amount: amount,
      date: dateStr,
      paymentMethod: _paymentMethod,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      createdAt: widget.existingPayment?.createdAt ?? DateTime.now(),
    );

    widget.onSave(payment);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormatted = ArabicDateHelper.formatArabicDateWithWeekday(
      _selectedDate,
    );
    final remainingFormatted =
        (widget.remainingDue != null && widget.remainingDue! > 0)
            ? '${widget.remainingDue!.toStringAsFixed(0)} ₪'
            : '0 ₪';

    return Container(
      decoration: BoxDecoration(
        color: RecordWorkplacePaymentSheet.surfaceMain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: RecordWorkplacePaymentSheet.surfaceBorder,
            width: 1.2,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: RecordWorkplacePaymentSheet.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Remix.hand_coin_line,
                          color: RecordWorkplacePaymentSheet.brandGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.existingPayment != null
                                  ? 'تعديل دفعة مستلمة'
                                  : 'قبض دفعة على الحساب',
                              style: TextStyle(
                                color: RecordWorkplacePaymentSheet.textWhite,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                const Text(
                                  'المشغّل: ',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 10.5,
                                  ),
                                ),
                                Text(
                                  widget.workplace.name,
                                  style: TextStyle(
                                    color:
                                        RecordWorkplacePaymentSheet.brandYellow,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Remix.close_line,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount Box with integrated quick actions bar
                Container(
                  decoration: BoxDecoration(
                    color: RecordWorkplacePaymentSheet.surfaceField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RecordWorkplacePaymentSheet.brandGreen,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Label & Current remaining
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'المبلغ المقبوض من المشغّل *',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'المتبقي حالياً: ',
                                  style: TextStyle(
                                    color:
                                        RecordWorkplacePaymentSheet.brandYellow,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  remainingFormatted,
                                  style: TextStyle(
                                    color:
                                        RecordWorkplacePaymentSheet.brandYellow,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Input row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  color: RecordWorkplacePaymentSheet.textWhite,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF52525B),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Text(
                              '₪ شيكل',
                              style: TextStyle(
                                color: RecordWorkplacePaymentSheet.brandYellow,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quick action addition pills bar
                      Container(
                        decoration: BoxDecoration(
                          color: RecordWorkplacePaymentSheet.surfaceField,
                          border: Border(
                            top: BorderSide(
                              color: RecordWorkplacePaymentSheet.surfaceBorder,
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(11),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildQuickAmountBtn(
                              '+500',
                              () => _addQuickAmount(500),
                            ),
                            _buildDivider(),
                            _buildQuickAmountBtn(
                              '+1,000',
                              () => _addQuickAmount(1000),
                            ),
                            _buildDivider(),
                            _buildQuickAmountBtn(
                              '+2,000',
                              () => _addQuickAmount(2000),
                            ),
                            _buildDivider(),
                            _buildQuickAmountBtn(
                              'كامل المتبقي',
                              _setFullRemaining,
                              isYellow: true,
                            ),
                            _buildDivider(),
                            _buildQuickAmountBtn(
                              'تصفير',
                              _clearAmount,
                              isRed: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Date Picker row
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: RecordWorkplacePaymentSheet.surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: RecordWorkplacePaymentSheet.surfaceBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Remix.calendar_event_line,
                              size: 15,
                              color: RecordWorkplacePaymentSheet.brandGreen,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'تاريخ استلام الدفعة:',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateFormatted,
                          style: TextStyle(
                            color: RecordWorkplacePaymentSheet.textWhite,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Payment Method: 4 buttons
                Row(
                  children:
                      _methods.map((m) {
                        final isSelected = _paymentMethod == m['name'];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.5,
                            ),
                            child: InkWell(
                              onTap: () {
                                SpendoHaptics.selection();
                                setState(() => _paymentMethod = m['name']);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      RecordWorkplacePaymentSheet.surfaceField,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? RecordWorkplacePaymentSheet
                                                .brandGreen
                                            : RecordWorkplacePaymentSheet
                                                .surfaceBorder,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      m['icon'] as IconData,
                                      size: 16,
                                      color:
                                          isSelected
                                              ? RecordWorkplacePaymentSheet
                                                  .brandGreen
                                              : const Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m['name'] as String,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? RecordWorkplacePaymentSheet
                                                    .textWhite
                                                : const Color(0xFF9CA3AF),
                                        fontSize: 11,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 8),

                // Notes Field
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: RecordWorkplacePaymentSheet.surfaceField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RecordWorkplacePaymentSheet.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Remix.sticky_note_line,
                        size: 15,
                        color: RecordWorkplacePaymentSheet.brandYellow,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _notesController,
                          style: TextStyle(
                            color: RecordWorkplacePaymentSheet.textWhite,
                            fontSize: 11.5,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'ملاحظات أو بيان الدفعة (اختياري)...',
                            hintStyle: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Save Button
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RecordWorkplacePaymentSheet.brandGreen,
                    foregroundColor: const Color(0xFF0A0B0B),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Remix.check_line,
                        size: 16,
                        color: Color(0xFF0A0B0B),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'حفظ الدفعة المستلمة',
                        style: TextStyle(
                          color: Color(0xFF0A0B0B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 22,
      color: RecordWorkplacePaymentSheet.surfaceBorder,
    );
  }

  Widget _buildQuickAmountBtn(
    String label,
    VoidCallback onTap, {
    bool isYellow = false,
    bool isRed = false,
  }) {
    Color textColor = RecordWorkplacePaymentSheet.textWhite;
    if (isYellow) textColor = RecordWorkplacePaymentSheet.brandYellow;
    if (isRed) textColor = const Color(0xFFF87171);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.5),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
