import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

/// A sleek, modern, zero-wasted-space deletion confirmation dialog
/// compliant with the Obsidian Dark & Daylight Unified Specification.
class SpendoConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String? itemName;
  final IconData? itemIcon;
  final String? description;
  final String? warningNote;
  final String confirmLabel;
  final String cancelLabel;
  final Color dangerColor;

  const SpendoConfirmDeleteDialog({
    super.key,
    required this.title,
    this.itemName,
    this.itemIcon,
    this.description,
    this.warningNote,
    this.confirmLabel = 'حذف',
    this.cancelLabel = 'إلغاء',
    this.dangerColor = AppColors.dangerRed,
  });

  /// Static helper to display the dialog cleanly from any screen
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? itemName,
    IconData? itemIcon,
    String? description,
    String? warningNote,
    String confirmLabel = 'حذف',
    String cancelLabel = 'إلغاء',
    Color dangerColor = AppColors.dangerRed,
  }) async {
    SpendoHaptics.warning();
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => SpendoConfirmDeleteDialog(
        title: title,
        itemName: itemName,
        itemIcon: itemIcon,
        description: description,
        warningNote: warningNote,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        dangerColor: dangerColor,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceMain = isDark ? const Color(0xFF141418) : Colors.white;
    final surfaceCell = isDark ? const Color(0xFF1B1B22) : const Color(0xFFF4F5F7);
    final surfaceBorder = isDark ? const Color(0xFF282832) : const Color(0xFFE2E4E8);
    final textWhite = isDark ? Colors.white : const Color(0xFF111827);
    final textMuted = isDark ? const Color(0xFF8E8E9A) : const Color(0xFF6B7280);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: surfaceMain,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: surfaceBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with soft danger icon badge + title + close icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dangerColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: dangerColor.withValues(alpha: 0.28),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(Remix.delete_bin_6_line, color: dangerColor, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                        ),
                        if (description != null && description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              description!,
                              style: TextStyle(
                                fontSize: 11,
                                color: textMuted,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context, false),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Remix.close_line, size: 18, color: textMuted),
                    ),
                  ),
                ],
              ),

              // 2. Highlighted entity card (if itemName is provided)
              if (itemName != null && itemName!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceCell,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        itemIcon ?? Remix.building_2_line,
                        size: 16,
                        color: textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          itemName!.trim(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textWhite,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. Warning Note banner (if provided)
              if (warningNote != null && warningNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: dangerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dangerColor.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Remix.error_warning_line, size: 15, color: dangerColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warningNote!.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // 4. Perfectly balanced symmetric action buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () {
                          SpendoHaptics.light();
                          Navigator.pop(context, false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textWhite,
                          side: BorderSide(color: surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          cancelLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Confirm Delete button
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          SpendoHaptics.success();
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Remix.delete_bin_line, size: 15, color: Colors.white),
                        label: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
}
