import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_card.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_details_modal_sheet.dart';
import 'package:sanad_app/features/people/presentation/widgets/person_accounts_modal_sheet.dart';
import 'package:sanad_app/features/settings/presentation/screens/app_settings_screen.dart';
import 'package:sanad_app/core/database/database_helper.dart';

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
    setState(() => _isLoading = true);
    final list = await _repository.getAllPeople();
    final counts = await _repository.getAllAccountCounts();
    if (!mounted) return;
    setState(() {
      _people = list;
      _accountCounts = counts;
      _isLoading = false;
    });
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

  // نافذة الإضافة والتعديل المدمجة المطابقة لكود الـ HTML بنسبة 1:1
  Future<void> _showAddEditModal([PersonModel? person]) async {
    SpendoHaptics.light();
    final isEdit = person != null;
    final nameCtrl = TextEditingController(text: person?.name ?? '');
    final phoneCtrl = TextEditingController(
        text: person?.phone ?? person?.whatsapp ?? '');
    final birthdayCtrl = TextEditingController(
      text: person?.birthdate != null
          ? DateFormat('dd/MM/yyyy').format(person!.birthdate!)
          : '',
    );
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
                              const SizedBox(height: 8),

                              // 2. الهاتف وعيد الميلاد في صف مقسوم عمودين
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('الهاتف'),
                                        _buildInputField(
                                          controller: phoneCtrl,
                                          placeholder: '05X-XXXXXXX',
                                          isLtr: true,
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel(
                                            'عيد الميلاد (اختياري)'),
                                        _buildInputField(
                                          controller: birthdayCtrl,
                                          placeholder: 'DD/MM/YYYY',
                                          isLtr: true,
                                          suffixIcon: Icons.calendar_today_rounded,
                                          onSuffixTap: () async {
                                            final now = DateTime.now();
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: selectedDate ??
                                                  DateTime(now.year - 25, 1, 1),
                                              firstDate: DateTime(1930),
                                              lastDate: now,
                                              builder: (dCtx, child) =>
                                                  Theme(
                                                data: ThemeData.dark().copyWith(
                                                  colorScheme:
                                                      ColorScheme.dark(
                                                    primary: brandGreen,
                                                    surface: surfaceField,
                                                  ),
                                                ),
                                                child: child!,
                                              ),
                                            );
                                            if (picked != null) {
                                              selectedDate = picked;
                                              birthdayCtrl.text =
                                                  DateFormat('dd/MM/yyyy')
                                                      .format(picked);
                                              setModalState(() {});
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 3. رقم الهوية
                              _buildFieldLabel('رقم الهوية (اختياري)'),
                              _buildInputField(
                                controller: idNumberCtrl,
                                placeholder: '9 أرقام',
                                isLtr: true,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),

                              // 4. الإيميل
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

                                          DateTime? bDate = selectedDate;
                                          if (bDate == null &&
                                              birthdayCtrl.text
                                                  .trim()
                                                  .isNotEmpty) {
                                            try {
                                              final parts = birthdayCtrl.text
                                                  .trim()
                                                  .split('/');
                                              if (parts.length == 3) {
                                                bDate = DateTime(
                                                  int.parse(parts[2]),
                                                  int.parse(parts[1]),
                                                  int.parse(parts[0]),
                                                );
                                              }
                                            } catch (_) {}
                                          }

                                          final updated = PersonModel(
                                            id: isEdit
                                                ? person.id
                                                : DateTime.now()
                                                    .millisecondsSinceEpoch
                                                    .toString(),
                                            name: name,
                                            isUser: person?.isUser ?? false,
                                            phone: phoneCtrl.text.trim().isEmpty
                                                ? null
                                                : phoneCtrl.text.trim(),
                                            whatsapp:
                                                phoneCtrl.text.trim().isEmpty
                                                    ? null
                                                    : phoneCtrl.text.trim(),
                                            birthdate: bDate,
                                            nationalId: idNumberCtrl.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : idNumberCtrl.text.trim(),
                                            email: emailCtrl.text.trim().isEmpty
                                                ? null
                                                : emailCtrl.text.trim(),
                                            isPinned: person?.isPinned ?? false,
                                            createdAt: person?.createdAt ??
                                                DateTime.now(),
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
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      height: 36,
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
        style: TextStyle(color: textPrimary, fontSize: 11.5),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: textSubtle, fontSize: 11),
          hintTextDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          suffixIcon: suffixIcon != null
              ? InkWell(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, size: 14, color: brandYellow),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PersonModel person) async {
    SpendoHaptics.light();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceField,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaceBorder),
        ),
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(
            color: textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف بطاقة "${person.name}" نهائياً من السجل؟',
          style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFFEF4444),
              side: BorderSide(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('حذف',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  height: 38,
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
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 14,
                              top: 2,
                              bottom: 96,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.15,
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
            ],
          ),
        ),
      ),
    );
  }
}
