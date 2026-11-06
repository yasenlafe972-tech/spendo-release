import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';
import '../../../work_logs/models/work_log_model.dart';
import '../../../work_logs/repositories/work_logs_repository.dart';
import '../../../work_logs/presentation/widgets/add_work_log_sheet.dart';
import '../../../vehicle/models/vehicle_model.dart';
import '../../../vehicle/presentation/widgets/fuel_expense_sheet.dart';
import '../../../settings/presentation/screens/app_settings_screen.dart';
import '../../models/daily_expense_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/firebase_backup_service.dart';

/// Spendo Central Executive Dashboard.
class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PeopleRepository _peopleRepo = PeopleRepository();
  final WorkLogsRepository _workLogsRepo = WorkLogsRepository();

  bool _isLoading = true;
  PersonModel? _userProfile;
  List<WorkLogModel> _allWorkLogs = [];
  List<VehicleExpenseRecord> _allFuelRecords = [];
  List<VehicleExpenseRecord> _allMaintenanceRecords = [];
  List<DailyExpenseModel> _allDailyExpenses = [];
  bool _showAllTimelineItems = false;

  // Filter state
  late String _selectedMonthKey; // e.g. '2026-10' or 'all'
  String _selectedLogsFilter = 'all'; // 'all', 'food', 'shopping', 'fuel'

  // Design tokens (Revolut 10 eye-friendly FinTech palette)
  static const Color surfaceMain = Color(0xFF0A0A0C);
  static const Color surfaceField = Color(0xFF121215);
  static const Color surfaceElevated = Color(0xFF16161A);
  static const Color surfaceBorder = Color(0xFF1E1E24);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color brandYellow = Color(0xFFF59E0B);
  static const Color brandRed = Color(0xFFEF4444);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF71717A);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    DailyExpenseService.expensesChangedNotifier.addListener(_onAutoExpensesUpdated);
    DatabaseHelper.dataVersionNotifier.addListener(_onAutoExpensesUpdated);
    DailyExpenseService.initAutoSyncListener();
    _loadData();
  }

  @override
  void dispose() {
    DailyExpenseService.expensesChangedNotifier.removeListener(_onAutoExpensesUpdated);
    DatabaseHelper.dataVersionNotifier.removeListener(_onAutoExpensesUpdated);
    super.dispose();
  }

  void _onAutoExpensesUpdated() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      // سحب أي دفعات Apple Pay جديدة وصلت بالخلفية عبر السحابة
      DailyExpenseService.pullCloudAutoExpenses();
      // مزامنة سحابية ثنائية تلقائية
      FirebaseBackupService.instance.syncWithCloud(isSilent: true);

      final peopleFuture = _peopleRepo.getAllPeople();
      final logsFuture = _workLogsRepo.getAllLogs();
      final expensesFuture = DailyExpenseService.getAllExpenses();

      // Load vehicle state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final rawVehicle = prefs.getString(FuelExpenseSheet.storageKey);
      List<VehicleExpenseRecord> fuelRecords = [];
      List<VehicleExpenseRecord> maintenanceRecords = [];
      if (rawVehicle != null && rawVehicle.isNotEmpty) {
        try {
          final state = VehicleDataState.fromJson(rawVehicle);
          final rawCount = (jsonDecode(rawVehicle)['history'] as List?)?.length ?? 0;
          if (state.history.length < rawCount) {
            await prefs.setString(FuelExpenseSheet.storageKey, state.toJson());
          }
          fuelRecords = state.history
              .where((e) => e.category == ExpenseCategory.fuel)
              .toList();
          maintenanceRecords = state.history
              .where((e) => e.category == ExpenseCategory.maintenance)
              .toList();
        } catch (_) {}
      }

      final results = await Future.wait([peopleFuture, logsFuture, expensesFuture]);
      if (!mounted) return;

      final people = results[0] as List<PersonModel>;
      final logs = results[1] as List<WorkLogModel>;
      final expenses = results[2] as List<DailyExpenseModel>;

      PersonModel? user;
      for (final p in people) {
        if (p.isUser) {
          user = p;
          break;
        }
      }

      if (user != null && (user.name == 'My profile' || user.name.trim().isEmpty)) {
        user = user.copyWith(name: 'لافي');
        _peopleRepo.updatePerson(user);
      }

      setState(() {
        _userProfile = user;
        _allWorkLogs = logs;
        _allFuelRecords = fuelRecords;
        _allMaintenanceRecords = maintenanceRecords;
        _allDailyExpenses = expenses;
        _isLoading = false;

        // If selected month has no records but records exist in other periods,
        // automatically switch to 'all' (كافة الفترات) so the user immediately sees all work logs & totals!
        if (_filteredWorkLogs.isEmpty && _filteredDailyExpenses.isEmpty && _filteredFuelRecords.isEmpty && _allWorkLogs.isNotEmpty) {
          _selectedMonthKey = 'all';
        }
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Currency number formatting with thousands separator (preserves decimals if present)
  String _formatAmount(num val) {
    if (val % 1 == 0) {
      final intVal = val.toInt();
      final s = intVal.abs().toString();
      final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
      final formatted = s.replaceAllMapped(reg, (match) => ',');
      return intVal < 0 ? '-$formatted' : formatted;
    } else {
      final fixed = val.abs().toStringAsFixed(2);
      final parts = fixed.split('.');
      final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
      final formattedInt = parts[0].replaceAllMapped(reg, (match) => ',');
      final result = '$formattedInt.${parts[1]}';
      return val < 0 ? '-$result' : result;
    }
  }

  // Monthly filtered lists
  List<WorkLogModel> get _filteredWorkLogs {
    if (_selectedMonthKey == 'all') return _allWorkLogs;
    return _allWorkLogs.where((l) {
      try {
        final d = DateTime.parse(l.date);
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        return key == _selectedMonthKey;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List<VehicleExpenseRecord> get _filteredFuelRecords {
    if (_selectedMonthKey == 'all') return _allFuelRecords;
    return _allFuelRecords.where((f) {
      final key = '${f.date.year}-${f.date.month.toString().padLeft(2, '0')}';
      return key == _selectedMonthKey;
    }).toList();
  }

  List<VehicleExpenseRecord> get _filteredMaintenanceRecords {
    if (_selectedMonthKey == 'all') return _allMaintenanceRecords;
    return _allMaintenanceRecords.where((m) {
      final key = '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
      return key == _selectedMonthKey;
    }).toList();
  }

  List<DailyExpenseModel> get _filteredDailyExpenses {
    if (_selectedMonthKey == 'all') return _allDailyExpenses;
    return _allDailyExpenses.where((e) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      return key == _selectedMonthKey;
    }).toList();
  }

  // Calculations
  double get _totalWorkIncome {
    return _filteredWorkLogs.fold(0.0, (sum, l) => sum + l.totalEarned);
  }

  double get _totalFoodExpense {
    return _filteredDailyExpenses
        .where((e) => e.category == 'food')
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get _totalShoppingExpense {
    final daily = _filteredDailyExpenses
        .where((e) => e.category == 'shopping')
        .fold(0.0, (sum, e) => sum + e.amount);
    final vehicleStore = _filteredMaintenanceRecords
        .where((m) =>
            (m.notes?.contains('مشتريات') == true ||
                m.title.contains('Yellow') ||
                m.provider?.contains('Yellow') == true) &&
            !_filteredDailyExpenses.any((d) =>
                d.amount == m.amount &&
                d.date.year == m.date.year &&
                d.date.month == m.date.month &&
                d.date.day == m.date.day))
        .fold(0.0, (sum, m) => sum + m.amount);
    return daily + vehicleStore;
  }

  double get _totalFuelExpense {
    final vehicleFuel = _filteredFuelRecords.fold(0.0, (sum, f) => sum + f.amount);
    final cardFuel = _filteredDailyExpenses
        .where((e) => e.category == 'fuel')
        .fold(0.0, (sum, e) => sum + e.amount);
    return vehicleFuel + cardFuel;
  }

  double get _totalMaintenanceExpense => _filteredMaintenanceRecords
      .where((m) =>
          !(m.notes?.contains('مشتريات') == true ||
              m.title.contains('Yellow') ||
              m.provider?.contains('Yellow') == true))
      .fold(0.0, (sum, m) => sum + m.amount);

  double get _totalAllExpenses =>
      _totalFoodExpense + _totalShoppingExpense + _totalFuelExpense + _totalMaintenanceExpense;

  double get _netMonthlyIncome => _totalWorkIncome - _totalAllExpenses;

  String _getMonthLabel() {
    if (_selectedMonthKey == 'all') return 'كافة الفترات';
    try {
      final parts = _selectedMonthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final monthName = ArabicDateHelper.arabicMonths[month] ?? parts[1];
      return '$monthName $year';
    } catch (_) {
      return _selectedMonthKey;
    }
  }

  void _showMonthPickerSheet() {
    SpendoHaptics.light();
    final now = DateTime.now();
    final List<String> months = [];

    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      months.add(key);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.75;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(ctx).viewPadding.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const Text(
                      'اختر فترة العرض',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      tileColor: _selectedMonthKey == 'all'
                          ? brandGreen.withValues(alpha: 0.15)
                          : surfaceField,
                      title: const Text('كافة الفترات',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      trailing: _selectedMonthKey == 'all'
                          ? const Icon(Remix.check_line, color: brandGreen, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedMonthKey = 'all');
                      },
                    ),
                    const SizedBox(height: 6),
                    ...months.map((key) {
                      final parts = key.split('-');
                      final y = int.parse(parts[0]);
                      final m = int.parse(parts[1]);
                      final label = '${ArabicDateHelper.arabicMonths[m]} $y';
                      final isSelected = _selectedMonthKey == key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          tileColor: isSelected
                              ? brandGreen.withValues(alpha: 0.15)
                              : surfaceField,
                          title: Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          trailing: isSelected
                              ? const Icon(Remix.check_line,
                                  color: brandGreen, size: 18)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedMonthKey = key);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build unified chronological expense timeline (Food / Shopping / Fuel ONLY - No Work Logs)
  List<_TimelineItem> _getTimelineItems() {
    final List<_TimelineItem> items = [];

    for (final e in _filteredDailyExpenses) {
      if (_selectedLogsFilter != 'all' && _selectedLogsFilter != e.category) {
        continue;
      }
      items.add(_TimelineItem(
        category: e.category,
        date: e.date,
        title: e.merchantName,
        subtitle:
            '${ArabicDateHelper.getRelativeDayDescription(e.date)} • ${e.sourceTitle} • ${e.categoryTitle}',
        amount: e.amount,
        dailyExpense: e,
      ));
    }

    if (_selectedLogsFilter == 'all' || _selectedLogsFilter == 'fuel') {
      for (final f in _filteredFuelRecords) {
        final invTag = (f.invoiceNumber != null && f.invoiceNumber!.isNotEmpty)
            ? ' • #${f.invoiceNumber}'
            : '';
        items.add(_TimelineItem(
          category: 'fuel',
          date: f.date,
          title: f.title.isNotEmpty ? f.title : 'تعبئة وقود • Yellow פז',
          subtitle:
              '${ArabicDateHelper.getRelativeDayDescription(f.date)} • وقود المركبة$invTag',
          amount: f.amount,
          fuelRecord: f,
        ));
      }
    }

    // Vehicle maintenance / Yellow store records
    for (final m in _filteredMaintenanceRecords) {
      final isStore = m.notes?.contains('مشتريات') == true ||
          m.title.contains('Yellow') ||
          m.provider?.contains('Yellow') == true;
      final categoryKey = isStore ? 'shopping' : 'maintenance';

      // Avoid duplicate display if it's already in _filteredDailyExpenses
      final alreadyInDaily = _filteredDailyExpenses.any((d) =>
          d.amount == m.amount &&
          d.date.year == m.date.year &&
          d.date.month == m.date.month &&
          d.date.day == m.date.day &&
          d.date.hour == m.date.hour &&
          d.date.minute == m.date.minute);
      if (alreadyInDaily) continue;

      if (_selectedLogsFilter != 'all' && _selectedLogsFilter != categoryKey) {
        continue;
      }
      final invTag = (m.invoiceNumber != null && m.invoiceNumber!.isNotEmpty)
          ? ' • #${m.invoiceNumber}'
          : '';
      items.add(_TimelineItem(
        category: categoryKey,
        date: m.date,
        title: m.title.isNotEmpty ? m.title : (isStore ? 'Yellow חנות נוחות' : 'صيانة مركبة'),
        subtitle: isStore
            ? '${ArabicDateHelper.getRelativeDayDescription(m.date)} • مشتريات Yellow$invTag'
            : '${ArabicDateHelper.getRelativeDayDescription(m.date)} • صيانة المركبة$invTag',
        amount: m.amount,
        fuelRecord: m,
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final userName = (_userProfile?.name.trim().isNotEmpty == true &&
            _userProfile!.name.trim() != 'My profile')
        ? _userProfile!.name.trim()
        : 'لافي';

    return Scaffold(
      backgroundColor: surfaceMain,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: brandGreen,
                  strokeWidth: 2,
                ),
              )
            : RefreshIndicator(
                color: Colors.white,
                backgroundColor: surfaceField,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // مؤشر السحب العلوي الهادئ
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

                      // الترويسة العلوية
                      _buildHeader(userName),
                      const SizedBox(height: 12),

                      // 1. بطاقة الملخص المالي الرئيسي (صافي الدخل الشهري)
                      _buildMainSummaryCard(),
                      const SizedBox(height: 10),

                      // 2. بطاقتين مدمجتين للمصاريف (أكل + مشتريات) - بدون أيام عمل ومعدل يومية ومقبوض
                      _buildExpenseCategoriesRow(),
                      const SizedBox(height: 12),

                      // 3. أزرار الإجراءات السريعة (تسجيل يوم عمل + تسجيل دفعة Apple Pay / כאל)
                      _buildQuickActionButtons(),
                      const SizedBox(height: 12),

                      // 4. سجل آخر السجلات (الكل | أكل | مشتريات | وقود)
                      _buildRecentTransactionsSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // الترويسة العلوية مع زر اختيار الشهر وزر الإعدادات الموحد
  Widget _buildHeader(String userName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Remix.dashboard_line, color: brandGreen, size: 18),
                SizedBox(width: 6),
                Text(
                  'لوحة التحكم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'أهلاً $userName • ملخص العمل والمصاريف',
              style: const TextStyle(
                fontSize: 11,
                color: textMuted,
              ),
            ),
          ],
        ),

        Row(
          children: [
            GestureDetector(
              onTap: _showMonthPickerSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: surfaceField,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Remix.calendar_2_line,
                        size: 11.5, color: brandYellow),
                    const SizedBox(width: 5),
                    Text(
                      _getMonthLabel(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Remix.arrow_down_s_line,
                        size: 13, color: textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Remix.settings_4_line,
                  color: textWhite, size: 18),
              tooltip: 'الإعدادات',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () async {
                SpendoHaptics.light();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                );
                _loadData();
              },
            ),
          ],
        ),
      ],
    );
  }

  // 1. بطاقة الملخص المالي الرئيسي (تصميم هادئ ومريح للعين)
  Widget _buildMainSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Remix.wallet_3_line, size: 14, color: brandGreen),
                  SizedBox(width: 6),
                  Text(
                    'صافي الدخل الشهري',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'محدث اليوم',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: brandGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatAmount(_netMonthlyIncome),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
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
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: surfaceBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: surfaceBorder.withValues(alpha: 0.6)),
                        ),
                        child: const Icon(Remix.arrow_up_circle_line,
                            size: 15, color: brandGreen),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إجمالي العمل',
                            style: TextStyle(fontSize: 10, color: textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatAmount(_totalWorkIncome)} ₪',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 28,
                  color: surfaceBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: surfaceBorder.withValues(alpha: 0.6)),
                        ),
                        child: const Icon(Remix.bank_card_line,
                            size: 15, color: brandYellow),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المصاريف والوقود',
                            style: TextStyle(fontSize: 10, color: textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatAmount(_totalAllExpenses)} ₪',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
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
        ],
      ),
    );
  }

  // 2. استغلال المساحة لملخص الأكل والمشتريات
  Widget _buildExpenseCategoriesRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              SpendoHaptics.selection();
              setState(() => _selectedLogsFilter =
                  _selectedLogsFilter == 'food' ? 'all' : 'food');
            },
            borderRadius: BorderRadius.circular(14),
            child: _buildStatCard(
              title: 'مصاريف الأكل',
              value: '${_formatAmount(_totalFoodExpense)} ₪',
              icon: Remix.restaurant_2_line,
              iconColor: brandYellow,
              isHighlighted: _selectedLogsFilter == 'food',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () {
              SpendoHaptics.selection();
              setState(() => _selectedLogsFilter =
                  _selectedLogsFilter == 'shopping' ? 'all' : 'shopping');
            },
            borderRadius: BorderRadius.circular(14),
            child: _buildStatCard(
              title: 'المشتريات العامة',
              value: '${_formatAmount(_totalShoppingExpense)} ₪',
              icon: Remix.shopping_bag_3_line,
              iconColor: brandGreen,
              isHighlighted: _selectedLogsFilter == 'shopping',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isHighlighted = false,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? surfaceElevated : surfaceField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? iconColor.withValues(alpha: 0.6) : surfaceBorder,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: textMuted,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: surfaceMain,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: surfaceBorder.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ],
      ),
    );
  }

  // 3. أزرار الإجراءات السريعة (تصميم مريح مع زوايا ناعمة)
  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        // زر تسجيل يوم عمل (أخضر زمردي هادئ)
        Expanded(
          child: Material(
            color: brandGreen,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                SpendoHaptics.light();
                final res = await AddWorkLogSheet.show(context);
                if (res != null) {
                  _loadData();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Remix.briefcase_4_line,
                        size: 16, color: Colors.white),
                    SizedBox(width: 7),
                    Text(
                      'تسجيل يوم عمل',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // زر تعبئة وقود (رمادي داكن ناعم بحواف محددة)
        Expanded(
          child: Material(
            color: surfaceField,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                SpendoHaptics.light();
                FuelExpenseSheet.show(
                  context,
                  onSaved: _loadData,
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: surfaceBorder),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Remix.gas_station_line,
                        size: 16, color: brandYellow),
                    SizedBox(width: 7),
                    Text(
                      'تعبئة وقود',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 4. سجل آخر السجلات مع فلترة واستقبال تلقائي
  Widget _buildRecentTransactionsSection() {
    final timelineItems = _getTimelineItems();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Remix.history_line, size: 15, color: brandGreen),
                  const SizedBox(width: 5),
                  const Text(
                    'آخر السجلات',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _showAutoApplePaySetupSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Remix.apple_line, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'تلقائي',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // الفلاتر المطلوبة: الكل | أكل | مشتريات | وقود
              Row(
                children: [
                  _buildFilterChip('all', 'الكل'),
                  const SizedBox(width: 3),
                  _buildFilterChip('food', 'أكل'),
                  const SizedBox(width: 3),
                  _buildFilterChip('shopping', 'مشتريات'),
                  const SizedBox(width: 3),
                  _buildFilterChip('fuel', 'وقود'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: surfaceBorder, height: 1),

          if (timelineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Column(
                  children: [
                    Icon(Remix.bank_card_2_line,
                        size: 24, color: textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    const Text(
                      'لا توجد دفعات مسجلة في هذا التصنيف',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'اضغط على أي سجل لتحديد صنف المحل (أكل / مشتريات / وقود) وسيحفظه التطبيق تلقائياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: textMuted),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Builder(builder: (context) {
              final displayList = _showAllTimelineItems
                  ? timelineItems
                  : timelineItems.take(10).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder: (_, __) =>
                    Divider(color: surfaceBorder.withValues(alpha: 0.4), height: 1),
                itemBuilder: (context, index) {
                  final item = displayList[index];
                  final IconData itemIcon;
                  final Color itemColor;

                  if (item.category == 'food') {
                    itemIcon = Remix.restaurant_2_line;
                    itemColor = brandYellow;
                  } else if (item.category == 'fuel') {
                    itemIcon = Remix.gas_station_line;
                    itemColor = brandYellow;
                  } else if (item.category == 'maintenance') {
                    itemIcon = Remix.tools_line;
                    itemColor = const Color(0xFF60A5FA);
                  } else {
                    itemIcon = Remix.shopping_bag_3_line;
                    itemColor = brandGreen;
                  }

                  return InkWell(
                    onTap: () {
                      SpendoHaptics.light();
                      if (item.dailyExpense != null) {
                        _showMerchantCategorySheet(item.dailyExpense!);
                      } else if (item.fuelRecord != null) {
                        _showFuelDetailsModal(item.fuelRecord!);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: surfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: surfaceBorder.withValues(alpha: 0.6)),
                                  ),
                                  child: Icon(
                                    itemIcon,
                                    size: 16,
                                    color: itemColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '-${_formatAmount(item.amount)} ₪',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: itemColor,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Remix.equalizer_line,
                                size: 12,
                                color: textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
            if (timelineItems.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () {
                    SpendoHaptics.selection();
                    setState(() => _showAllTimelineItems = !_showAllTimelineItems);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showAllTimelineItems
                            ? 'إظهار أقل'
                            : 'عرض كافة السجلات (${timelineItems.length})',
                          style: const TextStyle(
                            color: brandGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showAllTimelineItems
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: brandGreen,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedLogsFilter == key;
    return GestureDetector(
      onTap: () {
        SpendoHaptics.selection();
        setState(() => _selectedLogsFilter = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? brandGreen : surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? brandGreen : surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : textMuted,
          ),
        ),
      ),
    );
  }

  /// نافذة إعداد الربط التلقائي مع Apple Pay Shortcuts (بدون تدخل يدوي وبدون تحديد البطاقة)
  void _showAutoApplePaySetupSheet() {
    SpendoHaptics.light();
    const directUrlTemplate = DailyExpenseService.shortcutDeepLinkTemplate;
    const cloudWebhookUrl = DailyExpenseService.cloudWebhookUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: surfaceBorder,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Remix.apple_line, color: Colors.white, size: 19),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الربط التلقائي مع Apple Pay (Shortcuts)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'يسجل الدفعة تلقائياً من أي بطاقة في المحفظة بدون تدخلك',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Remix.close_line,
                            color: textMuted, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: surfaceBorder, height: 1),
                  const SizedBox(height: 10),

                  // شرح مبسط لطريقة العمل
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كيف يعمل تلقائياً مع كل كروتك؟',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: brandGreen,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '1. في تطبيق Shortcuts بالآيفون: اختر Automation ثم Transaction وحدد جميع بطاقاتك دفعة واحدة.\n'
                          '2. يرسل الاختصار (المبلغ + اسم المحل) للتطبيق مباشرة دون الحاجة لتحديد نوع الكرت.\n'
                          '3. يتعرف التطبيق على صنف المحل (أكل / مشتريات / وقود) تلقائياً حسب الاسم المحفوظ.',
                          style: TextStyle(
                            fontSize: 10,
                            color: textWhite,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // نسخ الرابط المباشر للاختصار
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: surfaceBorder),
                            backgroundColor: surfaceField,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(
                                const ClipboardData(text: directUrlTemplate));
                            SpendoHaptics.success();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'تم نسخ رابط الاختصار المباشر (spendo://pay)'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Remix.links_line,
                              size: 14, color: brandGreen),
                          label: const Text(
                            'نسخ رابط الاختصار المباشر',
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: surfaceBorder),
                            backgroundColor: surfaceField,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(
                                const ClipboardData(text: cloudWebhookUrl));
                            SpendoHaptics.success();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'تم نسخ رابط الإرسال الصامت بالخلفية (Webhook)'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Remix.cloud_line,
                              size: 14, color: brandYellow),
                          label: const Text(
                            'نسخ رابط الخلفية الصامت',
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // تجربة سريعة لوصول دفعة Apple Pay تلقائية
                  const Text(
                    'تجربة وصول دفعة Apple Pay تلقائية الآن:',
                    style: TextStyle(fontSize: 10, color: textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandYellow.withValues(alpha: 0.16),
                            foregroundColor: brandYellow,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            side: const BorderSide(color: brandYellow),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            SpendoHaptics.success();
                            Navigator.pop(ctx);
                            await DailyExpenseService.handleIncomingShortcutUri(
                              'spendo://pay?amount=55&merchant=%D7%A9%D7%95%D7%95%D7%90%D7%A8%D7%9E%D7%94%20%D7%94%D7%A0%D7%A9%D7%99%D7%90',
                            );
                            _loadData();
                          },
                          icon: const Icon(Remix.restaurant_2_line, size: 14),
                          label: const Text(
                            'تجربة دفعة أكل (55 ₪)',
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen.withValues(alpha: 0.16),
                            foregroundColor: brandGreen,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            side: const BorderSide(color: brandGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            SpendoHaptics.success();
                            Navigator.pop(ctx);
                            await DailyExpenseService.handleIncomingShortcutUri(
                              'spendo://pay?amount=120&merchant=%D7%A9%D7%95%D7%A4%D7%A8%D7%A1%D7%9C%20%D7%93%D7%99%D7%9C',
                            );
                            _loadData();
                          },
                          icon: const Icon(Remix.shopping_bag_3_line, size: 14),
                          label: const Text(
                            'تجربة دفعة مشتريات (120 ₪)',
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
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
    );
  }

  /// نافذة سريعة عند الضغط على أي حركة في "آخر السجلات" لتغيير صنف المحل وحفظه للأبد
  void _showMerchantCategorySheet(DailyExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 3.5,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: surfaceBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.merchantName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'المبلغ: ${expense.amount.toStringAsFixed(0)} ₪ • ${expense.sourceTitle}',
                            style: const TextStyle(fontSize: 11, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await DailyExpenseService.deleteExpense(expense.id);
                        _loadData();
                      },
                      icon: const Icon(Remix.delete_bin_6_line,
                          color: brandRed, size: 18),
                      tooltip: 'حذف السجل',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'حدد صنف هذا المحل (سيتذكره التطبيق تلقائياً في كل دفعة قادمة):',
                  style: TextStyle(fontSize: 10.5, color: textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategorySelectButton(
                        ctx: ctx,
                        expense: expense,
                        categoryKey: 'food',
                        label: 'أكل',
                        icon: Remix.restaurant_2_line,
                        color: brandYellow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCategorySelectButton(
                        ctx: ctx,
                        expense: expense,
                        categoryKey: 'shopping',
                        label: 'مشتريات',
                        icon: Remix.shopping_bag_3_line,
                        color: brandGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCategorySelectButton(
                        ctx: ctx,
                        expense: expense,
                        categoryKey: 'fuel',
                        label: 'وقود',
                        icon: Remix.gas_station_line,
                        color: brandYellow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategorySelectButton({
    required BuildContext ctx,
    required DailyExpenseModel expense,
    required String categoryKey,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isCurrent = expense.category == categoryKey;
    return InkWell(
      onTap: () async {
        SpendoHaptics.success();
        await DailyExpenseService.updateExpenseCategory(
          expenseId: expense.id,
          merchantName: expense.merchantName,
          newCategory: categoryKey,
        );
        if (ctx.mounted) Navigator.pop(ctx);
        _loadData();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? color.withValues(alpha: 0.16) : surfaceField,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isCurrent ? color : surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCurrent ? Colors.white : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFuelDetailsModal(VehicleExpenseRecord record) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: surfaceField,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          record.title,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المبلغ: ₪${record.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: brandYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                'التاريخ: ${ArabicDateHelper.formatArabicDateWithWeekday(record.date)}',
                style: const TextStyle(color: textMuted, fontSize: 11)),
            if (record.provider != null) ...[
              const SizedBox(height: 4),
              Text('المزود: ${record.provider}',
                  style: const TextStyle(color: textMuted, fontSize: 11)),
            ],
            if (record.liters != null) ...[
              const SizedBox(height: 4),
              Text('اللترات: ${record.liters} لتر',
                  style: const TextStyle(color: textMuted, fontSize: 11)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('إغلاق', style: TextStyle(color: brandGreen)),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem {
  final String category; // 'food', 'shopping', 'fuel'
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final DailyExpenseModel? dailyExpense;
  final VehicleExpenseRecord? fuelRecord;

  const _TimelineItem({
    required this.category,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.dailyExpense,
    this.fuelRecord,
  });
}
