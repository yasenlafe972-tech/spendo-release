import 'package:sanad_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';
import '../../../../core/widgets/spendo_date_picker.dart';
import '../../models/debt_model.dart';

/// Modal bottom sheet to add or edit a personal debt / loan / receipt (`تسجيل سلفة / دين مالي`).
/// Designed 1:1 based on the Spendo Obsidian Dark Design System.
class AddDebtSheet extends StatefulWidget {
  final List<PersonModel> people;
  final String? initialPersonId;
  final DebtModel? initialDebt;
  final Function(DebtModel) onSave;

  const AddDebtSheet({
    super.key,
    required this.people,
    this.initialPersonId,
    this.initialDebt,
    required this.onSave,
  });

  @override
  State<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final PeopleRepository _peopleRepo = PeopleRepository();

  late List<PersonModel> _peopleList;
  String? _selectedPersonId;
  String _debtType = 'they_owe'; // 'they_owe' (أخذ مني مصاري), 'i_owe' (أخذت منه مصاري), 'received'
  String _paymentMethod = 'bit'; // 'bit', 'cash', 'bank_transfer', 'check'
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  bool _isSaving = false;

  static bool get _isDark => AppTheme.isDarkMode;
  static Color get surfaceMain => _isDark ? const Color(0xFF121413) : const Color(0xFFFFFFFF);
  static Color get surfaceField => _isDark ? const Color(0xFF171A19) : const Color(0xFFF9FAFB);
  static Color get surfaceBorder => _isDark ? const Color(0xFF242927) : const Color(0xFFE5E7EB);
  static const Color brandGreen = Color(0xFF2563EB);
  static const Color brandYellow = Color(0xFFFFD600);
  static const Color brandRed = Color(0xFFEF4444);
  static Color get textMuted => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get textWhite => _isDark ? Colors.white : const Color(0xFF111827);

  static const List<Map<String, dynamic>> _paymentMethods = [
    {'key': 'bit', 'title': 'Bit', 'icon': Remix.smartphone_line, 'color': brandYellow},
    {'key': 'cash', 'title': 'كاش', 'icon': Remix.money_dollar_box_line, 'color': Color(0xFF10B981)},
    {'key': 'bank_transfer', 'title': 'تحويل بنكي', 'icon': Remix.bank_line, 'color': brandYellow},
    {'key': 'atm_code', 'title': 'كود صراف', 'icon': Remix.qr_code_line, 'color': brandGreen},
  ];

  @override
  void initState() {
    super.initState();
    _peopleList = widget.people.where((p) => !p.isUser).toList();

    if (widget.initialDebt != null) {
      final debt = widget.initialDebt!;
      _debtType = debt.type;
      _paymentMethod = debt.paymentMethod;
      _amountCtrl.text = debt.originalAmount == debt.originalAmount.roundToDouble()
          ? debt.originalAmount.toInt().toString()
          : debt.originalAmount.toStringAsFixed(1);
      _notesCtrl.text = debt.notes ?? '';
      _selectedPersonId = debt.personId;
      final p = _peopleList.where((x) => x.id == debt.personId).firstOrNull;
      if (p != null) {
        _nameCtrl.text = p.name;
      }
      _transactionDate = DateTime.tryParse(debt.transactionDate) ?? DateTime.now();
      if (debt.dueDate != null) {
        _dueDate = DateTime.tryParse(debt.dueDate!);
      }
    } else if (widget.initialPersonId != null) {
      final initial = _peopleList.where((p) => p.id == widget.initialPersonId).firstOrNull;
      if (initial != null) {
        _selectedPersonId = initial.id;
        _nameCtrl.text = initial.name;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDue) async {
    final picked = await SpendoDatePicker.pickDate(
      context,
      initialDate: isDue ? (_dueDate ?? DateTime.now().add(const Duration(days: 30))) : _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: isDue ? 'تاريخ السداد المتوقع' : 'تاريخ المعاملة',
    );
    if (picked != null) {
      setState(() {
        if (isDue) {
          _dueDate = picked;
        } else {
          _transactionDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final enteredName = _nameCtrl.text.trim();
    if (enteredName.isEmpty) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);
    SpendoHaptics.success();

    try {
      String resolvedPersonId;
      final match = _peopleList.where((p) =>
          (p.id == _selectedPersonId) ||
          (p.name.trim().toLowerCase() == enteredName.toLowerCase())
      ).firstOrNull;

      if (match != null) {
        resolvedPersonId = match.id;
      } else {
        // Auto-create person so user can write ANY name without friction
        final now = DateTime.now();
        final newPerson = PersonModel(
          id: const Uuid().v4(),
          name: enteredName,
          createdAt: now,
          updatedAt: now,
        );
        await _peopleRepo.addPerson(newPerson);
        resolvedPersonId = newPerson.id;
      }

      final now = DateTime.now();
      final isReceived = _debtType == 'received';
      final isPayLater = _debtType == 'pay_later';

      final DebtModel debtToSave;
      if (widget.initialDebt != null) {
        final existing = widget.initialDebt!;
        final paid = existing.paidAmount;
        final newRemaining = isReceived
            ? 0.0
            : ((amount - paid) <= 0 ? 0.0 : (amount - paid));
        final newStatus = isReceived
            ? 'settled'
            : (newRemaining <= 0 ? 'settled' : 'active');
        final savedMethod = (isPayLater && newStatus != 'settled')
            ? 'pending'
            : (existing.paymentMethod == 'pending' && !isPayLater ? _paymentMethod : (isPayLater ? existing.paymentMethod : _paymentMethod));

        debtToSave = existing.copyWith(
          personId: resolvedPersonId,
          type: _debtType,
          originalAmount: amount,
          remainingAmount: newRemaining,
          paymentMethod: savedMethod,
          transactionDate: DateFormat('yyyy-MM-dd').format(_transactionDate),
          dueDate: isReceived ? null : (_dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          status: newStatus,
          updatedAt: now,
        );
      } else {
        debtToSave = DebtModel(
          id: const Uuid().v4(),
          personId: resolvedPersonId,
          type: _debtType,
          originalAmount: amount,
          remainingAmount: isReceived ? 0.0 : amount,
          paymentMethod: isPayLater ? 'pending' : _paymentMethod,
          transactionDate: DateFormat('yyyy-MM-dd').format(_transactionDate),
          dueDate: isReceived ? null : (_dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          status: isReceived ? 'settled' : 'active',
          createdAt: now,
          updatedAt: now,
        );
      }

      widget.onSave(debtToSave);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialDebt != null;
    final isReceived = _debtType == 'received';
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomNavPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: BoxDecoration(
        color: surfaceMain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: surfaceBorder, width: 1.0),
          left: BorderSide(color: surfaceBorder, width: 1.0),
          right: BorderSide(color: surfaceBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: keyboardInset > 0
                ? keyboardInset
                : (bottomNavPadding > 0 ? bottomNavPadding + 8 : 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. مؤشر السحب العلوي (Drag handle)
              const SizedBox(height: 6),
              Center(
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: surfaceBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. ترويسة النافذة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: surfaceBorder, width: 1.0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Remix.hand_coin_line, color: brandYellow, size: 19),
                          const SizedBox(width: 7),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'تعديل سلفة / معاملة مالية' : 'تسجيل سلفة / دين مالي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: textWhite,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const Text(
                                'إدارة الديون والسلف الشخصية ومتابعة المتبقي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Remix.close_line, color: Color(0xFF9CA3AF), size: 19),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // اختيار نوع العملية
                        _buildTypeSelector(),
                        const SizedBox(height: 7),

                        // حقل اسم الشخص
                        _buildPersonNameField(),
                        const SizedBox(height: 6),

                        // حقل المبلغ الأصلي
                        _buildAmountField(),
                        const SizedBox(height: 7),

                        // طريقة دفع / تحويل السلفة
                        if (_debtType != 'pay_later') ...[
                          _buildPaymentMethodsGrid(),
                          const SizedBox(height: 7),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: brandYellow.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: brandYellow.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Remix.time_line, color: brandYellow, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'دفعة مؤجلة عالحساب — يتم اختيار طريقة الدفع (كاش / Bit / بنكي) عند الضغط على "تم الدفع" لاحقاً.',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: textMuted,
                                      fontSize: 10,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                        ],

                        // التواريخ: تاريخ السلفة + تاريخ السداد المتوقع
                        _buildDatesRow(isReceived),
                        const SizedBox(height: 6),

                        // ملاحظات وتفاصيل السلفة
                        _buildNotesField(),
                        const SizedBox(height: 8),

                        // زر الحفظ
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. اختيار نوع العملية (شبكة 2×2 مدمجة وأنيقة)
  Widget _buildTypeSelector() {
    final isTheyOwe = _debtType == 'they_owe';
    final isIOwe = _debtType == 'i_owe';
    final isPayLater = _debtType == 'pay_later';
    final isReceived = _debtType == 'received';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 1. إلي عنده (سلفة أعطيته)
              Expanded(
                child: _buildTypeOptionCard(
                  isSelected: isTheyOwe,
                  activeColor: brandGreen,
                  icon: Remix.arrow_left_down_line,
                  title: 'إلي عنده',
                  subtitle: 'سلفة أعطيته إياها',
                  onTap: () => setState(() => _debtType = 'they_owe'),
                ),
              ),
              const SizedBox(width: 4),
              // 2. عليّ إله (تدينت منه)
              Expanded(
                child: _buildTypeOptionCard(
                  isSelected: isIOwe,
                  activeColor: brandRed,
                  icon: Remix.arrow_right_up_line,
                  title: 'عليّ إله',
                  subtitle: 'مبلغ تدينته منه',
                  onTap: () => setState(() => _debtType = 'i_owe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // 3. عالحساب / دفع لاحقاً
              Expanded(
                child: _buildTypeOptionCard(
                  isSelected: isPayLater,
                  activeColor: brandYellow,
                  icon: Remix.time_line,
                  title: 'عالحساب (بدفع بعدين)',
                  subtitle: 'حلاق / محل / خدمة مؤجلة',
                  onTap: () => setState(() => _debtType = 'pay_later'),
                ),
              ),
              const SizedBox(width: 4),
              // 4. مبالغ مستلمة (سحب بنكي أو استلام مالي)
              Expanded(
                child: _buildTypeOptionCard(
                  isSelected: isReceived,
                  activeColor: brandGreen,
                  icon: Remix.checkbox_circle_line,
                  title: 'مبالغ مستلمة',
                  subtitle: 'سحب بنكي أو استلام مالي',
                  onTap: () => setState(() => _debtType = 'received'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOptionCard({
    required bool isSelected,
    required Color activeColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        SpendoHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : surfaceMain,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSelected ? activeColor : surfaceBorder,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: activeColor, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isSelected ? textWhite : textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1.5),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isSelected ? activeColor : const Color(0xFF71717A),
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. حقل اسم الشخص
  Widget _buildPersonNameField() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          const Icon(Remix.user_3_line, color: brandGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Autocomplete<PersonModel>(
              initialValue: TextEditingValue(text: _nameCtrl.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<PersonModel>.empty();
                }
                return _peopleList.where((p) => p.name
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (p) => p.name,
              onSelected: (p) {
                SpendoHaptics.light();
                _selectedPersonId = p.id;
                _nameCtrl.text = p.name;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (_nameCtrl.text.isNotEmpty && controller.text.isEmpty) {
                  controller.text = _nameCtrl.text;
                }

                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (val) {
                    _nameCtrl.text = val;
                    _selectedPersonId = null;
                  },
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: textWhite,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: _debtType == 'pay_later'
                        ? 'اسم المحل / الشخص (مثال: الحلاق، الكراج) *'
                        : 'اسم الشخص أو الجهة المعنية *',
                    hintStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF71717A),
                      fontSize: 11.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال اسم الشخص';
                    }
                    return null;
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    elevation: 4,
                    color: surfaceMain,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: surfaceBorder),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180, maxWidth: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final p = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            title: Text(
                              p.name,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: textWhite,
                                fontSize: 11.5,
                              ),
                            ),
                            onTap: () => onSelected(p),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 3. حقل المبلغ الأصلي
  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          const Icon(Remix.cash_line, color: brandYellow, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontFamily: 'Cairo',
                color: textWhite,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'المبلغ الأصلي (من أصل قديش) *',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF71717A),
                  fontSize: 11.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يرجى إدخال المبلغ';
                }
                final num = double.tryParse(val.trim());
                if (num == null || num <= 0) {
                  return 'يرجى إدخال مبلغ صحيح';
                }
                return null;
              },
            ),
          ),
          const Text(
            '₪',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: brandYellow,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. شبكة طرق الدفع (Bit / كاش / بنكي / كود صراف)
  Widget _buildPaymentMethodsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'طريقة دفع / تحويل السلفة:',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF9CA3AF),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: _paymentMethods.map((m) {
            final isSelected = _paymentMethod == m['key'];
            final IconData icon = m['icon'];
            final Color iconColor = m['color'];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    SpendoHaptics.selection();
                    setState(() => _paymentMethod = m['key']);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? brandYellow : surfaceBorder,
                        width: isSelected ? 1.2 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: iconColor, size: 14),
                        const SizedBox(height: 3),
                        Text(
                          m['title'],
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: isSelected ? textWhite : textMuted,
                            fontSize: 9.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 5. التواريخ: تاريخ السلفة + تاريخ السداد المتوقع
  Widget _buildDatesRow(bool isReceived) {
    if (isReceived) {
      return InkWell(
        onTap: () => _pickDate(false),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceField,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: surfaceBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Remix.calendar_event_line, color: brandGreen, size: 15),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تاريخ استلام المبلغ / المعاملة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFF9CA3AF),
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        ArabicDateHelper.formatArabicDateWithWeekday(_transactionDate),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: textWhite,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(Remix.edit_line, color: Color(0xFF9CA3AF), size: 13),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        // تاريخ السلفة
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(false),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: surfaceBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _debtType == 'pay_later' ? 'تاريخ الخدمة' : 'تاريخ المعاملة',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          ArabicDateHelper.formatArabicDateWithWeekday(_transactionDate),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: textWhite,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Remix.calendar_event_line, color: brandGreen, size: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // تاريخ السداد المتوقع
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(true),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: surfaceBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _debtType == 'pay_later' ? 'متى ناوي تدفع؟' : 'تاريخ السداد المتوقع',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF9CA3AF),
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _dueDate != null
                              ? ArabicDateHelper.formatArabicDateWithWeekday(_dueDate!)
                              : 'غير محدد (اختياري)',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: _dueDate != null ? textWhite : textMuted,
                            fontSize: 10.5,
                            fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Remix.calendar_check_line, color: brandYellow, size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 6. ملاحظات وتفاصيل السلفة
  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          const Icon(Remix.file_text_line, color: Color(0xFF9CA3AF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _notesCtrl,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: textWhite,
                fontSize: 11.5,
              ),
              decoration: InputDecoration(
                hintText: _debtType == 'pay_later'
                    ? 'تفاصيل الخدمة (مثال: حلاقة، غيار زيت، أغراض) - اختياري'
                    : (_debtType == 'received'
                        ? 'تفاصيل السحب أو الاستلام (مثال: كود صراف لصديق، تسليم كاش) - اختياري'
                        : 'ملاحظات وتفاصيل المعاملة (اختياري)'),
                hintStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF71717A),
                  fontSize: 11.5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 7. زر الحفظ الصلب
  Widget _buildSaveButton() {
    return InkWell(
      onTap: _isSaving ? null : _save,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8.5),
        decoration: BoxDecoration(
          color: brandGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Remix.check_line, color: Color(0xFF0A0B0B), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'حفظ في كشف المالية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF0A0B0B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}