import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/widgets/banking_animations.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';
import '../../../settings/presentation/screens/app_settings_screen.dart';
import '../../models/debt_model.dart';
import '../../repositories/finance_repository.dart';
import '../widgets/add_debt_sheet.dart';
import '../widgets/record_repayment_sheet.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/widgets/spendo_confirm_delete_dialog.dart';

/// Spendo Finance & Personal Debts Screen.
/// Designed 1:1 based on the Spendo Obsidian Dark Design System.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FinanceRepository _financeRepo = FinanceRepository();
  final PeopleRepository _peopleRepo = PeopleRepository();

  List<DebtModel> _debts = [];
  Map<String, PersonModel> _peopleMap = {};
  bool _isLoading = true;
  final Set<String> _expandedPeople = {};
  String _selectedFilter = 'all'; // 'all', 'they_owe', 'i_owe', 'received', 'settled', 'bit', 'cash', 'bank', 'check'

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get surfaceMain => _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  Color get surfaceField => _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  Color get surfaceBorder => _isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
  static const Color brandBlue = Color(0xFF2563EB);
  Color get brandYellow => AppColors.warningFor(_isDark);
  Color get successColor => AppColors.successFor(_isDark);
  static const Color brandRed = Color(0xFFEF4444);
  Color get textWhite => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textMuted => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  Color get textSubtle => _isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);






  @override
  void initState() {
    super.initState();
    DatabaseHelper.dataVersionNotifier.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    DatabaseHelper.dataVersionNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final debts = await _financeRepo.getAllDebts();
      final people = await _peopleRepo.getAllPeople();
      if (!mounted) return;
      setState(() {
        _debts = debts;
        _peopleMap = {for (var p in people) p.id: p};
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('FinanceScreen _loadData error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalTheyOweMe => FinanceRepository.calculateTotalTheyOwe(_debts);
  double get _totalIOweThem => FinanceRepository.calculateTotalIOwe(_debts);
  double get _netDebtBalance => FinanceRepository.calculateNetDebtBalance(_debts);
  double get _totalReceived => FinanceRepository.calculateTotalReceived(_debts);

  List<DebtModel> get _filteredDebts {
    switch (_selectedFilter) {
      case 'they_owe':
        return _debts.where((d) => d.isTheyOwe && !d.isSettled).toList();
      case 'i_owe':
        return _debts.where((d) => d.isIOwe && !d.isSettled).toList();
      case 'pay_later':
        return _debts.where((d) => d.isPayLater && !d.isSettled).toList();
      case 'received':
        return _debts.where((d) => d.isReceived).toList();
      case 'atm_code':
        return _debts.where((d) => d.paymentMethod.toLowerCase() == 'atm_code').toList();
      case 'bit':
        return _debts.where((d) => d.paymentMethod.toLowerCase() == 'bit').toList();
      case 'cash':
        return _debts.where((d) => d.paymentMethod.toLowerCase() == 'cash').toList();
      case 'bank':
        return _debts.where((d) => d.paymentMethod.toLowerCase() == 'bank_transfer').toList();
      case 'settled':
        return _debts.where((d) => d.isSettled && !d.isReceived).toList();
      case 'all':
      default:
        return _debts;
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: brandBlue, width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Remix.checkbox_circle_line, color: successColor, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: textWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddDebtSheet() async {
    SpendoHaptics.light();
    final people = await _peopleRepo.getAllPeople();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => AddDebtSheet(
        people: people,
        onSave: (debt) async {
          await _financeRepo.addDebt(debt);
          _loadData();
          _showToast('تم حفظ المعاملة في كشف المالية');
        },
      ),
    );
  }

  Future<void> _showEditDebtSheet(DebtModel debt) async {
    SpendoHaptics.light();
    final people = await _peopleRepo.getAllPeople();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => AddDebtSheet(
        people: people,
        initialDebt: debt,
        onSave: (updatedDebt) async {
          await _financeRepo.updateDebt(updatedDebt);
          _loadData();
          _showToast('تم تعديل المعاملة بنجاح');
        },
      ),
    );
  }

  Future<void> _showRepaymentSheet(DebtModel debt) async {
    SpendoHaptics.light();
    final person = _peopleMap[debt.personId] ??
        PersonModel(
          id: debt.personId,
          name: 'شخص غير معروف',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => RecordRepaymentSheet(
        debt: debt,
        person: person,
        onConfirm: (payment) async {
          await _financeRepo.recordDebtRepayment(payment: payment, parentDebt: debt);
          _loadData();
          _showToast('تم تسجيل الدفعة بنجاح');
        },
      ),
    );
  }

  void _shareDebtViaWhatsApp(DebtModel debt) async {
    SpendoHaptics.light();
    final person = _peopleMap[debt.personId];
    final buffer = StringBuffer();
    if (debt.isReceived) {
      buffer.writeln('إشعار استلام مالي - Spendo');
      buffer.writeln('--------------------------------');
      buffer.writeln('الاسم: ${person?.name ?? "غير محدد"}');
      buffer.writeln('نوع المعاملة: مبالغ مستلمة (سحب بنكي أو استلام مالي)');
      buffer.writeln('طريقة الاستلام: ${debt.paymentMethodTitle}');
      buffer.writeln('تاريخ المعاملة: ${ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate)}');
      buffer.writeln('المبلغ المستلم: ${debt.originalAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('الحالة: خالص ومسدد (مستلم بالكامل)');
      if (debt.notes != null) {
        buffer.writeln('ملاحظات: ${debt.notes}');
      }
      buffer.writeln('\nتم التوثيق عبر تطبيق Spendo');
    } else {
      buffer.writeln('توثيق سلفة مالية - Spendo');
      buffer.writeln('--------------------------------');
      buffer.writeln('الاسم: ${person?.name ?? "غير محدد"}');
      buffer.writeln('نوع المعاملة: ${debt.typeTitle}');
      buffer.writeln('طريقة الدفع: ${debt.paymentMethodTitle}');
      buffer.writeln('تاريخ السلفة: ${ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate)}');
      buffer.writeln('المبلغ الأصلي (من أصل): ${debt.originalAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('المسدد حتى الآن: ${debt.paidAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('المبلغ المتبقي: ${debt.remainingAmount.toStringAsFixed(1)} ₪');
      if (debt.dueDate != null) {
        buffer.writeln('تاريخ السداد المتوقع: ${ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.dueDate!)}');
      }
      if (debt.notes != null) {
        buffer.writeln('ملاحظات: ${debt.notes}');
      }
      buffer.writeln('\nتم التوثيق عبر تطبيق Spendo');
    }

    if (person?.whatsapp != null && person!.whatsapp!.isNotEmpty) {
      final cleanPhone = person.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
      final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString())}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'توثيق سلفة - ${person?.name}',
      ),
    );
  }

  Future<void> _confirmDelete(DebtModel debt) async {
    final personName = _peopleMap[debt.personId]?.name ?? 'معاملة مالية';
    final confirmed = await SpendoConfirmDeleteDialog.show(
      context,
      title: 'حذف المعاملة المالية',
      itemName: '$personName - ${debt.originalAmount.toStringAsFixed(0)} ₪',
      itemIcon: Remix.hand_coin_line,
      description: 'هل أنت متأكد من حذف هذا السجل المالي وسجل الدفعات المرتبطة به نهائياً؟',
      confirmLabel: 'حذف',
    );

    if (confirmed == true) {
      await _financeRepo.deleteDebt(debt.id);
      _loadData();
      _showToast('تم حذف المعاملة');
    }
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return '${amount.toInt()}';
    }
    return amount.toStringAsFixed(1);
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'pending':
        return Remix.time_line;
      case 'bit':
        return Remix.smartphone_line;
      case 'cash':
        return Remix.money_dollar_box_line;
      case 'bank_transfer':
      case 'bank':
        return Remix.bank_line;
      case 'check':
        return Remix.file_list_3_line;
      default:
        return Remix.cash_line;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'pending':
      case 'bit':
      case 'bank_transfer':
      case 'bank':
        return brandYellow;
      case 'cash':
      case 'check':
      default:
        return brandBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceMain,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandBlue, strokeWidth: 2))
            : RefreshIndicator(
                color: brandBlue,
                backgroundColor: surfaceMain,
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  children: [
                    // 1. الهيدر العلوي (أيقونات نظيفة بدون خلفية)
                    _buildHeader(),
                    const SizedBox(height: 12),

                    // 2. بطاقة ملخص الحسابات (مدمجة وبدون دوائر خلف الأيقونات)
                    BankingCascadeItem(
                      tabIndex: 4,
                      staggerIndex: 0,
                      child: _buildDashboardCards(),
                    ),
                    const SizedBox(height: 14),

                    // 3. عنوان سجل المعاملات + زر تسجيل جديد
                    BankingCascadeItem(
                      tabIndex: 4,
                      staggerIndex: 1,
                      child: _buildSectionHeader(),
                    ),
                    const SizedBox(height: 10),

                    // 5. قائمة بطاقات المعاملات (مع أنيميشن سلس عند تبديل الفلتر)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey<String>('${_selectedFilter}_${_filteredDebts.length}'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_filteredDebts.isEmpty)
                            _buildEmptyState()
                          else
                            _buildDebtGrid(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  /// 1. الهيدر العلوي (أيقونات نظيفة بدون أي خلفية)
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaceBorder, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Remix.wallet_3_line, color: brandBlue, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المالية والديون',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'متابعة السلف، الديون، والمبالغ المستلمة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () async {
                  SpendoHaptics.light();
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                  );
                  _loadData();
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Remix.settings_4_line, color: Color(0xFF9CA3AF), size: 19),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. بطاقة ملخص الحسابات (مدمجة وبدون دوائر خلف الأيقونات)
  Widget _buildDashboardCards() {
    final net = _netDebtBalance;
    final isPositive = net > 0.01;
    final isNegative = net < -0.01;
    final isBalanced = !isPositive && !isNegative;

    final String netPrefix = isPositive ? '+' : (isNegative ? '-' : '');
    final double absNet = net.abs();

    final String netStatusLabel = isPositive
        ? 'فائض لك عند الغير'
        : (isNegative ? 'التزام مالي عليك' : 'الحسابات متوازنة');

    final IconData netStatusIcon = isBalanced
        ? Remix.check_line
        : (isPositive ? Remix.arrow_left_down_line : Remix.arrow_right_up_line);

    final Color badgeColor = isBalanced ? textMuted : (isPositive ? successColor : brandRed);

    return Container(
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الصف العلوي: صافي الحسابات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Remix.scales_3_line, color: textMuted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'صافي الحسابات:',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  BankingRollingNumber(
                    tabIndex: 4,
                    value: absNet,
                    formatter: (val) => '$netPrefix${_formatCurrency(val)} ',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: textWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '₪',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: brandYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfaceMain,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(netStatusIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      netStatusLabel,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(color: surfaceBorder, height: 1, thickness: 1),
          const SizedBox(height: 10),

          // الصف السفلي: 3 أعمدة (سلف لي / ديون علي / مقبوضات)
          Row(
            children: [
              // سلف لي
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Remix.arrow_left_down_line, color: brandBlue, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'سلف لي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BankingRollingNumber(
                          tabIndex: 4,
                          value: _totalTheyOweMe,
                          formatter: (val) => _formatCurrency(val),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          '₪',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF71717A),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(width: 1, height: 28, color: surfaceBorder),

              // ديون علي
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Remix.arrow_right_up_line, color: brandRed, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'ديون علي',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BankingRollingNumber(
                          tabIndex: 4,
                          value: _totalIOweThem,
                          formatter: (val) => _formatCurrency(val),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          '₪',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF71717A),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(width: 1, height: 28, color: surfaceBorder),

              // مبالغ مستلمة (باللون الأصفر الدافئ)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Remix.checkbox_circle_line, color: successColor, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'مبالغ مستلمة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BankingRollingNumber(
                          tabIndex: 4,
                          value: _totalReceived,
                          formatter: (val) => '+${_formatCurrency(val)}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: brandYellow,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '₪',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: brandYellow,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Transaction heading and compact controls.
  Widget _buildSectionHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سجل المعاملات',
                style: TextStyle(fontFamily: 'Cairo', color: textWhite,
                    fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('${_filteredDebts.length}',
                style: TextStyle(fontFamily: 'Cairo', color: textMuted,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 90, child: _buildFilterDropdown()),
            const SizedBox(width: 6),
            FilledButton.icon(
                onPressed: _showAddDebtSheet,
                icon: const Icon(Remix.add_line, size: 15),
                label: const Text('تسجيل جديد'),
                style: FilledButton.styleFrom(
                  backgroundColor: brandBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  textStyle: const TextStyle(fontFamily: 'Cairo',
                      fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    const labels = <String, String>{
      'all': 'الكل',
      'they_owe': 'إلي عنده',
      'i_owe': 'عليّ إله',
      'pay_later': 'عالحساب',
      'received': 'مبالغ مستلمة',
      'settled': 'المسددة',
      'atm_code': 'كود صراف',
      'bit': 'Bit',
      'cash': 'كاش',
      'bank': 'تحويل بنكي',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: surfaceBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isExpanded: true,
          isDense: true,
          dropdownColor: surfaceField,
          borderRadius: BorderRadius.circular(12),
          menuWidth: 122,
          menuMaxHeight: 280,
          icon: Icon(Remix.arrow_down_s_line, size: 19, color: textMuted),
          style: TextStyle(fontFamily: 'Cairo', color: textWhite,
              fontSize: 11, fontWeight: FontWeight.w600),
          items: labels.entries.map((entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) {
            if (value == null || value == _selectedFilter) return;
            SpendoHaptics.selection();
            setState(() => _selectedFilter = value);
          },
        ),
      ),
    );
  }

  /// Group by the saved person ID so separate contacts with the same name stay separate.
  Widget _buildDebtGrid() {
    final sorted = List<DebtModel>.of(_filteredDebts)
      ..sort((a, b) {
        final dateOrder = b.transactionDate.compareTo(a.transactionDate);
        return dateOrder != 0 ? dateOrder : b.createdAt.compareTo(a.createdAt);
      });
    final groups = <String, List<DebtModel>>{};
    for (final debt in sorted) {
      groups.putIfAbsent(debt.personId, () => []).add(debt);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: groups.entries.map((entry) => SizedBox(
          width: cardWidth,
          child: _buildPersonHistoryCard(entry.key, entry.value),
        )).toList(),
      );
    });
  }

  Widget _buildPersonHistoryCard(String personId, List<DebtModel> debts) {
    final expanded = _expandedPeople.contains(personId);
    final visible = expanded ? debts : debts.take(3).toList();
    return Material(
      key: ValueKey('finance-person-$personId'),
      color: surfaceField,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Remix.user_3_line, size: 19, color: textMuted),
              const SizedBox(width: 5),
              Expanded(child: Text(_peopleMap[personId]?.name ?? 'شخص غير مسجل',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Cairo', color: textWhite,
                    fontSize: 11.5, fontWeight: FontWeight.bold))),
            ]),
            for (final debt in visible) ...[
              Divider(height: 9, thickness: 0.6, color: surfaceBorder),
              _buildHistoryEntry(debt),
            ],
            if (debts.length > 3)
              TextButton(
                onPressed: () => setState(() {
                  if (expanded) {
                    _expandedPeople.remove(personId);
                  } else {
                    _expandedPeople.add(personId);
                  }
                }),
                style: TextButton.styleFrom(
                  foregroundColor: brandBlue,
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 10),
                ),
                child: Text(expanded ? 'عرض أقل' : 'عرض باقي السجل (${debts.length - 3})'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(DebtModel debt) {
    final isSettled = debt.isSettled;
    final statusColor = isSettled || debt.isReceived
        ? successColor : (debt.isPayLater ? brandYellow : (debt.isIOwe ? brandRed : brandYellow));
    final status = debt.isReceived ? 'خالص ومسدد'
        : debt.isPayLater ? (isSettled ? 'تم الدفع' : 'للدفع لاحقاً')
        : isSettled ? 'تم السداد'
        : debt.isIOwe ? 'مستحق الدفع' : 'بانتظار السداد';
    final date = DateTime.tryParse(debt.transactionDate);
    final dateLabel = date == null ? debt.transactionDate
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return InkWell(
      onTap: () => _showDebtDetailsDialog(debt),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              Text(dateLabel, textDirection: TextDirection.ltr,
                style: TextStyle(fontFamily: 'Cairo', color: textMuted,
                    fontSize: 9, fontWeight: FontWeight.w500)),
              Text('${_formatCurrency(debt.originalAmount)} ₪',
                style: TextStyle(fontFamily: 'Cairo', color: textWhite,
                    fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              Text(status, style: TextStyle(fontFamily: 'Cairo',
                  color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildCardAction('واتساب', Remix.whatsapp_line,
                    const Color(0xFF10B981), () => _shareDebtViaWhatsApp(debt)),
                _buildCardAction('تعديل', Remix.pencil_line,
                    textMuted, () => _showEditDebtSheet(debt)),
                _buildCardAction('حذف', Remix.delete_bin_line,
                    textMuted, () => _confirmDelete(debt)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  /// النافذة المنبثقة الوسطية لتفاصيل المعاملة المالية (Popup Dialog وسطية وليست سلايد)
  void _showDebtDetailsDialog(DebtModel debt) {
    SpendoHaptics.selection();
    final person = _peopleMap[debt.personId];
    final isTheyOwe = debt.isTheyOwe;
    final isSettled = debt.isSettled;
    final isReceived = debt.isReceived;

    String badgeText = 'إلي عنده';
    Color badgeColor = brandBlue;
    String amountPrefix = '';
    String subStatus = isSettled ? 'تم السداد بالكامل' : 'بانتظار السداد';

    if (debt.isPayLater) {
      badgeText = 'عالحساب (مؤجل)';
      badgeColor = brandYellow;
      amountPrefix = '-';
      subStatus = isSettled ? 'تم الدفع بالكامل' : 'مستحق للدفع لاحقاً';
    } else if (debt.isIOwe) {
      badgeText = 'عليّ إله';
      badgeColor = brandRed;
      amountPrefix = '-';
      subStatus = isSettled ? 'تم السداد بالكامل' : 'مستحق الدفع فوراً';
    } else if (isReceived) {
      badgeText = 'مبالغ مستلمة';
      badgeColor = successColor;
      amountPrefix = '+';
      subStatus = 'خالص ومسدد';
    }

    final double displayAmount = isReceived
        ? debt.originalAmount
        : (isSettled ? debt.originalAmount : debt.remainingAmount);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DebtPopupDetails',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(dialogCtx).size.width.clamp(280.0, 380.0),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: surfaceBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isDark ? 0.45 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. ترويسة النافذة المنبثقة: زر الإغلاق + اسم الشخص + وسم الحالة
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(dialogCtx),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: surfaceBorder.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Remix.close_line, size: 16, color: textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person?.name ?? 'شخص غير مسجل',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: textWhite,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'تفاصيل المعاملة المالية',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: _isDark ? 0.14 : 0.20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: badgeColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. بطاقة Bento 1: المبلغ المالي وحالة السداد
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceMain,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isReceived ? 'إجمالي المبلغ المستلم' : (isSettled ? 'المبلغ المسدد' : 'المبلغ المستحق'),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$amountPrefix${_formatCurrency(displayAmount)} ',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isReceived
                                    ? successColor
                                    : (isSettled ? successColor : (debt.isPayLater || isTheyOwe ? brandYellow : brandRed)),
                              ),
                            ),
                            Text(
                              '₪',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            subStatus,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: badgeColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // تفصيل السداد الجزئي إن وجد
                        if (!isSettled && !isReceived && debt.remainingAmount < debt.originalAmount) ...[
                          const SizedBox(height: 8),
                          Divider(color: surfaceBorder, height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text('المبلغ الأصلي', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: textMuted)),
                                  Text('${_formatCurrency(debt.originalAmount)} ₪', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: textWhite)),
                                ],
                              ),
                              Column(
                                children: [
                                  Text('المسدد', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: textMuted)),
                                  Text('${_formatCurrency(debt.originalAmount - debt.remainingAmount)} ₪', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: successColor)),
                                ],
                              ),
                              Column(
                                children: [
                                  Text('المتبقي', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: textMuted)),
                                  Text('${_formatCurrency(debt.remainingAmount)} ₪', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: brandRed)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. بطاقة Bento 2: تفاصيل المعاملة (التاريخ + وسيلة الدفع)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: surfaceMain,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        // التاريخ
                        Row(
                          children: [
                            Icon(Remix.calendar_2_line, color: textMuted, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              'تاريخ المعاملة:',
                              style: TextStyle(fontFamily: 'Cairo', color: textMuted, fontSize: 11),
                            ),
                            const Spacer(),
                            Text(
                              ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate),
                              style: TextStyle(fontFamily: 'Cairo', color: textWhite, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Divider(color: surfaceBorder.withValues(alpha: 0.6), height: 12),
                        // وسيلة الدفع
                        Row(
                          children: [
                            Icon(_getPaymentMethodIcon(debt.paymentMethod), color: _getPaymentMethodColor(debt.paymentMethod), size: 14),
                            const SizedBox(width: 8),
                            Text(
                              'طريقة الدفع:',
                              style: TextStyle(fontFamily: 'Cairo', color: textMuted, fontSize: 11),
                            ),
                            const Spacer(),
                            Text(
                              debt.paymentMethodTitle,
                              style: TextStyle(fontFamily: 'Cairo', color: textWhite, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4. ملاحظات المعاملة إن وجدت
                  if (debt.notes != null && debt.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Remix.file_text_line, color: textMuted, size: 13),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              debt.notes!,
                              style: TextStyle(fontFamily: 'Cairo', color: textWhite, fontSize: 11, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 5. أزرار الإجراءات داخل النافذة المنبثقة
                  // زر سداد دفعة إذا كانت المعاملة فعالة
                  if (!isSettled && !isReceived) ...[
                    InkWell(
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        _showRepaymentSheet(debt);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(debt.isPayLater ? Remix.checkbox_circle_line : Remix.cash_line, size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              debt.isPayLater ? 'تأكيد دفع المعاملة' : 'تسجيل سداد دفعة',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // أزرار الإجراءات كأيقونات نقية بدون خلفية (واتساب، تعديل بالقلم، وحذف بالسطل)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // أيقونة واتساب بدون خلفية
                      InkWell(
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _shareDebtViaWhatsApp(debt);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Icon(Remix.whatsapp_line, size: 22, color: Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // أيقونة التعديل (قلم) بدون خلفية
                      InkWell(
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _showEditDebtSheet(debt);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Icon(Remix.pencil_line, size: 20, color: textMuted),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // أيقونة الحذف (سطل) بدون خلفية
                      InkWell(
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _confirmDelete(debt);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Icon(Remix.delete_bin_line, size: 20, color: brandRed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Remix.wallet_3_line, size: 36, color: Color(0xFF71717A)),
          SizedBox(height: 12),
          Text(
            'لا توجد معاملات مسجلة في هذا التصفية',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: textWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'سجل سلفك ومبالغك المستلمة وديونك لمتابعة الأرصدة والمتبقي وطريقة الدفع بكل دقة',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF71717A),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
