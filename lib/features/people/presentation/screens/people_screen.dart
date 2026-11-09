import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sanad_app/core/widgets/banking_animations.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:sanad_app/core/widgets/spendo_app_menu.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_card.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_accounts_modal_sheet.dart';
import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/widgets/spendo_confirm_delete_dialog.dart';
import 'package:sanad_app/core/widgets/spendo_date_picker.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final PeopleRepository _repository = PeopleRepository();
  List<PersonModel> _people = [];
  Map<String, int> _accountCounts = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Design Tokens - Adaptive to active theme
  Color get surfaceMain =>
      _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  Color get surfaceField =>
      _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  Color get surfaceBorder =>
      _isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF0F766E);
  Color get brandYellow => const Color(0xFFFFD600);
  Color get textPrimary =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textMuted =>
      _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  Color get textSubtle =>
      _isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    DatabaseHelper.dataVersionNotifier.addListener(_loadPeople);
    _loadPeople();
  }

  @override
  void dispose() {
    DatabaseHelper.dataVersionNotifier.removeListener(_loadPeople);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final list = await _repository.getAllPeople();
      final counts = await _repository.getAllAccountCounts();
      if (!mounted) return;
      setState(() {
        _people = list;
        _accountCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('PeopleScreen _loadPeople error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<PersonModel> get _filteredPeople {
    var list = _people;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list =
          list.where((p) {
            final nameMatches = p.name.toLowerCase().contains(q);
            final phoneMatches = p.phone?.contains(q) ?? false;
            final emailMatches = p.email?.toLowerCase().contains(q) ?? false;
            final idMatches = p.nationalId?.contains(q) ?? false;
            return nameMatches || phoneMatches || emailMatches || idMatches;
          }).toList();
    }

    // Sort: Pinned first, then user first, then by name
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return b.isPinned ? 1 : -1;
      }
      if (a.isUser != b.isUser) {
        return b.isUser ? 1 : -1;
      }
      return a.name.compareTo(b.name);
    });

    return list;
  }

  /// Cleans pasted numbers: converts Indic/Eastern numerals to ASCII digits,
  /// strips zero-width/directional marks, and sanitizes for phone or national ID.
  static String _cleanPastedNumber(
    String raw, {
    bool isPhone = false,
    bool digitsOnly = false,
  }) {
    if (raw.isEmpty) return raw;
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternIndic = '۰۱۲۳۴۵۶۷۸۹';
    var cleaned = raw;
    for (int i = 0; i < 10; i++) {
      cleaned = cleaned.replaceAll(arabicIndic[i], i.toString());
      cleaned = cleaned.replaceAll(easternIndic[i], i.toString());
    }
    // Remove invisible directional and format unicode characters
    cleaned = cleaned.replaceAll(
      RegExp(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]'),
      '',
    );

    if (digitsOnly) {
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    } else if (isPhone) {
      final hasPlus = cleaned.trim().startsWith('+');
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
      if (hasPlus) cleaned = '+$cleaned';
    }
    return cleaned;
  }

  // نافذة الإضافة والتعديل بتصميم بطاقات Bento العصرية وثيم الذهب/الأصفر
  Future<void> _showAddEditModal([PersonModel? person]) async {
    SpendoHaptics.light();
    final isEdit = person != null;
    final nameCtrl = TextEditingController(text: person?.name ?? '');
    final phoneCtrl = TextEditingController(
      text: person?.phone ?? person?.whatsapp ?? '',
    );
    final idNumberCtrl = TextEditingController(text: person?.nationalId ?? '');
    final emailCtrl = TextEditingController(text: person?.email ?? '');
    String? avatarPath = person?.avatarPath;

    DateTime? selectedDate = person?.birthdate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding =
            media.padding.bottom > 0
                ? media.padding.bottom
                : media.viewPadding.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        keyboardInset > 0
                            ? keyboardInset
                            : (bottomNavPadding > 0
                                ? bottomNavPadding + 8
                                : 16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // مقبض السحب العلوي
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
                      const SizedBox(height: 8),

                      // ترويسة الهوية (Hero Profile Header)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: surfaceBorder,
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // الصورة الرمزية مع خيار إضافة صورة شخصية
                              InkWell(
                                onTap: () async {
                                  SpendoHaptics.light();
                                  final source = await showModalBottomSheet<
                                    ImageSource
                                  >(
                                    context: ctx,
                                    backgroundColor: surfaceMain,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    builder:
                                        (sheetCtx) => SafeArea(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                              horizontal: 16,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'الصورة الشخصية',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ListTile(
                                                  leading: Icon(
                                                    Remix.image_line,
                                                    color: brandYellow,
                                                  ),
                                                  title: Text(
                                                    'اختيار من المعرض',
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  onTap:
                                                      () => Navigator.pop(
                                                        sheetCtx,
                                                        ImageSource.gallery,
                                                      ),
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Remix.camera_line,
                                                    color: brandGreen,
                                                  ),
                                                  title: Text(
                                                    'التقاط بالكاميرا',
                                                    style: TextStyle(
                                                      fontFamily: 'Cairo',
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  onTap:
                                                      () => Navigator.pop(
                                                        sheetCtx,
                                                        ImageSource.camera,
                                                      ),
                                                ),
                                                if (avatarPath != null)
                                                  ListTile(
                                                    leading: const Icon(
                                                      Remix.delete_bin_line,
                                                      color: Color(0xFFEF4444),
                                                    ),
                                                    title: const Text(
                                                      'إزالة الصورة',
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        color: Color(
                                                          0xFFEF4444,
                                                        ),
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(sheetCtx);
                                                      setModalState(
                                                        () => avatarPath = null,
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  );

                                  if (source != null) {
                                    final picked = await ImagePicker()
                                        .pickImage(
                                          source: source,
                                          maxWidth: 600,
                                          maxHeight: 600,
                                          imageQuality: 85,
                                        );
                                    if (picked != null) {
                                      setModalState(
                                        () => avatarPath = picked.path,
                                      );
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(99),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: brandYellow.withValues(
                                          alpha: 0.12,
                                        ),
                                        border: Border.all(
                                          color: brandYellow.withValues(
                                            alpha: 0.55,
                                          ),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: brandYellow.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child:
                                            avatarPath != null &&
                                                    avatarPath!
                                                        .trim()
                                                        .isNotEmpty &&
                                                    File(
                                                      avatarPath!,
                                                    ).existsSync()
                                                ? Image.file(
                                                  File(avatarPath!),
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                )
                                                : Center(
                                                  child:
                                                      isEdit &&
                                                              person.name
                                                                  .trim()
                                                                  .isNotEmpty
                                                          ? Text(
                                                            person.name
                                                                .trim()
                                                                .characters
                                                                .first,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Cairo',
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  brandYellow,
                                                            ),
                                                          )
                                                          : Icon(
                                                            Remix.user_add_line,
                                                            size: 22,
                                                            color: brandYellow,
                                                          ),
                                                ),
                                      ),
                                    ),
                                    Positioned(
                                      left: -2,
                                      bottom: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(3.5),
                                        decoration: BoxDecoration(
                                          color: brandYellow,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: surfaceMain,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Remix.camera_fill,
                                          size: 10,
                                          color: Color(0xFF0A0B0B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // معلومات العنوان والشارة الذهبية
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit
                                          ? (person.name.isNotEmpty
                                              ? person.name
                                              : 'تعديل بيانات الشخص')
                                          : 'إضافة شخص جديد',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: brandYellow.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: brandYellow.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Remix.shield_user_line,
                                            size: 11,
                                            color: brandYellow,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isEdit
                                                ? 'بطاقة شخصية مسجلة'
                                                : 'ملف جهة اتصال جديد',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: brandYellow,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // زر الإغلاق
                              InkWell(
                                onTap: () => Navigator.pop(ctx),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: surfaceBorder.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Remix.close_line,
                                    size: 16,
                                    color: textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // محتوى البطاقات
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // وسم البطاقة 1: الهوية الأساسية
                              _buildSectionTag(
                                icon: Remix.profile_line,
                                title: 'البيانات التعريفية والسن',
                              ),
                              const SizedBox(height: 5),

                              // بطاقة Bento 1: الاسم + تاريخ الميلاد
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: surfaceBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: _isDark ? 0.2 : 0.03,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // حقل الاسم
                                    _buildBentoRow(
                                      icon: Remix.user_3_line,
                                      iconColor: brandYellow,
                                      child: TextField(
                                        controller: nameCtrl,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'الاسم الكامل أو التجاري *',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: textSubtle,
                                            fontSize: 11.5,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                        ),
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 0.8,
                                      color: surfaceBorder.withValues(
                                        alpha: 0.7,
                                      ),
                                      indent: 38,
                                      endIndent: 12,
                                    ),
                                    // صف تاريخ الميلاد المدمج
                                    _buildBirthdayRow(
                                      selectedDate: selectedDate,
                                      onPick: () async {
                                        final picked =
                                            await SpendoDatePicker.pickBirthDate(
                                              context,
                                              initialDate: selectedDate,
                                            );
                                        if (picked != null) {
                                          selectedDate = picked;
                                          setModalState(() {});
                                        }
                                      },
                                      onClear: () {
                                        selectedDate = null;
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // وسم البطاقة 2: الاتصال والتحقق
                              _buildSectionTag(
                                icon: Remix.shield_keyhole_line,
                                title: 'معلومات الاتصال والتحقق',
                              ),
                              const SizedBox(height: 5),

                              // بطاقة Bento 2: الهاتف + الهوية + الإيميل
                              Container(
                                decoration: BoxDecoration(
                                  color: surfaceField,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: surfaceBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: _isDark ? 0.2 : 0.03,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // رقم الهاتف مع زر لصق أصفر
                                    _buildBentoRow(
                                      icon: Remix.phone_line,
                                      iconColor: brandGreen,
                                      child: TextField(
                                        controller: phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        onChanged: (val) {
                                          final cleaned = _cleanPastedNumber(
                                            val,
                                            isPhone: true,
                                          );
                                          if (cleaned != val) {
                                            phoneCtrl.value = TextEditingValue(
                                              text: cleaned,
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: cleaned.length,
                                                  ),
                                            );
                                          }
                                        },
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'رقم الهاتف (05X-XXXXXXX)',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: textSubtle,
                                            fontSize: 11.5,
                                          ),
                                          hintTextDirection: TextDirection.rtl,
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                        ),
                                      ),
                                      trailing: _buildAmberPasteChip(
                                        iconColor: brandGreen,
                                        onPaste: () async {
                                          final data = await Clipboard.getData(
                                            Clipboard.kTextPlain,
                                          );
                                          final text = data?.text ?? '';
                                          if (text.trim().isNotEmpty) {
                                            final cleaned = _cleanPastedNumber(
                                              text,
                                              isPhone: true,
                                            );
                                            if (cleaned.isNotEmpty) {
                                              phoneCtrl.text = cleaned;
                                              phoneCtrl.selection =
                                                  TextSelection.collapsed(
                                                    offset: cleaned.length,
                                                  );
                                              SpendoHaptics.light();
                                              setModalState(() {});
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 0.8,
                                      color: surfaceBorder.withValues(
                                        alpha: 0.7,
                                      ),
                                      indent: 38,
                                      endIndent: 12,
                                    ),
                                    // رقم الهوية مع زر لصق أصفر
                                    _buildBentoRow(
                                      icon: Remix.id_card_line,
                                      iconColor: brandYellow,
                                      child: TextField(
                                        controller: idNumberCtrl,
                                        keyboardType: TextInputType.number,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        onChanged: (val) {
                                          final cleaned = _cleanPastedNumber(
                                            val,
                                            digitsOnly: true,
                                          );
                                          if (cleaned != val) {
                                            idNumberCtrl
                                                .value = TextEditingValue(
                                              text: cleaned,
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: cleaned.length,
                                                  ),
                                            );
                                          }
                                        },
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText:
                                              'رقم الهوية الوطنية (9 أرقام)',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: textSubtle,
                                            fontSize: 11.5,
                                          ),
                                          hintTextDirection: TextDirection.rtl,
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                        ),
                                      ),
                                      trailing: _buildAmberPasteChip(
                                        onPaste: () async {
                                          final data = await Clipboard.getData(
                                            Clipboard.kTextPlain,
                                          );
                                          final text = data?.text ?? '';
                                          if (text.trim().isNotEmpty) {
                                            final cleaned = _cleanPastedNumber(
                                              text,
                                              digitsOnly: true,
                                            );
                                            if (cleaned.isNotEmpty) {
                                              idNumberCtrl.text = cleaned;
                                              idNumberCtrl.selection =
                                                  TextSelection.collapsed(
                                                    offset: cleaned.length,
                                                  );
                                              SpendoHaptics.light();
                                              setModalState(() {});
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 0.8,
                                      color: surfaceBorder.withValues(
                                        alpha: 0.7,
                                      ),
                                      indent: 38,
                                      endIndent: 12,
                                    ),
                                    // البريد الإلكتروني
                                    _buildBentoRow(
                                      icon: Remix.mail_line,
                                      iconColor: brandYellow,
                                      child: TextField(
                                        controller: emailCtrl,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textDirection: TextDirection.ltr,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText:
                                              'البريد الإلكتروني (اختياري)',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Cairo',
                                            color: textSubtle,
                                            fontSize: 11.5,
                                          ),
                                          hintTextDirection: TextDirection.rtl,
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // أزرار الحفظ والإلغاء (زر حفظ أصفر فينتك مميز)
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final name = nameCtrl.text.trim();
                                        if (name.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'يرجى إدخال اسم الشخص أولاً',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final cleanPhone = _cleanPastedNumber(
                                          phoneCtrl.text.trim(),
                                          isPhone: true,
                                        );
                                        final cleanId = _cleanPastedNumber(
                                          idNumberCtrl.text.trim(),
                                          digitsOnly: true,
                                        );
                                        final cleanEmail =
                                            emailCtrl.text.trim();

                                        final updated =
                                            isEdit
                                                ? PersonModel(
                                                  id: person.id,
                                                  name: name,
                                                  isUser: person.isUser,
                                                  birthdate: selectedDate,
                                                  email:
                                                      cleanEmail.isEmpty
                                                          ? null
                                                          : cleanEmail,
                                                  phone:
                                                      cleanPhone.isEmpty
                                                          ? null
                                                          : cleanPhone,
                                                  whatsapp:
                                                      cleanPhone.isEmpty
                                                          ? null
                                                          : cleanPhone,
                                                  nationalId:
                                                      cleanId.isEmpty
                                                          ? null
                                                          : cleanId,
                                                  bank: person.bank,
                                                  accountNumber:
                                                      person.accountNumber,
                                                  avatarPath: avatarPath,
                                                  isPinned: person.isPinned,
                                                  hourlyRate: person.hourlyRate,
                                                  dailyRate: person.dailyRate,
                                                  notes: person.notes,
                                                  createdAt: person.createdAt,
                                                  updatedAt: DateTime.now(),
                                                )
                                                : PersonModel(
                                                  id:
                                                      DateTime.now()
                                                          .millisecondsSinceEpoch
                                                          .toString(),
                                                  name: name,
                                                  birthdate: selectedDate,
                                                  email:
                                                      cleanEmail.isEmpty
                                                          ? null
                                                          : cleanEmail,
                                                  phone:
                                                      cleanPhone.isEmpty
                                                          ? null
                                                          : cleanPhone,
                                                  whatsapp:
                                                      cleanPhone.isEmpty
                                                          ? null
                                                          : cleanPhone,
                                                  nationalId:
                                                      cleanId.isEmpty
                                                          ? null
                                                          : cleanId,
                                                  avatarPath: avatarPath,
                                                  createdAt: DateTime.now(),
                                                  updatedAt: DateTime.now(),
                                                );

                                        SpendoHaptics.success();
                                        if (isEdit) {
                                          await _repository.updatePerson(
                                            updated,
                                          );
                                        } else {
                                          await _repository.addPerson(updated);
                                        }
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                        _loadPeople();
                                      },
                                      borderRadius: BorderRadius.circular(11),
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: brandYellow,
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: brandYellow.withValues(
                                                alpha: 0.28,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Remix.check_line,
                                              size: 17,
                                              color:
                                                  _isDark
                                                      ? const Color(0xFF0A0B0B)
                                                      : Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isEdit
                                                  ? 'حفظ التعديلات'
                                                  : 'إضافة الشخص',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                color:
                                                    _isDark
                                                        ? const Color(
                                                          0xFF0A0B0B,
                                                        )
                                                        : Colors.white,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => Navigator.pop(ctx),
                                    borderRadius: BorderRadius.circular(11),
                                    child: Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: surfaceField,
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: surfaceBorder,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'إلغاء',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          color: textMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTag({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 12, color: brandYellow),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoRow({
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 10),
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );
  }

  Widget _buildBirthdayRow({
    required DateTime? selectedDate,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onPick,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Remix.cake_2_line, color: brandYellow, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child:
                  selectedDate != null
                      ? Row(
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (ctx) {
                              final now = DateTime.now();
                              int age = now.year - selectedDate.year;
                              if (now.month < selectedDate.month ||
                                  (now.month == selectedDate.month &&
                                      now.day < selectedDate.day)) {
                                age--;
                              }
                              if (age >= 0) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brandYellow.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: brandYellow.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '$age سنة',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: brandYellow,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      )
                      : Text(
                        'تاريخ الميلاد (اختياري)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: textSubtle,
                          fontSize: 11.5,
                        ),
                      ),
            ),
            if (selectedDate != null)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Remix.close_circle_line,
                    size: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: brandYellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: brandYellow.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Remix.calendar_event_line,
                      size: 11,
                      color: brandYellow,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'تحديد',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: brandYellow,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmberPasteChip({
    required VoidCallback onPaste,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? brandYellow;
    return InkWell(
      onTap: onPaste,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Remix.clipboard_line, size: 17, color: effectiveColor),
      ),
    );
  }

  Future<void> _confirmDelete(PersonModel person) async {
    final confirmed = await SpendoConfirmDeleteDialog.show(
      context,
      title: 'تأكيد حذف جهة الاتصال',
      itemName: person.name,
      itemIcon: Icons.person_outline,
      description:
          'هل أنت متأكد من حذف بطاقة "${person.name}" نهائياً من السجل؟',
      warningNote:
          'سيتم أيضاً حذف جميع الحسابات وكلمات المرور المرتبطة بهذا الشخص.',
      confirmLabel: 'حذف',
    );

    if (confirmed == true) {
      SpendoHaptics.success();
      await _repository.deletePerson(person.id);
      _loadPeople();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPeople;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceMain,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. مؤشر السحب العلوي المدمج
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF404040),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // 2. الترويسة العلوية المطابقة للـ HTML
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // العنوان والعداد والوصف
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.groups_outlined,
                              size: 18,
                              color: brandGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'الأشخاص المسجلين',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${filtered.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: brandYellow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'بطاقات مصغّرة • إدارة البيانات والهويات',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),

                    // أزرار الشريط العلوي: زر الإعدادات، التحديث، وزر إضافة شخص
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Remix.menu_line,
                            color: textMuted,
                            size: 20,
                          ),
                          tooltip: 'فتح القائمة',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed:
                              () => SpendoAppMenu.open(
                                context,
                                onSettingsClosed: () async {
                                  if (mounted) await _loadPeople();
                                },
                              ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: brandGreen,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => _showAddEditModal(),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'إضافة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. شريط البحث المدمج
              BankingCascadeItem(
                tabIndex: 3,
                staggerIndex: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 38),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: surfaceBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم، الهاتف، أو رقم الهوية...',
                        hintStyle: TextStyle(color: textSubtle, fontSize: 11.5),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: textMuted,
                        ),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: textMuted,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 4. شبكة البطاقات المصغرة (بطاقتان في كل صف)
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(color: brandGreen),
                        )
                        : filtered.isEmpty
                        ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'لا توجد بطاقات مطابقة للبحث',
                              style: TextStyle(color: textSubtle, fontSize: 12),
                            ),
                          ),
                        )
                        : BankingCascadeItem(
                          tabIndex: 3,
                          staggerIndex: 1,
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 14,
                              top: 2,
                              bottom: 96,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: (3.15 /
                                          AppTheme.fontScaleNotifier.value
                                              .clamp(0.85, 1.25))
                                      .clamp(2.55, 3.45),
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final person = filtered[index];
                              return PersonCard(
                                person: person,
                                accountCount: _accountCounts[person.id] ?? 0,
                                onEdit: () => _showAddEditModal(person),
                                onDelete: () => _confirmDelete(person),
                                onTogglePin: () async {
                                  await _repository.togglePin(
                                    person.id,
                                    person.isPinned,
                                  );
                                  _loadPeople();
                                },
                                onViewDetails: () {
                                  PersonDetailsModalSheet.show(
                                    context: context,
                                    person: person,
                                    onEdit: () => _showAddEditModal(person),
                                    onDelete: () => _confirmDelete(person),
                                    onTogglePin: () async {
                                      await _repository.togglePin(
                                        person.id,
                                        person.isPinned,
                                      );
                                      _loadPeople();
                                    },
                                    onAccountsChanged: _loadPeople,
                                  );
                                },
                                onOpenAccounts: () {
                                  PersonAccountsModalSheet.show(
                                    context: context,
                                    person: person,
                                    onAccountsChanged: _loadPeople,
                                  );
                                },
                              );
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
