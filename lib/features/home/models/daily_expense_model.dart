export '../services/daily_expense_service.dart';

class DailyExpenseModel {
  final String id;
  final String merchantName;
  final double amount;
  final String category; // 'food', 'shopping', 'fuel'
  final String source; // 'apple_pay', 'cal_card'
  final DateTime date;
  final String? notes;
  final String? location;

  const DailyExpenseModel({
    required this.id,
    required this.merchantName,
    required this.amount,
    required this.category,
    this.source = 'apple_pay',
    required this.date,
    this.notes,
    this.location,
  });

  DailyExpenseModel copyWith({
    String? id,
    String? merchantName,
    double? amount,
    String? category,
    String? source,
    DateTime? date,
    String? notes,
    String? location,
  }) {
    return DailyExpenseModel(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      source: source ?? this.source,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      location: location ?? this.location,
    );
  }

  String get categoryTitle {
    switch (category) {
      case 'food':
        return 'أكل';
      case 'fuel':
        return 'وقود';
      case 'shopping':
      default:
        return 'مشتريات';
    }
  }

  String get sourceTitle {
    switch (source) {
      case 'google_pay':
        return 'Google Pay';
      case 'samsung_pay':
        return 'Samsung Pay';
      case 'cal':
      case 'cal_card':
        return 'بطاقة כאל';
      case 'max':
        return 'بطاقة Max';
      case 'isracard':
        return 'بطاقة ישראכרט';
      case 'wallet':
        return 'محفظة الهاتف';
      case 'apple_pay':
      default:
        return 'Apple Pay';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'merchantName': merchantName,
        'amount': amount,
        'category': category,
        'source': source,
        'date': date.toIso8601String(),
        'notes': notes,
        'location': location,
      };

  factory DailyExpenseModel.fromMap(Map<String, dynamic> map) {
    return DailyExpenseModel(
      id: map['id'] as String? ?? '',
      merchantName: map['merchantName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'shopping',
      source: map['source'] as String? ?? 'apple_pay',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      notes: map['notes'] as String?,
      location: map['location'] as String?,
    );
  }
}
