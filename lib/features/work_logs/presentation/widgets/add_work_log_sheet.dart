import 'package:sanad_app/core/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/core/services/location_service.dart';
import 'package:sanad_app/core/services/attachment_service.dart';
import 'package:sanad_app/core/widgets/attachment_viewer_modal.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/workplaces/presentation/screens/map_location_picker_screen.dart';
import 'package:sanad_app/features/work_logs/models/work_log_model.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/repositories/workplaces_repository.dart';
import 'package:sanad_app/features/work_logs/repositories/work_logs_repository.dart';
import 'package:sanad_app/core/widgets/spendo_date_picker.dart';

/// نافذة تسجيل يوم عمل جديد (تسجيل يوم عمل جديد)
///
/// Designed strictly 1:1 based on the user's high-fidelity HTML specification and Remix Icons.
/// Changes implemented:
/// 1. إلغاء حقل تعديل سعر اليومية — يظهر كشارة ثابتة للقراءة فقط مع أيقونة قفل مسحوبة من المشغّل.
/// 2. إزالة قسم المقبوضات من المشغّل بالكامل — الحساب والقبض شهرياً وليس يومياً.
/// 3. بطاقة المبلغ المستحق لليوم (قراءة فقط مرحّل للحساب الشهري تلقائياً).
/// 4. 5 عناصر ملمومة ومرتبة مع أيقونات Remix Icon الأصلية بدون أي خلفيات.
class AddWorkLogSheet extends StatefulWidget {
  final PersonModel? preselectedPerson;
  final WorkplaceModel? preselectedWorkplace;
  final WorkLogModel? existingLog;
  final Function(WorkLogModel) onSave;

  const AddWorkLogSheet({
    super.key,
    this.preselectedPerson,
    this.preselectedWorkplace,
    this.existingLog,
    required this.onSave,
  });

  static Future<WorkLogModel?> show(
    BuildContext context, {
    WorkLogModel? existingLog,
    WorkplaceModel? preselectedWorkplace,
    PersonModel? preselectedPerson,
  }) {
    final workLogsRepo = WorkLogsRepository();
    return showModalBottomSheet<WorkLogModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => AddWorkLogSheet(
        existingLog: existingLog,
        preselectedWorkplace: preselectedWorkplace,
        preselectedPerson: preselectedPerson,
        onSave: (log) async {
          if (existingLog != null) {
            await workLogsRepo.updateWorkLog(log);
          } else {
            await workLogsRepo.addWorkLog(log);
          }
        },
      ),
    );
  }

  @override
  State<AddWorkLogSheet> createState() => _AddWorkLogSheetState();
}

class _AddWorkLogSheetState extends State<AddWorkLogSheet> {
  final WorkplacesRepository _workplacesRepo = WorkplacesRepository();
  final WorkLogsRepository _workLogsRepo = WorkLogsRepository();

  List<WorkplaceModel> _allWorkplaces = [];
  List<String> _recentCities = [];

  WorkplaceModel? _selectedWorkplace;
  String? _activePlaceChip;
  double? _overrideDailyRate;

  late final TextEditingController _cityController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;

  bool _isSaving = false;

  // الموقع الجغرافي والمرفقات
  double? _latitude;
  double? _longitude;
  String? _locationAddress;
  bool _isFetchingLocation = false;
  List<String> _attachments = [];

  // Design Tokens (Adaptive Light / Dark Mode)
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF171A19) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textSubtle => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    _selectedWorkplace = widget.preselectedWorkplace;

    _cityController = TextEditingController(
      text: log?.city ?? widget.preselectedWorkplace?.city ?? '',
    );
    _notesController = TextEditingController(text: log?.notes ?? '');

    _selectedDate = log != null
        ? DateTime.tryParse(log.date) ?? DateTime.now()
        : DateTime.now();

    _latitude = log?.latitude;
    _longitude = log?.longitude;
    _locationAddress = log?.locationAddress;
    _attachments = log != null ? List<String>.from(log.attachments) : [];

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final workplaces = await _workplacesRepo.getAllWorkplaces();
    final existingCities = await _workLogsRepo.getDistinctCities();

    final citiesSet = Set<String>.from(existingCities);
    // Popular fallback defaults if user has few entries
    final defaults = ['طمرة', 'مغار', 'القدس', 'كفر كنا', 'سخنين'];
    for (final d in defaults) {
      if (citiesSet.length < 6) citiesSet.add(d);
    }

    if (!mounted) return;

    setState(() {
      final sortedWorkplaces = List<WorkplaceModel>.from(workplaces)
        ..sort((a, b) {
          if (a.isActive && !b.isActive) return -1;
          if (!a.isActive && b.isActive) return 1;
          return 0;
        });
      _allWorkplaces = sortedWorkplaces;
      _recentCities = citiesSet.toList();

      if (_selectedWorkplace == null) {
        if (widget.existingLog?.workplaceId != null) {
          final match = _allWorkplaces
              .where((w) => w.id == widget.existingLog!.workplaceId)
              .firstOrNull;
          _selectedWorkplace = match ?? (_allWorkplaces.isNotEmpty ? _allWorkplaces.first : null);
        } else if (_allWorkplaces.isNotEmpty) {
          final firstActive = _allWorkplaces.where((w) => w.isActive).firstOrNull;
          _selectedWorkplace = firstActive ?? _allWorkplaces.first;
        }
      }

      if (_cityController.text.trim().isNotEmpty) {
        _activePlaceChip = _cityController.text.trim();
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _currentRate {
    if (_overrideDailyRate != null && _overrideDailyRate! > 0) {
      return _overrideDailyRate!;
    }
    if (_selectedWorkplace != null && _selectedWorkplace!.dailyRate > 0) {
      return _selectedWorkplace!.dailyRate;
    }
    if (widget.existingLog != null && widget.existingLog!.rateApplied > 0) {
      return widget.existingLog!.rateApplied;
    }
    return 350.0;
  }

  Future<void> _editDailyRateDialog() async {
    SpendoHaptics.selection();
    final ctrl = TextEditingController(text: _formattedRate);
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
              color: surfaceMain,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: surfaceBorder, width: 1.2),
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
                            color: brandYellow, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'تعديل سعر اليومية (₪)',
                          style: TextStyle(
                            color: textWhite,
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
                            size: 18, color: textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'سيتم تطبيق سعر اليومية الجديد وتحديث جميع أيام العمل المسجلة لهذا المشغّل في السجل تلقائياً.',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceField,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: brandYellow.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'مثال: 350',
                      hintStyle: TextStyle(color: textSubtle, fontSize: 13),
                      suffixText: '₪ / يوم',
                      suffixStyle: const TextStyle(
                        color: brandYellow,
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
                          backgroundColor: brandGreen,
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
                        foregroundColor: textMuted,
                        side: BorderSide(color: surfaceBorder),
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
      setState(() {
        _overrideDailyRate = newRate;
        if (_selectedWorkplace != null) {
          final updatedWp = _selectedWorkplace!.copyWith(
            dailyRate: newRate,
            updatedAt: DateTime.now(),
          );
          _selectedWorkplace = updatedWp;
          _allWorkplaces = _allWorkplaces
              .map((w) => w.id == updatedWp.id ? updatedWp : w)
              .toList();
        }
      });

      if (_selectedWorkplace != null) {
        await _workplacesRepo.cascadeEmployerDailyRate(
          workplaceId: _selectedWorkplace!.id,
          workplaceName: _selectedWorkplace!.name,
          newRate: newRate,
        );
      }
    }
  }

  String get _formattedRate {
    final rate = _currentRate;
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toStringAsFixed(1);
  }

  void _selectPlace(String place) {
    SpendoHaptics.light();
    setState(() {
      _cityController.text = place;
      _activePlaceChip = place;
    });
  }

  void _clearLocation() {
    SpendoHaptics.light();
    setState(() {
      _cityController.clear();
      _activePlaceChip = null;
    });
  }

  Future<void> _pickLocationFromMap() async {
    SpendoHaptics.light();
    final result = await MapLocationPickerScreen.pick(
      context,
      initialLatitude: _latitude,
      initialLongitude: _longitude,
      initialCity: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      initialAddress: _locationAddress,
    );

    if (result != null && mounted) {
      SpendoHaptics.success();
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (result.address != null && result.address!.trim().isNotEmpty) {
          _locationAddress = result.address!.trim();
          if (_cityController.text.trim().isEmpty) {
            _cityController.text = result.address!.trim();
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تثبيت مكان العمل من الخريطة بنجاح'),
          backgroundColor: brandGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _captureCurrentLocation() async {
    SpendoHaptics.light();
    setState(() => _isFetchingLocation = true);

    try {
      final res = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;

      if (res != null) {
        SpendoHaptics.success();
        setState(() {
          _latitude = res.latitude;
          _longitude = res.longitude;
          _isFetchingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تثبيت مكان العمل بنجاح'),
            backgroundColor: brandGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isFetchingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تفعيل الـ GPS وإعطاء إذن الموقع لتحديد مكان العمل'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _openLocationInMap() {
    if (_latitude != null && _longitude != null) {
      SpendoHaptics.light();
      LocationService.openMap(_latitude!, _longitude!);
    }
  }

  void _removeGpsLocation() {
    SpendoHaptics.light();
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationAddress = null;
    });
  }

  Future<void> _takePhoto() async {
    SpendoHaptics.light();
    final path = await AttachmentService.instance.capturePhoto();
    if (path != null && mounted) {
      SpendoHaptics.success();
      setState(() {
        _attachments.add(path);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    SpendoHaptics.light();
    final paths = await AttachmentService.instance.pickImagesFromGallery();
    if (paths.isNotEmpty && mounted) {
      SpendoHaptics.success();
      setState(() {
        _attachments.addAll(paths);
      });
    }
  }

  Future<void> _pickDocument() async {
    SpendoHaptics.light();
    final paths = await AttachmentService.instance.pickDocuments();
    if (paths.isNotEmpty && mounted) {
      SpendoHaptics.success();
      setState(() {
        _attachments.addAll(paths);
      });
    }
  }

  void _removeAttachment(int index) {
    SpendoHaptics.light();
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _viewAttachment(String path, int index) {
    SpendoHaptics.light();
    AttachmentViewerModal.show(
      context,
      filePath: path,
      onDelete: () => _removeAttachment(index),
    );
  }

  Future<void> _pickDate() async {
    final picked = await SpendoDatePicker.pickDate(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ يوم العمل',
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showWorkplacePicker() {
    if (_allWorkplaces.length <= 1) return;
    SpendoHaptics.light();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceMain,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: surfaceBorder, width: 1.2),
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
                          const Icon(Remix.building_2_line, color: brandGreen, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'اختر المشغّل / صاحب العمل',
                            style: TextStyle(
                              color: textWhite,
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
                          child: Icon(Remix.close_line, size: 18, color: textMuted),
                        ),
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
                        final isSelected = wp.id == _selectedWorkplace?.id;
                        return InkWell(
                          onTap: () {
                            SpendoHaptics.selection();
                            setState(() => _selectedWorkplace = wp);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandGreen.withValues(alpha: 0.12)
                                  : surfaceField,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? brandGreen
                                    : surfaceBorder,
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
                                      color: isSelected ? brandGreen : textMuted,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      wp.name,
                                      style: TextStyle(
                                        color: isSelected ? textWhite : textMuted,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                                          color: wp.isActive ? brandGreen : textSubtle,
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
                                    color: surfaceMain,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: surfaceBorder),
                                  ),
                                  child: Text(
                                    '${wp.dailyRate.toInt()} ₪ / يوم',
                                    style: const TextStyle(
                                      color: brandYellow,
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
        );
      },
    );
  }

  Future<void> _saveWorkday() async {
    final location = _cityController.text.trim();
    if (location.isEmpty) {
      SpendoHaptics.light();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة أو اختيار مكان العمل لهذا اليوم'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    SpendoHaptics.success();

    final rate = _currentRate;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dayName = ArabicDateHelper.getArabicWeekday(_selectedDate);

    final log = WorkLogModel(
      id: widget.existingLog?.id ?? const Uuid().v4(),
      workplaceId: _selectedWorkplace?.id,
      workplaceName: _selectedWorkplace?.name ?? 'مشغّل عام',
      personId: _selectedWorkplace?.personId,
      city: location,
      dayName: dayName,
      date: dateStr,
      rateType: 'daily',
      dayFraction: 1.0,
      rateApplied: rate,
      totalEarned: rate,
      amountCollected: 0.0, // الحساب والقبض يتم شهرياً تلقائياً
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      locationAddress: _locationAddress,
      attachments: _attachments,
      createdAt: widget.existingLog?.createdAt ?? DateTime.now(),
    );

    if (_selectedWorkplace != null && rate > 0 && rate != _selectedWorkplace!.dailyRate) {
      await _workplacesRepo.cascadeEmployerDailyRate(
        workplaceId: _selectedWorkplace!.id,
        workplaceName: _selectedWorkplace!.name,
        newRate: rate,
      );
    }

    widget.onSave(log);

    if (mounted) {
      Navigator.pop(context, log);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final bottomNavPadding = media.padding.bottom > 0
        ? media.padding.bottom
        : media.viewPadding.bottom;

    final employerName = _selectedWorkplace?.name ?? 'محدد تلقائياً';
    final dayName = ArabicDateHelper.getArabicWeekday(_selectedDate);
    final relativeDay =
        ArabicDateHelper.getRelativeDayDescription(_selectedDate);
    final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceMain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: surfaceBorder),
            left: BorderSide(color: surfaceBorder),
            right: BorderSide(color: surfaceBorder),
          ),
        ),
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
              // مؤشر السحب العلوي
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF404040).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // الترويسة العلوية + زر الإغلاق بدون خلفية
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Remix.calendar_todo_line,
                          color: brandGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تسجيل يوم عمل جديد',
                              style: TextStyle(
                                color: textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'توثيق يوم العمل وإضافته لحساب الشهر تلقائياً',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Remix.close_line,
                          color: textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 1. المشغّل / صاحب العمل (اختيار مباشر في الأعلى + شارة اليومية)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_allWorkplaces.length > 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Remix.building_2_line,
                                size: 13, color: brandYellow),
                            const SizedBox(width: 5),
                            Text(
                              'اختر المشغّل لهذا اليوم:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: _showWorkplacePicker,
                          child: Row(
                            children: [
                              Text(
                                '(${_allWorkplaces.length} مشغّلين)',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: brandYellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Remix.arrow_down_s_line,
                                  size: 12, color: brandYellow),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _allWorkplaces.map((wp) {
                          final isSelected = wp.id == _selectedWorkplace?.id;
                          final rateStr = wp.dailyRate > 0
                              ? (wp.dailyRate == wp.dailyRate.roundToDouble()
                                  ? '${wp.dailyRate.toInt()} ₪'
                                  : '${wp.dailyRate.toStringAsFixed(1)} ₪')
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: () {
                                SpendoHaptics.selection();
                                setState(() {
                                  _selectedWorkplace = wp;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? brandGreen.withValues(alpha: 0.18)
                                      : surfaceField,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? brandGreen
                                        : surfaceBorder,
                                    width: isSelected ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(Remix.check_line,
                                          size: 13, color: brandGreen),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      wp.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? textWhite
                                            : textMuted,
                                      ),
                                    ),
                                    if (!wp.isActive) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: surfaceMain,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border:
                                              Border.all(color: surfaceBorder),
                                        ),
                                        child: Text(
                                          'منتهي',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: textSubtle,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (rateStr.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? brandGreen.withValues(alpha: 0.32)
                                              : surfaceMain,
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          rateStr,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? textWhite
                                                : brandYellow,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // بطاقة المشغّل المختار الحالية (تأكيد الاختيار بدون قفل)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Remix.building_line,
                                size: 16,
                                color: brandGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'المشغّل المحدد: ',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: textMuted,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        employerName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: textWhite,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // شارة اليومية القابلة للتعديل لتحديث كل السجل
                        InkWell(
                          onTap: _editDailyRateDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: surfaceMain,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: surfaceBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_formattedRate ₪',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: brandYellow,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '/ يوم',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMuted,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Remix.pencil_line,
                                  size: 11,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 2. مكان العمل / الورشة + شريط الأماكن السابقة
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Remix.map_pin_2_line,
                          size: 16,
                          color: brandYellow,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _cityController,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textWhite,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'مكان العمل / البلد لهذا اليوم *',
                              hintStyle: TextStyle(
                                color: textSubtle,
                                fontSize: 11.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 6),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _activePlaceChip = val.trim();
                              });
                            },
                          ),
                        ),
                        if (_cityController.text.isNotEmpty)
                          GestureDetector(
                            onTap: _clearLocation,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Remix.close_circle_line,
                                size: 14,
                                color: textSubtle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // شريط الأماكن السابقة
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Remix.history_line,
                              size: 12,
                              color: brandGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'أماكن سابقة:',
                              style: TextStyle(
                                fontSize: 10,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        ..._recentCities.map((place) {
                          final isSelected = _activePlaceChip == place;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () => _selectPlace(place),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? brandYellow
                                        : surfaceBorder,
                                  ),
                                ),
                                child: Text(
                                  place,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? (_isDark ? brandYellow : const Color(0xFFB45309))
                                        : textMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // موقع العمل على الخريطة (GPS)
              _buildLocationCard(),

              const SizedBox(height: 10),

              // 3. تاريخ يوم العمل (مع اسم اليوم وشارة اليوم وزر التغيير)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Remix.calendar_check_line,
                          size: 18,
                          color: brandGreen,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textWhite,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: surfaceMain,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: surfaceBorder),
                                  ),
                                  child: Text(
                                    relativeDay,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: brandYellow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormatted,
                              style: TextStyle(
                                fontSize: 10,
                                color: textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // زر تغيير التاريخ
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: surfaceMain,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Remix.calendar_event_line,
                              size: 12,
                              color: brandYellow,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'تغيير',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. المبلغ المستحق لليوم (قابل للنقر لتعديل سعر اليومية وتحديث كل السجل)
              InkWell(
                onTap: _editDailyRateDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceField,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: brandGreen.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Remix.wallet_3_line,
                            size: 16,
                            color: brandGreen,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المبلغ المستحق لليوم',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textWhite,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'اضغط لتعديل اليومية وتحديث كل السجل تلقائياً',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // المبلغ المستحق بالـ LTR
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  '₪',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: brandYellow,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _currentRate.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textWhite,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Remix.pencil_line,
                            size: 13,
                            color: textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 5. ملاحظات وتفاصيل العمل (اختياري)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Remix.file_list_3_line,
                      size: 16,
                      color: textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _notesController,
                        style: TextStyle(
                          fontSize: 12,
                          color: textWhite,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ملاحظات وتفاصيل العمل (اختياري)',
                          hintStyle: TextStyle(
                            color: textSubtle,
                            fontSize: 11.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 6. توثيق العمل بالصور والمرفقات (مكيفات، فواتير، كفالات)
              _buildAttachmentsCard(),

              const SizedBox(height: 14),

              // 7. زر حفظ يوم العمل
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: _isSaving ? null : _saveWorkday,
                icon: const Icon(Remix.check_line, size: 16),
                label: const Text(
                  'حفظ يوم العمل',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= موقع العمل على الخريطة (GPS) =================

  Widget _buildLocationCard() {
    final hasLoc = _latitude != null && _longitude != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLoc ? brandGreen.withValues(alpha: 0.5) : surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasLoc ? Remix.map_pin_fill : Remix.map_pin_2_line,
                    size: 16,
                    color: hasLoc ? brandGreen : brandYellow,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLoc ? 'تم تثبيت مكان العمل' : 'موقع العمل على الخريطة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textWhite,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        hasLoc
                            ? (_locationAddress != null && _locationAddress!.isNotEmpty
                                ? _locationAddress!
                                : (_cityController.text.isNotEmpty ? _cityController.text : 'موقع موثّق على الخريطة ✓'))
                            : 'تحديد شارع أو بلد لتتذكر مكان الشغل لاحقاً',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isFetchingLocation)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: brandGreen,
                  ),
                )
              else if (hasLoc)
                GestureDetector(
                  onTap: _removeGpsLocation,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Remix.close_circle_line,
                        size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // خيارات التحديد: تحديد من الخريطة (حتى لو مروّح عالبيت) + موقعي الحالي
          if (!hasLoc)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickLocationFromMap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: brandGreen.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Remix.map_2_line, size: 13, color: brandGreen),
                          const SizedBox(width: 5),
                          Text(
                            'تحديد من الخريطة',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _captureCurrentLocation,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Remix.crosshair_2_line, size: 13, color: brandYellow),
                          const SizedBox(width: 5),
                          Text(
                            'موقعي الحالي',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickLocationFromMap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: surfaceMain,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Remix.edit_line, size: 12, color: brandYellow),
                          const SizedBox(width: 4),
                          Text(
                            'تعديل المكان من الخريطة',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _openLocationInMap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: brandGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: brandGreen.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Remix.google_line, size: 12, color: brandGreen),
                          SizedBox(width: 4),
                          Text(
                            'فتح Google Maps',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: brandGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ================= توثيق العمل بالصور والمرفقات =================

  Widget _buildAttachmentsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
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
                  const Icon(Remix.camera_3_line, size: 16, color: brandGreen),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'توثيق العمل بالصور والمرفقات',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textWhite,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'صور المكيف، الفواتير، الكفالات، أو العقد',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_attachments.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: brandGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: brandGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_attachments.length} مرفق',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: brandGreen,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // أزرار الإضافة السريعة: كاميرا + معرض + ملف
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _takePhoto,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6.5),
                    decoration: BoxDecoration(
                      color: surfaceMain,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Remix.camera_line, size: 13, color: brandYellow),
                        const SizedBox(width: 4),
                        Text(
                          'تصوير كاميرا',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: _pickFromGallery,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6.5),
                    decoration: BoxDecoration(
                      color: surfaceMain,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Remix.image_line, size: 13, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Text(
                          'من المعرض',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: _pickDocument,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6.5),
                    decoration: BoxDecoration(
                      color: surfaceMain,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Remix.file_pdf_2_line, size: 13, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          'ملف / PDF',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // شريط المعاينة للصور المصغرة
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final path = _attachments[idx];
                  final item = AttachmentItem.fromPath(path);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _viewAttachment(path, idx),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: surfaceMain,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: surfaceBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.isImage
                              ? Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Remix.image_line,
                                    color: textMuted,
                                    size: 20,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.isPdf
                                          ? Remix.file_pdf_2_fill
                                          : Remix.file_text_fill,
                                      size: 24,
                                      color: item.isPdf
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF38BDF8),
                                    ),
                                    const SizedBox(height: 2),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(idx),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E2120),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Remix.close_circle_fill,
                              size: 15,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
