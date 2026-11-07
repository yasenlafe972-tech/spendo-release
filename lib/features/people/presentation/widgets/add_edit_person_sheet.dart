import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/widgets/spendo_date_picker.dart';
import 'package:sanad_app/features/people/models/person_model.dart';

class AddEditPersonSheet extends StatefulWidget {
  final PersonModel? person;
  final Function(PersonModel) onSave;

  const AddEditPersonSheet({
    super.key,
    this.person,
    required this.onSave,
  });

  @override
  State<AddEditPersonSheet> createState() => _AddEditPersonSheetState();
}

class _AddEditPersonSheetState extends State<AddEditPersonSheet> {
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF16161A) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF222229) : const Color(0xFFE5E7EB);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _nationalIdController;
  late TextEditingController _notesController;

  DateTime? _selectedBirthdate;
  bool _isUser = false;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _nameController = TextEditingController(text: p?.name ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? p?.whatsapp ?? '');
    _nationalIdController = TextEditingController(text: p?.nationalId ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
    _selectedBirthdate = p?.birthdate;
    _isUser = p?.isUser ?? false;
    _isPinned = p?.isPinned ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await SpendoDatePicker.pickBirthDate(
      context,
      initialDate: _selectedBirthdate,
    );
    if (picked != null) {
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final phoneVal = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

    final person = PersonModel(
      id: widget.person?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      isUser: _isUser,
      birthdate: _selectedBirthdate,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phone: phoneVal,
      whatsapp: phoneVal,
      nationalId: _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
      bank: widget.person?.bank,
      accountNumber: widget.person?.accountNumber,
      isPinned: _isPinned,
      dailyRate: widget.person?.dailyRate ?? 0.0,
      hourlyRate: widget.person?.hourlyRate ?? 0.0,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: widget.person?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave(person);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: surfaceBorder, width: 1.2),
          left: BorderSide(color: surfaceBorder, width: 1.2),
          right: BorderSide(color: surfaceBorder, width: 1.2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. FIXED TOP DRAG HANDLE
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

              // 2. FIXED TOP HEADER BAR
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
                          border: Border.all(color: const Color(0xFF272730)),
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
                      child: Text(
                        widget.person == null ? 'إضافة شخص جديد' : 'تعديل بيانات الشخص',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: textWhite,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. SCROLLABLE FORM (ClampingScrollPhysics - No bounce void)
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
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Name Field
                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل *',
                    hint: 'مثال: أحمد لافي',
                    icon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 10),

                  // 2. Phone / WhatsApp
                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف / الواتساب',
                    hint: 'مثال: 0528841200',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),

                  // 3. National ID
                  _buildTextField(
                    controller: _nationalIdController,
                    label: 'رقم الهوية',
                    hint: 'مثال: 308441920',
                    icon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),

                  // 4. Email
                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني (GMAIL)',
                    hint: 'مثال: ahmad.lafi@gmail.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),

                  // 5. Birthdate Selector
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceField,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.monoIcon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تاريخ الميلاد',
                                  style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedBirthdate == null
                                      ? 'اضغط لاختيار تاريخ الميلاد'
                                      : DateFormat('yyyy-MM-dd').format(_selectedBirthdate!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedBirthdate == null ? AppColors.textMuted : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedBirthdate != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                              onPressed: () => setState(() => _selectedBirthdate = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 6. Notes
                  _buildTextField(
                    controller: _notesController,
                    label: 'ملاحظات',
                    hint: 'ملاحظات إضافية عن الشخص...',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // 9. Toggle (Is You)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'هذا ملفي الشخصي (You)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      value: _isUser,
                      activeTrackColor: AppColors.spendoGreen,
                      onChanged: (val) => setState(() => _isUser = val),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.person == null ? 'إضافة الشخص' : 'حفظ التعديلات',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 12),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: textWhite, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w700),
        hintText: hint,
        hintStyle: TextStyle(color: textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: AppColors.monoIcon, size: 18),
        filled: true,
        fillColor: surfaceField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.spendoGreen, width: 1.2),
        ),
      ),
    );
  }
}
