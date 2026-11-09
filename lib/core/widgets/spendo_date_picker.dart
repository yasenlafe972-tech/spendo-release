import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

/// Arabic calendar date picker shared across the app.
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

  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DatePickerMode initialDatePickerMode = DatePickerMode.day,
    String? helpText,
    String cancelText = 'إلغاء',
    String confirmText = 'تأكيد التاريخ',
  }) {
    SpendoHaptics.light();
    return _showCalendar(
      context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      isBirthDate: false,
      helpText: helpText ?? 'اختيار التاريخ',
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  static Future<DateTime?> pickBirthDate(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String helpText = 'اختر تاريخ الميلاد',
    String cancelText = 'إلغاء',
    String confirmText = 'تثبيت تاريخ الميلاد',
  }) {
    SpendoHaptics.light();
    final today = DateTime.now();
    final earliest = firstDate ?? DateTime(1930, 1, 1);
    final latest = lastDate ?? DateTime(today.year, today.month, today.day);
    final requested = initialDate ?? DateTime(today.year - 25, 1, 1);
    final safeInitial =
        requested.isAfter(latest)
            ? latest
            : (requested.isBefore(earliest) ? earliest : requested);

    return _showCalendar(
      context,
      initialDate: safeInitial,
      firstDate: earliest,
      lastDate: latest,
      isBirthDate: true,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  static Future<DateTime?> _showCalendar(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required bool isBirthDate,
    required String helpText,
    required String cancelText,
    required String confirmText,
  }) {
    final safeInitial =
        initialDate.isBefore(firstDate)
            ? firstDate
            : (initialDate.isAfter(lastDate) ? lastDate : initialDate);
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder:
          (context) => _SpendoCalendarSheet(
            initialDate: safeInitial,
            firstDate: firstDate,
            lastDate: lastDate,
            isBirthDate: isBirthDate,
            helpText: helpText,
            cancelText: cancelText,
            confirmText: confirmText,
          ),
    );
  }
}

class _SpendoCalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isBirthDate;
  final String helpText;
  final String cancelText;
  final String confirmText;

  const _SpendoCalendarSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.isBirthDate,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
  });

  @override
  State<_SpendoCalendarSheet> createState() => _SpendoCalendarSheetState();
}

class _SpendoCalendarSheetState extends State<_SpendoCalendarSheet> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  static const Color _teal = Color(0xFF0F766E);
  static const Color _gold = Color(0xFFD6AD52);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _background => _isDark ? const Color(0xFF101114) : Colors.white;
  Color get _surface =>
      _isDark ? const Color(0xFF18191D) : const Color(0xFFF5F6F7);
  Color get _border =>
      _isDark ? const Color(0xFF292B31) : const Color(0xFFE2E5E9);
  Color get _primaryText =>
      _isDark ? const Color(0xFFF4F4F5) : const Color(0xFF181A1F);
  Color get _mutedText =>
      _isDark ? const Color(0xFF9296A1) : const Color(0xFF747985);
  Color get _quietText =>
      _isDark ? const Color(0xFF5D626D) : const Color(0xFFADB2BB);

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isAllowed(DateTime date) {
    final day = _dateOnly(date);
    return !day.isBefore(_dateOnly(widget.firstDate)) &&
        !day.isAfter(_dateOnly(widget.lastDate));
  }

  int _saturdayFirstWeekday(DateTime date) {
    // Dart: Monday = 1; this calendar starts with Saturday.
    return (date.weekday + 1) % 7;
  }

  bool _monthIsAllowed(int year, int month) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    return !last.isBefore(_dateOnly(widget.firstDate)) &&
        !first.isAfter(_dateOnly(widget.lastDate));
  }

  bool _canMoveMonth(int delta) {
    final candidate = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + delta,
      1,
    );
    return _monthIsAllowed(candidate.year, candidate.month);
  }

  void _moveMonth(int delta) {
    if (!_canMoveMonth(delta)) return;
    SpendoHaptics.selection();
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  void _chooseDay(DateTime day) {
    if (!_isAllowed(day)) return;
    SpendoHaptics.selection();
    setState(() {
      _selectedDate = _dateOnly(day);
      _visibleMonth = DateTime(day.year, day.month, 1);
    });
  }

  Future<void> _chooseMonth() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: _ChoiceSheet(
              title: 'اختيار الشهر',
              background: _background,
              surface: _surface,
              border: _border,
              primaryText: _primaryText,
              mutedText: _mutedText,
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 46,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final enabled = _monthIsAllowed(_visibleMonth.year, month);
                  final selected = month == _visibleMonth.month;
                  return _ChoiceTile(
                    label: SpendoDatePicker.arabicMonths[index],
                    enabled: enabled,
                    selected: selected,
                    teal: _teal,
                    surface: _surface,
                    border: _border,
                    primaryText: _primaryText,
                    quietText: _quietText,
                    onTap: () => Navigator.pop(sheetContext, month),
                  );
                },
              ),
            ),
          ),
    );

    if (!mounted || picked == null) return;
    SpendoHaptics.light();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, picked, 1);
    });
  }

  Future<void> _chooseYear() async {
    final yearCount = widget.lastDate.year - widget.firstDate.year + 1;
    final selectedRow = (widget.lastDate.year - _visibleMonth.year) ~/ 4;
    final yearScrollController = ScrollController(
      initialScrollOffset: (selectedRow * 54).toDouble(),
    );
    int? picked;
    try {
      picked = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (sheetContext) => Directionality(
              textDirection: TextDirection.rtl,
              child: _ChoiceSheet(
                title: 'اختيار السنة',
                background: _background,
                surface: _surface,
                border: _border,
                primaryText: _primaryText,
                mutedText: _mutedText,
                child: GridView.builder(
                  controller: yearScrollController,
                  shrinkWrap: true,
                  itemCount: yearCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: 46,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final year = widget.lastDate.year - index;
                    final selected = year == _visibleMonth.year;
                    return _ChoiceTile(
                      label: year.toString(),
                      enabled: true,
                      selected: selected,
                      teal: _teal,
                      surface: _surface,
                      border: _border,
                      primaryText: _primaryText,
                      quietText: _quietText,
                      onTap: () => Navigator.pop(sheetContext, year),
                    );
                  },
                ),
              ),
            ),
      );
    } finally {
      yearScrollController.dispose();
    }

    final selectedYear = picked;
    if (!mounted || selectedYear == null) return;
    SpendoHaptics.light();
    var month = _visibleMonth.month;
    if (!_monthIsAllowed(selectedYear, month)) {
      month = List<int>.generate(
        12,
        (index) => index + 1,
      ).firstWhere((candidate) => _monthIsAllowed(selectedYear, candidate));
    }
    setState(() {
      _visibleMonth = DateTime(selectedYear, month, 1);
    });
  }

  int _ageFor(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  String _weekdayName(DateTime date) {
    const names = [
      'السبت',
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    ];
    return names[_saturdayFirstWeekday(date)];
  }

  @override
  Widget build(BuildContext context) {
    final monthName = SpendoDatePicker.arabicMonths[_visibleMonth.month - 1];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: _background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 28,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildSelectedDate(),
                  const SizedBox(height: 16),
                  _buildMonthNavigation(monthName),
                  const SizedBox(height: 8),
                  _buildWeekdayLabels(),
                  const SizedBox(height: 4),
                  _buildDaysGrid(),
                  const SizedBox(height: 14),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _teal.withValues(alpha: 0.3)),
          ),
          child: Icon(
            widget.isBirthDate ? Remix.cake_2_line : Remix.calendar_2_line,
            color: _teal,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.helpText,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _primaryText,
                ),
              ),
              Text(
                'اختر السنة والشهر ثم اضغط اليوم',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  color: _mutedText,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: _surface,
          shape: CircleBorder(side: BorderSide(color: _border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(Remix.close_line, size: 17, color: _mutedText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDate() {
    final monthName = SpendoDatePicker.arabicMonths[_selectedDate.month - 1];
    final dateText =
        '${_weekdayName(_selectedDate)}، ${_selectedDate.day} $monthName ${_selectedDate.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedDate.day.toString(),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _teal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: _teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isBirthDate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _gold.withValues(alpha: 0.5)),
              ),
              child: Text(
                // ignore: prefer_interpolation_to_compose_strings
                _ageFor(_selectedDate).toString() + ' سنة',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: _gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation(String monthName) {
    return Row(
      children: [
        _navigationButton(
          icon: Remix.arrow_right_s_line,
          tooltip: 'الشهر السابق',
          enabled: _canMoveMonth(-1),
          onTap: () => _moveMonth(-1),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _selectorButton(
                  label: monthName,
                  icon: Remix.arrow_down_s_line,
                  onTap: _chooseMonth,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _selectorButton(
                  label: _visibleMonth.year.toString(),
                  icon: Remix.arrow_down_s_line,
                  onTap: _chooseYear,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _navigationButton(
          icon: Remix.arrow_left_s_line,
          tooltip: 'الشهر التالي',
          enabled: _canMoveMonth(1),
          onTap: () => _moveMonth(1),
        ),
      ],
    );
  }

  Widget _selectorButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: _primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(icon, size: 17, color: _teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigationButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _border),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20),
        color: _teal,
        disabledColor: _quietText,
        constraints: const BoxConstraints.tightFor(width: 43, height: 43),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    return Row(
      children:
          SpendoDatePicker.arabicWeekdays.map((label) {
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _mutedText,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final offset = _saturdayFirstWeekday(firstOfMonth);
    final gridStart = firstOfMonth.subtract(Duration(days: offset));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final date = gridStart.add(Duration(days: index));
        final inCurrentMonth = date.month == _visibleMonth.month;
        final selected = DateUtils.isSameDay(date, _selectedDate);
        final today = DateUtils.isSameDay(date, DateTime.now());
        final allowed = _isAllowed(date);
        final color =
            selected ? Colors.white : (allowed ? _primaryText : _quietText);

        return Material(
          color:
              selected
                  ? _teal
                  : (today
                      ? _gold.withValues(alpha: 0.12)
                      : Colors.transparent),
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: allowed ? () => _chooseDay(date) : null,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border:
                    today && !selected
                        ? Border.all(color: _gold, width: 1)
                        : null,
              ),
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight:
                      selected || today ? FontWeight.w800 : FontWeight.w600,
                  color:
                      inCurrentMonth
                          ? color
                          : (allowed ? _mutedText : _quietText),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _mutedText,
              side: BorderSide(color: _border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              widget.cancelText,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () {
              SpendoHaptics.success();
              Navigator.pop(context, _selectedDate);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(Remix.check_line, size: 18),
            label: Text(
              widget.confirmText,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  final String title;
  final Color background;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color mutedText;
  final Widget child;

  const _ChoiceSheet({
    required this.title,
    required this.background,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.mutedText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool selected;
  final Color teal;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color quietText;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.teal,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.quietText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? teal.withValues(alpha: 0.18) : surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? teal : border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: !enabled ? quietText : (selected ? teal : primaryText),
            ),
          ),
        ),
      ),
    );
  }
}
