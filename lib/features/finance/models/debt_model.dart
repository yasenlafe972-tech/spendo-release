class DebtModel {
  final String id;
  final String personId;
  final String type; // 'they_owe' (أخذ مني مصاري / دين لي) or 'i_owe' (أخذت منه مصاري / دين علي)
  final double originalAmount; // المبلغ الأصلي (من أصل قديش)
  final double remainingAmount; // المبلغ المتبقي (قديش ضل أدفع أو هو يدفع)
  final String paymentMethod; // 'cash', 'bit', 'bank_transfer', 'check'
  final String transactionDate; // تاريخ السلفة / المعاملة
  final String? dueDate; // تاريخ السداد المتوقع
  final String? notes; // ملاحظات
  final String status; // 'active' (جاري) or 'settled' (تم السداد بالكامل)
  final DateTime createdAt;
  final DateTime updatedAt;

  DebtModel({
    required this.id,
    required this.personId,
    required this.type,
    required this.originalAmount,
    required this.remainingAmount,
    required this.paymentMethod,
    required this.transactionDate,
    this.dueDate,
    this.notes,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  /// المبلغ المسدد حتى الآن
  double get paidAmount => (originalAmount - remainingAmount).clamp(0.0, originalAmount);

  /// نسبة السداد من 0.0 إلى 1.0
  double get progress => originalAmount > 0 ? (paidAmount / originalAmount).clamp(0.0, 1.0) : 1.0;

  /// هل تم السداد بالكامل
  bool get isSettled => status == 'settled' || remainingAmount <= 0.01;

  /// هل هو دين لي (أخذ مني مصاري)
  bool get isTheyOwe => type == 'they_owe';

  /// هل هو دين علي (تدينت منه أو حساب مؤجل دفعه لاحقاً)
  bool get isIOwe => type == 'i_owe' || type == 'pay_later';

  /// هل هو حساب مؤجل (خدمة أو مشتريات عالحساب بدفعها بعدين مثل حلاق / محل)
  bool get isPayLater => type == 'pay_later';

  /// هل هو استلام مبلغ بدون إرجاع (مقبوضات / دفعة غير مستردة)
  bool get isReceived => type == 'received';

  DebtModel copyWith({
    String? id,
    String? personId,
    String? type,
    double? originalAmount,
    double? remainingAmount,
    String? paymentMethod,
    String? transactionDate,
    String? dueDate,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      originalAmount: originalAmount ?? this.originalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// اسم طريقة الدفع بالعربية
  String get paymentMethodTitle {
    switch (paymentMethod.toLowerCase()) {
      case 'pending':
        return 'لم يُدفع بعد (عالحساب)';
      case 'bit':
        return 'تطبيق Bit';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'atm_code':
        return 'كود صراف بنكي';
      case 'check':
        return 'شيك';
      case 'cash':
      default:
        return 'كاش نقدي';
    }
  }

  /// وصف نوع المعاملة بالعربية
  String get typeTitle {
    if (isReceived) return 'مبالغ مستلمة (سحب بنكي أو استلام مالي)';
    if (isPayLater) return 'عالحساب / دفع لاحقاً (خدمة أو محل)';
    return isTheyOwe ? 'إلي عنده (سلفة أعطيته)' : 'عليّ إله (دين أخذته)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'type': type,
      'original_amount': originalAmount,
      'remaining_amount': remainingAmount,
      'payment_method': paymentMethod,
      'transaction_date': transactionDate,
      'due_date': dueDate,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      type: map['type'] as String,
      originalAmount: (map['original_amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? 'cash',
      transactionDate: map['transaction_date'] as String,
      dueDate: map['due_date'] as String?,
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
