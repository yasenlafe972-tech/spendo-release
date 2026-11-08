import 'package:sanad_app/core/widgets/banking_animations.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Static brand accents
  static const Color brandGreen = Color(0xFF2563EB);
  static const Color brandYellow = Color(0xFFFFD600);
  static const Color brandRed = Color(0xFFEF4444);

  // Dynamic surface & text tokens based on active theme
  Color get surfaceMain => _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  Color get surfaceField => _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  Color get surfaceElevated => _isDark ? const Color(0xFF16161A) : const Color(0xFFF1F3F5);
  Color get surfaceBorder => _isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
  Color get textWhite => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textMuted => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);

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
      // سحب أي دفعات جديدة وصلت بالخلفية من محفظة الهاتف أو السحابة
      await DailyExpenseService.pullPendingAndroidWalletNotifications();
      DailyExpenseService.pullCloudAutoExpenses();
      // مزامنة سحابية ثنائية تلقائية
      FirebaseBackupService.instance.syncWithCloud(isSilent: true);

      final peopleFuture = _peopleRepo.getAllPeople().catchError((_) => <PersonModel>[]);
      final logsFuture = _workLogsRepo.getAllLogs().catchError((_) => <WorkLogModel>[]);
      final expensesFuture = DailyExpenseService.getAllExpenses().catchError((_) => <DailyExpenseModel>[]);

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
        // automatically switch to 'all' (كافة الفترات) so the user immediately sees all records & totals!
        if (_filteredWorkLogs.isEmpty &&
            _filteredDailyExpenses.isEmpty &&
            _filteredFuelRecords.isEmpty &&
            (_allDailyExpenses.isNotEmpty ||
                _allFuelRecords.isNotEmpty ||
                _allWorkLogs.isNotEmpty)) {
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
                    Text(
                      'اختر فترة العرض',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
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
                      title: Text('كافة الفترات',
                          style: TextStyle(
                              color: textWhite,
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
                              style: TextStyle(
                                  color: textWhite,
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
      final timeStr =
          '${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}';
      final locPart = (e.location != null && e.location!.trim().isNotEmpty)
          ? ' • ${e.location!.trim()}'
          : '';
      items.add(_TimelineItem(
        category: e.category,
        date: e.date,
        title: e.merchantName,
        subtitle:
            '${ArabicDateHelper.getRelativeDayDescription(e.date)} • $timeStr • ${e.sourceTitle}$locPart',
        amount: e.amount,
        dailyExpense: e,
      ));
    }

    if (_selectedLogsFilter == 'all' || _selectedLogsFilter == 'fuel') {
      for (final f in _filteredFuelRecords) {
        items.add(_TimelineItem(
          category: 'fuel',
          date: f.date,
          title: f.title.isNotEmpty ? f.title : 'تعبئة وقود • Yellow פז',
          subtitle:
              '${ArabicDateHelper.getRelativeDayDescription(f.date)} • وقود المركبة',
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
      items.add(_TimelineItem(
        category: categoryKey,
        date: m.date,
        title: m.title.isNotEmpty ? m.title : (isStore ? 'Yellow חנות נוחות' : 'صيانة مركبة'),
        subtitle: isStore
            ? '${ArabicDateHelper.getRelativeDayDescription(m.date)} • مشتريات Yellow'
            : '${ArabicDateHelper.getRelativeDayDescription(m.date)} • صيانة المركبة',
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
                            color: _isDark ? const Color(0xFF404040) : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),

                      // الترويسة العلوية
                      BankingCascadeItem(
                        tabIndex: 0,
                        staggerIndex: 0,
                        child: _buildHeader(userName),
                      ),
                      const SizedBox(height: 12),

                      // 1. بطاقتين مدمجتين للمصاريف (أكل + مشتريات)
                      BankingCascadeItem(
                        tabIndex: 0,
                        staggerIndex: 1,
                        child: _buildExpenseCategoriesRow(),
                      ),
                      const SizedBox(height: 10),

                      // 2. أزرار الإجراءات السريعة (تسجيل يوم عمل + تعبئة وقود)
                      BankingCascadeItem(
                        tabIndex: 0,
                        staggerIndex: 2,
                        child: _buildQuickActionButtons(),
                      ),
                      const SizedBox(height: 12),

                      // 3. سجل آخر السجلات (الكل | أكل | مشتريات | وقود)
                      BankingCascadeItem(
                        tabIndex: 0,
                        staggerIndex: 3,
                        child: _buildRecentTransactionsSection(),
                      ),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Remix.dashboard_line, color: brandGreen, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'لوحة التحكم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'أهلاً $userName • ملخص العمل والمصاريف',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        Row(
          mainAxisSize: MainAxisSize.min,
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
                    Icon(Remix.calendar_2_line,
                        size: 11.5, color: brandYellow),
                    const SizedBox(width: 5),
                    Text(
                      _getMonthLabel(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Remix.arrow_down_s_line,
                        size: 13, color: textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Remix.settings_4_line,
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
              numericValue: _totalFoodExpense,
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
              numericValue: _totalShoppingExpense,
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
    required double numericValue,
    required IconData icon,
    required Color iconColor,
    bool isHighlighted = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? surfaceElevated : surfaceField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? iconColor.withValues(alpha: 0.6) : surfaceBorder,
          width: isHighlighted ? 1.2 : 1,
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
                  style: TextStyle(
                    fontSize: 9,
                    color: textMuted,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                BankingRollingNumber(
                  tabIndex: 0,
                  value: numericValue,
                  formatter: (val) => '${_formatAmount(val)} ₪',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: textWhite,
                    height: 1.15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 15, color: iconColor),
        ],
      ),
    );
  }

  // أزرار الإجراءات السريعة (تصميم مريح ومصغر يتمدد مع حجم الخط)
  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        // زر تسجيل يوم عمل (أخضر زمردي هادئ)
        Expanded(
          child: Material(
            color: brandGreen,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () async {
                SpendoHaptics.light();
                final res = await AddWorkLogSheet.show(context);
                if (res != null) {
                  _loadData();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Remix.briefcase_4_line,
                        size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'تسجيل يوم عمل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
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
        const SizedBox(width: 8),

        // زر تعبئة وقود (رمادي ناعم بحواف محددة)
        Expanded(
          child: Material(
            color: surfaceField,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                SpendoHaptics.light();
                FuelExpenseSheet.show(
                  context,
                  onSaved: _loadData,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: surfaceBorder),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Remix.gas_station_line,
                        size: 12, color: brandYellow),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'تعبئة وقود',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: textWhite,
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
    );
  }

  // 4. سجل آخر السجلات مع فلترة واستقبال تلقائي (مضاد للـ Overflow عند تكبير الخط)
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
            children: [
              const Icon(Remix.history_line, size: 15, color: brandGreen),
              const SizedBox(width: 6),
              Text(
                'آخر السجلات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: surfaceBorder, height: 1),

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
              key: ValueKey<String>('${_selectedLogsFilter}_${_selectedMonthKey}_${_showAllTimelineItems}_${timelineItems.length}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (timelineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Column(
                  children: [
                    Icon(Remix.bank_card_2_line,
                        size: 24, color: textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    Text(
                      'لا توجد دفعات مسجلة في هذا التصنيف',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
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
                        _showExpenseDetailsSheet(item.dailyExpense!);
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
                                Icon(
                                  itemIcon,
                                  size: 17,
                                  color: itemColor,
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textWhite,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
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
                              Icon(
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
          ),
        ],
      ),
    );
  }



  /// نافذة تفاصيل العملية (المبلغ، التاريخ، الساعة، وسيلة الدفع، والموقع)
  void _showExpenseDetailsSheet(DailyExpenseModel initialExpense) {
    DailyExpenseModel expense = initialExpense;
    bool isUpdatingLoc = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final timeStr =
                '${expense.date.hour.toString().padLeft(2, '0')}:${expense.date.minute.toString().padLeft(2, '0')}';
            final media = MediaQuery.of(ctx);
            final bottomInset = media.viewInsets.bottom;
            final bottomPadding = media.padding.bottom > 0
                ? media.padding.bottom
                : media.viewPadding.bottom;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    bottomInset > 0
                        ? bottomInset + 12
                        : (bottomPadding > 0 ? bottomPadding + 14 : 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
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
                            child: Text(
                              expense.merchantName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textWhite,
                              ),
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
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: surfaceField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'المبلغ:',
                                  style:
                                      TextStyle(color: textMuted, fontSize: 11.5),
                                ),
                                Text(
                                  '₪${expense.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: brandYellow,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Divider(color: surfaceBorder, height: 16),
                            Row(
                              children: [
                                const Icon(Remix.calendar_event_line,
                                    size: 13, color: brandGreen),
                                const SizedBox(width: 6),
                                Text(
                                  'التاريخ: ${ArabicDateHelper.formatArabicDateWithWeekday(expense.date)}',
                                  style:
                                      TextStyle(color: textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Remix.time_line,
                                    size: 13, color: brandYellow),
                                const SizedBox(width: 6),
                                Text(
                                  'الساعة: $timeStr',
                                  style:
                                      TextStyle(color: textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Remix.wallet_3_line,
                                    size: 13, color: textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  'المصدر: ${expense.sourceTitle}',
                                  style:
                                      TextStyle(color: textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Remix.map_pin_2_line,
                                    size: 13, color: brandRed),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    expense.location != null &&
                                            expense.location!.isNotEmpty
                                        ? 'الموقع: ${expense.location}'
                                        : 'الموقع: غير محدد بعد',
                                    style: TextStyle(
                                        color: expense.location != null &&
                                                expense.location!.isNotEmpty
                                            ? textWhite
                                            : textMuted,
                                        fontSize: 11,
                                        fontWeight: expense.location != null &&
                                                expense.location!.isNotEmpty
                                            ? FontWeight.w600
                                            : FontWeight.normal),
                                  ),
                                ),
                                InkWell(
                                  onTap: isUpdatingLoc
                                      ? null
                                      : () async {
                                          setSheetState(
                                              () => isUpdatingLoc = true);
                                          final loc = await DailyExpenseService
                                              .updateExpenseLocationWithCurrentGps(
                                                  expense.id);
                                          if (ctx.mounted) {
                                            setSheetState(() {
                                              isUpdatingLoc = false;
                                              if (loc != null) {
                                                expense = expense.copyWith(
                                                    location: loc);
                                              }
                                            });
                                          }
                                          _loadData();
                                        },
                                  child: Text(
                                    isUpdatingLoc
                                        ? 'جاري التحديد...'
                                        : 'تحديث الموقع (GPS)',
                                    style: const TextStyle(
                                      color: brandGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: surfaceBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'إغلاق',
                            style: TextStyle(
                              color: brandGreen,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditFuelDialog(VehicleExpenseRecord record) {
    final titleCtrl = TextEditingController(text: record.title);
    final providerCtrl = TextEditingController(text: record.provider ?? '');
    final amountCtrl = TextEditingController(text: record.amount.toStringAsFixed(2));
    final litersCtrl = TextEditingController(text: record.liters?.toString() ?? '');

    showDialog(
      context: context,
      builder: (editCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: surfaceField,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: surfaceBorder),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          title: Text(
            'تعديل الفاتورة والمحطة',
            style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: providerCtrl,
                  style: TextStyle(color: textWhite, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'اسم المحطة / المزود (الموقع)',
                    labelStyle: TextStyle(color: textMuted, fontSize: 11),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: textWhite, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'بيان الفاتورة',
                    labelStyle: TextStyle(color: textMuted, fontSize: 11),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: brandYellow, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'المبلغ (₪)',
                          labelStyle: TextStyle(color: textMuted, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: litersCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: textWhite, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'اللترات',
                          labelStyle: TextStyle(color: textMuted, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => Navigator.pop(editCtx),
              child: Text('إلغاء', style: TextStyle(color: textMuted, fontSize: 11.5)),
            ),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () async {
                final newAmt = double.tryParse(amountCtrl.text.trim()) ?? record.amount;
                final newLiters = double.tryParse(litersCtrl.text.trim());
                final newProv = providerCtrl.text.trim();
                final newTitle = titleCtrl.text.trim();

                final updatedRec = record.copyWith(
                  title: newTitle.isNotEmpty ? newTitle : record.title,
                  provider: newProv.isNotEmpty ? newProv : record.provider,
                  amount: newAmt,
                  liters: newLiters,
                );

                Navigator.pop(editCtx);
                final prefs = await SharedPreferences.getInstance();
                final raw = prefs.getString('spendo_vehicle_tracker_v5');
                if (raw != null) {
                  final state = VehicleDataState.fromJson(raw);
                  final updatedHistory = state.history.map((x) => x.id == record.id ? updatedRec : x).toList();
                  await prefs.setString(
                    'spendo_vehicle_tracker_v5',
                    state.copyWith(history: updatedHistory).toJson(),
                  );
                  FirebaseBackupService.instance.scheduleAutoBackup(
                    debounce: const Duration(seconds: 1),
                  );
                }
                _loadData();
              },
              child: const Text('حفظ', style: TextStyle(color: brandGreen, fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFuelDetailsModal(VehicleExpenseRecord record) {
    showDialog(
      context: context,
      builder: (dCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: surfaceField,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: surfaceBorder),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          title: Text(
            record.title,
            style: TextStyle(
              color: textWhite,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المبلغ: ₪${record.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: brandYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'التاريخ: ${ArabicDateHelper.formatArabicDateWithWeekday(record.date)}',
                style: TextStyle(color: textMuted, fontSize: 10.5),
              ),
              if (record.provider != null && record.provider!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'المزود: ${record.provider}',
                  style: TextStyle(color: textMuted, fontSize: 10.5),
                ),
              ],
              if (record.liters != null) ...[
                const SizedBox(height: 3),
                Text(
                  'اللترات: ${record.liters} لتر',
                  style: TextStyle(color: textMuted, fontSize: 10.5),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              onPressed: () async {
                Navigator.pop(dCtx);
                final prefs = await SharedPreferences.getInstance();
                final raw = prefs.getString('spendo_vehicle_tracker_v5');
                if (raw != null) {
                  final state = VehicleDataState.fromJson(raw);
                  final updated =
                      state.history.where((x) => x.id != record.id).toList();
                  await prefs.setString(
                    'spendo_vehicle_tracker_v5',
                    state.copyWith(history: updated).toJson(),
                  );
                  FirebaseBackupService.instance.scheduleAutoBackup(
                    debounce: const Duration(seconds: 1),
                  );
                }
                _loadData();
              },
              child: const Text(
                'حذف',
                style: TextStyle(
                  color: brandRed,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                _showEditFuelDialog(record);
              },
              child: Text(
                'تعديل',
                style: TextStyle(
                  color: brandYellow,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              onPressed: () => Navigator.pop(dCtx),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  color: brandGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
