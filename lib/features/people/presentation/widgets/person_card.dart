import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';

/// Ultra-compact, high-density FinTech Person Card for the outer grid.
/// Cleanly displays:
/// 1. Symbolic User Icon (matching the Finance section, no personal photo images).
/// 2. Person Name and Birthday Date.
/// 3. Edit Pencil icon right next to the Delete Trash bucket.
/// Reduced padding and zero dead whitespace.
class PersonCard extends StatelessWidget {
  final PersonModel person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onViewDetails;
  final VoidCallback? onOpenAccounts;
  final int accountCount;

  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceCard =>
      _isDark ? const Color(0xFF16161A) : const Color(0xFFFFFFFF);
  static Color get surfaceBorder =>
      _isDark ? const Color(0xFF222229) : const Color(0xFFE5E7EB);
  static const Color brandBlue = Color(0xFF10B981);

  static Color get textPrimary =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color get textMuted =>
      _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textSubtle =>
      _isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);

  const PersonCard({
    super.key,
    required this.person,
    required this.onEdit,
    required this.onDelete,
    this.onTogglePin,
    this.onViewDetails,
    this.onOpenAccounts,
    this.accountCount = 0,
  });

  void _openDetails(BuildContext context) {
    SpendoHaptics.light();
    if (onViewDetails != null) {
      onViewDetails!();
    } else {
      PersonDetailsModalSheet.show(
        context: context,
        person: person,
        onEdit: onEdit,
        onDelete: onDelete,
        onTogglePin: onTogglePin ?? () {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthdayStr = person.birthdate != null
        ? DateFormat('dd/MM/yyyy').format(person.birthdate!)
        : null;

    final isHighlighted = person.isPinned || person.isUser;
    const highlightColor = brandBlue;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? highlightColor.withValues(alpha: _isDark ? 0.55 : 0.45)
              : surfaceBorder,
          width: isHighlighted ? 1.1 : 0.9,
        ),
        boxShadow: [
          if (_isDark)
            BoxShadow(
              color: isHighlighted
                  ? highlightColor.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.20),
              blurRadius: 6,
              offset: const Offset(0, 1.5),
            )
          else
            BoxShadow(
              color: isHighlighted
                  ? highlightColor.withValues(alpha: 0.12)
                  : const Color(0x0A000000),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetails(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. أيقونة المستخدم الرمزية (مثل قسم المالية - بدون صورة شخصية)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: Icon(
                      person.isUser ? Remix.user_star_line : Remix.user_3_line,
                      size: 20,
                      color: person.isUser ? brandBlue : textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 7),

                // 2. الاسم وتاريخ الميلاد فقط في الوسط
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                height: 1.15,
                              ),
                            ),
                          ),
                          if (person.isUser) ...[
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3.5, vertical: 0.5),
                              decoration: BoxDecoration(
                                color: brandBlue.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(3.5),
                                border: Border.all(
                                  color: brandBlue.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'أنت',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: brandBlue,
                                ),
                              ),
                            ),
                          ],
                          if (person.isPinned) ...[
                            const SizedBox(width: 3),
                            Icon(Remix.pushpin_fill,
                                size: 9.5, color: textMuted),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),

                      // تاريخ الميلاد فقط
                      if (birthdayStr != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Remix.cake_2_line,
                                  size: 9.5, color: textMuted),
                              const SizedBox(width: 3),
                              Text(
                                birthdayStr,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontFamilyFallback: const ['Cairo', 'Heebo'],
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'بدون ميلاد',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 8.5,
                            color: textSubtle,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // 3. قلم التعديل بجانب سطل الحذف مباشرة
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        SpendoHaptics.light();
                        onEdit();
                      },
                      borderRadius: BorderRadius.circular(5),
                      child: Padding(
                        padding: const EdgeInsets.all(3.5),
                        child: Icon(Remix.pencil_line,
                            size: 13, color: textMuted),
                      ),
                    ),
                    const SizedBox(width: 1),
                    InkWell(
                      onTap: () {
                        SpendoHaptics.light();
                        onDelete();
                      },
                      borderRadius: BorderRadius.circular(5),
                      child: Padding(
                        padding: const EdgeInsets.all(3.5),
                        child: Icon(Remix.delete_bin_line,
                            size: 13, color: textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
