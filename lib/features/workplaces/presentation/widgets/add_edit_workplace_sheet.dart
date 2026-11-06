import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';

/// Modal bottom sheet for adding or editing a Workplace (`مكان عمل / ورشة`).
///
/// Features:
/// - Workplace Name (`اسم مكان العمل / الورشة *`)
/// - City / Town (`اسم البلد / المدينة *`) with quick Palestine city chips
/// - Agreed Daily Rate (`سعر اليومية المتفق عليه لهذه الورشة (₪) *`)
/// - Default Hourly Rate (`سعر الساعة (₪)`)
/// - Responsible Contractor/Employer (`المشغل / المقاول المسؤول`, optional dropdown)
/// - Notes (`ملاحظات`)
///
/// Adheres strictly to Spendo design tokens, safe area clearance for Android
/// 3-button navigation, and smooth bouncing scroll physics with on-drag keyboard dismiss.
class AddEditWorkplaceSheet extends StatefulWidget {
  final WorkplaceModel? workplace;
  final Function(WorkplaceModel)? onSave;

  const AddEditWorkplaceSheet({
    super.key,
    this.workplace,
    this.onSave,
  });

  /// Convenient static helper to show the sheet as a modal bottom sheet.
  static Future<WorkplaceModel?> show(
    BuildContext context, {
    WorkplaceModel? workplace,
    Function(WorkplaceModel)? onSave,
  }) {
    return showModalBottomSheet<WorkplaceModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => AddEditWorkplaceSheet(
        workplace: workplace,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditWorkplaceSheet> createState() => _AddEditWorkplaceSheetState();
}

class _AddEditWorkplaceSheetState extends State<AddEditWorkplaceSheet> {
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF141417) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF101014) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF202026) : const Color(0xFFE5E7EB);
  static Color get textWhite => _isDark ? const Color(0xFFF4F4F5) : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  final _formKey = GlobalKey<FormState>();
  final PeopleRepository _peopleRepo = PeopleRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _dailyRateController;
  late final TextEditingController _notesController;
  late String _status;

  List<PersonModel> _peopleList = [];
  PersonModel? _selectedContractor;
  bool _isLoadingPeople = true;

  // Quick Palestinian cities suggestions
  static const List<String> _popularCities = [
    'القدس',
    'رام الله',
    'بيت لحم',
    'الخليل',
    'نابلس',
    'أريحا',
    'جنين',
  ];

  @override
  void initState() {
    super.initState();
    final wp = widget.workplace;

    _nameController = TextEditingController(text: wp?.name ?? '');
    _cityController = TextEditingController(text: wp?.city ?? '');
    _dailyRateController = TextEditingController(
      text: wp != null && wp.dailyRate > 0 ? wp.dailyRate.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: wp?.notes ?? '');
    _status = wp?.status ?? 'active';

    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final all = await _peopleRepo.getAllPeople();
      if (!mounted) return;
      setState(() {
        // Filter out "isUser" so only actual workers/contractors appear
        _peopleList = all.where((p) => !p.isUser).toList();

        if (widget.workplace?.contractorId != null) {
          final matched = _peopleList.where((p) => p.id == widget.workplace!.contractorId);
          if (matched.isNotEmpty) {
            _selectedContractor = matched.first;
          }
        }
        _isLoadingPeople = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPeople = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _dailyRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final dailyRate = double.tryParse(_dailyRateController.text.trim()) ?? 0.0;
    final notesText = _notesController.text.trim();
    final notes = notesText.isNotEmpty ? notesText : null;

    final now = DateTime.now();

    final result = WorkplaceModel(
      id: widget.workplace?.id ?? const Uuid().v4(),
      name: name,
      city: city,
      dailyRate: dailyRate,
      hourlyRate: 0.0,
      contractorId: _selectedContractor?.id,
      contractorName: _selectedContractor?.name,
      notes: notes,
      status: _status,
      createdAt: widget.workplace?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave?.call(result);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.workplace != null;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomNavPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: surfaceBorder,
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: keyboardInset > 0
                ? keyboardInset
                : (bottomNavPadding > 0 ? bottomNavPadding + 12 : 20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. FIXED TOP DRAG HANDLE (Slides bottom sheet down when dragged)
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF272730) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. FIXED TOP HEADER BAR (Row with close X, centered title, and balancer)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: surfaceField,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceBorder),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          color: textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEditing ? 'تعديل بيانات المشغّل (מעסיק)' : 'إضافة مشغّل جديد (מעסיק)',
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'توثيق بيانات المشغّل واليومية المتفق عليها',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. SCROLLABLE FORM CONTENT (ClampingScrollPhysics - No bounce void)
              Flexible(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is OverscrollNotification && notification.overscroll < -12) {
                      Navigator.of(context).maybePop();
                      return true;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(
                      left: 18,
                      right: 18,
                      bottom: 12,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Workplace Name Field
                          TextFormField(
                            controller: _nameController,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: textWhite, fontSize: 14.5),
                    decoration: _inputDecoration(
                      label: 'اسم المشغّل أو الشركة (מעסיק) *',
                      icon: Icons.domain_rounded,
                      hint: 'مثال: لا في חשמל، شركة الأفق...',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم المشغّل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. City / Town Field (Optional)
                  TextFormField(
                    controller: _cityController,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: textWhite, fontSize: 14.5),
                    decoration: _inputDecoration(
                      label: 'البلد / المقر الرئيسي (اختياري)',
                      icon: Icons.location_on_outlined,
                      hint: 'مثال: القدس، رام الله، أو تركه فارغاً...',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick City Chips Suggestions
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _popularCities.map((city) {
                        final isSelected = _cityController.text.trim() == city;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            label: Text(city),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: isSelected
                                ? const Color(0xFF1E1E26)
                                : surfaceField,
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF2C2C38)
                                  : surfaceBorder,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            onPressed: () {
                              setState(() {
                                _cityController.text = city;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Daily Rate * (Full width)
                  TextFormField(
                    controller: _dailyRateController,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      color: textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                    decoration: _inputDecoration(
                      label: 'سعر اليومية المتفق عليه (₪) *',
                      icon: Icons.payments_outlined,
                      hint: '350',
                      suffixText: '₪ / يوم',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'سعر اليومية مطلوب';
                      }
                      final rate = double.tryParse(val.trim());
                      if (rate == null || rate <= 0) {
                        return 'قيمة غير صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 5. Responsible Contractor / Employer (Dropdown, optional)
                  if (_isLoadingPeople)
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: surfaceField,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: surfaceBorder),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerRight,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.spendoGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'جاري تحميل قائمة المشغلين...',
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<PersonModel?>(
                      key: ValueKey(_selectedContractor?.id ?? 'none'),
                      initialValue: _selectedContractor,
                      dropdownColor: surfaceMain,
                      style: TextStyle(color: textWhite, fontSize: 14),
                      decoration: _inputDecoration(
                        label: 'المشغل / المقاول المسؤول',
                        icon: Icons.engineering_outlined,
                        hint: 'اختيار مقاول مسؤول (اختياري)',
                      ),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.iconMuted),
                      items: [
                        DropdownMenuItem<PersonModel?>(
                          value: null,
                          child: Text(
                            'بدون تحديد (اختياري)',
                            style: TextStyle(color: textMuted, fontSize: 13.5),
                          ),
                        ),
                        ..._peopleList.map((person) {
                          return DropdownMenuItem<PersonModel?>(
                            value: person,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: AppColors.avatarBackground,
                                  child: Text(
                                    person.name.characters.first,
                                    style: const TextStyle(
                                      color: AppColors.spendoGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  person.name,
                                  style: TextStyle(
                                    color: textWhite,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedContractor = val;
                        });
                      },
                    ),
                  const SizedBox(height: 14),

                  // Status Selector (نشط / غير نشط - مدمج في سطر واحد)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'حالة العمل مع المشغّل',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _status = 'active'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _status == 'active'
                                  ? AppColors.spendoGreen.withValues(alpha: 0.15)
                                  : surfaceField,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _status == 'active'
                                    ? AppColors.spendoGreen
                                    : const Color(0xFF272730),
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
                                    color: AppColors.spendoGreen,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'نشط',
                                  style: TextStyle(
                                    color: _status == 'active'
                                        ? AppColors.spendoGreen
                                        : AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _status = 'completed'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _status == 'completed'
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : surfaceField,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _status == 'completed'
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : const Color(0xFF272730),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: textWhite,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'غير نشط',
                                  style: TextStyle(
                                    color: _status == 'completed'
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
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

                  // 6. Notes Field (Optional, Multiline)
                  TextFormField(
                    controller: _notesController,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(color: textWhite, fontSize: 14),
                    decoration: _inputDecoration(
                      label: 'ملاحظات',
                      icon: Icons.edit_note_rounded,
                      hint: 'أي تفاصيل إضافية عن مكان العمل، الموقع الدقيق، أو شروط العمل...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Action Button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 19),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'حفظ تعديلات المشغّل' : 'إضافة المشغّل',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
),
);
}

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textMuted, fontSize: 13),
      hintText: hint,
      hintStyle: TextStyle(
        color: textMuted,
        fontSize: 12,
      ),
      suffixText: suffixText,
      suffixStyle: TextStyle(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: textMuted, size: 19),
      filled: true,
      fillColor: surfaceField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: surfaceBorder, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.dangerRed, width: 1.5),
      ),
    );
  }
}
