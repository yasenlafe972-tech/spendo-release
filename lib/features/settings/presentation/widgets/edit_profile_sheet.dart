import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';

class EditProfileSheet extends StatefulWidget {
  final PersonModel? userProfile;
  final ValueChanged<PersonModel> onSaved;

  const EditProfileSheet({
    super.key,
    required this.userProfile,
    required this.onSaved,
  });

  static Future<PersonModel?> show(BuildContext context, PersonModel? userProfile) {
    return showModalBottomSheet<PersonModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => EditProfileSheet(
        userProfile: userProfile,
        onSaved: (updated) => Navigator.of(ctx).pop(updated),
      ),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF141418) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF1B1B22) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF282834) : const Color(0xFFE5E7EB);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);
  final PeopleRepository _peopleRepo = PeopleRepository();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _dailyRateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.userProfile;
    _nameController = TextEditingController(text: user?.name ?? 'ياسين');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _dailyRateController = TextEditingController(
      text: user != null && user.dailyRate > 0 ? user.dailyRate.toInt().toString() : '400',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dailyRateController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    SpendoHaptics.light();
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final dailyRate = double.tryParse(_dailyRateController.text.trim()) ?? 0.0;

      PersonModel updated;
      if (widget.userProfile != null) {
        updated = widget.userProfile!.copyWith(
          name: name,
          phone: phone.isNotEmpty ? phone : null,
          email: email.isNotEmpty ? email : null,
          dailyRate: dailyRate,
          updatedAt: DateTime.now(),
        );
        await _peopleRepo.updatePerson(updated);
      } else {
        updated = PersonModel(
          id: 'user_profile_main',
          name: name,
          isUser: true,
          phone: phone.isNotEmpty ? phone : null,
          email: email.isNotEmpty ? email : null,
          dailyRate: dailyRate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _peopleRepo.addPerson(updated);
      }

      SpendoHaptics.success();
      widget.onSaved(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.spendoGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.spendoGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تعديل الملف الشخصي',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'تخصيص بيانات حسابك ومعدل يوميتك الافتراضي',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'الاسم الكامل أو اللقب *',
                hint: 'أدخل اسمك...',
                icon: Icons.badge_outlined,
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
              ),

              const SizedBox(height: 14),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                hint: '05xxxxxxxx',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 14),

              // Email Field
              _buildTextField(
                controller: _emailController,
                label: 'البريد الإلكتروني',
                hint: 'name@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 14),

              // Daily Rate Field
              _buildTextField(
                controller: _dailyRateController,
                label: 'سعر اليومية الافتراضي (₪)',
                hint: '400',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                suffixText: '₪ / يوم',
              ),

              const SizedBox(height: 26),

              // Save button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.spendoGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'حفظ التعديلات',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: textWhite,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
            suffixText: suffixText,
            suffixStyle: TextStyle(
              color: AppColors.spendoMint,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            filled: true,
            fillColor: surfaceField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              borderSide: const BorderSide(color: AppColors.spendoGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
