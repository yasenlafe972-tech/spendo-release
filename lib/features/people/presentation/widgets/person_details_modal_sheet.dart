import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_accounts_modal_sheet.dart';

/// Luxury FinTech Bento Modal Sheet for Person Details.
/// Opens upon tapping any PersonCard in the people directory.
/// Features high-contrast obsidian styling, photo avatar support,
/// quick actions (Call, WhatsApp, Copy, Email, Vault), and Plus Jakarta Sans figures.
class PersonDetailsModalSheet extends StatefulWidget {
  final PersonModel person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onAccountsChanged;

  const PersonDetailsModalSheet({
    super.key,
    required this.person,
    required this.onEdit,
    required this.onDelete,
    this.onTogglePin,
    this.onAccountsChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required PersonModel person,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onTogglePin,
    VoidCallback? onAccountsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => PersonDetailsModalSheet(
        person: person,
        onEdit: onEdit,
        onDelete: onDelete,
        onTogglePin: onTogglePin,
        onAccountsChanged: onAccountsChanged,
      ),
    );
  }

  @override
  State<PersonDetailsModalSheet> createState() =>
      _PersonDetailsModalSheetState();
}

class _PersonDetailsModalSheetState extends State<PersonDetailsModalSheet> {
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain =>
      _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  static Color get surfaceCard =>
      _isDark ? const Color(0xFF16161A) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder =>
      _isDark ? const Color(0xFF222229) : const Color(0xFFE5E7EB);
  static const Color brandBlue = Color(0xFF10B981);
  static Color get brandYellow =>
      const Color(0xFFFFD600);
  static const Color brandRed = Color(0xFFEF4444);
  static const Color brandGreen = Color(0xFF10B981);
  static Color get textWhite =>
      _isDark ? Colors.white : const Color(0xFF111827);
  static Color get textMuted =>
      _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  final PeopleRepository _repository = PeopleRepository();
  int _accountsCount = 0;
  List<String> _accountServices = [];

  @override
  void initState() {
    super.initState();
    _loadAccountsCount();
  }

  Future<void> _loadAccountsCount() async {
    final list = await _repository.getAccountsForPerson(widget.person.id);
    if (mounted) {
      setState(() {
        _accountsCount = list.length;
        _accountServices = list.map((a) => a.service).toList();
      });
    }
  }

  void _copy(String text, String message) {
    if (text.trim().isEmpty || text == '—') return;
    Clipboard.setData(ClipboardData(text: text));
    SpendoHaptics.selection();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: surfaceCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: brandBlue, width: 0.8),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(Remix.checkbox_circle_line,
                color: brandYellow, size: 16),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: textWhite,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAll() {
    final p = widget.person;
    final buffer = StringBuffer();
    buffer.writeln('الاسم: ${p.name}');
    if (p.phone != null && p.phone!.trim().isNotEmpty) {
      buffer.writeln('الهاتف: ${p.phone}');
    }
    if (p.nationalId != null && p.nationalId!.trim().isNotEmpty) {
      buffer.writeln('رقم الهوية: ${p.nationalId}');
    }
    if (p.birthdate != null) {
      buffer.writeln(
          'تاريخ الميلاد: ${p.birthdate!.day}/${p.birthdate!.month}/${p.birthdate!.year}');
    }
    if (p.email != null && p.email!.trim().isNotEmpty) {
      buffer.writeln('البريد الإلكتروني: ${p.email}');
    }
    if (p.notes != null && p.notes!.trim().isNotEmpty) {
      buffer.writeln('ملاحظات: ${p.notes}');
    }

    _copy(buffer.toString().trim(), 'تم نسخ كافة بيانات الشخص');
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) {
      clean = '972${clean.substring(1)}';
    }
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openAccountsVault() {
    Navigator.pop(context);
    PersonAccountsModalSheet.show(
      context: context,
      person: widget.person,
      onAccountsChanged: () {
        _loadAccountsCount();
        widget.onAccountsChanged?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final phone = (p.phone != null && p.phone!.trim().isNotEmpty)
        ? p.phone!.trim()
        : (p.whatsapp != null && p.whatsapp!.trim().isNotEmpty)
            ? p.whatsapp!.trim()
            : null;
    final nationalId = (p.nationalId != null && p.nationalId!.trim().isNotEmpty)
        ? p.nationalId!.trim()
        : null;
    final email = (p.email != null && p.email!.trim().isNotEmpty)
        ? p.email!.trim()
        : null;
    final notes = (p.notes != null && p.notes!.trim().isNotEmpty)
        ? p.notes!.trim()
        : null;

    final hasAvatarPhoto = p.avatarPath != null &&
        p.avatarPath!.trim().isNotEmpty &&
        File(p.avatarPath!).existsSync();

    final isHighlighted = p.isPinned || p.isUser;
    final highlightColor = p.isUser ? brandBlue : brandYellow;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceMain,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: surfaceBorder),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. مقبض السحب العلوي
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: surfaceBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. ترويسة الملف الشخصي (Hero Profile Header)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // صورة البروفايل أو المونوغرام الفخم
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isHighlighted
                              ? highlightColor.withValues(alpha: 0.16)
                              : brandYellow.withValues(alpha: 0.14),
                          border: Border.all(
                            color: isHighlighted
                                ? highlightColor.withValues(alpha: 0.6)
                                : brandYellow.withValues(alpha: 0.5),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isHighlighted
                                  ? highlightColor.withValues(alpha: 0.18)
                                  : brandYellow.withValues(alpha: 0.15),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasAvatarPhoto
                              ? Image.file(
                                  File(p.avatarPath!),
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    p.name.trim().isNotEmpty
                                        ? p.name.trim().characters.first
                                        : '؟',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isHighlighted
                                          ? highlightColor
                                          : brandYellow,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // اسم الشخص والبادجات
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (p.isUser) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: brandBlue.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: brandBlue
                                              .withValues(alpha: 0.45)),
                                    ),
                                    child: const Text(
                                      'أنت',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: brandBlue,
                                      ),
                                    ),
                                  ),
                                ],
                                if (p.isPinned) ...[
                                  const SizedBox(width: 4),
                                  Icon(Remix.pushpin_fill,
                                      size: 13, color: brandYellow),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),

                            // تاريخ الميلاد والعمر المحسوب
                            if (p.birthdate != null)
                              Row(
                                children: [
                                  Icon(Remix.cake_2_line,
                                      size: 12, color: brandYellow),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${p.birthdate!.day}/${p.birthdate!.month}/${p.birthdate!.year}',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontFamilyFallback: const ['Cairo', 'Heebo'],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: brandYellow,
                                    ),
                                    textDirection: TextDirection.ltr,
                                  ),
                                  if (p.calculatedAge != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color:
                                            brandYellow.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${p.calculatedAge} سنة',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: brandYellow,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            else
                              Text(
                                'بدون تاريخ ميلاد',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // أزرار التحكم العلوية (تعديل وحذف وتثبيت)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onTogglePin != null)
                            InkWell(
                              onTap: () {
                                SpendoHaptics.light();
                                widget.onTogglePin!();
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  p.isPinned
                                      ? Remix.pushpin_fill
                                      : Remix.pushpin_line,
                                  size: 16,
                                  color: p.isPinned ? brandYellow : textMuted,
                                ),
                              ),
                            ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onEdit();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(Remix.pencil_line,
                                  size: 16, color: brandBlue),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onDelete();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(Remix.delete_bin_line,
                                  size: 16, color: brandRed),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Icon(Remix.close_line,
                                  size: 18, color: textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: surfaceBorder, height: 1),
                const SizedBox(height: 10),

                // 3. شبكة بطاقات المعلومات التفصيلية (FinTech Bento Cells)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      // بطاقة الهاتف مع خيارات اتصال واتساب ونسخ
                      _buildDetailTile(
                        icon: Remix.phone_line,
                        iconColor: brandBlue,
                        title: 'رقم الهاتف / الواتساب',
                        value: phone ?? 'غير مسجل',
                        isLtrValue: phone != null,
                        actions: phone != null
                            ? [
                                _buildActionIcon(
                                  icon: Remix.phone_fill,
                                  color: brandBlue,
                                  tooltip: 'اتصال',
                                  onTap: () => _makeCall(phone),
                                ),
                                const SizedBox(width: 4),
                                _buildActionIcon(
                                  icon: Remix.whatsapp_fill,
                                  color: brandGreen,
                                  tooltip: 'واتساب',
                                  onTap: () => _openWhatsApp(phone),
                                ),
                                const SizedBox(width: 4),
                                _buildActionIcon(
                                  icon: Remix.file_copy_line,
                                  color: textMuted,
                                  tooltip: 'نسخ',
                                  onTap: () =>
                                      _copy(phone, 'تم نسخ رقم الهاتف'),
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // بطاقة رقم الهوية
                      _buildDetailTile(
                        icon: Remix.id_card_line,
                        iconColor: brandYellow,
                        title: 'رقم الهوية الوطنية',
                        value: nationalId ?? 'غير مسجل',
                        isLtrValue: nationalId != null,
                        actions: nationalId != null
                            ? [
                                _buildActionIcon(
                                  icon: Remix.file_copy_line,
                                  color: textMuted,
                                  tooltip: 'نسخ',
                                  onTap: () => _copy(
                                      nationalId, 'تم نسخ رقم الهوية'),
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // بطاقة البريد الإلكتروني
                      _buildDetailTile(
                        icon: Remix.mail_line,
                        iconColor: brandBlue,
                        title: 'البريد الإلكتروني',
                        value: email ?? 'غير مسجل',
                        isLtrValue: email != null,
                        actions: email != null
                            ? [
                                _buildActionIcon(
                                  icon: Remix.send_plane_fill,
                                  color: brandBlue,
                                  tooltip: 'إرسال إيميل',
                                  onTap: () => _sendEmail(email),
                                ),
                                const SizedBox(width: 4),
                                _buildActionIcon(
                                  icon: Remix.file_copy_line,
                                  color: textMuted,
                                  tooltip: 'نسخ',
                                  onTap: () => _copy(
                                      email, 'تم نسخ البريد الإلكتروني'),
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // بطاقة خزنة الحسابات وكلمات المرور المرتبطة
                      InkWell(
                        onTap: _openAccountsVault,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: brandYellow.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: brandYellow.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Remix.key_2_line,
                                    size: 16, color: brandYellow),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'خزنة الحسابات وكلمات المرور',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _accountServices.isNotEmpty
                                          ? _accountServices
                                              .take(4)
                                              .join(' • ')
                                          : 'إدارة كلمات المرور والحسابات التابعة',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: brandYellow.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_accountsCount',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontFamilyFallback: [
                                          'Cairo',
                                          'Heebo'
                                        ],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: brandYellow,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(Remix.arrow_left_s_line,
                                        size: 12, color: brandYellow),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (notes != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailTile(
                          icon: Remix.file_text_line,
                          iconColor: brandYellow,
                          title: 'ملاحظات',
                          value: notes,
                          isLtrValue: false,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. زر نسخ كافة البيانات
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: InkWell(
                    onTap: _copyAll,
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: surfaceCard,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: surfaceBorder),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Remix.file_copy_2_line,
                              size: 15, color: textWhite),
                          const SizedBox(width: 6),
                          Text(
                            'نسخ كافة بيانات الشخص',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textWhite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isLtrValue,
    List<Widget>? actions,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection:
                      isLtrValue ? TextDirection.ltr : TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: isLtrValue ? 'PlusJakartaSans' : 'Cairo',
                    fontFamilyFallback: const ['Cairo', 'Heebo'],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textWhite,
                  ),
                ),
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 6),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        SpendoHaptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}
