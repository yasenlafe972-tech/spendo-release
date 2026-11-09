import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:remixicon/remixicon.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../../core/services/firebase_backup_service.dart';
import '../../../../core/widgets/banking_animations.dart';
import '../../../../core/widgets/spendo_app_menu.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _menuKey = GlobalKey<SpendoMenuHostState>();
  int _currentIndex = 0;
  int _previousIndex = 0;
  late final AnimationController _tabAnimController;
  late final CurvedAnimation _tabCurvedAnim;

  static const MethodChannel _shareChannel = MethodChannel(
    'com.finance.spendo/share',
  );
  String? _lastHandledSharePath;
  DateTime? _lastHandledShareTime;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _tabCurvedAnim = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.fastLinearToSlowEaseIn,
    );

    _screens = [
      HomeScreen(
        onNavigateTab: (idx) {
          _switchToTab(idx);
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

  void _switchToTab(int newIndex) {
    _menuKey.currentState?.close();
    if (newIndex == _currentIndex ||
        newIndex < 0 ||
        newIndex >= _screens.length) {
      return;
    }
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
    });
    _tabAnimController.forward(from: 0.0);
    BankingMotionController.notifyTabActivated(newIndex);
  }

  void _initSharedFileListener() {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile' && call.arguments is String) {
        await _handleIncomingSharedFile(call.arguments as String);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final initial = await _shareChannel.invokeMethod<String>(
          'getInitialSharedFile',
        );
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

    _switchToTab(2); // Jump straight to Vehicle tab with banking animation

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
    _tabCurvedAnim.dispose();
    _tabAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        FirebaseBackupService.instance.syncWithCloud(isSilent: true);
      } catch (_) {}
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      try {
        if (Firebase.apps.isNotEmpty) {
          FirebaseBackupService.instance.scheduleAutoBackup(
            debounce: Duration.zero,
          );
        }
      } catch (_) {}
    }
  }

  /// Revolut 10 / Apple Wallet Banking Parallax & Depth Transition
  Widget _buildAnimatedTabBody() {
    return AnimatedBuilder(
      animation: _tabCurvedAnim,
      builder: (context, _) {
        final double t = _tabCurvedAnim.value;
        final bool isTransitioning =
            _tabAnimController.isAnimating && _previousIndex != _currentIndex;

        // In RTL layout, index 0 (الرئيسية) is on the right, index 4 (المالية) is on the left.
        final bool movingLeftwards = _currentIndex > _previousIndex;
        final double enterStartDx = movingLeftwards ? -0.10 : 0.10;
        final double exitEndDx = movingLeftwards ? 0.06 : -0.06;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(_screens.length, (index) {
            final bool isCurrent = index == _currentIndex;
            final bool isPrevious = isTransitioning && index == _previousIndex;
            final bool isVisible = isCurrent || isPrevious;

            double opacity = 1.0;
            double dx = 0.0;
            double dy = 0.0;
            double scale = 1.0;

            if (isTransitioning) {
              if (isCurrent) {
                opacity = t.clamp(0.0, 1.0);
                dx = enterStartDx * (1.0 - t);
                dy = 0.018 * (1.0 - t);
                scale = 0.96 + (0.04 * t);
              } else if (isPrevious) {
                opacity = (1.0 - (t * 1.35)).clamp(0.0, 1.0);
                dx = exitEndDx * t;
                scale = 1.0 - (0.045 * t);
              }
            }

            return Offstage(
              offstage: !isVisible,
              child: IgnorePointer(
                ignoring: !isCurrent,
                child: FractionalTranslation(
                  translation: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: KeyedSubtree(
                        key: ValueKey<int>(index),
                        child: _screens[index],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SpendoMenuHost(key: _menuKey, child: _buildAnimatedTabBody()),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final navBg =
                isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
            final navBorder =
                isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);

            return Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              decoration: BoxDecoration(
                color: navBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: navBorder, width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double itemWidth = constraints.maxWidth / 5;
                  // In RTL, index 0 is on the right edge: right offset = _currentIndex * itemWidth
                  final double rightOffset = _currentIndex * itemWidth;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Matte neutral selection indicator, without glow or shadows.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        right: rightOffset + 3,
                        top: 1,
                        bottom: 1,
                        width: itemWidth - 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFF0F1F3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Navigation Items Row
                      Row(
                        children: [
                          _buildNavItem(
                            context,
                            0,
                            'الرئيسية',
                            Remix.home_5_line,
                            Remix.home_5_fill,
                          ),
                          _buildNavItem(
                            context,
                            1,
                            'سجل العمل',
                            Remix.briefcase_4_line,
                            Remix.briefcase_4_fill,
                          ),
                          _buildNavItem(
                            context,
                            2,
                            'المركبة',
                            Remix.motorbike_line,
                            Remix.motorbike_fill,
                          ),
                          _buildNavItem(
                            context,
                            3,
                            'الأشخاص',
                            Remix.group_line,
                            Remix.group_fill,
                          ),
                          _buildNavItem(
                            context,
                            4,
                            'المالية',
                            Remix.wallet_3_line,
                            Remix.wallet_3_fill,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    String label,
    IconData lineIcon,
    IconData fillIcon,
  ) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? const Color(0xFFF4F4F5) : const Color(0xFF27272A);
    final color =
        isSelected
            ? activeColor
            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              if (_currentIndex == index) return;
              FocusManager.instance.primaryFocus?.unfocus();
              SpendoHaptics.selection();
              _switchToTab(index);
            },
            borderRadius: BorderRadius.circular(12),
            splashColor: activeColor.withValues(alpha: 0.15),
            highlightColor: activeColor.withValues(alpha: 0.08),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        scale: isSelected ? 1.08 : 1,
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          isSelected ? fillIcon : lineIcon,
                          size: 22,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: color,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
