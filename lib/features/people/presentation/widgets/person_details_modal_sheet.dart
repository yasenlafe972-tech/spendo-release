import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_accounts_modal_sheet.dart';

/// Modal Popup for Person Details (بطاقة الملف الشخصي - My profile).
/// Fully replicates the Obsidian Dark Clean Grid Prototype (Image 2).
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
      barrierColor: Colors.black.withValues(alpha: 0.8),
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
  State<PersonDetailsModalSheet> createState() => _PersonDetailsModalSheetState();
}

class _PersonDetailsModalSheetState extends State<PersonDetailsModalSheet> {
  // Theme Design Tokens
  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121417) : const Color(0xFFFFFFFF);
  static Color get surfaceCell => _isDark ? const Color(0xFF16191E) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF22262E) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static const Color brandRed = Color(0xFFEF4444);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);

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
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: surfaceCell,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: brandGreen, width: 0.8),
        ),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Remix.checkbox_circle_line, color: brandYellow, size: 15),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(color: textWhite, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAll() {
    final p = widget.person;
    final buffer = StringBuffer();
    buffer.writeln(p.name);
    if (p.phone != null && p.phone!.trim().isNotEmpty) {
      buffer.writeln('الهاتف: ${p.phone}');
    }
    if (p.nationalId != null && p.nationalId!.trim().isNotEmpty) {
      buffer.writeln('الهوية: ${p.nationalId}');
    }
    if (p.email != null && p.email!.trim().isNotEmpty) {
      buffer.writeln('الإيميل: ${p.email}');
    }
    if (p.notes != null && p.notes!.trim().isNotEmpty) {
      buffer.writeln('ملاحظات: ${p.notes}');
    }

    _copy(buffer.toString().trim(), 'تم نسخ كافة بيانات الملف الشخصي');
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
            : '0505870690';
    final nationalId = (p.nationalId != null && p.nationalId!.trim().isNotEmpty)
        ? p.nationalId!.trim()
        : '12346790';
    final email = (p.email != null && p.email!.trim().isNotEmpty)
        ? p.email!.trim()
        : 'yasenlafe972@gmail.com';
    final notes = (p.notes != null && p.notes!.trim().isNotEmpty)
        ? p.notes!.trim()
        : 'الملف الشخصي الأساسي';

    final birthAndAge = (p.formattedBirthdateAndAge?.isNotEmpty ?? false)
        ? p.formattedBirthdateAndAge!
        : '24/10/1998 • 28y';

    final servicesPreview = _accountServices.isNotEmpty
        ? _accountServices.take(5).join(', ')
        : 'Apple, DaVinci AI, Mapbox, PayPal, cloud.oracle...';

    return Container(
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: surfaceBorder, width: 1.0),
          left: BorderSide(color: surfaceBorder, width: 1.0),
          right: BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Action & Info Bar (Without large circular avatar)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceCell,
                    border: Border(bottom: BorderSide(color: surfaceBorder)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Close (X) + Divider + Edit + Delete
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Remix.close_line, size: 18, color: Color(0xFFA1A1AA)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(width: 1, height: 14, color: surfaceBorder),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onEdit();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Remix.pencil_line, size: 14, color: Color(0xFFA1A1AA)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onDelete();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Remix.delete_bin_6_line, size: 14, color: brandRed),
                            ),
                          ),
                        ],
                      ),

                      // Right: Profile Name + DOB + Copy All Button
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Remix.shield_user_line, size: 13, color: brandGreen),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.name.isNotEmpty ? p.name : 'My profile',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: brandYellow.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: brandYellow,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                birthAndAge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: Color(0xFFA1A1AA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: _copyAll,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: surfaceMain,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: surfaceBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Remix.file_copy_2_line, size: 11, color: brandGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'نسخ الكل',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Profile Details Grid (Aligned side-by-side without wasted space)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Row 1: ID / رقم الهوية + WHATSAPP / الهاتف
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCell(
                            label: 'ID / رقم الهوية',
                            value: nationalId,
                            isMonospace: true,
                            onCopy: () => _copy(nationalId, 'تم نسخ رقم الهوية'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoCell(
                            label: 'WHATSAPP / الهاتف',
                            value: phone,
                            isMonospace: true,
                            onCopy: () => _copy(phone, 'تم نسخ رقم الهاتف'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 2: ملاحظات + GMAIL / البريد الإلكتروني
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildInfoCell(
                            label: 'ملاحظات',
                            value: notes,
                            isMonospace: false,
                            onCopy: () => _copy(notes, 'تم نسخ الملاحظات'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 7,
                          child: _buildInfoCell(
                            label: 'GMAIL / البريد الإلكتروني',
                            value: email,
                            isMonospace: true,
                            onCopy: () => _copy(email, 'تم نسخ البريد الإلكتروني'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row 3: Banner Button to Accounts & Passwords Section
                    InkWell(
                      onTap: _openAccountsVault,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: surfaceCell,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brandGreen.withValues(alpha: 0.5)),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            children: [
                              // Count Badge + Arrow on Left
                              Row(
                                children: [
                                  const Icon(Remix.arrow_left_s_line, size: 14, color: Color(0xFFA1A1AA)),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: surfaceMain,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: surfaceBorder),
                                    ),
                                    child: Text(
                                      '$_accountsCount',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: brandGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),

                              // Text Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Text(
                                          '(Accounts & passwords)',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: Color(0xFFA1A1AA),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'قسم الإيميلات والحسابات',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: textWhite,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      servicesPreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFFA1A1AA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Yellow Key Icon on Right
                              const Icon(Remix.key_2_line, color: brandYellow, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCell({
    required String label,
    required String value,
    required bool isMonospace,
    required VoidCallback onCopy,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCell,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            // Copy button on side
            InkWell(
              onTap: onCopy,
              child: Container(
                width: 30,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surfaceCell,
                  border: Border(left: BorderSide(color: surfaceBorder)),
                ),
                child: const Icon(Remix.file_copy_line, size: 12, color: Color(0xFFA1A1AA)),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: isMonospace ? 11 : 11,
                        fontFamily: isMonospace ? 'monospace' : null,
                        fontWeight: FontWeight.bold,
                        color: textWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}