import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../../core/services/firebase_backup_service.dart';
import 'home_screen.dart';
import '../../../people/presentation/screens/people_screen.dart';
import '../../../work_logs/presentation/screens/work_logs_screen.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../vehicle/presentation/screens/vehicle_tracker_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

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

    // Automatic cloud sync on app launch (debounced by 3s to let UI settle)
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseBackupService.instance.scheduleAutoBackup(debounce: const Duration(seconds: 3));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF121413),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF242927), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              _buildNavItem(0, 'الرئيسية', Remix.home_5_line, Remix.home_5_fill),
              _buildNavItem(1, 'سجل العمل', Remix.briefcase_4_line, Remix.briefcase_4_fill),
              _buildNavItem(2, 'المركبة', Remix.motorbike_line, Remix.motorbike_fill),
              _buildNavItem(3, 'الأشخاص', Remix.group_line, Remix.group_fill),
              _buildNavItem(4, 'المالية', Remix.wallet_3_line, Remix.wallet_3_fill),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData lineIcon, IconData fillIcon) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_currentIndex != index) {
            SpendoHaptics.selection();
            setState(() => _currentIndex = index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0x1A00A86B),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active top indicator (yellow slim line)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEAB308) : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 6),
              // Clean Icon (no capsule / no background)
              Icon(
                isSelected ? fillIcon : lineIcon,
                size: 20,
                color: isSelected ? const Color(0xFF00A86B) : const Color(0xFF9CA3AF),
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
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
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
