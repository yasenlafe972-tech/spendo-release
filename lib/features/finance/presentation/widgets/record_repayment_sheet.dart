import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../people/models/person_model.dart';
import '../../models/debt_model.dart';
import '../../models/debt_payment_model.dart';
import '../../../../core/widgets/spendo_date_picker.dart';

/// Bottom sheet to record a repayment toward an existing debt (`سداد دفعة`).
class RecordRepaymentSheet extends StatefulWidget {
  final DebtModel debt;
  final PersonModel person;
  final Function(DebtPaymentModel) onConfirm;

  const RecordRepaymentSheet({
    super.key,
    required this.debt,
    required this.person,
    required this.onConfirm,
  });

  @override
  State<RecordRepaymentSheet> createState() => _RecordRepaymentSheetState();
}

class _RecordRepaymentSheetState extends State<RecordRepaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'bit';
  DateTime _paymentDate = DateTime.now();

  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF171A19) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const Color brandBlue = Color(0xFF0F766E);
  static Color get brandYellow => AppColors.warningFor(_isDark);
  static Color get successColor => AppColors.successFor(_isDark);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  static List<Map<String, dynamic>> get _methods => [
    {'key': 'bit', 'title': 'Bit', 'icon': Remix.smartphone_line, 'color': brandBlue},
    {'key': 'cash', 'title': 'كاش', 'icon': Remix.money_dollar_box_line, 'color': successColor},
    {'key': 'bank_transfer', 'title': 'تحويل بنكي', 'icon': Remix.bank_line, 'color': brandBlue},
    {'key': 'atm_code', 'title': 'كود صراف', 'icon': Remix.qr_code_line, 'color': brandBlue},
  ];

  @override
  void initState() {
    super.initState();
    final initialMethod = widget.debt.paymentMethod;
    _paymentMethod = (initialMethod == 'pending' || initialMethod == 'check')
        ? 'cash'
        : initialMethod;
    _amountCtrl.text = widget.debt.remainingAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    SpendoHaptics.success();
    final payment = DebtPaymentModel(
      id: const Uuid().v4(),
      debtId: widget.debt.id,
      amount: amount,
      paymentMethod: _paymentMethod,
      paymentDate: DateFormat('yyyy-MM-dd').format(_paymentDate),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    widget.onConfirm(payment);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await SpendoDatePicker.pickDate(
      context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'تاريخ الدفعة',
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.debt;
    final isTheyOwe = d.isTheyOwe;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomNavPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: surfaceBorder, width: 1.0),
          left: BorderSide(color: surfaceBorder, width: 1.0),
          right: BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: keyboardInset > 0
                ? keyboardInset
                : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مؤشر السحب العلوي
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: surfaceBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ترويسة النافذة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: surfaceBorder, width: 1.0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Remix.cash_line, color: brandBlue, size: 22),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTheyOwe
                                    ? 'استلام دفعة من ${widget.person.name}'
                                    : (d.isPayLater
                                        ? 'دفع الحساب المؤجل لـ ${widget.person.name}'
                                        : 'سداد دفعة لـ ${widget.person.name}'),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                d.isPayLater
                                    ? 'اختر طريقة الدفع الآن (كاش / Bit / بنكي) لإغلاق الحساب'
                                    : 'تسجيل دفعة جديدة وتحديث المتبقي تلقائياً',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Remix.close_line, color: Color(0xFF9CA3AF), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // المحتوى القابل للتمرير
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ملخص حالة السلفة
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surfaceField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('المبلغ الأصلي', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9CA3AF), fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.originalAmount.toStringAsFixed(0)} ₪',
                                  style: TextStyle(fontFamily: 'Cairo', color: textWhite, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 26, color: surfaceBorder),
                            Column(
                              children: [
                                const Text('المسدد حالياً', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9CA3AF), fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.paidAmount.toStringAsFixed(0)} ₪',
                                  style: TextStyle(fontFamily: 'Cairo', color: successColor, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 26, color: surfaceBorder),
                            Column(
                              children: [
                                const Text('المتبقي للسداد', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9CA3AF), fontSize: 10)),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.remainingAmount.toStringAsFixed(0)} ₪',
                                  style: TextStyle(fontFamily: 'Cairo', color: brandYellow, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // حقل مبلغ الدفعة
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: surfaceBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Remix.cash_line, color: brandBlue, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'مبلغ الدفعة المسددة *',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: Color(0xFF71717A),
                                    fontSize: 12,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            Text(
                              '₪',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: brandYellow,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // زر تعبئة كامل المبلغ المتبقي
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () {
                            SpendoHaptics.light();
                            _amountCtrl.text = d.remainingAmount.toStringAsFixed(0);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Remix.check_line, size: 13, color: brandBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'سداد كامل المتبقي (${d.remainingAmount.toStringAsFixed(0)} ₪)',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    color: brandBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // طريقة الدفع
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          'طريقة استلام / سداد الدفعة:',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: _methods.map((m) {
                          final isSelected = _paymentMethod == m['key'];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: InkWell(
                                onTap: () {
                                  SpendoHaptics.selection();
                                  setState(() => _paymentMethod = m['key']);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: surfaceField,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? brandBlue : surfaceBorder,
                                      width: isSelected ? 1.2 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(m['icon'] as IconData, color: m['color'] as Color, size: 16),
                                      const SizedBox(height: 4),
                                      Text(
                                        m['title'] as String,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: isSelected ? textWhite : textMuted,
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // تاريخ الدفعة
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('تاريخ الدفعة', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9CA3AF), fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text(
                                    ArabicDateHelper.formatArabicDateWithWeekday(_paymentDate),
                                    style: TextStyle(fontFamily: 'Cairo', color: textWhite, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Icon(Remix.calendar_event_line, color: brandBlue, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ملاحظات
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: surfaceBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Remix.file_text_line, color: Color(0xFF9CA3AF), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _notesCtrl,
                                style: TextStyle(fontFamily: 'Cairo', color: textWhite, fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'ملاحظات وتفاصيل الدفعة (اختياري)',
                                  hintStyle: TextStyle(fontFamily: 'Cairo', color: Color(0xFF71717A), fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // زر التأكيد
                      InkWell(
                        onTap: _confirm,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: brandBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Remix.check_line, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                d.isPayLater ? 'تأكيد تم الدفع' : 'تأكيد تسجيل الدفعة',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
