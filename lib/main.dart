import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/security/security_service.dart';
import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/services/auth_link_service.dart';
import 'package:sanad_app/features/home/presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent Flutter's default grey screen in release mode if any sub-widget fails
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Widget build error: ${details.exception}');
    return const SizedBox.shrink();
  };

  // Force dark status bar and orientation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF18181B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    AuthLinkService.linkAccount();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize security key & SQLite database safely without blocking runApp on iOS Keychain restrictions
  try {
    await SecurityService.instance.initialize();
  } catch (e) {
    debugPrint('SecurityService initialization notice: $e');
  }

  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('DatabaseHelper initialization notice: $e');
  }

  runApp(const SanadApp());
}

class SanadApp extends StatelessWidget {
  const SanadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spendo - سبيندو',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Arabic RTL support by default for natural directionality
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}
