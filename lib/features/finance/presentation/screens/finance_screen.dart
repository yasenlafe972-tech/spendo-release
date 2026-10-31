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
  String _selectedFilter = 'all'; // 'all', 'they_owe', 'i_owe', 'received', 'settled', 'bit', 'cash', 'bank', 'check'

  static const Color surfaceMain = Color(0xFF121413);
  static const Color surfaceField = Color(0xFF171A19);
  static const Color surfaceBorder = Color(0xFF242927);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static const Color brandRed = Color(0xFFEF4444);

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
    setState(() => _isLoading = true);
    final debts = await _financeRepo.getAllDebts();
    final people = await _peopleRepo.getAllPeople();
    if (!mounted) return;
    setState(() {
      _debts = debts;
      _peopleMap = {for (var p in people) p.id: p};
      _isLoading = false;
    });
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
            border: Border.all(color: brandGreen, width: 1.0),
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
              const Icon(Remix.checkbox_circle_line, color: brandYellow, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
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
      buffer.writeln('إشعار استلام مبلغ - Spendo');
      buffer.writeln('--------------------------------');
      buffer.writeln('الاسم: ${person?.name ?? "غير محدد"}');
      buffer.writeln('نوع المعاملة: استلام مبلغ (بدون إرجاع)');
      buffer.writeln('طريقة الاستلام: ${debt.paymentMethodTitle}');
      buffer.writeln('تاريخ الاستلام: ${ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate)}');
      buffer.writeln('المبلغ المستلم: ${debt.originalAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('الحالة: مستلم بالكامل (غير مسترد)');
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
    SpendoHaptics.light();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceMain,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder),
        ),
        title: const Text(
          'حذف المعاملة',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذا السجل المالي وسجل الدفعات المرتبطة به نهائياً؟',
          style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9CA3AF), fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF71717A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
        return brandGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0B),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandGreen, strokeWidth: 2))
            : RefreshIndicator(
                color: brandGreen,
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
                    _buildDashboardCards(),
                    const SizedBox(height: 14),

                    // 3. عنوان سجل المعاملات + زر تسجيل جديد
                    _buildSectionHeader(),
                    const SizedBox(height: 10),

                    // 4. فلاتر التصنيف المدمجة
                    _buildFilterBar(),
                    const SizedBox(height: 12),

                    // 5. قائمة بطاقات المعاملات
                    if (_filteredDebts.isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredDebts.map((debt) => _buildDebtCard(debt)),

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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaceBorder, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Remix.wallet_3_line, color: brandGreen, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'المالية والديون',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'متابعة السلف، الديون، والمقبوضات',
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

    final Color badgeColor = isBalanced ? brandGreen : (isPositive ? brandGreen : brandRed);

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
                  const Icon(Remix.scales_3_line, color: brandYellow, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'صافي الحسابات:',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFFD4D4D8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$netPrefix${_formatCurrency(absNet)} ',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
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
          const Divider(color: surfaceBorder, height: 1, thickness: 1),
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
                      children: const [
                        Icon(Remix.arrow_left_down_line, color: brandGreen, size: 14),
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
                        Text(
                          _formatCurrency(_totalTheyOweMe),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
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
                      children: const [
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
                        Text(
                          _formatCurrency(_totalIOweThem),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
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

              // مقبوضات (باللون الأصفر الدافئ)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Remix.checkbox_circle_line, color: brandYellow, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'مقبوضات',
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
                        Text(
                          '+${_formatCurrency(_totalReceived)}',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: brandYellow,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
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

  /// 3. عنوان سجل المعاملات + زر تسجيل جديد
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'سجل المعاملات',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: brandYellow.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${_filteredDebts.length}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: brandYellow,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _showAddDebtSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: brandGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Remix.add_line, size: 14, color: Color(0xFF0A0B0B)),
                SizedBox(width: 4),
                Text(
                  'تسجيل جديد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF0A0B0B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 4. فلاتر التصنيف المدمجة
  Widget _buildFilterBar() {
    final allCount = _debts.length;
    final theyOweCount = _debts.where((d) => d.isTheyOwe && !d.isSettled).length;
    final iOweCount = _debts.where((d) => d.isIOwe && !d.isSettled).length;
    final payLaterCount = _debts.where((d) => d.isPayLater && !d.isSettled).length;
    final receivedCount = _debts.where((d) => d.isReceived).length;
    final settledCount = _debts.where((d) => d.isSettled && !d.isReceived).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('all', 'الكل ($allCount)'),
          const SizedBox(width: 6),
          _buildFilterChip('they_owe', 'إلي عنده ($theyOweCount)', icon: Remix.arrow_left_down_line, iconColor: brandGreen),
          const SizedBox(width: 6),
          _buildFilterChip('i_owe', 'عليّ إله ($iOweCount)', icon: Remix.arrow_right_up_line, iconColor: brandRed),
          const SizedBox(width: 6),
          _buildFilterChip('pay_later', 'عالحساب ($payLaterCount)', icon: Remix.time_line, iconColor: brandYellow),
          const SizedBox(width: 6),
          _buildFilterChip('received', 'مقبوضات ($receivedCount)', icon: Remix.checkbox_circle_line, iconColor: brandGreen),
          const SizedBox(width: 6),
          _buildFilterChip('settled', 'المسددة ($settledCount)'),
          const SizedBox(width: 6),
          _buildFilterChip('bit', 'Bit', icon: Remix.smartphone_line, iconColor: brandYellow),
          const SizedBox(width: 6),
          _buildFilterChip('cash', 'كاش', icon: Remix.money_dollar_box_line, iconColor: brandGreen),
          const SizedBox(width: 6),
          _buildFilterChip('bank', 'تحويل بنكي', icon: Remix.bank_line, iconColor: brandYellow),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {IconData? icon, Color? iconColor}) {
    final isSelected = _selectedFilter == key;

    return InkWell(
      onTap: () {
        SpendoHaptics.selection();
        setState(() => _selectedFilter = key);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: surfaceField,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? brandGreen : surfaceBorder,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: iconColor ?? (isSelected ? Colors.white : const Color(0xFF9CA3AF))),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 5. بطاقة المعاملة (بدون أي دوائر أو مربعات خلفية)
  Widget _buildDebtCard(DebtModel debt) {
    final person = _peopleMap[debt.personId];
    final isTheyOwe = debt.isTheyOwe;
    final isSettled = debt.isSettled;
    final isReceived = debt.isReceived;

    String badgeText = 'إلي عنده';
    Color badgeColor = brandGreen;
    String amountPrefix = '';
    String subStatus = isSettled ? 'تم السداد' : 'بانتظار السداد';

    if (debt.isPayLater) {
      badgeText = 'عالحساب (مؤجل)';
      badgeColor = brandYellow;
      amountPrefix = '-';
      subStatus = isSettled ? 'تم الدفع' : 'للدفع لاحقاً';
    } else if (debt.isIOwe) {
      badgeText = 'عليّ إله';
      badgeColor = brandRed;
      amountPrefix = '-';
      subStatus = isSettled ? 'تم السداد' : 'مستحق الدفع';
    } else if (isReceived) {
      badgeText = 'مقبوضات';
      badgeColor = brandYellow;
      amountPrefix = '+';
      subStatus = 'غير مسترد';
    }

    final double displayAmount = isReceived ? debt.originalAmount : (isSettled ? debt.originalAmount : debt.remainingAmount);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الصف العلوي: الاسم والتفاصيل مقابل المبلغ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // يمين: اسم الشخص والتفاصيل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Remix.user_3_line, color: brandGreen, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            person?.name ?? 'شخص غير مسجل',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Remix.calendar_line, color: Color(0xFF71717A), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Color(0xFF52525B))),
                        Icon(
                          _getPaymentMethodIcon(debt.paymentMethod),
                          color: _getPaymentMethodColor(debt.paymentMethod),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          debt.paymentMethodTitle,
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
              ),

              // يسار: المبلغ وحالة الاسترداد
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$amountPrefix${_formatCurrency(displayAmount)} ',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: isReceived
                              ? brandYellow
                              : (isSettled ? brandGreen : (isTheyOwe ? brandYellow : brandRed)),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '₪',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: isReceived
                              ? brandYellow
                              : (isSettled ? brandGreen : (isTheyOwe ? brandYellow : brandRed)),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subStatus,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isSettled ? brandGreen : (debt.isIOwe ? brandRed : brandGreen),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ملاحظات إذا وجدت
          if (debt.notes != null && debt.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: surfaceMain,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: surfaceBorder),
              ),
              child: Row(
                children: [
                  const Icon(Remix.file_text_line, color: Color(0xFF71717A), size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      debt.notes!,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(color: surfaceBorder, height: 1, thickness: 1),
          const SizedBox(height: 6),

          // خط أزرار الإجراءات النظيفة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // زر تعديل
                  InkWell(
                    onTap: () => _showEditDebtSheet(debt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Remix.pencil_line, size: 12, color: brandYellow),
                          SizedBox(width: 4),
                          Text(
                            'تعديل',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFFD4D4D8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // زر واتساب
                  InkWell(
                    onTap: () => _shareDebtViaWhatsApp(debt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Remix.whatsapp_line, size: 12, color: brandGreen),
                          SizedBox(width: 4),
                          Text(
                            'واتساب',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFFD4D4D8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // زر سداد دفعة / تم الدفع إذا كان الدين فعالاً
                  if (!isSettled && !isReceived) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showRepaymentSheet(debt),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: surfaceMain,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: debt.isPayLater
                                ? brandYellow.withValues(alpha: 0.45)
                                : surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              debt.isPayLater ? Remix.checkbox_circle_line : Remix.cash_line,
                              size: 12,
                              color: debt.isPayLater ? brandYellow : brandGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              debt.isPayLater ? 'تم الدفع' : 'سداد دفعة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: debt.isPayLater ? brandYellow : brandGreen,
                                fontSize: 11,
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

              // زر الحذف بدون أي خلفية مربعة
              InkWell(
                onTap: () => _confirmDelete(debt),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Remix.delete_bin_6_line,
                    size: 16,
                    color: Color(0xFF71717A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Remix.wallet_3_line, size: 36, color: Color(0xFF71717A)),
          SizedBox(height: 12),
          Text(
            'لا توجد معاملات مسجلة في هذا التصفية',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'سجل سلفك ومقبوضاتك وديونك لمتابعة الأرصدة والمتبقي وطريقة الدفع بكل دقة',
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
