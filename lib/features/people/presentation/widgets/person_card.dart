import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';

/// Compact 2-Column Person Card strictly matching the user's HTML prototype 1:1.
/// Features clean typography, subtle background watermark, and zero extra clutter.
class PersonCard extends StatelessWidget {
  final PersonModel person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onViewDetails;
  final VoidCallback? onOpenAccounts;
  final int accountCount;

  // Design Tokens matching HTML specification
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceField => _isDark ? const Color(0xFF171A19) : const Color(0xFFFFFFFF);
  static Color get surfaceBorder => _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const brandGreen = Color(0xFF00A86B);
  static const brandYellow = Color(0xFFEAB308);
  static Color get textPrimary => _isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
  static Color get textSubtle => _isDark ? const Color(0xFF6B7280) : const Color(0xFF4B5563);
  static Color get textDim => _isDark ? const Color(0xFF52525B) : const Color(0xFF6B7280);

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
    final phone = (person.phone != null && person.phone!.trim().isNotEmpty)
        ? person.phone!.trim()
        : (person.whatsapp != null && person.whatsapp!.trim().isNotEmpty)
            ? person.whatsapp!.trim()
            : null;
    final idNumber = (person.nationalId != null &&
            person.nationalId!.trim().isNotEmpty)
        ? person.nationalId!.trim()
        : null;
    final email = (person.email != null && person.email!.trim().isNotEmpty)
        ? person.email!.trim()
        : null;
    final birthdayStr = person.birthdate != null
        ? DateFormat('dd/MM/yyyy').format(person.birthdate!)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: person.isPinned
                ? brandYellow.withValues(alpha: 0.5)
                : surfaceBorder,
            width: 1.0,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            // أيقونة مدمجة هادئة في خلفية البطاقة
            Positioned(
              left: -4,
              bottom: -4,
              child: Icon(
                Icons.person_outline_rounded,
                size: 58,
                color: Colors.white.withValues(alpha: 0.025),
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openDetails(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. الجزء العلوي: الاسم وعيد الميلاد مع أزرار التعديل والحذف
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // الاسم مع أيقونة الشخص الخضراء
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline_rounded,
                                          size: 13,
                                          color: brandGreen,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            person.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (person.isUser) ...[
                                          const SizedBox(width: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: brandGreen
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: brandGreen
                                                      .withValues(alpha: 0.4)),
                                            ),
                                            child: const Text('أنت',
                                                style: TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: brandGreen)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),

                                    // عيد الميلاد (أصفر إذا كان مسجلاً، باهت إذا لم يسجل)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.cake_outlined,
                                          size: 11,
                                          color: birthdayStr != null
                                              ? brandYellow
                                              : textDim,
                                        ),
                                        const SizedBox(width: 4),
                                        if (birthdayStr != null)
                                          Text(
                                            birthdayStr,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: brandYellow,
                                            ),
                                            textDirection: TextDirection.ltr,
                                          )
                                        else
                                          Text(
                                            'بدون ميلاد',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: textSubtle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),

                              // أزرار التعديل والحذف بدون خلفية
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      SpendoHaptics.light();
                                      onEdit();
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.5),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  InkWell(
                                    onTap: () {
                                      SpendoHaptics.light();
                                      onDelete();
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.5),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 13,
                                        color: textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),

                          // خط فاصل رفيع هادئ
                          Container(
                            height: 0.8,
                            color: surfaceBorder.withValues(alpha: 0.8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 2. الجزء السفلي: الهاتف، الهوية، الإيميل
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // صف الهاتف
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      size: 11, color: brandGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    'هاتف',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: Text(
                                  phone ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // صف الهوية
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 11,
                                    color: idNumber != null
                                        ? brandYellow
                                        : textDim,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'هوية',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: idNumber != null
                                    ? Text(
                                        idNumber,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      )
                                    : Text(
                                        'غير مسجل',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: textSubtle,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // صف الإيميل
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                size: 11,
                                color: email != null ? brandGreen : textDim,
                              ),
                              Flexible(
                                child: email != null
                                    ? Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: textPrimary,
                                        ),
                                      )
                                    : Text(
                                        'بدون إيميل',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: textSubtle,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
