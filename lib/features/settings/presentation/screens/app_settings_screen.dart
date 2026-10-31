import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/auth_link_service.dart';
import '../../../../core/services/firebase_backup_service.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';
import '../../services/settings_service.dart';

/// AppSettingsScreen (شاشة الإعدادات المدمجة).
/// Fully redesigned according to the Obsidian Dark Unified Specification.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final PeopleRepository _peopleRepo = PeopleRepository();
  final FirebaseBackupService _backupService = FirebaseBackupService.instance;
  final SettingsService _settingsService = SettingsService.instance;

  // Design color tokens from specifications
  static const Color surfaceBg = Color(0xFF0C0E0D);
  static const Color surfaceMain = Color(0xFF121514);
  static const Color surfaceCell = Color(0xFF161A18);
  static const Color surfaceBorder = Color(0xFF232927);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static const Color brandRed = Color(0xFFEF4444);
  static const Color textMuted = Color(0xFFA1A1AA);

  bool _isLoading = true;
  PersonModel? _userProfile;
  String _linkedAccountEmail = '';

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Work log reminder settings
  bool _dailyReminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 17, minute: 0);
  bool _showTimeSelector = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final people = await _peopleRepo.getAllPeople();
      PersonModel? user;
      for (final p in people) {
        if (p.isUser) {
          user = p;
          break;
        }
      }

      final fbUser = FirebaseAuth.instance.currentUser;
      final linkedEmail = await AuthLinkService.getLinkedEmail();
      final reminder = await _settingsService.isDailyReminderEnabled();
      final reminderTimeStr = await _settingsService.getDailyReminderTime();
      TimeOfDay parsedTime = const TimeOfDay(hour: 17, minute: 0);
      try {
        final parts = reminderTimeStr.split(':');
        parsedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _userProfile = user;
        _linkedAccountEmail = linkedEmail;
        if (fbUser != null) {
          final displayName = fbUser.displayName;
          _nameController.text = (displayName != null && displayName.trim().isNotEmpty)
              ? displayName
              : (user?.name.trim().isNotEmpty == true && user!.name != 'My profile' ? user.name : 'لافي');
          _emailController.text = fbUser.email ?? (user?.email ?? linkedEmail);
        } else {
          _nameController.text =
              user?.name.trim().isNotEmpty == true && user!.name != 'My profile' ? user.name : 'لافي';
          _emailController.text = user?.email?.trim().isNotEmpty == true
              ? user!.email!
              : (linkedEmail.isNotEmpty ? linkedEmail : 'yasenlafe972@gmail.com');
        }
        _dailyReminderEnabled = reminder;
        _reminderTime = parsedTime;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomToast(String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: surfaceCell,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: brandGreen, width: 0.8),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Remix.checkbox_circle_line, color: brandYellow, size: 15),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveSettings() async {
    SpendoHaptics.light();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null && name.isNotEmpty) {
        try {
          await fbUser.updateDisplayName(name);
        } catch (_) {}
      }

      if (_userProfile != null) {
        final updated = _userProfile!.copyWith(
          name: name.isNotEmpty ? name : _userProfile!.name,
          email: email.isNotEmpty ? email : _userProfile!.email,
          updatedAt: DateTime.now(),
        );
        await _peopleRepo.updatePerson(updated);
        _userProfile = updated;
      } else {
        final newUser = PersonModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name.isNotEmpty ? name : 'My profile',
          email: email.isNotEmpty ? email : null,
          isUser: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _peopleRepo.addPerson(newUser);
        _userProfile = newUser;
      }

      await _settingsService.setDailyReminderEnabled(_dailyReminderEnabled);
      await _settingsService.setDailyReminderTime(_formatTimeOfDay(_reminderTime));
      await _backupService.setAutoBackupEnabled(true);

      SpendoHaptics.success();
      _showCustomToast('تم حفظ كافة الإعدادات بنجاح');
    } catch (e) {
      debugPrint('Error saving settings: $e');
      _showCustomToast('حدث خطأ أثناء حفظ الإعدادات');
    }
  }

  void _copyEmail() {
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : 'yasenlafe972@gmail.com';
    Clipboard.setData(ClipboardData(text: email));
    _showCustomToast('تم نسخ البريد الإلكتروني');
  }

  void _toggleReminderSwitch() {
    setState(() {
      _dailyReminderEnabled = !_dailyReminderEnabled;
      if (!_dailyReminderEnabled) _showTimeSelector = false;
    });
    _settingsService.setDailyReminderEnabled(_dailyReminderEnabled);
    _showCustomToast(
      _dailyReminderEnabled ? 'تم تفعيل تذكير تسجيل يوم العمل' : 'تم إيقاف التذكير اليومي',
    );
  }

  void _toggleTimeSelector() {
    setState(() {
      _showTimeSelector = !_showTimeSelector;
    });
  }

  void _selectReminderTime(String timeStr) {
    final parts = timeStr.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    setState(() {
      _reminderTime = TimeOfDay(hour: h, minute: m);
      _dailyReminderEnabled = true;
    });
    _settingsService.setDailyReminderTime(timeStr);
    _settingsService.setDailyReminderEnabled(true);
    _showCustomToast('تم ضبط وقت التذكير على $timeStr');
  }

  Future<void> _handleSelectCustomTime() async {
    SpendoHaptics.light();
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: brandGreen,
              onPrimary: Color(0xFF0A0B0D),
              surface: surfaceCell,
              onSurface: Colors.white,
              secondary: brandYellow,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: surfaceMain,
              hourMinuteColor: surfaceCell,
              hourMinuteTextColor: Colors.white,
              dialBackgroundColor: surfaceCell,
              dialHandColor: brandGreen,
              dialTextColor: Colors.white,
              entryModeIconColor: brandYellow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: surfaceBorder),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: textMuted,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: brandGreen,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child!,
          ),
        );
      },
    );

    if (picked != null && mounted) {
      final timeStr = _formatTimeOfDay(picked);
      setState(() {
        _reminderTime = picked;
        _dailyReminderEnabled = true;
      });
      await _settingsService.setDailyReminderTime(timeStr);
      await _settingsService.setDailyReminderEnabled(true);
      _showCustomToast('تم ضبط وقت التذكير على $timeStr وتفعيله');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _handleExportBackup() async {
    SpendoHaptics.light();
    try {
      // 1. Silent sync to cloud/cache first
      await _backupService.performBackup();

      // 2. Export to a real JSON file
      final file = await _backupService.exportBackupToJsonFile();

      // 3. Open native share sheet so user can send via Telegram, WhatsApp, Save to Files, AirDrop
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'نسخة احتياطية Spendo',
          text: 'نسخة احتياطية كاملة لبيانات Spendo',
        ),
      );
      _showCustomToast('تم تجهيز ملف النسخة الاحتياطية بنجاح');
    } catch (e) {
      _showCustomToast('فشل تصدير النسخة الاحتياطية: $e');
    }
  }

  Future<void> _handleImportBackup() async {
    SpendoHaptics.light();

    // Show choice sheet: Cloud Restore vs File Import
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: const BoxDecoration(
          color: surfaceMain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: surfaceBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'استعادة البيانات والنسخ الاحتياطي',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'cloud'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceCell,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  children: const [
                    Icon(Remix.cloud_line, color: brandGreen, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('استعادة من سحابة Firebase', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('جلب أحدث نسخة متزامنة تلقائياً من السحابة', style: TextStyle(color: textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'file'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceCell,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaceBorder),
                ),
                child: Row(
                  children: const [
                    Icon(Remix.file_upload_line, color: brandYellow, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('استيراد ملف نسخة احتياطية (.json)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('اختيار ملف مستلم عبر تلغرام أو محفوظ في الملفات', style: TextStyle(color: textMuted, fontSize: 10)),
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
    );

    if (choice == 'cloud') {
      try {
        final res = await _backupService.performRestore();
        if (res.isSuccess) {
          SpendoHaptics.success();
          _showCustomToast('تمت استعادة البيانات بنجاح (${res.recordsRestored} سجل)');
          setState(() {});
        } else {
          _showCustomToast(res.message);
        }
      } catch (e) {
        _showCustomToast('فشل استعادة النسخة السحابية: $e');
      }
    } else if (choice == 'file') {
      try {
        final file = await FilePicker.pickFile();
        if (file != null && file.path != null) {
          final ioFile = File(file.path!);
          final content = await ioFile.readAsString();
          final res = await _backupService.importBackupFromJsonString(content);
          if (res.isSuccess) {
            SpendoHaptics.success();
            _showCustomToast('تم استعادة البيانات بنجاح (${res.recordsRestored} سجل)');
            setState(() {});
          } else {
            _showCustomToast(res.message);
          }
        }
      } catch (e) {
        _showCustomToast('فشل استيراد الملف: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : 'الحساب الحالي';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceMain,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorder),
        ),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت متأكد من تسجيل الخروج من ($email)؟',
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج', style: TextStyle(color: brandRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthLinkService.performLogout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _openEditModal(String mode) async {
    SpendoHaptics.light();
    final isName = mode == 'name';
    final controller = TextEditingController(
      text: isName ? _nameController.text : _emailController.text,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: surfaceMain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: surfaceBorder),
            left: BorderSide(color: surfaceBorder),
            right: BorderSide(color: surfaceBorder),
          ),
        ),
        padding: EdgeInsets.only(
          top: 14,
          left: 14,
          right: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isName ? Remix.user_3_line : Remix.mail_line,
                        size: 15,
                        color: isName ? brandGreen : brandYellow,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isName ? 'تعديل الاسم الشخصي' : 'تعديل البريد الإلكتروني',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Remix.close_line, size: 18, color: textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: surfaceCell,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: surfaceBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isName ? 'الاسم الشخصي في البروفايل' : 'البريد الإلكتروني للحساب',
                      style: const TextStyle(fontSize: 9.5, color: textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: isName ? null : 'monospace',
                      ),
                      textDirection: isName ? null : TextDirection.ltr,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final val = controller.text.trim();
                        if (val.isNotEmpty) {
                          setState(() {
                            if (isName) {
                              _nameController.text = val;
                            } else {
                              _emailController.text = val;
                            }
                          });
                          Navigator.pop(ctx);
                          _showCustomToast(isName ? 'تم تحديث الاسم الشخصي' : 'تم تحديث البريد الإلكتروني');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        foregroundColor: const Color(0xFF0A0B0D),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Remix.check_line, size: 15, color: Color(0xFF0A0B0D)),
                          SizedBox(width: 4),
                          Text(
                            'تحديث',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A0B0D)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: surfaceBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(fontSize: 12, color: textMuted),
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
  }

  Future<void> _showChangePasswordDialog() async {
    SpendoHaptics.selection();
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceMain,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: surfaceBorder, width: 1.0),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Remix.lock_password_line, color: brandYellow, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'تغيير كلمة المرور',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Remix.close_line, size: 18, color: textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'الحساب المرتبط: ${_emailController.text.trim().isNotEmpty ? _emailController.text.trim() : _linkedAccountEmail}',
                          style: const TextStyle(color: textMuted, fontSize: 10.5),
                        ),
                        const SizedBox(height: 12),

                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: brandRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: brandRed.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Remix.error_warning_line, color: brandRed, size: 15),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: brandRed, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Current Password
                        const Text('كلمة المرور الحالية', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceCell,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: TextField(
                            controller: currentPwCtrl,
                            obscureText: obscureCurrent,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              hintText: 'أدخل كلمة المرور الحالية',
                              hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 11),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureCurrent ? Remix.eye_off_line : Remix.eye_line,
                                  size: 15,
                                  color: textMuted,
                                ),
                                onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // New Password
                        const Text('كلمة المرور الجديدة (6 خانات على الأقل)', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceCell,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: TextField(
                            controller: newPwCtrl,
                            obscureText: obscureNew,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              hintText: 'كلمة مرور جديدة قوية',
                              hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 11),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureNew ? Remix.eye_off_line : Remix.eye_line,
                                  size: 15,
                                  color: textMuted,
                                ),
                                onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Confirm Password
                        const Text('تأكيد كلمة المرور الجديدة', style: TextStyle(fontSize: 10.5, color: textMuted)),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceCell,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: TextField(
                            controller: confirmPwCtrl,
                            obscureText: obscureConfirm,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              hintText: 'أعد إدخال كلمة المرور الجديدة',
                              hintStyle: const TextStyle(color: Color(0xFF52525B), fontSize: 11),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirm ? Remix.eye_off_line : Remix.eye_line,
                                  size: 15,
                                  color: textMuted,
                                ),
                                onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Reset link option
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              final emailToSend = _emailController.text.trim().isNotEmpty
                                  ? _emailController.text.trim()
                                  : null;
                              final ok = await AuthLinkService.sendPasswordResetEmail(emailToSend);
                              if (dialogCtx.mounted) {
                                Navigator.pop(ctx);
                                _showCustomToast(ok ? 'تم إرسال رابط إعادة التعيين لبريدك' : 'فشل إرسال الرابط');
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'نسيت كلمة المرور؟ إرسال رابط للإيميل',
                              style: TextStyle(color: brandYellow, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Submit Button
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final currentPw = currentPwCtrl.text.trim();
                                  final newPw = newPwCtrl.text.trim();
                                  final confirmPw = confirmPwCtrl.text.trim();

                                  if (currentPw.isEmpty) {
                                    setDialogState(() => errorMessage = 'يرجى إدخال كلمة المرور الحالية');
                                    return;
                                  }
                                  if (newPw.length < 6) {
                                    setDialogState(() => errorMessage = 'كلمة المرور الجديدة يجب أن تكون 6 خانات على الأقل');
                                    return;
                                  }
                                  if (newPw != confirmPw) {
                                    setDialogState(() => errorMessage = 'كلمتا المرور غير متطابقتين');
                                    return;
                                  }

                                  setDialogState(() {
                                    isSubmitting = true;
                                    errorMessage = null;
                                  });

                                  final result = await AuthLinkService.updatePassword(
                                    currentPassword: currentPw,
                                    newPassword: newPw,
                                  );

                                  if (!dialogCtx.mounted) return;

                                  final isSuccess = result['success'] == true;
                                  final msg = (result['message'] ?? result['error'] ?? 'تم تحديث كلمة المرور') as String;

                                  if (isSuccess) {
                                    Navigator.pop(ctx);
                                    _showCustomToast(msg);
                                  } else {
                                    setDialogState(() {
                                      isSubmitting = false;
                                      errorMessage = msg;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            foregroundColor: const Color(0xFF0A0B0D),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0B0D)),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Remix.check_line, size: 16, color: Color(0xFF0A0B0D)),
                                    SizedBox(width: 6),
                                    Text(
                                      'تحديث كلمة المرور',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0A0B0D),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fbUser = FirebaseAuth.instance.currentUser;
    final isLoggedIn = fbUser != null;
    final currentEmail = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : 'yasenlafe972@gmail.com';

    return Scaffold(
      backgroundColor: surfaceBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandGreen))
          : SafeArea(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // 1. Unified Compact Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0x99161A18),
                        border: Border(bottom: BorderSide(color: surfaceBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Right: Back arrow + Divider + Settings icon + Title + General Badge + Subtitle
                          Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(Remix.arrow_right_line, size: 18, color: textMuted),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 16, color: surfaceBorder),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Remix.settings_4_line, size: 14, color: brandGreen),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'الإعدادات',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: brandYellow.withValues(alpha: 0.3)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'إعدادات عامة',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: brandYellow,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'إدارة الحساب، التذكيرات، والنسخ الاحتياطي',
                                    style: TextStyle(fontSize: 9.5, color: textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Left: Account Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: surfaceMain,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: surfaceBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isLoggedIn ? brandGreen : brandGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isLoggedIn ? 'سحابي متصل' : 'حساب محلي',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD1D5DB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Settings Sections
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ================= Section 1: البروفايل والأمان =================
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'البروفايل والأمان',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                                ),
                                Text(
                                  'Spendo ID',
                                  style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Color(0xFF71717A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Container(
                              decoration: BoxDecoration(
                                color: surfaceCell,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: surfaceBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  // Top Row: Name + Change Password (2 columns side by side)
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Column 1 (Right): Profile Name
                                        Expanded(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: surfaceBorder),
                                                left: BorderSide(color: surfaceBorder),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Remix.user_3_line, size: 14, color: brandGreen),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              const Text(
                                                                'الاسم الشخصي',
                                                                style: TextStyle(fontSize: 8.5, color: textMuted),
                                                              ),
                                                              const SizedBox(height: 1),
                                                              Text(
                                                                _nameController.text.isNotEmpty
                                                                    ? _nameController.text
                                                                    : 'My profile',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(
                                                                  fontSize: 11.5,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => _openEditModal('name'),
                                                  child: Container(
                                                    width: 30,
                                                    alignment: Alignment.center,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0x66121514),
                                                      border: Border(right: BorderSide(color: surfaceBorder)),
                                                    ),
                                                    child: const Icon(Remix.pencil_line, size: 12, color: textMuted),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Column 2 (Left): Change Password
                                        Expanded(
                                          child: InkWell(
                                            onTap: _showChangePasswordDialog,
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: surfaceBorder)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Remix.lock_password_line, size: 14, color: brandYellow),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: const [
                                                                Text(
                                                                  'تحديث كلمة السر',
                                                                  style: TextStyle(fontSize: 8.5, color: textMuted),
                                                                ),
                                                                SizedBox(height: 1),
                                                                Text(
                                                                  'تغيير كلمة المرور',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontSize: 11.5,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 26,
                                                    alignment: Alignment.center,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0x66121514),
                                                      border: Border(right: BorderSide(color: surfaceBorder)),
                                                    ),
                                                    child: const Icon(Remix.arrow_left_s_line, size: 14, color: textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Bottom Row: Email + Copy & Edit Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          child: Row(
                                            children: [
                                              const Icon(Remix.mail_line, size: 14, color: brandYellow),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'البريد الإلكتروني المسجل',
                                                      style: TextStyle(fontSize: 8.5, color: textMuted),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      currentEmail,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      textDirection: TextDirection.ltr,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontFamily: 'monospace',
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          color: Color(0x66121514),
                                          border: Border(right: BorderSide(color: surfaceBorder)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: _copyEmail,
                                              child: Container(
                                                width: 30,
                                                alignment: Alignment.center,
                                                child: const Icon(Remix.file_copy_line, size: 12, color: textMuted),
                                              ),
                                            ),
                                            Container(width: 1, height: 38, color: surfaceBorder),
                                            InkWell(
                                              onTap: () => _openEditModal('email'),
                                              child: Container(
                                                width: 30,
                                                alignment: Alignment.center,
                                                child: const Icon(Remix.pencil_line, size: 12, color: textMuted),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ================= Section 2: التذكيرات والتنبيهات =================
                            const Text(
                              'التذكيرات والتنبيهات',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                            ),
                            const SizedBox(height: 4),

                            Container(
                              decoration: BoxDecoration(
                                color: surfaceCell,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: surfaceBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Remix.notification_3_line, size: 15, color: brandYellow),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'تذكير تسجيل يوم العمل',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(height: 1),
                                              Text(
                                                'إشعار يومي بعد الدوام لتسجيل عمل اليوم',
                                                style: TextStyle(fontSize: 9.5, color: textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Reminder Time Button
                                        InkWell(
                                          onTap: _handleSelectCustomTime,
                                          onLongPress: _toggleTimeSelector,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: surfaceMain,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: _dailyReminderEnabled ? brandYellow : surfaceBorder,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Remix.time_line, size: 10, color: brandYellow),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _formatTimeOfDay(_reminderTime),
                                                  style: const TextStyle(
                                                    color: brandYellow,
                                                    fontSize: 10,
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Sleek Compact Toggle Switch
                                        InkWell(
                                          onTap: _toggleReminderSwitch,
                                          borderRadius: BorderRadius.circular(20),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            width: 36,
                                            height: 20,
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: _dailyReminderEnabled ? brandGreen : surfaceMain,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _dailyReminderEnabled ? brandGreen : surfaceBorder,
                                              ),
                                            ),
                                            alignment: _dailyReminderEnabled
                                                ? Alignment.centerLeft
                                                : Alignment.centerRight,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: _dailyReminderEnabled
                                                    ? const Color(0xFF0A0B0D)
                                                    : const Color(0xFF71717A),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quick Time Selector Row
                                  if (_showTimeSelector || _dailyReminderEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: const BoxDecoration(
                                        color: Color(0x99121514),
                                        border: Border(top: BorderSide(color: surfaceBorder)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'وقت التذكير اليومي:',
                                            style: TextStyle(fontSize: 9.5, color: textMuted),
                                          ),
                                          const Spacer(),
                                          Row(
                                            children: ['16:00', '17:00', '18:30', '20:00'].map((t) {
                                              final isSel = _formatTimeOfDay(_reminderTime) == t;
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 4),
                                                child: InkWell(
                                                  onTap: () => _selectReminderTime(t),
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isSel ? brandYellow.withValues(alpha: 0.15) : surfaceCell,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: isSel ? brandYellow : surfaceBorder,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      t,
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontFamily: 'monospace',
                                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                                        color: isSel ? brandYellow : const Color(0xFFD1D5DB),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: _handleSelectCustomTime,
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: brandGreen.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: brandGreen.withValues(alpha: 0.45)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Remix.time_line, size: 10, color: brandGreen),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'تخصيص',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: brandGreen,
                                                    ),
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
                            ),
                            const SizedBox(height: 10),

                            // ================= Section 3: النسخ الاحتياطي والبيانات =================
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'النسخ الاحتياطي والبيانات',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                                ),
                                Text(
                                  'حفظ محلي آمن',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF71717A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Export backup
                                  Expanded(
                                    child: InkWell(
                                      onTap: _handleExportBackup,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: surfaceCell,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: surfaceBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Remix.download_cloud_2_line, size: 14, color: brandGreen),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Text(
                                                    'تصدير نسخة',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(height: 1),
                                                  Text(
                                                    'حفظ ملف البيانات',
                                                    style: TextStyle(fontSize: 8.5, color: textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Remix.arrow_left_up_line, size: 11, color: Color(0xFF71717A)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Restore backup
                                  Expanded(
                                    child: InkWell(
                                      onTap: _handleImportBackup,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: surfaceCell,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: surfaceBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Remix.upload_cloud_2_line, size: 14, color: brandYellow),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Text(
                                                    'استعادة نسخة',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(height: 1),
                                                  Text(
                                                    'استيراد من الجهاز',
                                                    style: TextStyle(fontSize: 8.5, color: textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Remix.folder_open_line, size: 11, color: Color(0xFF71717A)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ================= Section 4: أزرار الحفظ وتسجيل الخروج =================
                            Row(
                              children: [
                                // Save Button (Flex 7)
                                Expanded(
                                  flex: 7,
                                  child: SizedBox(
                                    height: 38,
                                    child: ElevatedButton(
                                      onPressed: _handleSaveSettings,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: brandGreen,
                                        foregroundColor: const Color(0xFF0A0B0D),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Remix.check_line, size: 15, color: Color(0xFF0A0B0D)),
                                          SizedBox(width: 4),
                                          Text(
                                            'حفظ الإعدادات',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0A0B0D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Logout Button (Flex 5)
                                Expanded(
                                  flex: 5,
                                  child: SizedBox(
                                    height: 38,
                                    child: OutlinedButton(
                                      onPressed: _handleLogout,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: surfaceCell,
                                        side: BorderSide(color: brandRed.withValues(alpha: 0.3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Remix.logout_box_r_line, size: 14, color: brandRed),
                                          SizedBox(width: 4),
                                          Text(
                                            'تسجيل الخروج',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: brandRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Bottom Session Info Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: surfaceMain,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: surfaceBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'الجلسة المسجلة حالياً:',
                                    style: TextStyle(fontSize: 9.5, color: textMuted),
                                  ),
                                  Text(
                                    currentEmail,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontFamily: 'monospace',
                                      color: Color(0xFFD1D5DB),
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
              ),
            ),
    );
  }
}
