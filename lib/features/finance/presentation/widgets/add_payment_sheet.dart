import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sanad_app/core/theme/app_colors.dart';
import 'package:sanad_app/features/people/models/person_model.dart';
import 'package:sanad_app/features/people/repositories/people_repository.dart';
import 'package:sanad_app/features/finance/models/payment_model.dart';

class AddPaymentSheet extends StatefulWidget {
  final PersonModel? preselectedPerson;
  final Function(PaymentModel) onSave;

  const AddPaymentSheet({
    super.key,
    this.preselectedPerson,
    required this.onSave,
  });

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final PeopleRepository _peopleRepo = PeopleRepository();

  List<PersonModel> _allPeople = [];
  PersonModel? _selectedPerson;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentType = 'advance'; // 'advance' (سلفة) or 'payment' (دفعة حساب)

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.preselectedPerson;
    _initPeople();
  }

  Future<void> _initPeople() async {
    final people = await _peopleRepo.getAllPeople();
    setState(() {
      _allPeople = people.where((p) => !p.isUser).toList();
      if (_selectedPerson == null && _allPeople.isNotEmpty) {
        _selectedPerson = _allPeople.first;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedPerson == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final payment = PaymentModel(
      id: const Uuid().v4(),
      personId: _selectedPerson!.id,
      amount: amount,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      type: _paymentType,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    widget.onSave(payment);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: keyboardInset > 0 ? keyboardInset : 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. FIXED TOP DRAG HANDLE
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272730),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. FIXED TOP HEADER BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181D),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF272730)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFA1A1AA),
                          size: 16,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'تسجيل مقبوضات / سلفة',
                        style: TextStyle(
                          color: Color(0xFFF4F4F5),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. SCROLLABLE FORM
              Flexible(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is OverscrollNotification && notification.overscroll < -12) {
                      Navigator.of(context).maybePop();
                      return true;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(
                      left: 18,
                      right: 18,
                      bottom: 16,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Select Person
                          if (widget.preselectedPerson == null) ...[
                DropdownButtonFormField<PersonModel>(
                  initialValue: _selectedPerson,
                  decoration: _inputDecoration('المشغل / الشخص الذي دفع', Icons.person_outline),
                  dropdownColor: AppColors.surfaceElevated,
                  items: _allPeople.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPerson = val),
                ),
                const SizedBox(height: 14),
              ],

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('المبلغ المستلم (₪) *', Icons.attach_money_outlined),
                style: const TextStyle(color: AppColors.whatsappGreen, fontSize: 18, fontWeight: FontWeight.w700),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'المبلغ مطلوب';
                  if (double.tryParse(val.trim()) == null) return 'أدخل رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceCardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today_outlined, color: AppColors.iconMuted, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Payment Type (Advance vs Payment)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('سلفة كاش'),
                      selected: _paymentType == 'advance',
                      onSelected: (_) => setState(() => _paymentType = 'advance'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('دفعة حساب / راتب'),
                      selected: _paymentType == 'payment',
                      onSelected: (_) => setState(() => _paymentType = 'payment'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: _inputDecoration('ملاحظات إضافية (تحويل بنكي / كاش باليد)', Icons.notes_outlined),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsappGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('حفظ الدفعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.iconMuted, size: 20),
      filled: true,
      fillColor: AppColors.surfaceCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.surfaceCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.surfaceCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.whatsappGreen, width: 1.5),
      ),
    );
  }
}
