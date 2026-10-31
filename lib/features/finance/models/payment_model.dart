class PaymentModel {
  final String id;
  final String personId;
  final double amount;
  final String date;
  final String type; // 'advance' (سلفة), 'payment' (دفعة), 'settlement' (تصفية)
  final String? notes;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.personId,
    required this.amount,
    required this.date,
    required this.type,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'amount': amount,
      'date': date,
      'type': type,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      type: map['type'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
