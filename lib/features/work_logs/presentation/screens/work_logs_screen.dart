import 'package:sanad_app/core/widgets/banking_animations.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/repositories/workplaces_repository.dart';
import 'package:sanad_app/features/workplaces/presentation/screens/employer_details_screen.dart';
import 'package:sanad_app/features/work_logs/models/work_log_model.dart';
import 'package:sanad_app/features/work_logs/repositories/work_logs_repository.dart';
import 'package:sanad_app/features/settings/presentation/screens/app_settings_screen.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/widgets/spendo_confirm_delete_dialog.dart';

/// سجل العمل - دليل المشغّلين وأصحاب العمل (מעסיקים)
///
/// Designed strictly 1:1 based on the user's high-fidelity HTML specification and Remix Icons.
class WorkLogsScreen extends StatefulWidget {
  const WorkLogsScreen({super.key});

  @override
  State<WorkLogsScreen> createState() => _WorkLogsScreenState();
}

class _WorkLogsScreenState extends State<WorkLogsScreen> {
  final WorkplacesRepository _workplacesRepo = WorkplacesRepository();
  final WorkLogsRepository _workRepo = WorkLogsRepository();

  List<WorkplaceModel> _workplaces = [];
  List<WorkLogModel> _logs = [];
  bool _isLoading = true;

  // Design Tokens - Reactive to active Theme
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get surfaceMain => _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  Color get surfaceField => _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  Color get surfaceBorder => _isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF2563EB);
  Color get brandYellow =>
      const Color(0xFFFFD600);
  Color get textPrimary => _isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get textSubtle => _isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);
  Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    DatabaseHelper.dataVersionNotifier.addListener(_loadData);
    AppTheme.themeModeNotifier.addListener(_onThemeChanged);
    _loadData();
  }

  @override
  void dispose() {
    AppTheme.themeModeNotifier.removeListener(_onThemeChanged);
    DatabaseHelper.dataVersionNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final workplaces = await _workplacesRepo.getAllWorkplaces();
      final logs = await _workRepo.getAllLogs();

      if (!mounted) return;

      setState(() {
        _workplaces = workplaces;
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('WorkLogsScreen _loadData error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openEmployerDetails(WorkplaceModel wp) async {
    SpendoHaptics.light();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployerDetailsScreen(workplace: wp),
      ),
    );
    _loadData();
  }

  Future<void> _openSideMenu() async {
    SpendoHaptics.light();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق القائمة الجانبية',
      barrierColor: Colors.black.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Material(
            color: surfaceMain,
            elevation: 0,
            child: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.82 > 320
                  ? 320
                  : MediaQuery.of(dialogContext).size.width * 0.82,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: surfaceBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('القائمة',
                              style: TextStyle(fontFamily: 'Cairo',
                                color: textWhite, fontSize: 16,
                                fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Remix.close_line, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: surfaceBorder),
                    ListTile(
                      leading: Icon(Remix.settings_4_line, color: brandGreen),
                      title: Text('الإعدادات',
                        style: TextStyle(fontFamily: 'Cairo', color: textWhite,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Icon(Remix.arrow_left_s_line, color: textMuted),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AppSettingsScreen(),
                          ),
                        );
                        if (mounted) _loadData();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0), end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

Future<void> _openEmployerModal([WorkplaceModel? existing]) async {
    SpendoHaptics.light();
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rateCtrl = TextEditingController(
      text: existing != null && existing.dailyRate > 0
          ? (existing.dailyRate == existing.dailyRate.roundToDouble()
              ? existing.dailyRate.toInt().toString()
              : existing.dailyRate.toString())
          : '',
    );
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    String currentStatus = existing?.status ?? 'active';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isActive = currentStatus == 'active';

            return Directionality(
              textDirection: TextDirection.rtl,
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
                      // مقبض السحب العلوي
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
                      const SizedBox(height: 8),

                      // ترويسة الهوية والمشغّل (Hero Profile Header)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: surfaceBorder, width: 1.0),
                            ),
                          ),
                          child: Row(
                            children: [
                              // أيقونة المشغّل أو حرفه الأول مع إطار ذهبي
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: brandYellow.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: brandYellow.withValues(alpha: 0.55),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          brandYellow.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: isEdit && existing.name.trim().isNotEmpty
                                    ? Text(
                                        existing.name.trim().characters.first,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: brandYellow,
                                        ),
                                      )
                                    : Icon(
                                        Remix.building_4_line,
                                        size: 22,
                                        color: brandYellow,
                                      ),
                              ),
                              const SizedBox(width: 10),

                              // اسم المشغّل وشارة الحالة
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit
                                          ? (existing.name.isNotEmpty
                                              ? existing.name
                                              : 'تعديل بيانات المشغّل')
                                          : 'إضافة مشغّل جديد',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? brandGreen.withValues(alpha: 0.14)
                                            : surfaceBorder
                                                .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isActive
                                              ? brandGreen
                                                  .withValues(alpha: 0.4)
                                              : surfaceBorder,
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
                                              color: isActive
                                                  ? brandGreen
                                                  : textSubtle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isActive
                                                ? 'مشغّل نشط حالياً'
                                                : 'غير نشط / مكتمل',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isActive
                                                  ? brandGreen
                                                  : textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // زر الإغلاق
                              InkWell(
                                onTap: () => Navigator.pop(ctx),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: surfaceBorder.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Remix.close_line,
                                    size: 16,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // محتوى البطاقات (Bento Cards)
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // وسم البطاقة 1: بيانات المنشأة
                              Row(
                                children: [
                                  Icon(Remix.building_line,
                                      size: 12, color: brandYellow),
                                  const SizedBox(width: 5),
                                  Text(
                                    'بيانات المشغّل والمنشأة',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // بطاقة Bento 1: الاسم + المدينة
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: surfaceBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: _isDark ? 0.2 : 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // حقل اسم المشغّل
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 3),
                                      child: Row(
                                        children: [
                                          Icon(Remix.briefcase_line,
                                              color: brandYellow, size: 17),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: nameCtrl,
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText:
                                                    'اسم المشغّل أو الشركة (مثال: מזגני אלנور) *',
                                                hintStyle: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  color: textSubtle,
                                                  fontSize: 11.5,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 0.8,
                                      color: surfaceBorder
                                          .withValues(alpha: 0.7),
                                      indent: 38,
                                      endIndent: 12,
                                    ),
                                    // حقل المدينة أو موقع العمل
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 3),
                                      child: Row(
                                        children: [
                                          const Icon(Remix.map_pin_line,
                                              color: brandGreen, size: 17),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextField(
                                              controller: cityCtrl,
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText:
                                                    'المدينة أو موقع العمل (مثال: القدس)',
                                                hintStyle: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  color: textSubtle,
                                                  fontSize: 11.5,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // وسم البطاقة 2: الأجور وحالة النشاط
                              Row(
                                children: [
                                  const Icon(Remix.money_dollar_circle_line,
                                      size: 12, color: brandGreen),
                                  const SizedBox(width: 5),
                                  Text(
                                    'الأجر اليومي وحالة العمل',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),

                              // بطاقة Bento 2: الأجر اليومي + حالة العمل
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: surfaceBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: _isDark ? 0.2 : 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // صف سعر اليومية
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(Remix.coin_line,
                                              color: brandYellow, size: 17),
                                          const SizedBox(width: 10),
                                          Text(
                                            'سعر اليومية الافتراضي',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            width: 105,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: surfaceMain,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: brandYellow
                                                    .withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: rateCtrl,
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                            decimal: true),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: brandYellow,
                                                    ),
                                                    decoration:
                                                        InputDecoration(
                                                      hintText: '0',
                                                      hintStyle: TextStyle(
                                                          color: textMuted,
                                                          fontSize: 12),
                                                      border:
                                                          InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                              vertical: 4),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '₪',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: brandYellow,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 0.8,
                                      color: surfaceBorder
                                          .withValues(alpha: 0.7),
                                      indent: 38,
                                      endIndent: 12,
                                    ),
                                    // صف حالة المشغّل مع مفتاح تبديل مدمج
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      child: Row(
                                        children: [
                                          const Icon(Remix.toggle_line,
                                              color: brandGreen, size: 17),
                                          const SizedBox(width: 10),
                                          Text(
                                            'حالة العمل مع المشغّل',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const Spacer(),
                                          // مفتاح التبديل نشط / غير نشط
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  SpendoHaptics.selection();
                                                  setModalState(() =>
                                                      currentStatus = 'active');
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 150),
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 9,
                                                          vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? brandGreen
                                                            .withValues(
                                                                alpha: 0.16)
                                                        : surfaceMain,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                    border: Border.all(
                                                      color: isActive
                                                          ? brandGreen
                                                          : surfaceBorder,
                                                      width:
                                                          isActive ? 1.2 : 1.0,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration:
                                                            const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: brandGreen,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'نشط',
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isActive
                                                              ? brandGreen
                                                              : textMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () {
                                                  SpendoHaptics.selection();
                                                  setModalState(() =>
                                                      currentStatus =
                                                          'completed');
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 150),
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 9,
                                                          vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: !isActive
                                                        ? (_isDark
                                                            ? Colors.white
                                                                .withValues(
                                                                    alpha: 0.1)
                                                            : const Color(
                                                                0xFFE5E7EB))
                                                        : surfaceMain,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                    border: Border.all(
                                                      color: !isActive
                                                          ? (_isDark
                                                              ? Colors.white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.5)
                                                              : const Color(
                                                                  0xFF9CA3AF))
                                                          : surfaceBorder,
                                                      width:
                                                          !isActive ? 1.2 : 1.0,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: textSubtle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'غير نشط',
                                                        style: TextStyle(
                                                          fontFamily: 'Cairo',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: !isActive
                                                              ? (_isDark
                                                                  ? Colors.white
                                                                  : const Color(
                                                                      0xFF1F2937))
                                                              : textMuted,
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
                              const SizedBox(height: 14),

                              // أزرار الحفظ والإلغاء (زر أخضر فينتك مشع)
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final name = nameCtrl.text.trim();
                                        if (name.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'يرجى إدخال اسم المشغّل أولاً'),
                                              backgroundColor:
                                                  Color(0xFFEF4444),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                          return;
                                        }

                                        final dailyRate = double.tryParse(
                                                rateCtrl.text.trim()) ??
                                            0.0;
                                        final city = cityCtrl.text.trim();

                                        SpendoHaptics.success();
                                        if (isEdit) {
                                          final updated = existing.copyWith(
                                            name: name,
                                            city: city,
                                            dailyRate: dailyRate,
                                            status: currentStatus,
                                            updatedAt: DateTime.now(),
                                          );
                                          await _workplacesRepo
                                              .updateWorkplace(updated);
                                        } else {
                                          final created =
                                              WorkplaceModel.create(
                                            name: name,
                                            city: city,
                                            dailyRate: dailyRate,
                                            status: currentStatus,
                                          );
                                          await _workplacesRepo
                                              .addWorkplace(created);
                                        }

                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                        _loadData();
                                      },
                                      borderRadius: BorderRadius.circular(11),
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: brandGreen,
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          boxShadow: [
                                            BoxShadow(
                                              color: brandGreen.withValues(
                                                  alpha: 0.28),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Remix.check_line,
                                              size: 17,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isEdit
                                                  ? 'حفظ التعديلات'
                                                  : 'إضافة المشغّل',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                color: Colors.white,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => Navigator.pop(ctx),
                                    borderRadius: BorderRadius.circular(11),
                                    child: Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: surfaceField,
                                        borderRadius:
                                            BorderRadius.circular(11),
                                        border:
                                            Border.all(color: surfaceBorder),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'إلغاء',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteWorkplace(WorkplaceModel wp) async {
    SpendoHaptics.light();
    final matchedLogs = _logs.where((l) {
      if (l.workplaceId != null && l.workplaceId == wp.id) return true;
      if (l.workplaceName.trim().toLowerCase() ==
          wp.name.trim().toLowerCase()) {
        return true;
      }
      return false;
    }).toList();
    final count = matchedLogs.length;

    final confirmed = await SpendoConfirmDeleteDialog.show(
      context,
      title: 'تأكيد حذف المشغّل',
      itemName: wp.name,
      itemIcon: Remix.building_2_line,
      warningNote: count > 0
          ? 'سيتم حذف المشغّل وجميع أيام وسجلات العمل التابعة له ($count يوم عمل).'
          : 'سيتم حذف المشغّل نهائياً من السجل.',
      confirmLabel: 'حذف المشغّل',
    );

    if (confirmed == true) {
      SpendoHaptics.success();
      await _workplacesRepo.deleteWorkplace(wp.id,
          workplaceName: wp.name, deleteLogs: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف المشغّل "${wp.name}" بنجاح'),
            backgroundColor: surfaceField,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalEmployers = _workplaces.length;
    final totalDays = _logs.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceMain,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. مؤشر السحب العلوي المدمج
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF404040).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // 2. الترويسة العلوية المطابقة للتصميم (أيقونات ريميكس نظيفة بدون خلفيات)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Remix.briefcase_4_line,
                          color: brandGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سجل العمل',
                              style: TextStyle(
                                color: textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'إدارة أصحاب العمل وأيام الدوام',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    IconButton(
                      tooltip: 'فتح القائمة',
                      onPressed: _openSideMenu,
                      icon: Icon(Remix.menu_line, color: textMuted, size: 20),
                      splashRadius: 22,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. المحتوى القابل للتمرير
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: brandGreen,
                          strokeWidth: 2.5,
                        ),
                      )
                    : RefreshIndicator(
                        color: brandGreen,
                        backgroundColor: surfaceField,
                        onRefresh: _loadData,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 90),
                          children: [
                            // بطاقة ملخص دليل المشغّلين وأصحاب العمل
                            BankingCascadeItem(
                              tabIndex: 1,
                              staggerIndex: 0,
                              child: _buildSummaryCard(
                                totalEmployers: totalEmployers,
                                totalDays: totalDays,
                              ),
                            ),

                            // شريط عنوان القائمة + زر إضافة مشغّل
                            BankingCascadeItem(
                              tabIndex: 1,
                              staggerIndex: 1,
                              child: _buildSectionHeader(count: totalEmployers),
                            ),

                            // قائمة بطاقات المشغّلين
                            BankingCascadeItem(
                              tabIndex: 1,
                              staggerIndex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_workplaces.isEmpty)
                                    _buildEmptyState()
                                  else
                                    ..._workplaces.map(_buildWorkplaceCard),
                                ],
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

  // بطاقة ملخص دليل المشغّلين وأصحاب العمل
  Widget _buildSummaryCard(
      {required int totalEmployers, required int totalDays}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        children: [
          // سطر العنوان داخل البطاقة
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Remix.building_2_line, size: 14, color: brandGreen),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: 'دليل المشغّلين وأصحاب العمل ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textWhite,
                            ),
                            children: [
                              TextSpan(
                                text: '(מעסיקים)',
                                style: TextStyle(
                                  color: brandYellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: surfaceMain,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: surfaceBorder),
                  ),
                  child: Text(
                    '$totalEmployers مشغّل مسجل',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: brandYellow,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // خط فاصل رفيع
          Container(
            height: 1,
            color: surfaceBorder,
            margin: const EdgeInsets.only(bottom: 10),
          ),

          // مربعات الإحصائيات المدمجة
          Row(
            children: [
              // المشغّلين النشطين (يمين)
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: surfaceMain,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: surfaceBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المشغّلين النشطين',
                            style: TextStyle(
                              fontSize: 10,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalEmployers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textWhite,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Remix.user_star_line,
                        color: brandGreen,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // إجمالي أيام العمل (يسار)
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: surfaceMain,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: surfaceBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي أيام العمل',
                            style: TextStyle(
                              fontSize: 10,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$totalDays',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: brandYellow,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'يوم',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(
                        Remix.calendar_check_line,
                        color: brandYellow,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // شريط عنوان القائمة + زر إضافة مشغّل
  Widget _buildSectionHeader({required int count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Remix.list_check_2, size: 14, color: brandGreen),
              const SizedBox(width: 6),
              Text(
                'قائمة المشغّلين',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textWhite,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: brandYellow,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => _openEmployerModal(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: brandGreen.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Remix.add_line, size: 13, color: brandGreen),
                  const SizedBox(width: 4),
                  Text.rich(
                    TextSpan(
                      text: 'إضافة مشغّل ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                      ),
                      children: [
                        TextSpan(
                          text: '(מעסיק)',
                          style: TextStyle(
                            color: brandYellow,
                            fontWeight: FontWeight.normal,
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
      ),
    );
  }

  // بطاقة المشغّل المدمجة (أيقونات Remix نظيفة بدون دوائر أو مربعات خلفية)
  Widget _buildWorkplaceCard(WorkplaceModel wp) {
    final matchedLogs = _logs.where((l) {
      if (l.workplaceId != null && l.workplaceId == wp.id) return true;
      if (l.workplaceName.trim().toLowerCase() ==
          wp.name.trim().toLowerCase()) {
        return true;
      }
      return false;
    }).toList();
    final shiftCount = matchedLogs.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEmployerDetails(wp),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // القسم الأيمن: أيقونة المبنى بدون خلفية + اسم المشغل وأيام العمل
                Expanded(
                  child: Row(
                    children: [
                      // أيقونة نظيفة بدون دائرة أو مربع خلفية
                      const Icon(
                        Remix.building_line,
                        size: 18,
                        color: brandGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    wp.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (wp.city.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: surfaceMain,
                                      borderRadius: BorderRadius.circular(4),
                                      border:
                                          Border.all(color: surfaceBorder),
                                    ),
                                    child: Text(
                                      wp.city,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: brandYellow,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: wp.isActive
                                        ? brandGreen.withValues(alpha: 0.12)
                                        : surfaceMain,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: wp.isActive
                                          ? brandGreen.withValues(alpha: 0.4)
                                          : surfaceBorder,
                                    ),
                                  ),
                                  child: Text(
                                    wp.isActive ? 'نشط' : 'منتهي',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: wp.isActive ? brandGreen : textSubtle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Remix.time_line,
                                  size: 11,
                                  color: brandYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$shiftCount يوم عمل',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textMuted,
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

                // القسم الأيسر: تعديل + سطل الحذف + سهم التفاصيل (بدون خلفية وبالترتيب والاتجاه الصحيح)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _openEmployerModal(wp),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(
                          Remix.pencil_line,
                          size: 14,
                          color: textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _confirmDeleteWorkplace(wp),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(
                          Remix.delete_bin_6_line,
                          size: 14,
                          color: textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _openEmployerDetails(wp),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(
                          Remix.arrow_left_s_line,
                          size: 16,
                          color: textSubtle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      alignment: Alignment.center,
      child: Text(
        'لا يوجد مشغّلين مسجلين حالياً',
        style: TextStyle(
          fontSize: 12,
          color: textSubtle,
        ),
      ),
    );
  }
}
