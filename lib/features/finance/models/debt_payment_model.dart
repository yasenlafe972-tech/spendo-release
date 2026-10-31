class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final String paymentMethod; // 'cash', 'bit', 'bank_transfer', 'check'
  final String paymentDate;
  final String? notes;
  final DateTime createdAt;

  DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    this.notes,
    required this.createdAt,
  });

  String get paymentMethodTitle {
    switch (paymentMethod.toLowerCase()) {
      case 'bit':
        return 'Bit';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'check':
        return 'شيك';
      case 'cash':
      default:
        return 'كاش';
    }
  }

  DebtPaymentModel copyWith({
    String? id,
    String? debtId,
    double? amount,
    String? paymentMethod,
    String? paymentDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return DebtPaymentModel(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_date': paymentDate,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DebtPaymentModel.fromMap(Map<String, dynamic> map) {
    return DebtPaymentModel(
      id: map['id'] as String,
      debtId: map['debt_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: (map['payment_method'] as String?) ?? 'cash',
      paymentDate: map['payment_date'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
