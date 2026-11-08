import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';

/// Compact Boro UI 2-Column Person Card with zero dead space, zero overflow,
/// vibrant Canary Yellow (#FFD600) & Electric Royal Blue (#2563EB) accents,
/// Plus Jakarta Sans numbers, and tight micro-bento ergonomics.
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
  static const Color brandYellow = Color(0xFFFFD600);
  static Color get textPrimary =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color get textMuted =>
      _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textSubtle =>
      _isDark ? const Color(0xFF71717A) : const Color(0xFF9CA3AF);
  static Color get textDim =>
      _isDark ? const Color(0xFF45454E) : const Color(0xFFD1D5DB);

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

    final isHighlighted = person.isPinned || person.isUser;
    final highlightColor = person.isUser ? brandBlue : brandYellow;

    return Container(
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? highlightColor.withValues(alpha: 0.5)
              : surfaceBorder,
          width: isHighlighted ? 1.2 : 1.0,
        ),
        boxShadow: [
          if (_isDark)
            BoxShadow(
              color: isHighlighted
                  ? highlightColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.25),
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
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. الترويسة: الحرف الرمزي المضيء + الاسم والوسوم + أزرار الإجراءات
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // الحرف الرمزي (Monogram) بالأصفر الكناري أو الأزرق الملكي
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: person.isUser
                            ? brandBlue.withValues(alpha: 0.16)
                            : brandYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: person.isUser
                              ? brandBlue.withValues(alpha: 0.45)
                              : brandYellow.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        person.name.trim().isNotEmpty
                            ? person.name.trim().characters.first
                            : '؟',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: person.isUser ? brandBlue : brandYellow,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // الاسم والشارات مع حماية ضد الـ Overflow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              if (person.isUser) ...[
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: brandBlue.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: brandBlue.withValues(alpha: 0.4),
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
                                const SizedBox(width: 2),
                                const Icon(Remix.pushpin_fill,
                                    size: 9.5, color: brandYellow),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),

                          // تاريخ الميلاد بخط بلس جاكرتا الأصفر مع حماية كاملة
                          if (birthdayStr != null)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Remix.cake_2_line,
                                      size: 9.5, color: brandYellow),
                                  const SizedBox(width: 3),
                                  Text(
                                    birthdayStr,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontFamilyFallback: ['Cairo', 'Heebo'],
                                      fontSize: 9,
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
                                fontSize: 8.5,
                                color: textSubtle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 3),

                    // أزرار التعديل والحذف
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
                            padding: const EdgeInsets.all(2),
                            child: Icon(Remix.edit_line,
                                size: 12, color: textMuted),
                          ),
                        ),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () {
                            SpendoHaptics.light();
                            onDelete();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Remix.delete_bin_line,
                                size: 12, color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 5),
                Divider(
                  height: 1,
                  thickness: 0.7,
                  color: surfaceBorder.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4.5),

                // 2. الحقول السفلية المنظمة بإحكام (Micro-Bento بدون فراغ)
                // صف الهاتف بالأزرق الملكي
                Row(
                  children: [
                    const Icon(Remix.phone_line, size: 10.5, color: brandBlue),
                    const SizedBox(width: 3.5),
                    Text(
                      'هاتف',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 9,
                        color: textMuted,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          phone ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontFamilyFallback: const ['Cairo', 'Heebo'],
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2.5),

                // صف الهوية بالأصفر الكناري
                Row(
                  children: [
                    Icon(
                      Remix.id_card_line,
                      size: 10.5,
                      color: idNumber != null ? brandYellow : textDim,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'هوية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 9,
                        color: textMuted,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          idNumber ?? 'غير مسجل',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: idNumber != null
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          style: TextStyle(
                            fontFamily:
                                idNumber != null ? 'PlusJakartaSans' : 'Cairo',
                            fontFamilyFallback: const ['Cairo', 'Heebo'],
                            fontSize: idNumber != null ? 10 : 8.5,
                            fontWeight: idNumber != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: idNumber != null ? textPrimary : textSubtle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // صف الإيميل أو الحسابات
                const SizedBox(height: 2.5),
                if (accountCount > 0 || email != null)
                  Row(
                    children: [
                      if (accountCount > 0) ...[
                        const Icon(Remix.key_2_line,
                            size: 10, color: brandYellow),
                        const SizedBox(width: 2.5),
                        Text(
                          '$accountCount حساب',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: brandYellow,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (email != null) ...[
                        Icon(Remix.mail_line,
                            size: 10,
                            color: accountCount > 0 ? textSubtle : brandBlue),
                        const SizedBox(width: 2.5),
                        Expanded(
                          child: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontFamilyFallback: const ['Cairo', 'Heebo'],
                              fontSize: 8.5,
                              color: textSubtle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Remix.mail_line, size: 10, color: textDim),
                      const SizedBox(width: 3.5),
                      Text(
                        'بدون إيميل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 8.5,
                          color: textSubtle,
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
