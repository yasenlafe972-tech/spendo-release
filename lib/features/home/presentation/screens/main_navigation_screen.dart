import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../../core/services/firebase_backup_service.dart';
import 'home_screen.dart';
import '../../../people/presentation/screens/people_screen.dart';
import '../../../work_logs/presentation/screens/work_logs_screen.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../vehicle/presentation/screens/vehicle_tracker_screen.dart';
import '../../../vehicle/presentation/widgets/fuel_expense_sheet.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  static const MethodChannel _shareChannel = MethodChannel('com.finance.spendo/share');
  String? _lastHandledSharePath;
  DateTime? _lastHandledShareTime;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _screens = [
      HomeScreen(
        onNavigateTab: (idx) {
          setState(() => _currentIndex = idx);
        },
      ),
      const WorkLogsScreen(),
      const VehicleTrackerScreen(),
      const PeopleScreen(),
      const FinanceScreen(),
    ];

    _initSharedFileListener();

    // Automatic bi-directional cloud sync on app launch
    try {
      FirebaseBackupService.instance.syncWithCloud(isSilent: true);
    } catch (_) {}
  }

  void _initSharedFileListener() {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile' && call.arguments is String) {
        await _handleIncomingSharedFile(call.arguments as String);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final initial = await _shareChannel.invokeMethod<String>('getInitialSharedFile');
        if (initial != null && initial.isNotEmpty) {
          await _handleIncomingSharedFile(initial);
        }
      } catch (_) {}
    });
  }

  Future<void> _handleIncomingSharedFile(String path) async {
    if (path.isEmpty) return;
    final now = DateTime.now();
    if (_lastHandledSharePath == path &&
        _lastHandledShareTime != null &&
        now.difference(_lastHandledShareTime!).inSeconds < 3) {
      return;
    }
    _lastHandledSharePath = path;
    _lastHandledShareTime = now;

    final file = File(path);
    if (!await file.exists()) return;

    if (!mounted) return;

    setState(() {
      _currentIndex = 2; // Jump straight to Vehicle tab
    });

    final ext = path.toLowerCase();
    final isPdf = ext.endsWith('.pdf');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FuelExpenseSheet.show(
          context,
          initialPdfFile: isPdf ? file : null,
          initialImageFile: !isPdf ? file : null,
        );
      }
    });
  }

  @override
  void dispose() {
    _shareChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Whenever app returns to foreground, sync with cloud
      try {
        FirebaseBackupService.instance.syncWithCloud(isSilent: true);
      } catch (_) {}
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Auto-save backup snapshot when app goes to background
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseBackupService.instance.scheduleAutoBackup(debounce: Duration.zero);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final navBg = isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
          final navBorder = isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
          final shadowColor = isDark ? const Color(0x66000000) : const Color(0x12000000);

          return Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: navBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                _buildNavItem(context, 0, 'الرئيسية', Remix.home_5_line, Remix.home_5_fill),
                _buildNavItem(context, 1, 'سجل العمل', Remix.briefcase_4_line, Remix.briefcase_4_fill),
                _buildNavItem(context, 2, 'المركبة', Remix.motorbike_line, Remix.motorbike_fill),
                _buildNavItem(context, 3, 'الأشخاص', Remix.group_line, Remix.group_fill),
                _buildNavItem(context, 4, 'المالية', Remix.wallet_3_line, Remix.wallet_3_fill),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String label, IconData lineIcon, IconData fillIcon) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = const Color(0xFF10B981);
    final inactiveColor = isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);
    final activeTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_currentIndex != index) {
            SpendoHaptics.selection();
            setState(() => _currentIndex = index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0x1A10B981),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active top indicator (emerald slim line)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 6),
              // Clean Icon
              Icon(
                isSelected ? fillIcon : lineIcon,
                size: 20,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? activeTextColor : inactiveColor,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
