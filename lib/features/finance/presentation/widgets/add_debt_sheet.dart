import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/spendo_haptic_feedback.dart';
import '../../../people/models/person_model.dart';
import '../../../people/repositories/people_repository.dart';
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

  static const Color surfaceMain = Color(0xFF121413);
  static const Color surfaceField = Color(0xFF171A19);
  static const Color surfaceBorder = Color(0xFF242927);
  static const Color brandGreen = Color(0xFF00A86B);
  static const Color brandYellow = Color(0xFFEAB308);
  static const Color brandRed = Color(0xFFEF4444);

  static const List<Map<String, dynamic>> _paymentMethods = [
    {'key': 'bit', 'title': 'تطبيق Bit', 'icon': Remix.smartphone_line, 'color': brandYellow},
    {'key': 'cash', 'title': 'كاش نقدي', 'icon': Remix.money_dollar_box_line, 'color': brandGreen},
    {'key': 'bank_transfer', 'title': 'تحويل بنكي', 'icon': Remix.bank_line, 'color': brandYellow},
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
    SpendoHaptics.light();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDue ? (_dueDate ?? DateTime.now().add(const Duration(days: 30))) : _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: brandGreen,
              onPrimary: Colors.black,
              surface: surfaceMain,
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: surfaceMain,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: surfaceBorder),
              ),
            ),
          ),
          child: child!,
        );
      },
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
      decoration: const BoxDecoration(
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

              // 2. ترويسة النافذة (أيقونات نظيفة بدون أي خلفيات دائرية)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: surfaceBorder, width: 1.0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Remix.hand_coin_line, color: brandYellow, size: 22),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'تعديل سلفة / معاملة مالية' : 'تسجيل سلفة / دين مالي',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              const Text(
                                'إدارة الديون والسلف الشخصية ومتابعة المتبقي',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
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
                          child: Icon(Remix.close_line, color: Color(0xFF9CA3AF), size: 20),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // اختيار نوع العملية
                        _buildTypeSelector(),
                        const SizedBox(height: 12),

                        // حقل اسم الشخص
                        _buildPersonNameField(),
                        const SizedBox(height: 10),

                        // حقل المبلغ الأصلي
                        _buildAmountField(),
                        const SizedBox(height: 12),

                        // طريقة دفع / تحويل السلفة (تختفي عند اختيار عالحساب لأن الدفع مؤجل لوقت السداد)
                        if (_debtType != 'pay_later') ...[
                          _buildPaymentMethodsGrid(),
                          const SizedBox(height: 12),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: brandYellow.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: brandYellow.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Remix.time_line, color: brandYellow, size: 15),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'دفعة مؤجلة عالحساب — يتم اختيار طريقة الدفع (كاش / Bit / بنكي) عند الضغط على "تم الدفع" لاحقاً.',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Color(0xFFD4D4D8),
                                      fontSize: 10.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // التواريخ: تاريخ السلفة + تاريخ السداد المتوقع
                        _buildDatesRow(isReceived),
                        const SizedBox(height: 10),

                        // ملاحظات وتفاصيل السلفة
                        _buildNotesField(),
                        const SizedBox(height: 16),

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

  /// 1. اختيار نوع العملية (شبكة 2×2 مرتبة وواضحة)
  Widget _buildTypeSelector() {
    final isTheyOwe = _debtType == 'they_owe';
    final isIOwe = _debtType == 'i_owe';
    final isPayLater = _debtType == 'pay_later';
    final isReceived = _debtType == 'received';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: surfaceField,
        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 6),
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
          const SizedBox(height: 6),
          Row(
            children: [
              // 3. عالحساب / دفع لاحقاً (حلاق، محل، خدمة ما دفعتها اسا)
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
              const SizedBox(width: 6),
              // 4. مقبوضات (استلمت مبلغ بدون إرجاع)
              Expanded(
                child: _buildTypeOptionCard(
                  isSelected: isReceived,
                  activeColor: brandGreen,
                  icon: Remix.checkbox_circle_line,
                  title: 'مقبوضات',
                  subtitle: 'استلمت مبلغ بدون إرجاع',
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : surfaceMain,
          borderRadius: BorderRadius.circular(8),
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
                Icon(icon, color: activeColor, size: 13),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isSelected ? Colors.white : const Color(0xFFD4D4D8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: isSelected ? activeColor : const Color(0xFF71717A),
                fontSize: 9.5,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Remix.user_3_line, color: brandGreen, size: 18),
          const SizedBox(width: 10),
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
                controller.addListener(() {
                  _nameCtrl.text = controller.text;
                  _selectedPersonId = null;
                });

                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: _debtType == 'pay_later'
                        ? 'اسم المحل / الشخص (مثال: الحلاق، الكراج) *'
                        : 'اسم الشخص أو الجهة المعنية *',
                    hintStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF71717A),
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                      side: const BorderSide(color: surfaceBorder),
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
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 12,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Remix.cash_line, color: brandYellow, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'المبلغ الأصلي (من أصل قديش) *',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF71717A),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
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
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. شبكة طرق الدفع (Bit / كاش / بنكي / شيك)
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
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
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: surfaceField,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? brandYellow : surfaceBorder,
                        width: isSelected ? 1.2 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: iconColor, size: 16),
                        const SizedBox(height: 4),
                        Text(
                          m['title'],
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                            fontSize: 10,
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
    return Row(
      children: [
        // تاريخ السلفة
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(false),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: surfaceBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _debtType == 'pay_later' ? 'تاريخ الخدمة / الشراء' : 'تاريخ المعاملة',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ArabicDateHelper.formatArabicDateWithWeekday(_transactionDate),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Remix.calendar_event_line, color: brandGreen, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // تاريخ السداد المتوقع
        Expanded(
          child: Opacity(
            opacity: isReceived ? 0.35 : 1.0,
            child: IgnorePointer(
              ignoring: isReceived,
              child: InkWell(
                onTap: () => _pickDate(true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceField,
                    borderRadius: BorderRadius.circular(12),
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
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dueDate != null
                                  ? ArabicDateHelper.formatArabicDateWithWeekday(_dueDate!)
                                  : 'غير محدد (اختياري)',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: _dueDate != null ? Colors.white : const Color(0xFF9CA3AF),
                                fontSize: 11,
                                fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Remix.calendar_check_line, color: brandYellow, size: 16),
                    ],
                  ),
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaceBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Remix.file_text_line, color: Color(0xFF9CA3AF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _notesCtrl,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: _debtType == 'pay_later'
                    ? 'تفاصيل الخدمة (مثال: حلاقة، غيار زيت، أغراض) - اختياري'
                    : 'ملاحظات وتفاصيل المعاملة (اختياري)',
                hintStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF71717A),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: brandGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Remix.check_line, color: Color(0xFF0A0B0B), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'حفظ في كشف المالية',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF0A0B0B),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
