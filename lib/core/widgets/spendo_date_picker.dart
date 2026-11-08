import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

/// A luxury, GitHub & Revolut-inspired FinTech DatePicker for Spendo.
///
/// Features:
/// 1. Dual Mode: Smooth 3D Cupertino Wheels & Modern Arabic Calendar Grid.
/// 2. Signature Amber / Gold (#F59E0B) branding matching Spendo FinTech identity.
/// 3. Live Age and Relative Date Showcase.
/// 4. Quick Jump Presets for Birthdates and Transactions.
/// 5. 100% Native Arabic Localization (Weekdays & Months).
class SpendoDatePicker {
  SpendoDatePicker._();

  static const List<String> arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> arabicWeekdays = [
    'سبت',
    'أحد',
    'إثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
  ];

  /// Standard date picker for work logs, payments, vehicle logs, and debts.
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DatePickerMode initialDatePickerMode = DatePickerMode.day,
    String? helpText,
    String cancelText = 'إلغاء',
    String confirmText = 'تأكيد التاريخ',
  }) async {
    SpendoHaptics.light();
    return _showModalPicker(
      context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      isBirthDate: false,
      helpText: helpText ?? 'تحديد وتأكيد التاريخ',
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  /// Specialized birth date picker: starts in Wheel mode with quick age presets
  /// and live age badge calculation.
  static Future<DateTime?> pickBirthDate(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String helpText = 'اختر وتأكيد تاريخ الميلاد',
    String cancelText = 'إلغاء',
    String confirmText = 'تثبيت تاريخ الميلاد',
  }) async {
    SpendoHaptics.light();
    final now = DateTime.now();
    final effectiveFirst = firstDate ?? DateTime(1930, 1, 1);
    final effectiveLast = lastDate ?? now;
    final effectiveInitial = initialDate ?? DateTime(now.year - 25, 1, 1);

    final clampedInitial = effectiveInitial.isAfter(effectiveLast)
        ? effectiveLast
        : (effectiveInitial.isBefore(effectiveFirst)
            ? effectiveFirst
            : effectiveInitial);

    return _showModalPicker(
      context,
      initialDate: clampedInitial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      isBirthDate: true,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  static Future<DateTime?> _showModalPicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required bool isBirthDate,
    required String helpText,
    required String cancelText,
    required String confirmText,
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        return _SpendoDatePickerSheet(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          isBirthDate: isBirthDate,
          helpText: helpText,
          cancelText: cancelText,
          confirmText: confirmText,
        );
      },
    );
  }
}

class _SpendoDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isBirthDate;
  final String helpText;
  final String cancelText;
  final String confirmText;

  const _SpendoDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.isBirthDate,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
  });

  @override
  State<_SpendoDatePickerSheet> createState() => _SpendoDatePickerSheetState();
}

class _SpendoDatePickerSheetState extends State<_SpendoDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _calendarViewMonth;
  bool _useWheelMode = true;

  // Controllers for CupertinoPickers
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  static const Color brandYellow = Color(0xFFF59E0B);
  static const Color brandGreen = Color(0xFF10B981);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get surfaceMain =>
      _isDark ? const Color(0xFF0F0F12) : const Color(0xFFFFFFFF);
  Color get surfaceField =>
      _isDark ? const Color(0xFF17171C) : const Color(0xFFF4F5F7);
  Color get surfaceBorder =>
      _isDark ? const Color(0xFF262630) : const Color(0xFFE5E7EB);
  Color get textPrimary =>
      _isDark ? Colors.white : const Color(0xFF111827);
  Color get textMuted =>
      _isDark ? const Color(0xFF8E8E9A) : const Color(0xFF6B7280);
  Color get textSubtle =>
      _isDark ? const Color(0xFF5E5E68) : const Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _calendarViewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    // Birthdays default to wheels; standard dates default to calendar
    _useWheelMode = widget.isBirthDate;

    _initControllers();
  }

  void _initControllers() {
    final dayIndex = _selectedDate.day - 1;
    final monthIndex = _selectedDate.month - 1;
    final yearIndex = _selectedDate.year - widget.firstDate.year;

    _dayController = FixedExtentScrollController(initialItem: dayIndex);
    _monthController = FixedExtentScrollController(initialItem: monthIndex);
    _yearController = FixedExtentScrollController(
      initialItem: yearIndex.clamp(0, widget.lastDate.year - widget.firstDate.year),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int _daysInCurrentSelection(int year, int month) {
    return DateUtils.getDaysInMonth(year, month);
  }

  void _onWheelChanged() {
    final year = widget.firstDate.year + _yearController.selectedItem;
    final month = (_monthController.selectedItem + 1).clamp(1, 12);
    final maxDays = _daysInCurrentSelection(year, month);
    final day = (_dayController.selectedItem + 1).clamp(1, maxDays);

    DateTime candidate = DateTime(year, month, day);
    if (candidate.isAfter(widget.lastDate)) candidate = widget.lastDate;
    if (candidate.isBefore(widget.firstDate)) candidate = widget.firstDate;

    setState(() {
      _selectedDate = candidate;
      _calendarViewMonth = DateTime(candidate.year, candidate.month, 1);
    });
  }

  void _jumpToDate(DateTime date) {
    DateTime clamped = date;
    if (clamped.isAfter(widget.lastDate)) clamped = widget.lastDate;
    if (clamped.isBefore(widget.firstDate)) clamped = widget.firstDate;

    setState(() {
      _selectedDate = clamped;
      _calendarViewMonth = DateTime(clamped.year, clamped.month, 1);
    });

    final dayIndex = clamped.day - 1;
    final monthIndex = clamped.month - 1;
    final yearIndex = clamped.year - widget.firstDate.year;

    if (_dayController.hasClients) _dayController.jumpToItem(dayIndex);
    if (_monthController.hasClients) _monthController.jumpToItem(monthIndex);
    if (_yearController.hasClients) _yearController.jumpToItem(yearIndex);

    SpendoHaptics.light();
  }

  int _calculateAge(DateTime birthdate) {
    final now = DateTime.now();
    int age = now.year - birthdate.year;
    if (now.month < birthdate.month ||
        (now.month == birthdate.month && now.day < birthdate.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  String _formatArabicFullDate(DateTime date) {
    final weekday = SpendoDatePicker.arabicWeekdays[_getArabicWeekdayIndex(date)];
    final monthName = SpendoDatePicker.arabicMonths[date.month - 1];
    return '$weekday، ${date.day} $monthName ${date.year}';
  }

  int _getArabicWeekdayIndex(DateTime date) {
    // DateTime.monday = 1 ... DateTime.sunday = 7
    // Spendo: سبت (0), أحد (1), إثنين (2), ثلاثاء (3), أربعاء (4), خميس (5), جمعة (6)
    switch (date.weekday) {
      case DateTime.saturday:
        return 0;
      case DateTime.sunday:
        return 1;
      case DateTime.monday:
        return 2;
      case DateTime.tuesday:
        return 3;
      case DateTime.wednesday:
        return 4;
      case DateTime.thursday:
        return 5;
      case DateTime.friday:
        return 6;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomNavPadding = media.padding.bottom > 0
        ? media.padding.bottom
        : media.viewPadding.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          decoration: BoxDecoration(
            color: surfaceMain,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: bottomNavPadding > 0 ? bottomNavPadding + 8 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. مقبض السحب العلوي
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: surfaceBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2. ترويسة منتقي التاريخ الفينتك
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // أيقونة خضراء
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: brandGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: brandGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        widget.isBirthDate
                            ? Remix.cake_2_line
                            : Remix.calendar_2_line,
                        size: 18,
                        color: brandGreen,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // عنوان المنتقي
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.helpText,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            widget.isBirthDate
                                ? 'مرر العجلات لاختيار اليوم والشهر والسنة وحساب العمر'
                                : 'اختر التاريخ من التقويم أو عجلات التمرير',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // مفتاح التبديل (عجلات / تقويم)
                    InkWell(
                      onTap: () {
                        SpendoHaptics.light();
                        setState(() {
                          _useWheelMode = !_useWheelMode;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: surfaceField,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _useWheelMode
                                  ? Remix.calendar_event_line
                                  : Remix.compass_discover_line,
                              size: 13,
                              color: brandYellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _useWheelMode ? 'تقويم' : 'عجلات',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: brandYellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // زر الإغلاق
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: surfaceBorder.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Remix.close_line, size: 16, color: textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. بطاقة المعاينة الفينتك (Hero Bento Date & Age Card)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceField,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: brandGreen.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: brandGreen.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatArabicFullDate(_selectedDate),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: brandGreen,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isBirthDate)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: brandYellow.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: brandYellow.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Remix.cake_2_line,
                                  size: 13, color: brandYellow),
                              const SizedBox(width: 4),
                              Text(
                                '${_calculateAge(_selectedDate)} سنة',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: brandYellow,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 4. جسم المنتقي الرئيسي: عجلات دوارة ثلاثية أو تقويم شهري
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _useWheelMode
                    ? _buildCupertinoWheelPicker()
                    : _buildCalendarGrid(),
              ),

              const SizedBox(height: 12),

              // 5. أزرار التأكيد والإلغاء (زر فينتك مميز)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          SpendoHaptics.success();
                          Navigator.pop(context, _selectedDate);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: brandGreen,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: brandGreen.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Remix.check_line,
                                size: 18,
                                color: Color(0xFF0A0B0B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.confirmText,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A0B0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: surfaceField,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: surfaceBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.cancelText,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupertinoWheelPicker() {
    final maxDays = _daysInCurrentSelection(
      _selectedDate.year,
      _selectedDate.month,
    );
    final totalYears = widget.lastDate.year - widget.firstDate.year + 1;

    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // مؤشر الاختيار المضيء باللون الذهبي
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: brandYellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: brandYellow.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
          ),
          // العجلات الثلاث: اليوم / الشهر / السنة
          Row(
            children: [
              // 1. عجلة اليوم
              Expanded(
                flex: 3,
                child: CupertinoPicker.builder(
                  scrollController: _dayController,
                  itemExtent: 38,
                  magnification: 1.15,
                  useMagnifier: true,
                  squeeze: 1.1,
                  childCount: maxDays,
                  onSelectedItemChanged: (index) {
                    SpendoHaptics.selection();
                    _onWheelChanged();
                  },
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSel = day == _selectedDate.day;
                    return Center(
                      child: Text(
                        day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isSel ? 16 : 13,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? brandGreen : textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),

              Container(width: 1, height: 120, color: surfaceBorder),

              // 2. عجلة الشهر باللغة العربية
              Expanded(
                flex: 5,
                child: CupertinoPicker.builder(
                  scrollController: _monthController,
                  itemExtent: 38,
                  magnification: 1.15,
                  useMagnifier: true,
                  squeeze: 1.1,
                  childCount: 12,
                  onSelectedItemChanged: (index) {
                    SpendoHaptics.selection();
                    _onWheelChanged();
                  },
                  itemBuilder: (context, index) {
                    final monthName = SpendoDatePicker.arabicMonths[index];
                    final isSel = index + 1 == _selectedDate.month;
                    return Center(
                      child: Text(
                        '${(index + 1).toString().padLeft(2, '0')} - $monthName',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isSel ? 14 : 12,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? brandYellow : textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),

              Container(width: 1, height: 120, color: surfaceBorder),

              // 3. عجلة السنة
              Expanded(
                flex: 4,
                child: CupertinoPicker.builder(
                  scrollController: _yearController,
                  itemExtent: 38,
                  magnification: 1.15,
                  useMagnifier: true,
                  squeeze: 1.1,
                  childCount: totalYears,
                  onSelectedItemChanged: (index) {
                    SpendoHaptics.selection();
                    _onWheelChanged();
                  },
                  itemBuilder: (context, index) {
                    final year = widget.firstDate.year + index;
                    final isSel = year == _selectedDate.year;
                    return Center(
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: isSel ? 16 : 13,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? brandGreen : textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = _calendarViewMonth.year;
    final month = _calendarViewMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOfMonth = DateTime(year, month, 1);
    final startWeekdayOffset = _getArabicWeekdayIndex(firstDayOfMonth);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        children: [
          // شريط التنقل بين الشهور
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  SpendoHaptics.light();
                  setState(() {
                    _calendarViewMonth = DateTime(year, month - 1, 1);
                  });
                },
                icon: const Icon(Remix.arrow_right_s_line, size: 20),
                color: brandGreen,
                tooltip: 'الشهر السابق',
              ),
              Text(
                '${SpendoDatePicker.arabicMonths[month - 1]} $year',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              IconButton(
                onPressed: () {
                  SpendoHaptics.light();
                  setState(() {
                    _calendarViewMonth = DateTime(year, month + 1, 1);
                  });
                },
                icon: const Icon(Remix.arrow_left_s_line, size: 20),
                color: brandGreen,
                tooltip: 'الشهر القادم',
              ),
            ],
          ),
          const SizedBox(height: 6),

          // أسماء أيام الأسبوع العربية
          Row(
            children: SpendoDatePicker.arabicWeekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // شبكة أيام الشهر
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekdayOffset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekdayOffset) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - startWeekdayOffset + 1;
              final cellDate = DateTime(year, month, dayNumber);
              final isSelected = cellDate.year == _selectedDate.year &&
                  cellDate.month == _selectedDate.month &&
                  cellDate.day == _selectedDate.day;
              final isToday = DateUtils.isSameDay(cellDate, DateTime.now());
              final isDisabled = cellDate.isAfter(widget.lastDate) ||
                  cellDate.isBefore(widget.firstDate);

              return InkWell(
                onTap: isDisabled
                    ? null
                    : () {
                        _jumpToDate(cellDate);
                      },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? brandGreen
                        : (isToday
                            ? brandYellow.withValues(alpha: 0.15)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: brandYellow, width: 1.0)
                        : null,
                  ),
                  child: Text(
                    dayNumber.toString(),
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight:
                          isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0A0B0B)
                          : (isDisabled ? textSubtle : textPrimary),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
