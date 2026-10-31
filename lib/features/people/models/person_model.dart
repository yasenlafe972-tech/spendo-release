import 'package:intl/intl.dart';

class PersonModel {
  final String id;
  final String name;
  final bool isUser;
  final DateTime? birthdate;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final String? nationalId;
  final String? bank;
  final String? accountNumber;
  final bool isPinned;
  final double hourlyRate;
  final double dailyRate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PersonModel({
    required this.id,
    required this.name,
    this.isUser = false,
    this.birthdate,
    this.email,
    this.phone,
    this.whatsapp,
    this.nationalId,
    this.bank,
    this.accountNumber,
    this.isPinned = false,
    this.hourlyRate = 0.0,
    this.dailyRate = 0.0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Dynamically computes initials for the circular avatar (e.g. "My profile" -> "MP", "أحمد لافي" -> "أل")
  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Exact age computation based on current local date
  int? get calculatedAge {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  /// Formatted subtitle matching the UI card: "24/10/1998 • 27y"
  String? get formattedBirthdateAndAge {
    if (birthdate == null) return null;
    final dateStr = DateFormat('dd/MM/yyyy').format(birthdate!);
    final age = calculatedAge;
    if (age != null) {
      return '$dateStr • ${age}y';
    }
    return dateStr;
  }

  PersonModel copyWith({
    String? id,
    String? name,
    bool? isUser,
    DateTime? birthdate,
    String? email,
    String? phone,
    String? whatsapp,
    String? nationalId,
    String? bank,
    String? accountNumber,
    bool? isPinned,
    double? hourlyRate,
    double? dailyRate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isUser: isUser ?? this.isUser,
      birthdate: birthdate ?? this.birthdate,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      nationalId: nationalId ?? this.nationalId,
      bank: bank ?? this.bank,
      accountNumber: accountNumber ?? this.accountNumber,
      isPinned: isPinned ?? this.isPinned,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      dailyRate: dailyRate ?? this.dailyRate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_user': isUser ? 1 : 0,
      'birthdate': birthdate?.toIso8601String().split('T').first,
      'email': email,
      'phone': phone,
      'whatsapp': whatsapp,
      'national_id': nationalId,
      'bank': bank,
      'account_number': accountNumber,
      'is_pinned': isPinned ? 1 : 0,
      'hourly_rate': hourlyRate,
      'daily_rate': dailyRate,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PersonModel.fromMap(Map<String, dynamic> map) {
    return PersonModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isUser: (map['is_user'] as int? ?? 0) == 1,
      birthdate: map['birthdate'] != null && (map['birthdate'] as String).isNotEmpty
          ? DateTime.tryParse(map['birthdate'] as String)
          : null,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      nationalId: map['national_id'] as String?,
      bank: map['bank'] as String?,
      accountNumber: map['account_number'] as String?,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      hourlyRate: (map['hourly_rate'] as num? ?? 0.0).toDouble(),
      dailyRate: (map['daily_rate'] as num? ?? 0.0).toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
