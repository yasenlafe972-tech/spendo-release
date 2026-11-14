import 'dart:convert';
import 'package:sanad_app/core/utils/arabic_date_helper.dart';

class WorkLogModel {
  final String id;
  final String? personId; // اختياري: في حال لم يتم ربط يوم العمل بشخص/معلم معين
  final String? workplaceId; // رابط اختياري مع جدول أماكن العمل
  final String workplaceName;
  final String city; // اسم البلد / المدينة التي تم العمل فيها
  final String dayName; // اسم اليوم بالعربية (الخميس، الجمعة...)
  final String date; // YYYY-MM-DD
  final String rateType; // 'daily' or 'hourly'
  final double? hoursWorked;
  final double dayFraction; // 1.0 (full day), 0.5 (half day), 1.25 (overtime)
  final double rateApplied;
  final double totalEarned;
  final double amountCollected; // المقبوض من هذه الورشة والبلد
  final String? notes;
  final double? latitude; // إحداثيات موقع العمل GPS
  final double? longitude; // إحداثيات موقع العمل GPS
  final String? locationAddress; // اسم أو وصف موقع الورشة على الخريطة
  final List<String> attachments; // مسارات الصور والمرفقات (صور المكيف، الفاتورة، الكفالة...)
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkLogModel({
    required this.id,
    this.personId,
    String? workplaceId,
    String? employerId,
    String? workplaceName,
    String? employerName,
    this.city = '',
    String? dayName,
    required this.date,
    required this.rateType,
    this.hoursWorked,
    this.dayFraction = 1.0,
    required this.rateApplied,
    required this.totalEarned,
    this.amountCollected = 0.0,
    this.notes,
    this.latitude,
    this.longitude,
    this.locationAddress,
    List<String>? attachments,
    required this.createdAt,
    DateTime? updatedAt,
  })  : workplaceId = workplaceId ?? employerId,
        workplaceName = (workplaceName ?? employerName ?? '').trim(),
        dayName = (dayName != null && dayName.trim().isNotEmpty)
            ? dayName.trim()
            : ArabicDateHelper.getWeekdayFromDateString(date),
        attachments = attachments ?? const [],
        updatedAt = updatedAt ?? createdAt;

  /// معرف المشغّل / الورشة المرتبط بيوم العمل (Master-Detail Employer ID)
  String? get employerId => workplaceId;

  /// اسم المشغّل / الورشة
  String get employerName => workplaceName;

  /// المتبقي للتحصيل من هذه الورشة
  double get remainingToCollect => totalEarned - amountCollected;
  bool get isFullyCollected => remainingToCollect <= 0.01;

  /// هل يوم العمل يحتوي على موقع جغرافي مسجل
  bool get hasLocation => latitude != null && longitude != null;

  /// هل يوم العمل يحتوي على صور أو مرفقات
  bool get hasAttachments => attachments.isNotEmpty;

  /// رابط Google Maps المباشر للموقع
  String get googleMapsUrl => hasLocation
      ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      : '';

  /// Formatted date string with Arabic weekday (e.g. "الخميس • 22/10/2026")
  String get formattedDateWithDay {
    final d = dayName.isNotEmpty ? dayName : ArabicDateHelper.getWeekdayFromDateString(date);
    return '$d • $date';
  }

  WorkLogModel copyWith({
    String? id,
    String? personId,
    String? workplaceId,
    String? employerId,
    String? workplaceName,
    String? employerName,
    String? city,
    String? dayName,
    String? date,
    String? rateType,
    double? hoursWorked,
    double? dayFraction,
    double? rateApplied,
    double? totalEarned,
    double? amountCollected,
    String? notes,
    double? latitude,
    double? longitude,
    String? locationAddress,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkLogModel(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      workplaceId: workplaceId ?? employerId ?? this.workplaceId,
      workplaceName: workplaceName ?? employerName ?? this.workplaceName,
      city: city ?? this.city,
      dayName: dayName ?? this.dayName,
      date: date ?? this.date,
      rateType: rateType ?? this.rateType,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      dayFraction: dayFraction ?? this.dayFraction,
      rateApplied: rateApplied ?? this.rateApplied,
      totalEarned: totalEarned ?? this.totalEarned,
      amountCollected: amountCollected ?? this.amountCollected,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'workplace_id': workplaceId,
      'workplace_name': workplaceName,
      'city': city,
      'day_name': dayName.isNotEmpty ? dayName : ArabicDateHelper.getWeekdayFromDateString(date),
      'date': date,
      'rate_type': rateType,
      'hours_worked': hoursWorked,
      'day_fraction': dayFraction,
      'rate_applied': rateApplied,
      'total_earned': totalEarned,
      'amount_collected': amountCollected,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'location_address': locationAddress,
      'attachments': jsonEncode(attachments),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WorkLogModel.fromMap(Map<String, dynamic> map) {
    final dateVal = map['date'] as String;
    final explicitDay = map['day_name'] as String?;
    final dayComputed = (explicitDay != null && explicitDay.trim().isNotEmpty)
        ? explicitDay
        : ArabicDateHelper.getWeekdayFromDateString(dateVal);

    List<String> parsedAttachments = [];
    final rawAttachments = map['attachments'];
    if (rawAttachments is String && rawAttachments.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAttachments);
        if (decoded is List) {
          parsedAttachments = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawAttachments is List) {
      parsedAttachments = rawAttachments.map((e) => e.toString()).toList();
    }

    final created = DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now();
    final updated = DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? created;

    return WorkLogModel(
      id: map['id'] as String,
      personId: map['person_id'] as String?,
      workplaceId: (map['workplace_id'] ?? map['employer_id']) as String?,
      workplaceName: (map['workplace_name'] ?? map['employer_name'] ?? '') as String,
      city: (map['city'] as String?) ?? '',
      dayName: dayComputed,
      date: dateVal,
      rateType: map['rate_type'] as String,
      hoursWorked: (map['hours_worked'] as num?)?.toDouble(),
      dayFraction: (map['day_fraction'] as num? ?? 1.0).toDouble(),
      rateApplied: (map['rate_applied'] as num).toDouble(),
      totalEarned: (map['total_earned'] as num).toDouble(),
      amountCollected: (map['amount_collected'] as num? ?? 0.0).toDouble(),
      notes: map['notes'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationAddress: map['location_address'] as String?,
      attachments: parsedAttachments,
      createdAt: created,
      updatedAt: updated,
    );
  }
}
