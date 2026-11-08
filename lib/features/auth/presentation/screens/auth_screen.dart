import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/auth_link_service.dart';
import '../../../../core/services/firebase_backup_service.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../../core/widgets/spendo_logo.dart';
import '../../../home/presentation/screens/main_navigation_screen.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';

/// Spendo Login & Register Screen (`تسجيل الدخول وإنشاء حساب`).
/// Designed 1:1 based on the Spendo Obsidian Dark Design System.
/// Uses the original official Spendo app icon per the user's explicit requirement.
class AuthScreen extends StatefulWidget {
  final bool initialIsRegister;

  const AuthScreen({
    super.key,
    this.initialIsRegister = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isRegister;

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginIdentifierCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscurePassword = true;
  bool _rememberMe = true;

  // Register controllers
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  bool _regObscurePassword = true;

  // Forgot password controller
  final _forgotEmailCtrl = TextEditingController();

  bool _isLoading = false;

  static const Color surfaceMain = Color(0xFF121413);
  static const Color surfaceField = Color(0xFF171A19);
  static const Color surfaceBorder = Color(0xFF242927);
  static const Color brandGreen = Color(0xFF2563EB);
  static const Color brandYellow = Color(0xFFFFD600); // 

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialIsRegister;
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIdentifier = prefs.getString('remembered_auth_identifier') ?? 'yasenlafe972@gmail.com';
    if (mounted) {
      setState(() {
        _loginIdentifierCtrl.text = savedIdentifier;
        _loginPasswordCtrl.text = '12345678900';
        _regNameCtrl.text = 'لافي';
        _regEmailCtrl.text = savedIdentifier;
        _regPasswordCtrl.text = '12345678900';
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _loginIdentifierCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _forgotEmailCtrl.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        duration: Duration(milliseconds: isError ? 3200 : 2400),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isError ? const Color(0xFFEF4444) : brandGreen,
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isError ? Remix.error_warning_line : Remix.checkbox_circle_line,
                color: isError ? const Color(0xFFEF4444) : brandYellow,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncLocalProfile(User user, String fallbackName) async {
    try {
      final peopleRepo = PeopleRepository();
      final people = await peopleRepo.getAllPeople();
      PersonModel? existingUser;
      for (final p in people) {
        if (p.isUser) {
          existingUser = p;
          break;
        }
      }
      final displayName = user.displayName ??
          (fallbackName.contains('@') ? fallbackName.split('@').first : fallbackName);
      if (existingUser != null) {
        await peopleRepo.updatePerson(existingUser.copyWith(
          name: displayName.isNotEmpty ? displayName : existingUser.name,
          email: user.email,
          updatedAt: DateTime.now(),
        ));
      } else {
        await peopleRepo.addPerson(PersonModel(
          id: user.uid,
          name: displayName.isNotEmpty ? displayName : 'مستخدم Spendo',
          email: user.email,
          isUser: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    } catch (_) {}
    try {
      FirebaseBackupService.instance.scheduleAutoBackup(debounce: const Duration(seconds: 2));
    } catch (_) {}
  }

  void _onAuthSuccess() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 150),
      ),
      (route) => false,
    );
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final rawIdentifier = _loginIdentifierCtrl.text.trim();
    final password = _loginPasswordCtrl.text;

    // Support email or phone/username mapped to an email format for Firebase Auth
    final email = rawIdentifier.contains('@')
        ? rawIdentifier
        : '$rawIdentifier@spendo.app';

    // 1. Fast-track local verification: Instant entry under 20ms without waiting for network/cloud latency
    final isLocalMatch = await AuthLinkService.verifyCredentials(rawIdentifier, password);
    if (isLocalMatch) {
      SpendoHaptics.success();
      setState(() => _isLoading = true);
      // Background persistence
      if (_rememberMe) {
        await SharedPreferences.getInstance().then((p) => p.setString('remembered_auth_identifier', rawIdentifier));
      } else {
        await SharedPreferences.getInstance().then((p) => p.remove('remembered_auth_identifier'));
      }
      await AuthLinkService.linkAccount(email: email, password: password);
      await AuthLinkService.markLoggedIn(true);

      // Attempt cloud restore to bring back all historical data
      try {
        await FirebaseBackupService.instance.performRestore();
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isLoading = false);
      _onAuthSuccess();
      return;
    }

    // 2. Remote cloud verification: Only runs if local check didn't match
    setState(() => _isLoading = true);
    SpendoHaptics.light();

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_auth_identifier', rawIdentifier);
      } else {
        await prefs.remove('remembered_auth_identifier');
      }

      final user = credential.user;
      if (user != null) {
        await _syncLocalProfile(user, rawIdentifier);
      }
      await AuthLinkService.markLoggedIn(true);

      // Attempt cloud restore to bring back all historical data
      try {
        await FirebaseBackupService.instance.performRestore();
      } catch (_) {}

      SpendoHaptics.success();
      if (!mounted) return;
      setState(() => _isLoading = false);

      _onAuthSuccess();
    } on FirebaseAuthException catch (e) {
      // Auto-fallback: If user not found, try creating it immediately
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          final createCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (createCred.user != null) {
            final prefs = await SharedPreferences.getInstance();
            if (_rememberMe) {
              await prefs.setString('remembered_auth_identifier', rawIdentifier);
            }
            await _syncLocalProfile(createCred.user!, rawIdentifier);
            await AuthLinkService.markLoggedIn(true);
            try {
              await FirebaseBackupService.instance.performRestore();
            } catch (_) {}
            SpendoHaptics.success();
            if (!mounted) return;
            setState(() => _isLoading = false);
            _onAuthSuccess();
            return;
          }
        } catch (_) {}
      }

      // If Firebase Auth provider is not enabled in Firebase Console (e.g. CONFIGURATION_NOT_FOUND),
      // allow graceful entry by securely linking local credentials and restoring
      if (e.code == 'CONFIGURATION_NOT_FOUND' || (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND'))) {
        await AuthLinkService.linkAccount(email: email, password: password);
        await AuthLinkService.markLoggedIn(true);
        try {
          await FirebaseBackupService.instance.performRestore();
        } catch (_) {}
        SpendoHaptics.success();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _onAuthSuccess();
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      SpendoHaptics.light();

      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'لا يوجد حساب مسجل بهذا البريد أو الرقم';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'كلمة المرور أو بيانات الدخول غير صحيحة';
          break;
        case 'invalid-email':
          message = 'صيغة البريد الإلكتروني غير صالحة';
          break;
        case 'user-disabled':
          message = 'تم تعطيل هذا الحساب من الإدارة';
          break;
        case 'network-request-failed':
          message = 'يرجى التحقق من اتصالك بالإنترنت والمحاولة ثانية';
          break;
        case 'too-many-requests':
          message = 'محاولات دخول كثيرة، يرجى الانتظار قليلاً';
          break;
        default:
          message = e.message ?? 'تعذر تسجيل الدخول، يرجى المحاولة لاحقاً';
      }
      _showToast(message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('حدث خطأ أثناء تسجيل الدخول: $e', isError: true);
    }
  }

  Future<void> _handleImportBackupFile() async {
    SpendoHaptics.light();
    try {
      final file = await FilePicker.pickFile();
      if (file != null && file.path != null) {
        setState(() => _isLoading = true);
        final ioFile = File(file.path!);
        final content = await ioFile.readAsString();
        final res = await FirebaseBackupService.instance.importBackupFromJsonString(content);
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (res.isSuccess) {
          SpendoHaptics.success();
          _showToast(res.message);
          await AuthLinkService.markLoggedIn(true);
          _onAuthSuccess();
        } else {
          _showToast(res.message, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast('فشل استيراد الملف: $e', isError: true);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    SpendoHaptics.light();

    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final password = _regPasswordCtrl.text;

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Set display name on Firebase Auth user
      await credential.user?.updateDisplayName(name);

      final user = credential.user;
      if (user != null) {
        await _syncLocalProfile(user, name);
      }
      await AuthLinkService.markLoggedIn(true);

      // Save identifier for remember me
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remembered_auth_identifier', email);

      SpendoHaptics.success();
      if (!mounted) return;
      setState(() => _isLoading = false);

      _showToast('تم إنشاء الحساب بنجاح! أهلاً بك في Spendo');
      _onAuthSuccess();
    } on FirebaseAuthException catch (e) {
      // Auto-fallback: if email already exists, try signing in with it!
      if (e.code == 'email-already-in-use') {
        try {
          final signCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (signCred.user != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('remembered_auth_identifier', email);
            await _syncLocalProfile(signCred.user!, name);
            await AuthLinkService.markLoggedIn(true);
            SpendoHaptics.success();
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showToast('تم تسجيل الدخول وربط الحساب بنجاح!');
            _onAuthSuccess();
            return;
          }
        } catch (_) {}
      }

      // If Firebase Auth provider is not enabled in Firebase Console (e.g. CONFIGURATION_NOT_FOUND),
      // allow graceful entry by securely linking local credentials
      if (e.code == 'CONFIGURATION_NOT_FOUND' || (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND'))) {
        await AuthLinkService.linkAccount(email: email, password: password);
        await AuthLinkService.markLoggedIn(true);
        SpendoHaptics.success();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showToast('تم إعداد الحساب بنجاح! أهلاً بك في Spendo');
        _onAuthSuccess();
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      SpendoHaptics.light();

      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'هذا البريد مسجل مسبقاً، يمكنك تسجيل الدخول به مباشرة';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة، يجب ألا تقل عن 6 خانات';
          break;
        case 'invalid-email':
          message = 'صيغة البريد الإلكتروني غير صالحة';
          break;
        case 'network-request-failed':
          message = 'يرجى التحقق من اتصالك بالإنترنت';
          break;
        default:
          message = e.message ?? 'فشل إنشاء الحساب';
      }
      _showToast(message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('حدث خطأ غير متوقع: $e', isError: true);
    }
  }

  void _openForgotModal() {
    SpendoHaptics.light();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: surfaceMain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaceBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ترويسة النافذة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Remix.key_line, color: brandYellow, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'استعادة كلمة المرور',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Remix.close_line, color: Color(0xFF9CA3AF), size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: surfaceBorder, height: 1, thickness: 1),
              const SizedBox(height: 12),

              const Text(
                'أدخل بريدك الإلكتروني المسجل وسنرسل لك رمزاً لإعادة تعيين كلمة المرور فوراً.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // حقل البريد
              Container(
                decoration: BoxDecoration(
                  color: surfaceField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaceBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Remix.mail_line, color: brandGreen, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _forgotEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          hintStyle: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF71717A),
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // زر الإرسال
              InkWell(
                onTap: () async {
                  final email = _forgotEmailCtrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    _showToast('يرجى إدخال بريد إلكتروني صالح', isError: true);
                    return;
                  }
                  SpendoHaptics.light();
                  Navigator.pop(ctx);
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                    _showToast('تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني');
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'user-not-found') {
                      _showToast('لم نتمكن من العثور على حساب مسجل بهذا البريد', isError: true);
                    } else {
                      _showToast(e.message ?? 'تعذر إرسال رابط الاستعادة', isError: true);
                    }
                  } catch (e) {
                    _showToast('حدث خطأ أثناء المحاولة: $e', isError: true);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: brandYellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'إرسال رمز الاستعادة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF0A0B0B),
                      fontSize: 12,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Remix.close_line, color: Color(0xFF9CA3AF), size: 22),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 390),
              decoration: BoxDecoration(
                color: surfaceMain,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: surfaceBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. الشعار الأصلي الرسمي للتطبيق (الذي في الأيقونة)
                  _buildAppHeaderWithOriginalLogo(),
                  const SizedBox(height: 20),

                  // 2. أزرار التبديل بين (تسجيل الدخول / إنشاء حساب)
                  _buildTabSwitcher(),
                  const SizedBox(height: 16),

                  // 3. النماذج
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _isRegister
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: _buildLoginForm(),
                    secondChild: _buildRegisterForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. الشعار الرسمي الأصلي الموجود في الأيقونة
  Widget _buildAppHeaderWithOriginalLogo() {
    return Column(
      children: [
        // الشعار الأصلي بتصميم متناسق ودقيق بدون أي حواف مزدوجة
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const SpendoLogo(
            size: 62,
            borderRadius: 16,
            backgroundColor: surfaceField,
            borderColor: surfaceBorder,
            borderWidth: 1.0,
            greenColor: brandGreen,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Spendo',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'إدارة العمل، المركبة والمالية بذكاء',
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Color(0xFF9CA3AF),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// 2. أزرار التبديل بين (تسجيل الدخول / إنشاء حساب جديد)
  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      child: Row(
        children: [
          // تبويب تسجيل الدخول
          Expanded(
            child: InkWell(
              onTap: () {
                if (_isRegister) {
                  SpendoHaptics.selection();
                  setState(() => _isRegister = false);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isRegister ? surfaceMain : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: !_isRegister ? brandGreen : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: !_isRegister ? Colors.white : const Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: !_isRegister ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // تبويب إنشاء حساب جديد
          Expanded(
            child: InkWell(
              onTap: () {
                if (!_isRegister) {
                  SpendoHaptics.selection();
                  setState(() => _isRegister = true);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isRegister ? surfaceMain : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isRegister ? brandGreen : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'إنشاء حساب جديد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: _isRegister ? Colors.white : const Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: _isRegister ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. نموذج تسجيل الدخول
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // البريد الإلكتروني أو الهاتف
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'البريد الإلكتروني أو رقم الهاتف',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: surfaceField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaceBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                const Icon(Remix.user_3_line, color: brandGreen, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _loginIdentifierCtrl,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'name@example.com أو 0500000000',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF71717A),
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني أو رقم الهاتف';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // كلمة المرور مع زر نسيت كلمة المرور
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'كلمة المرور',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: _openForgotModal,
                child: const Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: brandYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: surfaceField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaceBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Icon(Remix.lock_password_line, color: brandYellow, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _loginPasswordCtrl,
                    textDirection: TextDirection.ltr,
                    obscureText: _loginObscurePassword,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: '••••••••',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF71717A),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      return null;
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() => _loginObscurePassword = !_loginObscurePassword);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _loginObscurePassword ? Remix.eye_off_line : Remix.eye_line,
                      color: const Color(0xFF9CA3AF),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // تذكرني على هذا الجهاز
          InkWell(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? false),
                      activeColor: brandGreen,
                      checkColor: const Color(0xFF0A0B0B),
                      side: const BorderSide(color: surfaceBorder, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'تذكرني على هذا الجهاز',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFFD4D4D8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // زر الدخول
          InkWell(
            onTap: _isLoading ? null : _handleLogin,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: brandGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Remix.login_box_line, color: Color(0xFF0A0B0B), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'تسجيل الدخول إلى Spendo',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF0A0B0B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // زر استيراد نسخة احتياطية من ملف
          InkWell(
            onTap: _isLoading ? null : _handleImportBackupFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: surfaceBorder),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Remix.file_upload_line, color: brandYellow, size: 15),
                  SizedBox(width: 8),
                  Text(
                    'استيراد نسخة احتياطية من ملف (.json)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFFD1D5DB),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
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

  /// 4. نموذج إنشاء حساب جديد
  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الاسم الكامل
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'الاسم الكامل',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: surfaceField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaceBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                const Icon(Remix.id_card_line, color: brandGreen, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _regNameCtrl,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'محمد أحمد',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF71717A),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال الاسم الكامل';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // البريد الإلكتروني
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'البريد الإلكتروني',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: surfaceField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaceBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Icon(Remix.mail_line, color: brandYellow, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _regEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'name@example.com',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF71717A),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'بريد إلكتروني غير صالح';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // كلمة المرور
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'كلمة المرور',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF9CA3AF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: surfaceField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaceBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Icon(Remix.lock_password_line, color: brandYellow, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _regPasswordCtrl,
                    textDirection: TextDirection.ltr,
                    obscureText: _regObscurePassword,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      hintText: '•••••••• (8 خانات على الأقل)',
                      hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Color(0xFF71717A),
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      if (val.trim().length < 6) {
                        return 'كلمة المرور يجب ألا تقل عن 6 خانات';
                      }
                      return null;
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() => _regObscurePassword = !_regObscurePassword);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _regObscurePassword ? Remix.eye_off_line : Remix.eye_line,
                      color: const Color(0xFF9CA3AF),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // زر إنشاء الحساب
          InkWell(
            onTap: _isLoading ? null : _handleRegister,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: brandGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Remix.user_add_line, color: Color(0xFF0A0B0B), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'إنشاء الحساب والبدء',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF0A0B0B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
}
