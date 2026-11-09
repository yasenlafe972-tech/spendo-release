import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/settings/presentation/screens/app_settings_screen.dart';

/// Consistent hamburger menu used from every main section.
class SpendoMenuButton extends StatelessWidget {
  final Future<void> Function()? onSettingsClosed;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;

  const SpendoMenuButton({
    super.key,
    this.onSettingsClosed,
    this.color,
    this.size = 20,
    this.padding = const EdgeInsets.all(8),
    this.constraints,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'فتح القائمة',
      onPressed: () => SpendoAppMenu.open(
        context,
        onSettingsClosed: onSettingsClosed,
      ),
      icon: Icon(Remix.menu_line, size: size, color: color),
      padding: padding,
      constraints: constraints,
      visualDensity: visualDensity,
    );
  }
}

class SpendoAppMenu {
  SpendoAppMenu._();

  static Future<void> open(
    BuildContext context, {
    Future<void> Function()? onSettingsClosed,
  }) async {
    SpendoHaptics.light();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.background : const Color(0xFFF8F9FA);
    final surface = isDark ? AppColors.surface : Colors.white;
    final border = isDark ? AppColors.surfaceCardBorder : const Color(0xFFE5E7EB);
    final foreground = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? AppColors.textMuted : const Color(0xFF6B7280);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق القائمة الجانبية',
      barrierColor: Colors.black.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Material(
            color: background,
            child: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.82 > 320
                  ? 320
                  : MediaQuery.of(dialogContext).size.width * 0.82,
              height: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(start: BorderSide(color: border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'القائمة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: foreground,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Remix.close_line, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: border),
                    ListTile(
                      leading: const Icon(
                        Remix.settings_4_line,
                        color: AppColors.spendoGreen,
                      ),
                      title: Text(
                        'الإعدادات',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Remix.arrow_left_s_line, color: muted),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AppSettingsScreen(),
                          ),
                        );
                        if (context.mounted && onSettingsClosed != null) {
                          await onSettingsClosed();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}