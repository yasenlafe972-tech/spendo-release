import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sanad_app/firebase_options.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/security/security_service.dart';
import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/services/auth_link_service.dart';
import 'package:sanad_app/core/services/deletion_sync_service.dart';
import 'package:sanad_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:sanad_app/features/home/presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for async unhandled errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Global error: $error');
    return true;
  };

  // If any widget throws an exception during build in release mode, show an informative diagnostic UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Widget build error: ${details.exception}');
    return Material(
      color: const Color(0xFF121413),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'تنبيه إقلاع Spendo',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: SelectableText(
                    details.exceptionAsString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  details.stack.toString(),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  // Initialize Firebase with explicit cross-platform options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

  // Initialize distributed deletion tombstone ledger
  try {
    await DeletionSyncService.init();
  } catch (e) {
    debugPrint('DeletionSyncService initialization notice: $e');
  }

  await AppTheme.initThemeMode();

  final bool isLoggedIn = await AuthLinkService.isAccountLoggedIn();

  runApp(SanadApp(initialRouteIsLoggedIn: isLoggedIn));
}

class SanadApp extends StatelessWidget {
  final bool initialRouteIsLoggedIn;

  const SanadApp({
    super.key,
    required this.initialRouteIsLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: AppTheme.fontScaleNotifier,
          builder: (context, fontScale, _) {
            return MaterialApp(
              title: 'Spendo - سبيندو',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              // Arabic RTL support + User-controlled Font & UI Scale across iOS & Android
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(fontScale),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              home: initialRouteIsLoggedIn
                  ? const MainNavigationScreen()
                  : const AuthScreen(),
            );
          },
        );
      },
    );
  }
}
