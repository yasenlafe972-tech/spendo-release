import 'package:uuid/uuid.dart';

/// Represents a Workplace / Job Site (`مكان عمل / ورشة`) in Spendo.
///
/// Cleanly separates Job Sites & Workplaces from individual people and finances.
/// Allows setting a default agreed daily rate (`سعر اليومية المتفق عليه`),
/// default hourly rate, location/city, and optional contractor/employer link.
class WorkplaceModel {
  final String id;
  final String name; // اسم مكان العمل / الورشة
  final String city; // اسم البلد / المدينة
  final String? personId; // المشغل / المقاول المسؤول (FK to people table)
  final String? contractorName; // اسم المقاول المعروض كاش
  final double dailyRate; // سعر اليومية المتفق عليه لهذه الورشة
  final double hourlyRate; // سعر الساعة المتفق عليه
  final String status; // 'active' or 'completed'
  final String? notes; // ملاحظات عامة حول الورشة
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkplaceModel({
    required this.id,
    required this.name,
    this.city = '',
    String? personId,
    String? contractorId,
    this.contractorName,
    this.dailyRate = 0.0,
    double? hourlyRate,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    DateTime? updatedAt,
  })  : personId = personId ?? contractorId,
        hourlyRate = hourlyRate ?? 0.0,
        updatedAt = updatedAt ?? createdAt;

  /// Alias for personId for UI components referencing contractorId
  String? get contractorId => personId;

  /// المعرف الفريد للمشغّل / الورشة (Master Employer ID)
  String get employerId => id;

  /// اسم المشغّل / مكان العمل
  String get employerName => name;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  /// Factory for creating a brand new Workplace with generated UUID.
  factory WorkplaceModel.create({
    required String name,
    required String city,
    required double dailyRate,
    double? hourlyRate,
    String? personId,
    String? contractorId,
    String? contractorName,
    String? status,
    String? notes,
  }) {
    final now = DateTime.now();
    return WorkplaceModel(
      id: const Uuid().v4(),
      name: name,
      city: city,
      personId: personId ?? contractorId,
      contractorName: contractorName,
      dailyRate: dailyRate,
      hourlyRate: hourlyRate ?? 0.0,
      status: status ?? 'active',
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  WorkplaceModel copyWith({
    String? id,
    String? name,
    String? city,
    String? personId,
    String? contractorId,
    String? contractorName,
    double? dailyRate,
    double? hourlyRate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkplaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      personId: personId ?? contractorId ?? this.personId,
      contractorName: contractorName ?? this.contractorName,
      dailyRate: dailyRate ?? this.dailyRate,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'person_id': personId,
      'daily_rate': dailyRate,
      'hourly_rate': hourlyRate,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WorkplaceModel.fromMap(Map<String, dynamic> map) {
    return WorkplaceModel(
      id: map['id'] as String,
      name: map['name'] as String,
      city: (map['city'] as String?) ?? '',
      personId: (map['person_id'] ?? map['contractor_id']) as String?,
      contractorName: map['contractor_name'] as String?,
      dailyRate: (map['daily_rate'] as num? ?? 0.0).toDouble(),
      hourlyRate: (map['hourly_rate'] as num? ?? 0.0).toDouble(),
      status: (map['status'] as String?) ?? 'active',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkplaceModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
