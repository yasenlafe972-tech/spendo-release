import 'package:sanad_app/core/widgets/banking_animations.dart';
import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:remixicon/remixicon.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_card.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_accounts_modal_sheet.dart';
import 'package:sanad_app/features/settings/presentation/screens/app_settings_screen.dart';
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
  Color get surfaceMain => _isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F9FA);
  Color get surfaceField => _isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
  Color get surfaceBorder => _isDark ? const Color(0xFF1E1E24) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color brandYellow = Color(0xFFF59E0B);
  Color get textPrimary => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  Color get textMuted => _isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  Color get textSubtle => _isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);

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
      list = list.where((p) {
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

  // نافذة الإضافة والتعديل المدمجة المطابقة لكود الـ HTML بنسبة 1:1
  Future<void> _showAddEditModal([PersonModel? person]) async {
    SpendoHaptics.light();
    final isEdit = person != null;
    final nameCtrl = TextEditingController(text: person?.name ?? '');
    final phoneCtrl = TextEditingController(
        text: person?.phone ?? person?.whatsapp ?? '');
    final idNumberCtrl =
        TextEditingController(text: person?.nationalId ?? '');
    final emailCtrl = TextEditingController(text: person?.email ?? '');

    DateTime? selectedDate = person?.birthdate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceMain,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final keyboardInset = media.viewInsets.bottom;
        final bottomNavPadding = media.padding.bottom > 0
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
                    left: 14,
                    right: 14,
                    top: 10,
                    bottom: keyboardInset > 0
                        ? keyboardInset + 8
                        : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // مؤشر السحب
                        Center(
                          child: Container(
                            width: 32,
                            height: 3.5,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF404040),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),

                        // صندوق الحقول الرئيسي
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceField,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: surfaceBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ترويسة النافذة
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isEdit
                                            ? Icons.edit_outlined
                                            : Icons.person_add_outlined,
                                        size: 16,
                                        color: brandYellow,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isEdit
                                            ? 'تعديل بيانات الشخص'
                                            : 'إضافة شخص جديد',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () => Navigator.pop(ctx),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Icon(Icons.close_rounded,
                                          size: 18, color: textMuted),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 0.8, color: surfaceBorder),
                              const SizedBox(height: 10),

                              // 1. الاسم
                              _buildFieldLabel('الاسم *'),
                              _buildInputField(
                                controller: nameCtrl,
                                placeholder: 'الاسم الكامل',
                              ),
                              const SizedBox(height: 10),

                              // 2. الهاتف (حقل كامل العرض مع زر لصق مخصص)
                              _buildFieldLabel('الهاتف (اختياري)'),
                              _buildInputField(
                                controller: phoneCtrl,
                                placeholder: '05X-XXXXXXX',
                                isLtr: true,
                                keyboardType: TextInputType.phone,
                                showPasteButton: true,
                                isPhone: true,
                              ),
                              const SizedBox(height: 10),

                              // 3. رقم الهوية (حقل كامل العرض مع زر لصق مخصص)
                              _buildFieldLabel('رقم الهوية (اختياري)'),
                              _buildInputField(
                                controller: idNumberCtrl,
                                placeholder: '9 أرقام',
                                isLtr: true,
                                keyboardType: TextInputType.number,
                                showPasteButton: true,
                                digitsOnlyOnPaste: true,
                              ),
                              const SizedBox(height: 10),

                              // 4. تاريخ الميلاد (بطاقة كبسولة تفاعلية أنيقة)
                              _buildFieldLabel('تاريخ الميلاد (اختياري)'),
                              InkWell(
                                onTap: () async {
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
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: surfaceMain,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedDate != null
                                          ? brandGreen.withValues(alpha: 0.5)
                                          : surfaceBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: (selectedDate != null
                                                  ? brandGreen
                                                  : brandYellow)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Remix.cake_2_line,
                                          size: 16,
                                          color: selectedDate != null
                                              ? brandGreen
                                              : brandYellow,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: selectedDate != null
                                            ? Row(
                                                children: [
                                                  Text(
                                                    DateFormat('dd/MM/yyyy')
                                                        .format(selectedDate!),
                                                    style: TextStyle(
                                                      color: textPrimary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Builder(
                                                    builder: (ctx) {
                                                      final now =
                                                          DateTime.now();
                                                      int age = now.year -
                                                          selectedDate!.year;
                                                      if (now.month <
                                                              selectedDate!
                                                                  .month ||
                                                          (now.month ==
                                                                  selectedDate!
                                                                      .month &&
                                                              now.day <
                                                                  selectedDate!
                                                                      .day)) {
                                                        age--;
                                                      }
                                                      if (age >= 0) {
                                                        return Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 6,
                                                              vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: brandGreen
                                                                .withValues(
                                                                    alpha: 0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          child: Text(
                                                            '$age سنة',
                                                            style:
                                                                const TextStyle(
                                                              color: brandGreen,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return const SizedBox
                                                          .shrink();
                                                    },
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'انقر لاختيار تاريخ الميلاد',
                                                style: TextStyle(
                                                  color: textSubtle,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                      ),
                                      if (selectedDate != null)
                                        InkWell(
                                          onTap: () {
                                            selectedDate = null;
                                            setModalState(() {});
                                          },
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(Icons.close_rounded,
                                                size: 16, color: textMuted),
                                          ),
                                        )
                                      else
                                        Icon(Remix.calendar_event_line,
                                            size: 16, color: textMuted),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 5. الإيميل
                              _buildFieldLabel('الإيميل (اختياري)'),
                              _buildInputField(
                                controller: emailCtrl,
                                placeholder: 'example@gmail.com',
                                isLtr: true,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),

                              // أزرار الحفظ والإلغاء
                              Row(
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: brandGreen,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () async {
                                          final name = nameCtrl.text.trim();
                                          if (name.isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'يرجى إدخال اسم الشخص أولاً'),
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

                                          final updated = isEdit
                                              ? PersonModel(
                                                  id: person.id,
                                                  name: name,
                                                  isUser: person.isUser,
                                                  birthdate: selectedDate,
                                                  email: cleanEmail.isEmpty
                                                      ? null
                                                      : cleanEmail,
                                                  phone: cleanPhone.isEmpty
                                                      ? null
                                                      : cleanPhone,
                                                  whatsapp: cleanPhone.isEmpty
                                                      ? null
                                                      : cleanPhone,
                                                  nationalId: cleanId.isEmpty
                                                      ? null
                                                      : cleanId,
                                                  bank: person.bank,
                                                  accountNumber:
                                                      person.accountNumber,
                                                  isPinned: person.isPinned,
                                                  hourlyRate: person.hourlyRate,
                                                  dailyRate: person.dailyRate,
                                                  notes: person.notes,
                                                  createdAt: person.createdAt,
                                                  updatedAt: DateTime.now(),
                                                )
                                              : PersonModel(
                                                  id: DateTime.now()
                                                      .millisecondsSinceEpoch
                                                      .toString(),
                                                  name: name,
                                                  birthdate: selectedDate,
                                                  email: cleanEmail.isEmpty
                                                      ? null
                                                      : cleanEmail,
                                                  phone: cleanPhone.isEmpty
                                                      ? null
                                                      : cleanPhone,
                                                  whatsapp: cleanPhone.isEmpty
                                                      ? null
                                                      : cleanPhone,
                                                  nationalId: cleanId.isEmpty
                                                      ? null
                                                      : cleanId,
                                                  createdAt: DateTime.now(),
                                                  updatedAt: DateTime.now(),
                                                );

                                          SpendoHaptics.success();
                                          if (isEdit) {
                                            await _repository
                                                .updatePerson(updated);
                                          } else {
                                            await _repository
                                                .addPerson(updated);
                                          }
                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                          }
                                          _loadPeople();
                                        },
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Container(
                                          height: 38,
                                          alignment: Alignment.center,
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.check_rounded,
                                                  size: 15,
                                                  color: Colors.white),
                                              SizedBox(width: 5),
                                              Text(
                                                'حفظ',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => Navigator.pop(ctx),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: surfaceMain,
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: surfaceBorder),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'إلغاء',
                                        style: TextStyle(
                                          color: textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    bool isLtr = false,
    TextInputType keyboardType = TextInputType.text,
    bool showPasteButton = false,
    bool isPhone = false,
    bool digitsOnlyOnPaste = false,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: surfaceBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
        textAlign: isLtr ? TextAlign.right : TextAlign.start,
        style: TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: isLtr ? FontWeight.w600 : FontWeight.normal,
        ),
        enableInteractiveSelection: true,
        onChanged: (val) {
          if (isPhone || digitsOnlyOnPaste) {
            final cleaned = _cleanPastedNumber(
              val,
              isPhone: isPhone,
              digitsOnly: digitsOnlyOnPaste,
            );
            if (cleaned != val) {
              controller.value = TextEditingValue(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );
            }
          }
          onChanged?.call(val);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: placeholder,
          hintStyle: TextStyle(color: textSubtle, fontSize: 11),
          hintTextDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 36),
          suffixIcon: showPasteButton
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: InkWell(
                    onTap: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text ?? '';
                      if (text.trim().isNotEmpty) {
                        final cleaned = _cleanPastedNumber(
                          text,
                          isPhone: isPhone,
                          digitsOnly: digitsOnlyOnPaste,
                        );
                        if (cleaned.isNotEmpty) {
                          controller.text = cleaned;
                          controller.selection =
                              TextSelection.collapsed(offset: cleaned.length);
                          SpendoHaptics.light();
                          onChanged?.call(cleaned);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: brandGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: brandGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_paste_rounded,
                              size: 12, color: brandGreen),
                          SizedBox(width: 4),
                          Text(
                            'لصق',
                            style: TextStyle(
                              color: brandGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : (suffixIcon != null
                  ? InkWell(
                      onTap: onSuffixTap,
                      child: Icon(suffixIcon, size: 14, color: brandYellow),
                    )
                  : null),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PersonModel person) async {
    final confirmed = await SpendoConfirmDeleteDialog.show(
      context,
      title: 'تأكيد حذف جهة الاتصال',
      itemName: person.name,
      itemIcon: Icons.person_outline,
      description: 'هل أنت متأكد من حذف بطاقة "${person.name}" نهائياً من السجل؟',
      warningNote: 'سيتم أيضاً حذف جميع الحسابات وكلمات المرور المرتبطة بهذا الشخص.',
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
                              style: const TextStyle(
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
                          style: TextStyle(
                            fontSize: 10,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),

                    // أزرار الشريط العلوي: زر الإعدادات، التحديث، وزر إضافة شخص
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.settings_outlined,
                              color: textMuted, size: 20),
                          tooltip: 'الإعدادات',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            SpendoHaptics.light();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const AppSettingsScreen()),
                            );
                            _loadPeople();
                          },
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
                                  horizontal: 10, vertical: 6),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_add_outlined,
                                      size: 13, color: Colors.white),
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
                    style:
                        TextStyle(color: textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم، الهاتف، أو رقم الهوية...',
                      hintStyle:
                          TextStyle(color: textSubtle, fontSize: 11.5),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 16, color: textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 15, color: textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              ),
              const SizedBox(height: 10),

              // 4. شبكة البطاقات المصغرة (بطاقتان في كل صف)
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: brandGreen))
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'لا توجد بطاقات مطابقة للبحث',
                                style: TextStyle(
                                  color: textSubtle,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : BankingCascadeItem(
                            tabIndex: 3,
                            staggerIndex: 1,
                            child: GridView.builder(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 14,
                              top: 2,
                              bottom: 96,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: (1.46 / AppTheme.fontScaleNotifier.value.clamp(0.85, 1.25)).clamp(1.18, 1.50),
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
                                      person.id, person.isPinned);
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
                                          person.id, person.isPinned);
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
