import 'package:sanad_app/core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/core/widgets/spendo_logo.dart';
import 'package:sanad_app/core/services/location_service.dart';
import 'package:sanad_app/core/services/attachment_service.dart';
import 'package:sanad_app/core/widgets/attachment_viewer_modal.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/models/workplace_payment_model.dart';
import 'package:sanad_app/features/workplaces/repositories/workplaces_repository.dart';
import 'package:sanad_app/features/workplaces/repositories/workplace_payments_repository.dart';
import 'package:sanad_app/features/workplaces/presentation/widgets/add_edit_workplace_sheet.dart';
import 'package:sanad_app/features/workplaces/presentation/widgets/record_workplace_payment_sheet.dart';
import 'package:sanad_app/features/work_logs/models/work_log_model.dart';
import 'package:sanad_app/features/work_logs/repositories/work_logs_repository.dart';
import 'package:sanad_app/features/work_logs/presentation/widgets/add_work_log_sheet.dart';
import 'package:sanad_app/features/workplaces/presentation/screens/map_location_picker_screen.dart';
import 'package:sanad_app/features/reports/services/pdf_statement_service.dart';

/// Employer Account Statement Screen (`كشف حساب المشغّل - Spendo`).
///
/// Refactored 1:1 to match the compact Bento obsidian design:
/// 1. Top Bar: Back arrow, Spendo mini logo, screen title, share PDF, copy summary (no refresh button needed).
/// 2. Bento Card: Building icon, employer name, active badge, agreed daily rate, edit/delete partition,
///    embedded month filter chips, 4-column financial grid [أيام العمل | المستحق الكلي | المقبوض | صافي المتبقي].
/// 3. 2-Column Action Buttons: "تسجيل يوم عمل" + "قبض دفعة".
/// 4. Payments on Account Collapsible Box with count badge, total, and payments list.
/// 5. 12-Column Structured Table for Workdays: [التاريخ واليوم (4) | مكان العمل (4) | اليومية (2) | إجراء (2)].
class EmployerDetailsScreen extends StatefulWidget {
  final WorkplaceModel workplace;
  final String? initialMonth;

  const EmployerDetailsScreen({
    super.key,
    required this.workplace,
    this.initialMonth,
  });

  static bool get _isDark => AppTheme.isDarkMode;

  static Color get bgCanvas => _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  static Color get surfaceMain => _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  static Color get surfaceField => _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  static Color get surfaceHover => _isDark ? const Color(0xFF16161A) : const Color(0xFFF1F3F5);
  static Color get surfaceBorder => _isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color brandYellow = Color(0xFFF59E0B);
  static Color get textPrimary => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  static Color get textSubtle => _isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);
  static Color get textWhite => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color get surfaceCell => _isDark ? const Color(0xFF181A18) : const Color(0xFFF3F4F6);

  @override
  State<EmployerDetailsScreen> createState() => _EmployerDetailsScreenState();
}

class _EmployerDetailsScreenState extends State<EmployerDetailsScreen> {
  final WorkLogsRepository _workRepo = WorkLogsRepository();
  final WorkplacesRepository _workplacesRepo = WorkplacesRepository();
  final PeopleRepository _peopleRepo = PeopleRepository();
  final WorkplacePaymentsRepository _paymentsRepo = WorkplacePaymentsRepository();

  late WorkplaceModel _workplace;
  List<WorkLogModel> _employerLogs = [];
  List<WorkplacePaymentModel> _workplacePayments = [];
  Map<String, PersonModel> _peopleMap = {};
  List<WorkplaceModel> _allWorkplaces = [];
  bool _isLoading = true;
  String _selectedMonth = 'ALL';
  bool _isPaymentsSectionExpanded = true;

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
    _workplace = widget.workplace;
    if (widget.initialMonth != null) {
      _selectedMonth = widget.initialMonth!;
    }
    _loadData();
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allWp = await _workplacesRepo.getAllWorkplaces();
      final updatedWp = await _workplacesRepo.getWorkplaceById(_workplace.id);
      if (updatedWp != null) {
        _workplace = updatedWp;
      }

      final workplaceLogs = await _workRepo.getLogsForWorkplaceOrName(_workplace.id, _workplace.name);
      final people = await _peopleRepo.getAllPeople();
      final payments = await _paymentsRepo.getPaymentsForWorkplace(_workplace.id);

      if (mounted) {
        setState(() {
          _allWorkplaces = allWp;
          _employerLogs = workplaceLogs;
          _workplacePayments = payments;
          _peopleMap = {for (var p in people) p.id: p};
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _availableMonthKeys {
    final Set<String> keys = {};
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    keys.add(currentKey);

    for (final log in _employerLogs) {
      if (log.date.length >= 7) {
        keys.add(log.date.substring(0, 7));
      }
    }
    for (final p in _workplacePayments) {
      if (p.date.length >= 7) {
        keys.add(p.date.substring(0, 7));
      }
    }
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<WorkLogModel> get _filteredLogs {
    if (_selectedMonth == 'ALL') {
      return _employerLogs;
    }
    return _employerLogs.where((l) => l.date.startsWith(_selectedMonth)).toList();
  }

  List<WorkplacePaymentModel> get _filteredPayments {
    if (_selectedMonth == 'ALL') {
      return _workplacePayments;
    }
    return _workplacePayments.where((p) => p.date.startsWith(_selectedMonth)).toList();
  }

  int get _filteredDaysWorked => _filteredLogs.length;
  double get _filteredTotalEarned => _filteredLogs.fold(0.0, (sum, log) => sum + log.totalEarned);
  double get _filteredPaymentsOnAccount => _filteredPayments.fold(0.0, (sum, p) => sum + p.amount);
  double get _filteredShiftCollected => _filteredLogs.fold(0.0, (sum, log) => sum + log.amountCollected);

  double get _filteredTotalCollected {
    if (_filteredPaymentsOnAccount > 0) {
      return _filteredPaymentsOnAccount;
    }
    return _filteredShiftCollected;
  }

  double get _filteredTotalRemaining => (_filteredTotalEarned - _filteredTotalCollected).clamp(0.0, double.infinity);

  // ==================== EMPLOYER STATUS DIALOG ====================

  Future<void> _changeEmployerStatusDialog() async {
    SpendoHaptics.selection();
    final newStatus = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: EmployerDetailsScreen.surfaceMain,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EmployerDetailsScreen.surfaceBorder, width: 1.2),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.toggle_line, color: EmployerDetailsScreen.brandYellow, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'حالة المشغّل',
                          style: TextStyle(
                            color: EmployerDetailsScreen.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Remix.close_line, size: 18, color: EmployerDetailsScreen.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'المشغّل: "${_workplace.name}"\nاختر حالة العمل مع هذا المشغّل حالياً:',
                  style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),

                // خيار 1: نشط
                InkWell(
                  onTap: () => Navigator.pop(ctx, 'active'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _workplace.isActive
                          ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.12)
                          : EmployerDetailsScreen.surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _workplace.isActive
                            ? EmployerDetailsScreen.brandGreen
                            : EmployerDetailsScreen.surfaceBorder,
                        width: _workplace.isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: EmployerDetailsScreen.brandGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'نشط (على رأس العمل)',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.textWhite,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'أعمل مع هذا المشغّل حالياً، ويظهر كخيار رئيسي عند تسجيل العمل',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_workplace.isActive)
                          Icon(Remix.check_line, color: EmployerDetailsScreen.brandGreen, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // خيار 2: غير نشط (منتهي)
                InkWell(
                  onTap: () => Navigator.pop(ctx, 'completed'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !_workplace.isActive
                          ? Colors.white.withValues(alpha: 0.08)
                          : EmployerDetailsScreen.surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_workplace.isActive
                            ? Colors.white.withValues(alpha: 0.5)
                            : EmployerDetailsScreen.surfaceBorder,
                        width: !_workplace.isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: EmployerDetailsScreen.textSubtle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'غير نشط (منتهي / خلصت شغل معه)',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.textWhite,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'انتهيت من العمل معه. تبقى كافة اليوميات والدفعات وكشوفات الحساب محفوظة ومؤرشفة',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_workplace.isActive)
                          const Icon(Remix.check_line, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (newStatus != null && newStatus != _workplace.status) {
      await _workplacesRepo.toggleWorkplaceStatus(_workplace.id, _workplace.status);
      _loadData();
      _showToast(newStatus == 'active' ? 'تم ضبط المشغّل كـ (نشط)' : 'تم تحويل المشغّل إلى (غير نشط / منتهي)');
    }
  }

  // ==================== SWITCH EMPLOYER MODAL ====================

  Future<void> _showSwitchEmployerModal() async {
    if (_allWorkplaces.length <= 1) {
      _showToast('لا يوجد مشغّلون آخرون مسجلون');
      return;
    }
    SpendoHaptics.selection();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: EmployerDetailsScreen.surfaceMain,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EmployerDetailsScreen.surfaceBorder, width: 1.2),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.building_2_line, color: EmployerDetailsScreen.brandGreen, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'اختر المشغّل / صاحب العمل',
                          style: TextStyle(
                            color: EmployerDetailsScreen.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '(${_allWorkplaces.length} مشغّلين)',
                          style: TextStyle(
                            color: EmployerDetailsScreen.brandYellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Remix.close_line, size: 18, color: EmployerDetailsScreen.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _allWorkplaces.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final wp = _allWorkplaces[idx];
                    final isSelected = wp.id == _workplace.id;
                    return InkWell(
                      onTap: () {
                        SpendoHaptics.selection();
                        Navigator.pop(ctx);
                        if (!isSelected) {
                          setState(() {
                            _workplace = wp;
                            _selectedMonth = 'ALL';
                          });
                          _loadData();
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.12)
                              : EmployerDetailsScreen.surfaceField,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? EmployerDetailsScreen.brandGreen
                                : EmployerDetailsScreen.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Remix.building_line,
                                  size: 16,
                                  color: isSelected ? EmployerDetailsScreen.brandGreen : EmployerDetailsScreen.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  wp.name,
                                  style: TextStyle(
                                    color: isSelected ? EmployerDetailsScreen.textWhite : EmployerDetailsScreen.textMuted,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: wp.isActive
                                        ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.12)
                                        : EmployerDetailsScreen.surfaceMain,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: wp.isActive
                                          ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.4)
                                          : EmployerDetailsScreen.surfaceBorder,
                                    ),
                                  ),
                                  child: Text(
                                    wp.isActive ? 'نشط' : 'منتهي',
                                    style: TextStyle(
                                      color: wp.isActive
                                          ? EmployerDetailsScreen.brandGreen
                                          : EmployerDetailsScreen.textSubtle,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: EmployerDetailsScreen.surfaceMain,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
                              ),
                              child: Text(
                                '${wp.dailyRate.toInt()} ₪ / يوم',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.brandYellow,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  // ==================== WORK LOG ACTIONS ====================

  Future<void> _openAddOrEditLog([WorkLogModel? existing]) async {
    SpendoHaptics.selection();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => AddWorkLogSheet(
        preselectedWorkplace: _workplace,
        existingLog: existing,
        onSave: (log) async {
          if (existing != null) {
            await _workRepo.updateWorkLog(log);
          } else {
            await _workRepo.addWorkLog(log);
          }
          _loadData();
        },
      ),
    );
    _loadData();
  }

  Future<void> _confirmDeleteWorkday(WorkLogModel log) async {
    SpendoHaptics.medium();
    final dayName = ArabicDateHelper.getWeekdayFromDateString(log.date);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmployerDetailsScreen.surfaceMain,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EmployerDetailsScreen.surfaceBorder),
        ),
        title: Text('حذف يوم العمل', style: TextStyle(color: EmployerDetailsScreen.textWhite, fontSize: 14)),
        content: Text(
          'هل تريد بالتأكيد حذف يومية $dayName (${log.date}) من السجل؟',
          style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: EmployerDetailsScreen.textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _workRepo.deleteWorkLog(log.id);
      _loadData();
      _showToast('تم حذف يوم العمل من السجل');
    }
  }

  // ==================== ON-ACCOUNT PAYMENT ACTIONS ====================

  Future<void> _openRecordPayment([WorkplacePaymentModel? existing]) async {
    SpendoHaptics.selection();
    await RecordWorkplacePaymentSheet.show(
      context,
      workplace: _workplace,
      existingPayment: existing,
      remainingDue: _filteredTotalRemaining,
      onSave: (payment) async {
        if (existing != null) {
          await _paymentsRepo.updatePayment(payment);
        } else {
          await _paymentsRepo.addPayment(payment);
        }
        _loadData();
        _showToast('تم حفظ الدفعة وخصمها من المتبقي بنجاح');
      },
    );
  }

  Future<void> _confirmDeletePayment(WorkplacePaymentModel payment) async {
    SpendoHaptics.medium();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmployerDetailsScreen.surfaceMain,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EmployerDetailsScreen.surfaceBorder),
        ),
        title: Text('حذف الدفعة المستلمة', style: TextStyle(color: EmployerDetailsScreen.textWhite, fontSize: 14)),
        content: Text(
          'هل تريد بالتأكيد حذف الدفعة بقيمة ${payment.amount.toStringAsFixed(0)} ₪ بتاريخ ${payment.date}؟',
          style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: EmployerDetailsScreen.textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الدفعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _paymentsRepo.deletePayment(payment.id);
      _loadData();
      _showToast('تم حذف الدفعة');
    }
  }

  // ==================== EMPLOYER EDIT & DELETE ====================

  Future<void> _editWorkplace() async {
    SpendoHaptics.selection();
    final result = await AddEditWorkplaceSheet.show(
      context,
      workplace: _workplace,
    );
    if (result != null) {
      await _workplacesRepo.updateWorkplace(result);
      setState(() => _workplace = result);
      _loadData();
      _showToast('تم تعديل بيانات المشغّل وتحديث اليوميات');
    }
  }

  Future<void> _editDailyRateDialog([double? initialRate]) async {
    SpendoHaptics.selection();
    final baseRate = initialRate ?? (_workplace.dailyRate > 0 ? _workplace.dailyRate : 350.0);
    final rateText = baseRate == baseRate.roundToDouble()
        ? baseRate.toInt().toString()
        : baseRate.toStringAsFixed(1);
    final ctrl = TextEditingController(text: rateText);

    final newRate = await showDialog<double>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EmployerDetailsScreen.surfaceMain,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: EmployerDetailsScreen.surfaceBorder, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.money_dollar_circle_line,
                            color: EmployerDetailsScreen.brandYellow, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'تعديل سعر اليومية (₪)',
                          style: TextStyle(
                            color: EmployerDetailsScreen.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Remix.close_line,
                            size: 18, color: EmployerDetailsScreen.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'سيتم تطبيق سعر اليومية الجديد وتحديث جميع أيام العمل المسجلة لـ "${_workplace.name}" في السجل تلقائياً.',
                  style: TextStyle(
                    color: EmployerDetailsScreen.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: EmployerDetailsScreen.surfaceField,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: EmployerDetailsScreen.brandYellow
                            .withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: EmployerDetailsScreen.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'مثال: 350',
                      hintStyle: TextStyle(
                          color: EmployerDetailsScreen.textSubtle,
                          fontSize: 13),
                      suffixText: '₪ / يوم',
                      suffixStyle: const TextStyle(
                        color: EmployerDetailsScreen.brandYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmployerDetailsScreen.brandGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          final parsed = double.tryParse(ctrl.text.trim());
                          if (parsed != null && parsed > 0) {
                            Navigator.pop(ctx, parsed);
                          }
                        },
                        icon: const Icon(Remix.check_line, size: 16),
                        label: const Text(
                          'تحديث كل اليوميات',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: EmployerDetailsScreen.textMuted,
                        side:
                            BorderSide(color: EmployerDetailsScreen.surfaceBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child:
                          const Text('إلغاء', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (newRate != null && newRate > 0 && mounted) {
      SpendoHaptics.success();
      final updated = _workplace.copyWith(
        dailyRate: newRate,
        updatedAt: DateTime.now(),
      );
      await _workplacesRepo.updateWorkplace(updated);
      setState(() => _workplace = updated);
      await _loadData();
      _showToast('تم تحديث سعر اليومية لجميع أيام العمل في السجل');
    }
  }

  Future<void> _confirmDeleteWorkplace() async {
    SpendoHaptics.medium();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmployerDetailsScreen.surfaceMain,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: EmployerDetailsScreen.surfaceBorder),
        ),
        title: Text('حذف المشغّل', style: TextStyle(color: EmployerDetailsScreen.textWhite, fontSize: 14)),
        content: Text(
          'هل أنت متأكد من حذف المشغّل "${_workplace.name}"؟ ستبقى سجلات أيام العمل السابقة محفوظة في الأرشيف.',
          style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: EmployerDetailsScreen.textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _workplacesRepo.deleteWorkplace(_workplace.id, workplaceName: _workplace.name, deleteLogs: true);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // ==================== STATEMENT TEXT & SHARE ====================

  String _buildStatementText() {
    final buffer = StringBuffer();
    final isMonthFiltered = _selectedMonth != 'ALL';
    final monthLabel = isMonthFiltered ? ArabicDateHelper.formatMonthYearKey(_selectedMonth) : 'كافة الأشهر المسجلة';

    buffer.writeln('كشف حساب أيام العمل - Spendo');
    buffer.writeln('--------------------------------');
    buffer.writeln('المشغّل: ${_workplace.name}');
    buffer.writeln('الفترة: $monthLabel');
    buffer.writeln('عدد الأيام: $_filteredDaysWorked يوم');
    if (_filteredTotalEarned > 0) {
      buffer.writeln('المستحق الكلي: ${_filteredTotalEarned.toStringAsFixed(0)} ₪');
      buffer.writeln('المقبوض: ${_filteredTotalCollected.toStringAsFixed(0)} ₪');
      final remStr = _filteredTotalRemaining <= 0.01 ? 'خالص' : '${_filteredTotalRemaining.toStringAsFixed(0)} ₪';
      buffer.writeln('المتبقي: $remStr');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('سجل أيام وتواريخ العمل:');
    if (_filteredLogs.isEmpty) {
      buffer.writeln('لا توجد أيام عمل مسجلة لهذه الفترة');
    } else {
      for (int i = 0; i < _filteredLogs.length; i++) {
        final l = _filteredLogs[i];
        final dayStr = ArabicDateHelper.formatArabicDateWithWeekdayFromString(l.date);
        final location = l.city.trim().isNotEmpty ? l.city.trim() : (l.workplaceName.isNotEmpty ? l.workplaceName : 'يوم عمل');
        buffer.writeln('${i + 1}. $dayStr ($location) - ${l.totalEarned.toStringAsFixed(0)} ₪');
      }
    }
    if (_filteredPayments.isNotEmpty) {
      buffer.writeln('--------------------------------');
      buffer.writeln('الدفعات المستلمة على الحساب:');
      for (int i = 0; i < _filteredPayments.length; i++) {
        final p = _filteredPayments[i];
        final note = p.notes != null ? ' (${p.notes})' : '';
        buffer.writeln('${i + 1}. ${p.date}: ${p.amount.toStringAsFixed(0)} ₪ [${p.paymentMethod}]$note');
      }
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('تم التوثيق عبر تطبيق Spendo');
    return buffer.toString();
  }

  void _copyStatement() {
    Clipboard.setData(ClipboardData(text: _buildStatementText()));
    SpendoHaptics.light();
    _showToast('تم نسخ ملخص الحساب للحافظة');
  }

  Future<void> _showStatementOptionsSheet() async {
    SpendoHaptics.selection();
    final isMonthFiltered = _selectedMonth != 'ALL';
    final periodLabel = isMonthFiltered
        ? 'شهر ${ArabicDateHelper.formatMonthYearKey(_selectedMonth)}'
        : 'كافة الأشهر والورديات';
    final contractor = _workplace.personId != null ? _peopleMap[_workplace.personId] : null;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: EmployerDetailsScreen.surfaceMain,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EmployerDetailsScreen.surfaceBorder, width: 1.2),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.share_forward_line, color: EmployerDetailsScreen.brandYellow, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'مشاركة كشف حساب رسمي معتمد (PDF)',
                          style: TextStyle(
                            color: EmployerDetailsScreen.textWhite,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Remix.close_line, size: 18, color: EmployerDetailsScreen.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'المشغّل: ${_workplace.name} • $periodLabel',
                  style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 11),
                ),
            if (_allWorkplaces.length > 1) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _allWorkplaces.map((wp) {
                    final isSel = wp.id == _workplace.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () {
                          SpendoHaptics.selection();
                          Navigator.pop(ctx);
                          if (!isSel) {
                            setState(() {
                              _workplace = wp;
                              _selectedMonth = 'ALL';
                            });
                            _loadData();
                            _showStatementOptionsSheet();
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel
                                ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.18)
                                : EmployerDetailsScreen.surfaceField,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? EmployerDetailsScreen.brandGreen : EmployerDetailsScreen.surfaceBorder,
                              width: isSel ? 1.3 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSel) ...[
                                Icon(Remix.check_line, size: 12, color: EmployerDetailsScreen.brandGreen),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                wp.name,
                                style: TextStyle(
                                  color: isSel ? EmployerDetailsScreen.textWhite : EmployerDetailsScreen.textMuted,
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Option 1: Print & Preview PDF
            _buildExportOptionTile(
              icon: Remix.printer_line,
              iconColor: const Color(0xFF38BDF8),
              title: 'معاينة وطباعة كشف أيام العمل (PDF)',
              subtitle: 'توثيق رسمي يتضمن أيام وساعات ومواقع العمل المنجزة',
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await PdfStatementService.instance.printWorkplaceStatement(
                    workplace: _workplace,
                    workLogs: _filteredLogs,
                    payments: _filteredPayments,
                    periodTitle: periodLabel,
                    contractor: contractor,
                    includeFinancials: false,
                  );
                } catch (e) {
                  if (mounted) _showToast('حدث خطأ أثناء فتح المعاينة: $e');
                }
              },
            ),
            const SizedBox(height: 8),

            // Option 2: WhatsApp PDF Share
            _buildExportOptionTile(
              icon: Remix.whatsapp_line,
              iconColor: const Color(0xFF25D366),
              title: 'مشاركة كشف أيام العمل عبر واتساب',
              subtitle: 'إرسال ملف PDF يوثق الأيام والمواقع للمشغّل فوراً',
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await PdfStatementService.instance.shareWorkplaceStatement(
                    workplace: _workplace,
                    workLogs: _filteredLogs,
                    payments: _filteredPayments,
                    periodTitle: periodLabel,
                    contractor: contractor,
                    includeFinancials: false,
                  );
                } catch (e) {
                  if (mounted) _showToast('حدث خطأ أثناء إعداد الكشف: $e');
                }
              },
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildExportOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        SpendoHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: EmployerDetailsScreen.surfaceField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: EmployerDetailsScreen.textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Icon(Remix.arrow_left_s_line, color: EmployerDetailsScreen.textSubtle, size: 16),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EmployerDetailsScreen.surfaceField,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: EmployerDetailsScreen.brandGreen),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Remix.checkbox_circle_line, color: EmployerDetailsScreen.brandYellow, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: EmployerDetailsScreen.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2300),
      ),
    );
  }

  void _showWorkdayDetailsModal(WorkLogModel log) {
    SpendoHaptics.light();
    final locationName = log.city.trim().isNotEmpty
        ? log.city.trim()
        : (log.workplaceName.trim().isNotEmpty ? log.workplaceName.trim() : 'مكان العمل');
    final hasNote = log.notes != null && log.notes!.trim().isNotEmpty;
    final hasAttachments = log.attachments.isNotEmpty;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: EmployerDetailsScreen.surfaceMain,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EmployerDetailsScreen.surfaceBorder, width: 1.2),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row: Day/Date + Wage Badge + Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Remix.calendar_check_line,
                              color: EmployerDetailsScreen.brandGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تفاصيل وتوثيق يوم العمل',
                                    style: TextStyle(
                                      color: EmployerDetailsScreen.textWhite,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${log.formattedDateWithDay} • ${_workplace.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: EmployerDetailsScreen.textMuted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: EmployerDetailsScreen.brandYellow.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EmployerDetailsScreen.brandYellow.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${log.totalEarned.toStringAsFixed(0)} ₪',
                          style: const TextStyle(
                            color: EmployerDetailsScreen.brandYellow,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Remix.close_line, size: 18, color: EmployerDetailsScreen.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. قسم الملاحظات وتفاصيل العمل
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EmployerDetailsScreen.surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasNote
                            ? EmployerDetailsScreen.brandYellow.withValues(alpha: 0.45)
                            : EmployerDetailsScreen.surfaceBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Remix.sticky_note_line,
                                  size: 15,
                                  color: hasNote
                                      ? EmployerDetailsScreen.brandYellow
                                      : EmployerDetailsScreen.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ملاحظات وتفاصيل العمل:',
                                  style: TextStyle(
                                    color: EmployerDetailsScreen.textWhite,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (hasNote)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: log.notes!.trim()));
                                  SpendoHaptics.light();
                                  _showToast('تم نسخ الملاحظة');
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Remix.file_copy_line, size: 12, color: EmployerDetailsScreen.textMuted),
                                      const SizedBox(width: 3),
                                      Text(
                                        'نسخ',
                                        style: TextStyle(
                                          color: EmployerDetailsScreen.textMuted,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (hasNote)
                          SelectableText(
                            log.notes!.trim(),
                            style: TextStyle(
                              color: EmployerDetailsScreen.textWhite,
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _openAddOrEditLog(log);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '+ لا توجد ملاحظة مسجلة • اضغط لإضافة ملاحظة',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.brandGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. قسم الصور والمرفقات الموثّقة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: EmployerDetailsScreen.surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasAttachments
                            ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.45)
                            : EmployerDetailsScreen.surfaceBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Remix.camera_3_line,
                                  size: 15,
                                  color: hasAttachments
                                      ? EmployerDetailsScreen.brandGreen
                                      : EmployerDetailsScreen.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasAttachments
                                      ? 'الصور والمرفقات (${log.attachments.length}):'
                                      : 'الصور والمرفقات:',
                                  style: TextStyle(
                                    color: EmployerDetailsScreen.textWhite,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                _openAddOrEditLog(log);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  '+ إرفاق صور/ملفات',
                                  style: TextStyle(
                                    color: EmployerDetailsScreen.brandGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (hasAttachments) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 84,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: log.attachments.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (c, idx) {
                                final path = log.attachments[idx];
                                final item = AttachmentItem.fromPath(path);
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    AttachmentViewerModal.show(context, filePath: path);
                                  },
                                  child: Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: EmployerDetailsScreen.surfaceMain,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: item.isImage
                                        ? Image.file(
                                            File(path),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Remix.image_line,
                                              color: EmployerDetailsScreen.textMuted,
                                              size: 26,
                                            ),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                item.isPdf ? Remix.file_pdf_2_fill : Remix.file_text_fill,
                                                size: 28,
                                                color: item.isPdf
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF38BDF8),
                                              ),
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    color: EmployerDetailsScreen.textMuted,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'لا توجد صور أو ملفات مرفقة لهذا اليوم',
                            style: TextStyle(
                              color: EmployerDetailsScreen.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. بطاقة مكان العمل والخريطة
                  InkWell(
                    onTap: log.hasLocation
                        ? () {
                            Navigator.pop(ctx);
                            LocationService.openMap(log.latitude!, log.longitude!);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: EmployerDetailsScreen.surfaceField,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: log.hasLocation
                              ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.4)
                              : EmployerDetailsScreen.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  log.hasLocation ? Remix.map_pin_fill : Remix.map_pin_2_line,
                                  size: 16,
                                  color: log.hasLocation
                                      ? EmployerDetailsScreen.brandGreen
                                      : EmployerDetailsScreen.brandYellow,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'مكان العمل:',
                                  style: TextStyle(
                                    color: EmployerDetailsScreen.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    locationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: EmployerDetailsScreen.textWhite,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (log.hasLocation)
                            const Row(
                              children: [
                                Text(
                                  'فتح الخريطة',
                                  style: TextStyle(
                                    color: EmployerDetailsScreen.brandGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Remix.arrow_left_s_line,
                                  size: 13,
                                  color: EmployerDetailsScreen.brandGreen,
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: () async {
                                Navigator.pop(ctx);
                                final result = await MapLocationPickerScreen.pick(
                                  context,
                                  initialCity: locationName,
                                  initialAddress: locationName,
                                );
                                if (result != null) {
                                  final newAddr = result.address;
                                  final updated = log.copyWith(
                                    latitude: result.latitude,
                                    longitude: result.longitude,
                                    locationAddress: newAddr,
                                    city: (newAddr != null && newAddr.trim().isNotEmpty) ? newAddr.trim() : log.city,
                                  );
                                  await _workRepo.updateWorkLog(updated);
                                  _loadData();
                                  _showToast('تم تثبيت مكان العمل بنجاح');
                                }
                              },
                              child: const Text(
                                'تثبيت على الخريطة',
                                style: TextStyle(
                                  color: EmployerDetailsScreen.brandYellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. أزرار التعديل والإغلاق
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EmployerDetailsScreen.brandGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openAddOrEditLog(log);
                          },
                          icon: const Icon(Remix.edit_2_line, size: 15),
                          label: const Text(
                            'تعديل اليوم والملاحظات والصور',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EmployerDetailsScreen.textMuted,
                          side: BorderSide(color: EmployerDetailsScreen.surfaceBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogAttachments(WorkLogModel log) {
    SpendoHaptics.light();
    if (log.attachments.isEmpty) return;

    if (log.attachments.length == 1) {
      AttachmentViewerModal.show(context, filePath: log.attachments.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: EmployerDetailsScreen.surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF404040),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Remix.camera_3_line, color: EmployerDetailsScreen.brandYellow, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'مرفقات يوم العمل (${log.attachments.length})',
                          style: TextStyle(color: EmployerDetailsScreen.textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      log.formattedDateWithDay,
                      style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: log.attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (c, idx) {
                      final path = log.attachments[idx];
                      final item = AttachmentItem.fromPath(path);
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          AttachmentViewerModal.show(context, filePath: path);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: EmployerDetailsScreen.surfaceField,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.isImage
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.isPdf ? Remix.file_pdf_2_fill : Remix.file_text_fill,
                                      size: 32,
                                      color: item.isPdf ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        item.name,
                                        style: TextStyle(fontSize: 8.5, color: EmployerDetailsScreen.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: EmployerDetailsScreen.bgCanvas,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: EmployerDetailsScreen.brandGreen))
            : RefreshIndicator(
                color: EmployerDetailsScreen.brandGreen,
                backgroundColor: EmployerDetailsScreen.surfaceField,
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    // 1. Top Bar
                    _buildTopBar(),
                    const SizedBox(height: 10),

                    // 2. Employer & 4-Column Financial Bento Card
                    _buildEmployerBentoCard(),
                    const SizedBox(height: 10),

                    // 3. Quick Action Buttons Grid (2 equal columns)
                    _buildActionButtons(),
                    const SizedBox(height: 10),

                    // 4. Payments on Account Collapsible Box (يظهر تلقائياً فقط عند وجود دفعات)
                    if (_filteredPayments.isNotEmpty) ...[
                      _buildPaymentsCollapsibleBox(),
                      const SizedBox(height: 10),
                    ],

                    // 5. Workdays Structured Table (سجل أيام وتواريخ العمل)
                    _buildWorkdaysStructuredTable(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  /// 1. Top Bar (رجوع + شعار Spendo + العنوان + أدوات التصدير والتحديث)
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: EmployerDetailsScreen.surfaceBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Right (RTL): Back + Logo + Title
          Row(
            children: [
              InkWell(
                onTap: () {
                  SpendoHaptics.light();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(Remix.arrow_right_line, size: 18, color: EmployerDetailsScreen.textWhite),
                ),
              ),
              const SizedBox(width: 4),
              const SpendoLogo(size: 20, borderRadius: 5),
              const SizedBox(width: 8),
              Text(
                'كشف حساب المشغّل',
                style: TextStyle(
                  color: EmployerDetailsScreen.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Left (RTL): Share PDF + Copy Summary
          Row(
            children: [
              InkWell(
                onTap: _showStatementOptionsSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.share_forward_line, size: 16, color: EmployerDetailsScreen.brandYellow),
                      SizedBox(width: 3),
                      Text(
                        'مشاركة',
                        style: TextStyle(
                          color: EmployerDetailsScreen.brandYellow,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _copyStatement,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(Remix.file_copy_line, size: 16, color: EmployerDetailsScreen.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Employer Card + Embedded Month Filter + 4-Column Financial Grid
  Widget _buildEmployerBentoCard() {
    final monthKeys = _availableMonthKeys;

    return Container(
      decoration: BoxDecoration(
        color: EmployerDetailsScreen.surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Row 1: Employer info + rate badge + partitioned edit/delete box
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info & Rate
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Remix.building_2_line,
                                color: EmployerDetailsScreen.brandGreen,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: _showSwitchEmployerModal,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _workplace.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: EmployerDetailsScreen.textWhite,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (_allWorkplaces.length > 1) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Remix.arrow_down_s_line,
                                              size: 15,
                                              color: EmployerDetailsScreen.brandYellow,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAB308).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFEAB308).withValues(alpha: 0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Text(
                                            'מעסיק',
                                            style: TextStyle(
                                              color: Color(0xFFEAB308),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: _changeEmployerStatusDialog,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _workplace.isActive
                                                  ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.15)
                                                  : EmployerDetailsScreen.surfaceField,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: _workplace.isActive
                                                    ? EmployerDetailsScreen.brandGreen.withValues(alpha: 0.6)
                                                    : EmployerDetailsScreen.surfaceBorder,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _workplace.isActive
                                                        ? EmployerDetailsScreen.brandGreen
                                                        : EmployerDetailsScreen.textSubtle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _workplace.isActive ? 'نشط ▾' : 'غير نشط (منتهي) ▾',
                                                  style: TextStyle(
                                                    color: _workplace.isActive
                                                        ? EmployerDetailsScreen.brandGreen
                                                        : EmployerDetailsScreen.textMuted,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
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
                        const SizedBox(width: 6),
                        // Daily rate badge (tappable to edit all daily rates)
                        InkWell(
                          onTap: () => _editDailyRateDialog(_workplace.dailyRate),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: EmployerDetailsScreen.surfaceMain,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'اليومية',
                                  style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 9),
                                ),
                                Text(
                                  _workplace.dailyRate > 0
                                      ? '${_workplace.dailyRate.toStringAsFixed(0)} ₪'
                                      : 'غير محددة',
                                  style: TextStyle(
                                    color: EmployerDetailsScreen.brandYellow,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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

                // Partitioned Edit & Delete Box
                Container(
                  decoration: BoxDecoration(
                    color: EmployerDetailsScreen.surfaceCell,
                    border: Border(right: BorderSide(color: EmployerDetailsScreen.surfaceBorder)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _editWorkplace,
                        child: Icon(Remix.pencil_line, size: 14, color: EmployerDetailsScreen.textMuted),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 1,
                        height: 14,
                        color: EmployerDetailsScreen.surfaceBorder,
                      ),
                      InkWell(
                        onTap: _confirmDeleteWorkplace,
                        child: Icon(Remix.delete_bin_6_line, size: 14, color: EmployerDetailsScreen.textSubtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Row 2: Embedded Month Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: EmployerDetailsScreen.surfaceCell,
              border: Border(
                top: BorderSide(color: EmployerDetailsScreen.surfaceBorder),
                bottom: BorderSide(color: EmployerDetailsScreen.surfaceBorder),
              ),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(Remix.calendar_line, size: 12, color: EmployerDetailsScreen.brandYellow),
                    const SizedBox(width: 4),
                    Text('الشهر:', style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 10)),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildMonthChip(
                          title: 'الكل (${_employerLogs.length})',
                          isSelected: _selectedMonth == 'ALL',
                          onTap: () {
                            SpendoHaptics.selection();
                            setState(() => _selectedMonth = 'ALL');
                          },
                        ),
                        ...monthKeys.map((key) {
                          final count = _employerLogs.where((l) => l.date.startsWith(key)).length;
                          final label = ArabicDateHelper.formatMonthYearKey(key);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildMonthChip(
                              title: '$label ($count)',
                              isSelected: _selectedMonth == key,
                              onTap: () {
                                SpendoHaptics.selection();
                                setState(() => _selectedMonth = key);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Row 3: 4-Column Financial Grid
          IntrinsicHeight(
            child: Row(
              children: [
                _buildFinancialCell(
                  label: 'أيام العمل',
                  value: '$_filteredDaysWorked',
                  unit: 'يوم',
                  valueColor: EmployerDetailsScreen.textWhite,
                ),
                _buildCellDivider(),
                _buildFinancialCell(
                  label: 'المستحق الكلي',
                  value: _filteredTotalEarned.toStringAsFixed(0),
                  unit: '₪',
                  valueColor: EmployerDetailsScreen.textWhite,
                ),
                _buildCellDivider(),
                _buildFinancialCell(
                  label: 'المقبوض',
                  value: _filteredTotalCollected.toStringAsFixed(0),
                  unit: '₪',
                  valueColor: EmployerDetailsScreen.brandGreen,
                ),
                _buildCellDivider(),
                _buildFinancialCell(
                  label: 'صافي المتبقي',
                  value: _filteredTotalRemaining.toStringAsFixed(0),
                  unit: '₪',
                  valueColor: EmployerDetailsScreen.brandYellow,
                  labelColor: EmployerDetailsScreen.brandYellow,
                  bgColor: EmployerDetailsScreen._isDark ? const Color(0x80121413) : const Color(0x18F59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthChip({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EmployerDetailsScreen.surfaceField,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? EmployerDetailsScreen.brandGreen : EmployerDetailsScreen.surfaceBorder,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? EmployerDetailsScreen.textWhite : EmployerDetailsScreen.textMuted,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCellDivider() {
    return Container(
      width: 1,
      color: EmployerDetailsScreen.surfaceBorder,
    );
  }

  Widget _buildFinancialCell({
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
    Color? labelColor,
    Color? bgColor,
  }) {
    final effectiveLabelColor = labelColor ?? EmployerDetailsScreen.textMuted;
    return Expanded(
      child: Container(
        color: bgColor ?? Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: effectiveLabelColor,
                fontSize: 10,
                fontWeight: effectiveLabelColor == EmployerDetailsScreen.brandYellow ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    color: EmployerDetailsScreen.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Quick Action Buttons Grid (2 equal columns)
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Button 1: تسجيل يوم عمل
        Expanded(
          child: InkWell(
            onTap: () => _openAddOrEditLog(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: EmployerDetailsScreen.surfaceField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Remix.calendar_check_line, color: EmployerDetailsScreen.brandYellow, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'تسجيل يوم عمل',
                    style: TextStyle(
                      color: EmployerDetailsScreen.textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Button 2: قبض دفعة
        Expanded(
          child: InkWell(
            onTap: () => _openRecordPayment(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: EmployerDetailsScreen.brandGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Remix.hand_coin_line, color: Color(0xFF0A0B0B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'قبض دفعة',
                    style: TextStyle(
                      color: Color(0xFF0A0B0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 4. Payments on Account Collapsible Box (قسم الدفعات المستلمة على الحساب)
  Widget _buildPaymentsCollapsibleBox() {
    final payments = _filteredPayments;

    return Container(
      decoration: BoxDecoration(
        color: EmployerDetailsScreen.surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Collapsible Header Button
          InkWell(
            onTap: () {
              SpendoHaptics.selection();
              setState(() => _isPaymentsSectionExpanded = !_isPaymentsSectionExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Remix.wallet_3_line,
                        color: EmployerDetailsScreen.brandGreen,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الدفعات المستلمة على الحساب',
                        style: TextStyle(
                          color: EmployerDetailsScreen.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: EmployerDetailsScreen.surfaceMain,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
                        ),
                        child: Text(
                          '${payments.length}',
                          style: TextStyle(
                            color: EmployerDetailsScreen.brandYellow,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${_filteredPaymentsOnAccount.toStringAsFixed(0)} ₪',
                        style: TextStyle(
                          color: EmployerDetailsScreen.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isPaymentsSectionExpanded ? Remix.arrow_up_s_line : Remix.arrow_down_s_line,
                        color: EmployerDetailsScreen.textMuted,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Payments Content
          if (_isPaymentsSectionExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: EmployerDetailsScreen.surfaceCell,
                border: Border(top: BorderSide(color: EmployerDetailsScreen.surfaceBorder)),
              ),
              child: payments.isEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Remix.information_line, size: 13, color: EmployerDetailsScreen.textSubtle),
                            const SizedBox(width: 6),
                            Text(
                              'لا توجد دفعات مسجلة لهذه الفترة',
                              style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _openRecordPayment(),
                          child: Text(
                            '+ تسجيل دفعة',
                            style: TextStyle(
                              color: EmployerDetailsScreen.brandGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: payments.map((p) => _buildPaymentItemRow(p)).toList(),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentItemRow(WorkplacePaymentModel payment) {
    final dateParts = payment.date.split('-');
    final dateFormatted = dateParts.length == 3 ? '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}' : payment.date;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33242927))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Remix.check_double_line,
                color: EmployerDetailsScreen.brandGreen,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'دفعة ${payment.paymentMethod} مستلمة',
                style: TextStyle(
                  color: EmployerDetailsScreen.textWhite,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dateFormatted,
                style: TextStyle(
                  color: EmployerDetailsScreen.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '+${payment.amount.toStringAsFixed(0)} ₪',
                style: TextStyle(
                  color: EmployerDetailsScreen.brandGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _openRecordPayment(payment),
                child: Icon(Remix.pencil_line, size: 13, color: EmployerDetailsScreen.textMuted),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _confirmDeletePayment(payment),
                child: Icon(Remix.delete_bin_6_line, size: 13, color: EmployerDetailsScreen.textSubtle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. Workdays Structured Table (سجل أيام وتواريخ العمل - 12 Columns)
  Widget _buildWorkdaysStructuredTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Remix.file_list_3_line, size: 14, color: EmployerDetailsScreen.brandYellow),
                const SizedBox(width: 6),
                Text(
                  'سجل أيام وتواريخ العمل',
                  style: TextStyle(
                    color: EmployerDetailsScreen.textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              'مرتب حسب الأحدث',
              style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Table Box
        Container(
          decoration: BoxDecoration(
            color: EmployerDetailsScreen.surfaceField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EmployerDetailsScreen.surfaceBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Column Headers: 4 | 4 | 2 | 2
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                decoration: BoxDecoration(
                  color: EmployerDetailsScreen.surfaceCell,
                  border: Border(bottom: BorderSide(color: EmployerDetailsScreen.surfaceBorder)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'التاريخ واليوم',
                          style: TextStyle(
                            color: EmployerDetailsScreen.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildCellDivider(),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'مكان العمل',
                            style: TextStyle(
                              color: EmployerDetailsScreen.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      _buildCellDivider(),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            'اليومية',
                            style: TextStyle(
                              color: EmployerDetailsScreen.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      _buildCellDivider(),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            'إجراء',
                            style: TextStyle(
                              color: EmployerDetailsScreen.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rows or Empty State
              if (_filteredLogs.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Remix.calendar_close_line, size: 28, color: EmployerDetailsScreen.textSubtle),
                      const SizedBox(height: 8),
                      Text(
                        'لا توجد أيام عمل مسجلة لهذه الفترة',
                        style: TextStyle(color: EmployerDetailsScreen.textWhite, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'اضغط على زر "تسجيل يوم عمل" بالأعلى لإضافة يومية جديدة',
                        style: TextStyle(color: EmployerDetailsScreen.textMuted, fontSize: 10.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ..._filteredLogs.map((log) => _buildWorkdayTableRow(log)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkdayTableRow(WorkLogModel log) {
    final dayName = ArabicDateHelper.getWeekdayFromDateString(log.date);
    final dateParts = log.date.split('-');
    final dateFormatted = dateParts.length == 3 ? '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}' : log.date;
    final location = log.city.trim().isNotEmpty
        ? log.city.trim()
        : (log.workplaceName.trim().isNotEmpty ? log.workplaceName.trim() : 'يوم عمل');
    final hasNote = log.notes != null && log.notes!.trim().isNotEmpty;
    final hasAttachments = log.hasAttachments;

    return InkWell(
      onTap: () => _showWorkdayDetailsModal(log),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: EmployerDetailsScreen.surfaceBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Col 1: Day & Date (flex: 4)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                dayName.isNotEmpty ? dayName : 'يوم عمل',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: EmployerDetailsScreen.textWhite,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (hasNote) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Remix.sticky_note_line,
                                size: 11,
                                color: EmployerDetailsScreen.brandYellow,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          dateFormatted,
                          style: TextStyle(
                            color: EmployerDetailsScreen.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCellDivider(),

                  // Col 2: Workplace Location (flex: 4)
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showWorkdayDetailsModal(log),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      log.hasLocation ? Remix.map_pin_fill : Remix.map_pin_2_line,
                                      color: log.hasLocation
                                          ? EmployerDetailsScreen.brandGreen
                                          : EmployerDetailsScreen.brandYellow,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: log.hasLocation ? EmployerDetailsScreen.textWhite : EmployerDetailsScreen.textMuted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (hasAttachments) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _showLogAttachments(log),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: EmployerDetailsScreen.brandYellow.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: EmployerDetailsScreen.brandYellow.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Remix.camera_3_line, size: 9, color: EmployerDetailsScreen.brandYellow),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${log.attachments.length}',
                                      style: const TextStyle(
                                        color: EmployerDetailsScreen.brandYellow,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildCellDivider(),

                  // Col 3: Amount (flex: 2) - tappable to edit daily rate across all logs
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _editDailyRateDialog(log.totalEarned),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              log.totalEarned.toStringAsFixed(0),
                              style: const TextStyle(
                                color: EmployerDetailsScreen.brandYellow,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Text(
                              '₪',
                              style: TextStyle(
                                color: EmployerDetailsScreen.brandYellow,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildCellDivider(),

                  // Col 4: Partitioned Actions: Edit & Delete (flex: 2)
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => _openAddOrEditLog(log),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Remix.pencil_line, size: 13, color: EmployerDetailsScreen.textMuted),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _confirmDeleteWorkday(log),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Remix.delete_bin_6_line, size: 13, color: EmployerDetailsScreen.textSubtle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Inline Note & Attachments Preview Strip (يظهر تلقائياً عند وجود ملاحظة أو صور)
            if (hasNote || hasAttachments) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: EmployerDetailsScreen.surfaceMain.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: EmployerDetailsScreen.surfaceBorder.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    if (hasNote) ...[
                      const Icon(
                        Remix.sticky_note_line,
                        size: 11,
                        color: EmployerDetailsScreen.brandYellow,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          log.notes!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: EmployerDetailsScreen.textWhite,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (hasAttachments) ...[
                      if (hasNote) const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.image_2_line,
                            size: 11,
                            color: EmployerDetailsScreen.brandGreen,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${log.attachments.length} مرفق',
                            style: const TextStyle(
                              color: EmployerDetailsScreen.brandGreen,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
