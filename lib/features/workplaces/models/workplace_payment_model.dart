class WorkplacePaymentModel {
  final String id;
  final String workplaceId;
  final double amount;
  final String date;
  final String paymentMethod;
  final String? notes;
  final DateTime createdAt;

  const WorkplacePaymentModel({
    required this.id,
    required this.workplaceId,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workplace_id': workplaceId,
      'amount': amount,
      'date': date,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WorkplacePaymentModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(map['created_at'] as String);
    } catch (_) {
      parsedCreated = DateTime.now();
    }
    return WorkplacePaymentModel(
      id: map['id'] as String,
      workplaceId: map['workplace_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      paymentMethod: (map['payment_method'] as String?) ?? 'كاش',
      notes: map['notes'] as String?,
      createdAt: parsedCreated,
    );
  }

  WorkplacePaymentModel copyWith({
    String? id,
    String? workplaceId,
    double? amount,
    String? date,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
  }) {
    return WorkplacePaymentModel(
      id: id ?? this.id,
      workplaceId: workplaceId ?? this.workplaceId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
