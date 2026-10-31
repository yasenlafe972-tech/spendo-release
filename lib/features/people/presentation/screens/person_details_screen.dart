import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/add_edit_person_sheet.dart';
import 'package:sanad_app/features/finance/models/debt_model.dart';
import 'package:sanad_app/features/finance/repositories/finance_repository.dart';
import 'package:sanad_app/features/finance/presentation/widgets/add_debt_sheet.dart';
import 'package:sanad_app/features/finance/presentation/widgets/record_repayment_sheet.dart';

/// Person Details Screen (`الملف المالي والشخصي للفرد`).
///
/// Strictly dedicated to Personal Finance, Debts, Loans, and Contact Management.
/// Work Shifts & Workshops belong exclusively to the Work section (`أماكن العمل والورشات`).
class PersonDetailsScreen extends StatefulWidget {
  final PersonModel person;

  const PersonDetailsScreen({super.key, required this.person});

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  final FinanceRepository _financeRepo = FinanceRepository();
  final PeopleRepository _peopleRepo = PeopleRepository();

  late PersonModel _person;
  List<DebtModel> _debts = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'they_owe', 'i_owe', 'unsettled'

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allPeople = await _peopleRepo.getAllPeople();
      final updated = allPeople.firstWhere(
        (p) => p.id == _person.id,
        orElse: () => _person,
      );
      final debts = await _financeRepo.getDebtsForPerson(_person.id);

      if (mounted) {
        setState(() {
          _person = updated;
          _debts = debts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Personal Finance Calculations
  double get _totalTheyOwe => FinanceRepository.calculateTotalTheyOwe(_debts);
  double get _totalIOwe => FinanceRepository.calculateTotalIOwe(_debts);
  double get _netDebtBalance => FinanceRepository.calculateNetDebtBalance(_debts);

  List<DebtModel> get _filteredDebts {
    switch (_selectedFilter) {
      case 'they_owe':
        return _debts.where((d) => d.isTheyOwe).toList();
      case 'i_owe':
        return _debts.where((d) => d.isIOwe).toList();
      case 'unsettled':
        return _debts.where((d) => !d.isSettled).toList();
      default:
        return _debts;
    }
  }

  String _buildPersonalStatementText() {
    final buffer = StringBuffer();
    buffer.writeln('كشف حساب السلف والديون الشخصية - Spendo');
    buffer.writeln('--------------------------------');
    buffer.writeln('الشخص: ${_person.name}');
    if (_person.phone != null && _person.phone!.isNotEmpty) {
      buffer.writeln('الهاتف: ${_person.phone}');
    }
    buffer.writeln('أخذ مني (سلفة لي عليه): ${_totalTheyOwe.toStringAsFixed(1)} ₪');
    buffer.writeln('أخذت منه (دين علي له): ${_totalIOwe.toStringAsFixed(1)} ₪');
    if (_netDebtBalance > 0) {
      buffer.writeln('صافي الحساب: باقي لك عنده ${_netDebtBalance.toStringAsFixed(1)} ₪');
    } else if (_netDebtBalance < 0) {
      buffer.writeln('صافي الحساب: باقي له عندك ${_netDebtBalance.abs().toStringAsFixed(1)} ₪');
    } else {
      buffer.writeln('صافي الحساب: الحسابات متوازنة تماماً (0 ₪)');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('سجل السلف والمعاملات المالية:');
    for (int i = 0; i < _debts.length; i++) {
      final d = _debts[i];
      final dayStr = ArabicDateHelper.formatArabicDateWithWeekdayFromString(d.transactionDate);
      buffer.writeln(
        '${i + 1}. ${d.typeTitle} | ${d.paymentMethodTitle} | $dayStr\n'
        '   أصل المبلغ: ${d.originalAmount.toStringAsFixed(0)} ₪ | مسدد: ${d.paidAmount.toStringAsFixed(0)} ₪ | متبقي: ${d.remainingAmount.toStringAsFixed(0)} ₪',
      );
    }
    buffer.writeln('\nتم التوثيق عبر تطبيق Spendo');
    return buffer.toString();
  }

  void _sharePersonalStatement() async {
    final statementText = _buildPersonalStatementText();
    if (_person.whatsapp != null && _person.whatsapp!.isNotEmpty) {
      final cleanPhone = _person.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
      final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(statementText)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    SharePlus.instance.share(
      ShareParams(
        text: statementText,
        subject: 'كشف حساب مالي - ${_person.name}',
      ),
    );
  }

  void _copyPersonalStatement() {
    Clipboard.setData(ClipboardData(text: _buildPersonalStatementText()));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.spendoGreen, size: 20),
            SizedBox(width: 8),
            Text('تم نسخ كشف الحساب المالي للحافظة', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _shareSingleDebt(DebtModel debt) async {
    final buffer = StringBuffer();
    if (debt.isReceived) {
      buffer.writeln('إشعار استلام مبلغ - Spendo');
      buffer.writeln('--------------------------------');
      buffer.writeln('الاسم: ${_person.name}');
      buffer.writeln('نوع المعاملة: استلام مبلغ (بدون إرجاع)');
      buffer.writeln('طريقة الاستلام: ${debt.paymentMethodTitle}');
      buffer.writeln('تاريخ الاستلام: ${ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate)}');
      buffer.writeln('المبلغ المستلم: ${debt.originalAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('الحالة: مستلم بالكامل (غير مسترد)');
      if (debt.notes != null && debt.notes!.isNotEmpty) buffer.writeln('ملاحظات: ${debt.notes}');
      buffer.writeln('\nتم التوثيق عبر تطبيق Spendo');
    } else {
      buffer.writeln('تذكير سلفة مالية - Spendo');
      buffer.writeln('--------------------------------');
      buffer.writeln('الاسم: ${_person.name}');
      buffer.writeln('نوع المعاملة: ${debt.typeTitle}');
      buffer.writeln('وسيلة الدفع: ${debt.paymentMethodTitle}');
      buffer.writeln('تاريخ السلفة: ${ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate)}');
      buffer.writeln('المبلغ الأصلي: ${debt.originalAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('المسدد حتى الآن: ${debt.paidAmount.toStringAsFixed(1)} ₪');
      buffer.writeln('المبلغ المتبقي: ${debt.remainingAmount.toStringAsFixed(1)} ₪');
      if (debt.dueDate != null) buffer.writeln('موعد السداد: ${debt.dueDate}');
      if (debt.notes != null && debt.notes!.isNotEmpty) buffer.writeln('ملاحظات: ${debt.notes}');
      buffer.writeln('\nتم التوثيق عبر تطبيق Spendo');
    }

    final text = buffer.toString();
    if (_person.whatsapp != null && _person.whatsapp!.isNotEmpty) {
      final cleanPhone = _person.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
      final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'تذكير سلفة - ${_person.name}',
      ),
    );
  }

  Future<void> _addNewDebt() async {
    final allPeople = await _peopleRepo.getAllPeople();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => AddDebtSheet(
        people: allPeople,
        initialPersonId: _person.id,
        onSave: (debt) async {
          await _financeRepo.addDebt(debt);
          _loadData();
        },
      ),
    );
  }

  Future<void> _recordRepayment(DebtModel debt) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => RecordRepaymentSheet(
        debt: debt,
        person: _person,
        onConfirm: (payment) async {
          await _financeRepo.recordDebtRepayment(payment: payment, parentDebt: debt);
          _loadData();
        },
      ),
    );
  }

  Future<void> _editPerson() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => AddEditPersonSheet(
        person: _person,
        onSave: (updated) async {
          await _peopleRepo.updatePerson(updated);
          _loadData();
        },
      ),
    );
  }

  Future<void> _confirmDeletePerson() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف جهة الاتصال', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'هل أنت متأكد من حذف "${_person.name}" من قائمة الأشخاص؟ ستبقى المعاملات المالية السابقة محفوظة في الأرشيف.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _peopleRepo.deletePerson(_person.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _deleteDebt(DebtModel debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف السلفة / الدين', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'هل تريد حذف هذه السلفة بمبلغ ${debt.originalAmount.toStringAsFixed(0)} ₪؟',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _financeRepo.deleteDebt(debt.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          _person.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.spendoGreen),
            tooltip: 'مشاركة كشف الحساب المالي',
            onPressed: _sharePersonalStatement,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.iconMuted),
            tooltip: 'نسخ كشف الحساب',
            onPressed: _copyPersonalStatement,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.spendoGreen))
          : RefreshIndicator(
              color: AppColors.spendoGreen,
              backgroundColor: AppColors.surfaceElevated,
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Profile Header Card
                  _buildProfileHeaderCard(),

                  const SizedBox(height: 14),

                  // 2. Personal Finance Ledger Summary
                  _buildFinancialLedgerCard(),

                  const SizedBox(height: 14),

                  // 3. Primary Action: Add New Debt/Loan with this Person
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.spendoGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_card, size: 20),
                    label: const Text(
                      'تسجيل سلفة / دين جديد لهذا الشخص',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    onPressed: _addNewDebt,
                  ),

                  const SizedBox(height: 18),

                  // 4. Section Title & Filter Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'سجل السلف والديون (${_debts.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_debts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'المعاملات: ${_filteredDebts.length}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Filter Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'الكل (${_debts.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('they_owe', 'أخذ مني'),
                        const SizedBox(width: 8),
                        _buildFilterChip('i_owe', 'أخذت منه'),
                        const SizedBox(width: 8),
                        _buildFilterChip('unsettled', 'غير مسدد'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Debts List
                  if (_filteredDebts.isEmpty)
                    _buildEmptyState(
                      _debts.isEmpty
                          ? 'لا توجد سلف أو ديون مسجلة لهذا الشخص بعد'
                          : 'لا توجد معاملات تطابق الفلتر المحدد',
                    )
                  else
                    ..._filteredDebts.map(_buildDebtCard),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final p = _person;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceCardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.avatarBackground,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  p.initials,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.isUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.spendoGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'حسابي الشخصي',
                              style: TextStyle(
                                color: AppColors.spendoGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (p.formattedBirthdateAndAge != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.formattedBirthdateAndAge!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    if (p.phone != null && p.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.phone!,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (!p.isUser) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                  tooltip: 'تعديل البيانات',
                  onPressed: _editPerson,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 20),
                  tooltip: 'حذف',
                  onPressed: _confirmDeletePerson,
                ),
              ],
            ],
          ),
          if (p.phone != null && p.phone!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSmallActionButton(Icons.phone, 'اتصال', () {
                    launchUrl(Uri.parse('tel:${p.phone}'));
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSmallActionButton(Icons.chat, 'واتساب', () {
                    final number = (p.whatsapp ?? p.phone)!.replaceAll(RegExp(r'[^\d+]'), '');
                    launchUrl(Uri.parse('https://wa.me/$number'), mode: LaunchMode.externalApplication);
                  }, color: AppColors.whatsappGreen),
                ),
                if (p.nationalId != null && p.nationalId!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSmallActionButton(Icons.copy, 'نسخ الهوية', () {
                      Clipboard.setData(ClipboardData(text: p.nationalId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رقم الهوية')),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialLedgerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ملخص السلف والديون الشخصية',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_debts.length} سلفة / دين',
                  style: const TextStyle(color: AppColors.spendoGreen, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricBox('أخذ مني (لي)', '${_totalTheyOwe.toStringAsFixed(0)} ₪', AppColors.spendoGreen),
              const SizedBox(width: 8),
              _buildMetricBox('أخذت منه (علي)', '${_totalIOwe.toStringAsFixed(0)} ₪', AppColors.dangerRed),
              const SizedBox(width: 8),
              _buildMetricBox(
                'الصافي',
                '${_netDebtBalance.abs().toStringAsFixed(0)} ₪',
                _netDebtBalance >= 0 ? AppColors.spendoGreen : AppColors.dangerRed,
                subtext: _netDebtBalance > 0
                    ? 'لك عنده'
                    : (_netDebtBalance < 0 ? 'له عندك' : 'متوازن'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.spendoGreen : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.spendoGreen : AppColors.surfaceCardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDebtCard(DebtModel debt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: debt.isSettled
              ? AppColors.surfaceCardBorder
              : (debt.isTheyOwe
                  ? AppColors.spendoGreen.withValues(alpha: 0.3)
                  : (debt.isReceived
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                      : AppColors.dangerRed.withValues(alpha: 0.3))),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: debt.isReceived
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                      : (debt.isTheyOwe
                          ? AppColors.spendoGreen.withValues(alpha: 0.15)
                          : AppColors.dangerRed.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  debt.isReceived
                      ? Icons.check_circle_outline
                      : (debt.isTheyOwe ? Icons.arrow_outward : Icons.arrow_downward),
                  color: debt.isReceived
                      ? const Color(0xFF38BDF8)
                      : (debt.isTheyOwe ? AppColors.spendoGreen : AppColors.dangerRed),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.typeTitle,
                      style: TextStyle(
                        color: debt.isReceived
                            ? const Color(0xFF38BDF8)
                            : (debt.isTheyOwe ? AppColors.spendoGreen : AppColors.dangerRed),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            debt.paymentMethodTitle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ArabicDateHelper.formatArabicDateWithWeekdayFromString(debt.transactionDate),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${debt.originalAmount.toStringAsFixed(0)} ₪',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    debt.isReceived
                        ? 'مستلم بدون إرجاع'
                        : (debt.isSettled ? 'مسدد بالكامل' : 'من أصل ${debt.originalAmount.toStringAsFixed(0)} ₪'),
                    style: TextStyle(
                      color: debt.isReceived ? const Color(0xFF38BDF8) : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: debt.isReceived ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: debt.progress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                debt.isSettled ? AppColors.spendoGreen : AppColors.spendoGreen,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Actions Row: Repayment button, WhatsApp share, Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                debt.isReceived
                    ? 'مستلم بالكامل (غير مسترد)'
                    : (debt.isSettled
                        ? 'مسدد بالكامل'
                        : 'سُدد: ${debt.paidAmount.toStringAsFixed(0)} ₪ • متبقي: ${debt.remainingAmount.toStringAsFixed(0)} ₪'),
                style: TextStyle(
                  color: debt.isReceived
                      ? const Color(0xFF38BDF8)
                      : (debt.isSettled ? AppColors.spendoGreen : AppColors.textSecondary),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _shareSingleDebt(debt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.share_outlined, color: AppColors.whatsappGreen, size: 16),
                    ),
                  ),
                  if (!debt.isSettled) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _recordRepayment(debt),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.spendoGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'سداد دفعة',
                          style: TextStyle(
                            color: AppColors.spendoGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _deleteDebt(debt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String title, String value, Color color, {String? subtext}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceCardBorder),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            if (subtext != null) ...[
              const SizedBox(height: 2),
              Text(subtext, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceCardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color ?? AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
    );
  }
}
