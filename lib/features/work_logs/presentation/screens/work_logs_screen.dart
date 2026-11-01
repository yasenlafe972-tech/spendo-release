import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/repositories/workplaces_repository.dart';
import 'package:sanad_app/features/workplaces/presentation/screens/employer_details_screen.dart';
import 'package:sanad_app/features/work_logs/models/work_log_model.dart';
import 'package:sanad_app/features/work_logs/repositories/work_logs_repository.dart';
import 'package:sanad_app/features/settings/presentation/screens/app_settings_screen.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/core/database/database_helper.dart';

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

  // Design Tokens (Matching HTML exactly)
  static const Color surfaceMain = Color(0xFF121413);
  static const Color surfaceField = Color(0xFF171A19);
  static const Color surfaceBorder = Color(0xFF242927);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textSubtle = Color(0xFF71717A);

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
    final workplaces = await _workplacesRepo.getAllWorkplaces();
    final logs = await _workRepo.getAllLogs();

    if (!mounted) return;

    setState(() {
      _workplaces = workplaces;
      _logs = logs;
      _isLoading = false;
    });
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
            ? media.padding.bottom
            : media.viewPadding.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 10,
                    bottom: keyboardInset > 0
                        ? keyboardInset + 8
                        : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // مؤشر السحب
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

                        // صندوق الحقول الرئيسي
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ترويسة النافذة
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Remix.building_4_line,
                                        size: 16,
                                        color: brandYellow,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isEdit
                                            ? 'تعديل بيانات المشغّل'
                                            : 'إضافة مشغّل جديد',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    behavior: HitTestBehavior.opaque,
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Remix.close_line,
                                        size: 18,
                                        color: textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // اسم المشغّل / الشركة
                              const Text(
                                'اسم المشغّل / الشركة',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceMain,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: surfaceBorder),
                                ),
                                child: TextField(
                                  controller: nameCtrl,
                                  style: const TextStyle(
                                      color: textPrimary, fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'مثال: מזגני אלנור',
                                    hintStyle: TextStyle(
                                        color: textSubtle, fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // شبكة عمودين: سعر اليومية + المدينة / ملاحظة
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'سعر اليومية (₪)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: surfaceMain,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: surfaceBorder),
                                          ),
                                          child: TextField(
                                            controller: rateCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            style: const TextStyle(
                                                color: textPrimary,
                                                fontSize: 12),
                                            decoration: const InputDecoration(
                                              hintText: '0',
                                              hintStyle: TextStyle(
                                                  color: textSubtle,
                                                  fontSize: 12),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'المدينة / ملاحظة (اختياري)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: surfaceMain,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: surfaceBorder),
                                          ),
                                          child: TextField(
                                            controller: cityCtrl,
                                            style: const TextStyle(
                                                color: textPrimary,
                                                fontSize: 12),
                                            decoration: const InputDecoration(
                                              hintText: 'مثال: القدس',
                                              hintStyle: TextStyle(
                                                  color: textSubtle,
                                                  fontSize: 12),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // حالة المشغّل: نشط / غير نشط (مدمج في سطر واحد)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: surfaceMain,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: surfaceBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'حالة العمل مع المشغّل',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: textMuted,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => setModalState(() => currentStatus = 'active'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: currentStatus == 'active'
                                              ? brandGreen.withValues(alpha: 0.15)
                                              : surfaceField,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: currentStatus == 'active'
                                                ? brandGreen
                                                : surfaceBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: brandGreen,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'نشط',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: currentStatus == 'active'
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
                                      onTap: () => setModalState(() => currentStatus = 'completed'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: currentStatus == 'completed'
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : surfaceField,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: currentStatus == 'completed'
                                                ? Colors.white.withValues(alpha: 0.6)
                                                : surfaceBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: textSubtle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'غير نشط',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: currentStatus == 'completed'
                                                    ? Colors.white
                                                    : textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // أزرار الحفظ والإلغاء
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: brandGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 9),
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        final name = nameCtrl.text.trim();
                                        if (name.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'يرجى إدخال اسم المشغّل'),
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
                                      icon: const Icon(Remix.check_line, size: 16),
                                      label: Text(
                                        isEdit
                                            ? 'حفظ التعديلات'
                                            : 'حفظ المشغّل',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFD1D5DB),
                                      backgroundColor: surfaceMain,
                                      side: const BorderSide(
                                          color: surfaceBorder),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 9),
                                    ),
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('إلغاء',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceField,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: surfaceBorder),
        ),
        title: Row(
          children: const [
            Icon(Remix.delete_bin_6_line,
                color: Color(0xFFEF4444), size: 18),
            SizedBox(width: 8),
            Text(
              'تأكيد الحذف',
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          count > 0
              ? 'هل أنت متأكد من حذف المشغّل "${wp.name}"؟\nسيتم حذف المشغّل وجميع أيام وسجلات العمل التابعة له ($count يوم).'
              : 'هل أنت متأكد من حذف المشغّل "${wp.name}" نهائياً من السجل؟',
          style: const TextStyle(color: textMuted, fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: textMuted, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
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
        backgroundColor: AppColors.background,
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
                          children: const [
                            Text(
                              'سجل العمل',
                              style: TextStyle(
                                color: Colors.white,
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

                    // زر الإعدادات
                    GestureDetector(
                      onTap: () async {
                        SpendoHaptics.light();
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const AppSettingsScreen()),
                        );
                        _loadData();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Remix.settings_4_line,
                          color: textMuted,
                          size: 18,
                        ),
                      ),
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
                        color: Colors.white,
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
                            _buildSummaryCard(
                              totalEmployers: totalEmployers,
                              totalDays: totalDays,
                            ),

                            // شريط عنوان القائمة + زر إضافة مشغّل
                            _buildSectionHeader(count: totalEmployers),

                            // قائمة بطاقات المشغّلين
                            if (_workplaces.isEmpty)
                              _buildEmptyState()
                            else
                              ..._workplaces.map(_buildWorkplaceCard),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Remix.building_2_line, size: 14, color: brandGreen),
                    SizedBox(width: 6),
                    const Text(
                      'دليل المشغّلين وأصحاب العمل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE5E7EB),
                      ),
                    ),
                  ],
                ),
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
                    style: const TextStyle(
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
                          const Text(
                            'المشغّلين النشطين',
                            style: TextStyle(
                              fontSize: 10,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalEmployers',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
                          const Text(
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: brandYellow,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'يوم',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD1D5DB),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
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
              const Text(
                'قائمة المشغّلين',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: const TextStyle(
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
                children: const [
                  Icon(Remix.add_line, size: 13, color: brandGreen),
                  SizedBox(width: 4),
                  const Text(
                    'إضافة مشغّل',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                                      style: const TextStyle(
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
                                const Icon(
                                  Remix.time_line,
                                  size: 11,
                                  color: brandYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$shiftCount يوم عمل',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD1D5DB),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
      child: const Text(
        'لا يوجد مشغّلين مسجلين حالياً',
        style: TextStyle(
          fontSize: 12,
          color: textSubtle,
        ),
      ),
    );
  }
}
