import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';

/// Quick actions bar component designed for the Spendo Obsidian Dark theme.
///
/// Displays four primary high-frequency actions with custom accent palettes,
/// embedded background watermark icons, tactile haptic feedback, and fluid press animations.
class QuickActionBar extends StatelessWidget {
  /// Callback triggered when "تسجيل يومية" is pressed.
  final VoidCallback? onAddWorkLog;

  /// Callback triggered when "مكان عمل جديد" is pressed.
  final VoidCallback? onAddWorkplace;

  /// Callback triggered when "دين أو سلفة" is pressed.
  final VoidCallback? onAddDebt;

  /// Callback triggered when "تعبئة وقود" is pressed.
  final VoidCallback? onAddFuelRefill;

  /// Backwards-compatible callback for legacy tests.
  final VoidCallback? onOpenCloudBackup;

  /// Optional outer padding for the row container.
  final EdgeInsetsGeometry padding;

  const QuickActionBar({
    super.key,
    this.onAddWorkLog,
    this.onAddWorkplace,
    this.onAddDebt,
    this.onAddFuelRefill,
    this.onOpenCloudBackup,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              label: 'تسجيل يومية',
              icon: Icons.add_task_rounded,
              accentColor: AppColors.spendoGreen,
              onTap: onAddWorkLog,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              label: 'مكان عمل جديد',
              icon: Icons.domain_add_rounded,
              accentColor: const Color(0xFF38BDF8),
              onTap: onAddWorkplace,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              label: 'دين أو سلفة',
              icon: Icons.receipt_long_rounded,
              accentColor: const Color(0xFFFFD600),
              onTap: onAddDebt,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              label: 'تعبئة وقود',
              icon: Icons.local_gas_station_rounded,
              accentColor: const Color(0xFF10B981),
              onTap: onAddFuelRefill ?? onOpenCloudBackup,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  void _handleTap() {
    SpendoHaptics.light();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
            decoration: BoxDecoration(
              color: _isPressed ? AppColors.surfaceElevated : AppColors.surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: _isPressed
                    ? widget.accentColor.withValues(alpha: 0.45)
                    : const Color(0xFF1E1E24),
                width: 1.0,
              ),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Embedded background watermark icon
                  Positioned(
                    left: -12,
                    bottom: -12,
                    child: IgnorePointer(
                      child: Icon(
                        widget.icon,
                        size: 58,
                        color: widget.accentColor.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                  // Foreground content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.22),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
