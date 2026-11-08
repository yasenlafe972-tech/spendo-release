import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';

/// Minimal, high-craft Boro UI Person Card for the outer grid.
/// Cleanly displays ONLY the Avatar/Photo, Name, and Date (Birthday),
/// alongside the Edit Pencil and Delete Trash actions.
/// Tapping the card opens the rich, precision-engineered PersonDetailsModalSheet.
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
  static const Color brandBlue = Color(0xFF2563EB);
  static Color get brandYellow =>
      const Color(0xFFFFD600);
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
    final highlightColor = person.isUser ? brandBlue : brandYellow;

    final hasAvatarPhoto = person.avatarPath != null &&
        person.avatarPath!.trim().isNotEmpty &&
        File(person.avatarPath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? highlightColor.withValues(alpha: 0.55)
              : surfaceBorder,
          width: isHighlighted ? 1.2 : 1.0,
        ),
        boxShadow: [
          if (_isDark)
            BoxShadow(
              color: isHighlighted
                  ? highlightColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: isHighlighted
                  ? highlightColor.withValues(alpha: 0.15)
                  : const Color(0x0A000000),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetails(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. الصورة الشخصية أو الحرف الرمزي المونوغرام
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: person.isUser
                        ? brandBlue.withValues(alpha: 0.16)
                        : brandYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: person.isUser
                          ? brandBlue.withValues(alpha: 0.45)
                          : brandYellow.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: hasAvatarPhoto
                        ? Image.file(
                            File(person.avatarPath!),
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              person.name.trim().isNotEmpty
                                  ? person.name.trim().characters.first
                                  : '؟',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: person.isUser ? brandBlue : brandYellow,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. الاسم وتاريخ الميلاد فقط من الخارج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (person.isUser) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: brandBlue.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: brandBlue.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                'أنت',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: brandBlue,
                                ),
                              ),
                            ),
                          ],
                          if (person.isPinned) ...[
                            const SizedBox(width: 3),
                            Icon(Remix.pushpin_fill,
                                size: 10, color: brandYellow),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // تاريخ الميلاد فقط
                      if (birthdayStr != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Remix.cake_2_line,
                                  size: 10.5, color: brandYellow),
                              const SizedBox(width: 4),
                              Text(
                                birthdayStr,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontFamilyFallback: ['Cairo', 'Heebo'],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: brandYellow,
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
                            fontSize: 9,
                            color: textSubtle,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // 3. قلم بجانب السطل (أزرار التعديل والحذف)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        SpendoHaptics.light();
                        onEdit();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(3.5),
                        child: Icon(Remix.pencil_line,
                            size: 14, color: textMuted),
                      ),
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: () {
                        SpendoHaptics.light();
                        onDelete();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(3.5),
                        child: Icon(Remix.delete_bin_line,
                            size: 14, color: textMuted),
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
