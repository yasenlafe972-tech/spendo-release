import 'dart:convert';
import '../../../../core/services/israeli_fuel_station_registry.dart';

enum ExpenseCategory {
  fuel,
  maintenance;

  bool get isFuel => this == ExpenseCategory.fuel;
  bool get isMaintenance => this == ExpenseCategory.maintenance;
}

class MaintenancePart {
  final String id;
  final String title;
  final String subtitle;
  final String iconName;
  final int lastServiceKm;
  final int intervalKm;

  const MaintenancePart({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconName,
    required this.lastServiceKm,
    required this.intervalKm,
  });

  /// المسافة المقطوعة منذ آخر صيانة
  int drivenKm(int currentOdometer) =>
      (currentOdometer - lastServiceKm).clamp(0, 999999);

  /// المسافة المتبقية للصيانة القادمة (قد تكون سالبة في حال التجاوز)
  int remainingKm(int currentOdometer) =>
      intervalKm - (currentOdometer - lastServiceKm);

  /// نسبة الاستهلاك للمؤشر بين 0.0 و 1.0
  double consumptionRatio(int currentOdometer) {
    if (intervalKm <= 0) return 1.0;
    final driven = currentOdometer - lastServiceKm;
    return (driven / intervalKm).clamp(0.0, 1.0);
  }

  /// نسبة الصحة المتبقية للمؤشر بين 0.0 و 1.0
  double remainingRatio(int currentOdometer) =>
      (1.0 - consumptionRatio(currentOdometer)).clamp(0.0, 1.0);

  MaintenancePart copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconName,
    int? lastServiceKm,
    int? intervalKm,
  }) {
    return MaintenancePart(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      lastServiceKm: lastServiceKm ?? this.lastServiceKm,
      intervalKm: intervalKm ?? this.intervalKm,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'iconName': iconName,
        'lastServiceKm': lastServiceKm,
        'intervalKm': intervalKm,
      };

  factory MaintenancePart.fromMap(Map<String, dynamic> map) {
    return MaintenancePart(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'settings',
      lastServiceKm: (map['lastServiceKm'] as num?)?.toInt() ?? 0,
      intervalKm: (map['intervalKm'] as num?)?.toInt() ?? 3000,
    );
  }
}

class VehicleExpenseRecord {
  final String id;
  final String title;
  final double amount;
  final int odometer;
  final DateTime date;
  final ExpenseCategory category;
  final String? invoiceNumber;
  final String? provider;
  final double? liters;
  final double? pricePerLiter;
  final String? notes;
  final List<String>? items;

  const VehicleExpenseRecord({
    required this.id,
    required this.title,
    required this.amount,
    required this.odometer,
    required this.date,
    required this.category,
    this.invoiceNumber,
    this.provider,
    this.liters,
    this.pricePerLiter,
    this.notes,
    this.items,
  });

  bool get isFuel => category == ExpenseCategory.fuel;
  bool get isMaintenance => category == ExpenseCategory.maintenance;

  VehicleExpenseRecord copyWith({
    String? id,
    String? title,
    double? amount,
    int? odometer,
    DateTime? date,
    ExpenseCategory? category,
    String? invoiceNumber,
    String? provider,
    double? liters,
    double? pricePerLiter,
    String? notes,
    List<String>? items,
  }) {
    return VehicleExpenseRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      odometer: odometer ?? this.odometer,
      date: date ?? this.date,
      category: category ?? this.category,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      provider: provider ?? this.provider,
      liters: liters ?? this.liters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'odometer': odometer,
        'date': date.toIso8601String(),
        'category': category.name,
        'invoiceNumber': invoiceNumber,
        'provider': provider,
        'liters': liters,
        'pricePerLiter': pricePerLiter,
        'notes': notes,
        'items': items,
      };

  factory VehicleExpenseRecord.fromMap(Map<String, dynamic> map) {
    final category = map['category'] == 'fuel'
        ? ExpenseCategory.fuel
        : ExpenseCategory.maintenance;
    var title = map['title'] as String? ?? '';
    final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
    var date = DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now();
    var invoiceNumber = map['invoiceNumber'] as String?;
    var provider = map['provider'] as String?;
    var liters = (map['liters'] as num?)?.toDouble();
    var pricePerLiter = (map['pricePerLiter'] as num?)?.toDouble();

    if (category == ExpenseCategory.fuel) {
      // Self-heal the 06/11/2026 50.00 NIS Paz Sakhnin (422) receipt if it was saved with the old fallback
      if (date.year == 2026 &&
          date.month == 11 &&
          date.day == 6 &&
          (amount - 50.0).abs() < 0.05 &&
          (title.contains('בעינה') || provider == 'פז בעינה 365' || provider == 'פז Yellow')) {
        invoiceNumber = '042209901087851';
        provider = 'פז סכנין החדשה (422)';
        liters = 6.369;
        pricePerLiter = 7.85;
        date = DateTime(2026, 11, 6, 14, 22);
        title = 'תדלוק פז סכנין החדשה (422) (6.369 ליטר)';
      } else if (invoiceNumber != null &&
          invoiceNumber.length == 15 &&
          invoiceNumber.startsWith('0')) {
        // Resolve exact station from the 15-digit Paz fiscal invoice number prefix (e.g. 0422... -> 422, 0417... -> 417)
        final resolved = IsraeliFuelStationRegistry.resolveStation(
          text: '$title ${provider ?? ''}',
          detectedCompany: 'פז',
          invoiceNumber: invoiceNumber,
        );
        if (resolved.isNotEmpty &&
            (provider == null ||
                provider.isEmpty ||
                provider == 'פז Yellow' ||
                (provider.contains('בעינה') && !invoiceNumber.startsWith('0365')))) {
          provider = resolved;
          final lStr = liters != null ? ' ($liters ליטר)' : '';
          title = 'תדלוק $resolved$lStr';
        }
      }
      if (title.contains('בעינה 365 417') || title.contains('בית הכנם')) {
        provider = 'פז בית הכרם (417)';
        final lStr = liters != null ? ' ($liters ליטר)' : '';
        title = 'תדלוק פז בית הכרם (417)$lStr';
      }
    }

    return VehicleExpenseRecord(
      id: map['id'] as String? ?? '',
      title: title,
      amount: amount,
      odometer: (map['odometer'] as num?)?.toInt() ?? 0,
      date: date,
      category: category,
      invoiceNumber: invoiceNumber,
      provider: provider,
      liters: liters,
      pricePerLiter: pricePerLiter,
      notes: map['notes'] as String?,
      items:
          (map['items'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

class VehicleDataState {
  final String vehicleName;
  final int currentOdometer;
  final List<MaintenancePart> parts;
  final List<VehicleExpenseRecord> history;
  final DateTime insuranceExpiry;
  final DateTime testExpiry;

  VehicleDataState({
    required this.vehicleName,
    required this.currentOdometer,
    required this.parts,
    required this.history,
    DateTime? insuranceExpiry,
    DateTime? testExpiry,
  })  : insuranceExpiry = insuranceExpiry ?? DateTime(2026, 11, 22),
        testExpiry = testExpiry ?? DateTime(2027, 1, 1);

  factory VehicleDataState.initial() {
    return VehicleDataState(
      vehicleName: 'SYM Joyride 200 (55-505-403)',
      currentOdometer: 94890,
      insuranceExpiry: DateTime(2026, 11, 22),
      testExpiry: DateTime(2027, 1, 1),
      parts: const [
        MaintenancePart(
          id: 'rear_brakes',
          title: 'דיסק אחורי + רפידות בלם',
          subtitle: 'הוחלף ב-9/10/2026 (94,890 ק"מ)',
          iconName: 'disc',
          lastServiceKm: 94890,
          intervalKm: 8000,
        ),
        MaintenancePart(
          id: 'engine_oil',
          title: 'שמן מנוע 4T',
          subtitle: 'הוחלף בטיפול גדול (91,500 ק"מ)',
          iconName: 'oil',
          lastServiceKm: 91500,
          intervalKm: 4000,
        ),
        MaintenancePart(
          id: 'timing_belt',
          title: 'רצועת טיימינג',
          subtitle: 'מוסך אור אמנוני (88,121 ק"מ)',
          iconName: 'belt',
          lastServiceKm: 88121,
          intervalKm: 12000,
        ),
        MaintenancePart(
          id: 'gear_oil',
          title: 'שמן גיר',
          subtitle: 'הוחלף בטיפול גדול (91,500 ק"מ)',
          iconName: 'gear',
          lastServiceKm: 91500,
          intervalKm: 6000,
        ),
        MaintenancePart(
          id: 'front_tire',
          title: 'צמיג קדמי (110/90-13)',
          subtitle: 'מוסך אור אמנוני (91,500 ק"מ)',
          iconName: 'tire',
          lastServiceKm: 91500,
          intervalKm: 15000,
        ),
        MaintenancePart(
          id: 'front_brakes',
          title: 'בלמים קדמיים',
          subtitle: 'שיפוץ בלמים קדמיים (חשבונית #513)',
          iconName: 'disc',
          lastServiceKm: 52800,
          intervalKm: 20000,
        ),
      ],
      history: [
        VehicleExpenseRecord(
          id: 'fuel_paz_2026_10_21',
          title: 'תדלוק פז בית הכרם (417) (6.0 ליטר)',
          amount: 46.62,
          odometer: 0,
          date: DateTime(2026, 10, 21, 8, 43),
          category: ExpenseCategory.fuel,
          invoiceNumber: '041709901387254',
          provider: 'פז בית הכרם (417)',
          liters: 6.0,
          pricePerLiter: 7.77,
          notes: 'תדלוק מהיר באפליקציית Yellow משאבה 05 - רכב 55-505-403',
          items: null,
        ),
        VehicleExpenseRecord(
          id: 'inv_user_2026_10',
          title: 'החלפת דיסק אחורי + רפידות בלם',
          amount: 400.0,
          odometer: 94890,
          date: DateTime(2026, 10, 9),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '0910-2026',
          provider: 'מוסך מורשה',
          notes: 'החלפת דיסק אחורי ורפידות בלם אחוריות חדשות (SYM Joyride 200)',
          items: const [
            'צלחת בלם (דיסק) אחורי מקורית',
            'סט רפידות בלם אחוריות חדשות',
            'בדיקת שמן בלמים וחיזוק קליפר',
            'עבודה וכיוונון',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_2289',
          title: 'טיפול גדול + צמיג קדמי (חשבונית #2289)',
          amount: 1400.0,
          odometer: 91500,
          date: DateTime(2026, 9, 1),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '2289',
          provider: 'מוסך אור אמנוני (כרמיאל)',
          notes: 'טיפול 15,000 ק"מ תקופתי והחלפת צמיג קדמי עקב שחיקה',
          items: const [
            'שמן מנוע 4T מקורי',
            'שמן תמסורת גיר',
            'מסנן אוויר מקורי',
            'צמיג קדמי 110/90-13 חדש',
            'עבודה ובדיקת מכלולים',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_2149',
          title: 'טיימינג, אטמים, שמן ועבודה (חשבונית #2149)',
          amount: 2200.0,
          odometer: 88121,
          date: DateTime(2026, 7, 29),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '2149',
          provider: 'מוסך אור אמנוני (כרמיאל)',
          notes: 'החלפת רצועת טיימינג ואטמי מנוע שמן ועבודה',
          items: const [
            'רצועת טיימינג מקורית Bando',
            'סט אטמי מנוע עליון',
            'שמן מנוע 4T',
            'משקולות וריאטור מקוריות',
            'עבודת מכונאי מוסמך',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_1729',
          title: 'מסכת חזית, מגן גחון, מראה ימין (חשבונית #1729)',
          amount: 1600.0,
          odometer: 85000,
          date: DateTime(2026, 4, 19),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '1729',
          provider: 'מוסך אור אמנוני (כרמיאל)',
          notes: 'החלפת פלסטיקה מקורית לאחר מכה',
          items: const [
            'מסכת חזית מקורית SYM',
            'מגן גחון תחתון מקורי',
            'מראה ימנית מקורית',
            'פירוק, התקנה וחיזוקים',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_1688',
          title: 'עבור תיקון קודם מוסך אור אמנוני (חשבונית #1688)',
          amount: 500.0,
          odometer: 85000,
          date: DateTime(2026, 4, 10),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '1688',
          provider: 'מוסך אור אמנוני (כרמיאל)',
          notes: 'השלמת תשלום עבור טיפול ותיקון קודם',
          items: const ['השלמת תשלום תיקון', 'בדיקה כללית וכיוונונים'],
        ),
        VehicleExpenseRecord(
          id: 'inv_513',
          title: 'שיפוץ בלמים קדמיים (חשבונית #513)',
          amount: 1050.0,
          odometer: 52800,
          date: DateTime(2025, 4, 29),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '513',
          provider: 'מוסך אור אמנוני (כרמיאל)',
          notes: 'שיפוץ קליפר בלם קדמי והחלפת רפידות ונוזל בלמים',
          items: const [
            'שיפוץ קליפר בלמים קדמי',
            'רפידות בלם קדמיות מקוריות',
            'נוזל בלמים DOT4',
            'ניקוז אוויר ובדיקת בלימה',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_465',
          title: 'טיפול מלא מקורי (חשבונית #465)',
          amount: 1100.0,
          odometer: 47000,
          date: DateTime(2025, 4, 15),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '465',
          provider: 'מוסך מורשה',
          items: const [
            'טיפול תקופתי מקיף',
            'שמן מנוע 4T',
            'שמן גיר',
            'מצת (פלאג) NGK',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_411',
          title: 'דיסק אחורי, רפידה, נורה (חשבונית #411)',
          amount: 550.0,
          odometer: 52800,
          date: DateTime(2025, 3, 26),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '411',
          provider: 'מוסך מורשה',
          items: const [
            'דיסק בלם אחורי',
            'רפידות בלם',
            'נורת תאורה ראשית אחורית',
          ],
        ),
        VehicleExpenseRecord(
          id: 'inv_277',
          title: 'טיפול מלא, נוזלי בלמים, צמיג 110/90, שסתומים (חשבונית #277)',
          amount: 1700.0,
          odometer: 47600,
          date: DateTime(2025, 2, 11),
          category: ExpenseCategory.maintenance,
          invoiceNumber: '277',
          provider: 'מוסך מורשה',
          items: const [
            'טיפול מלא תקופתי',
            'החלפת נוזלי בלמים קדמי ואחורי',
            'צמיג קדמי 110/90-13',
            'כיוונון שסתומים מנוע',
          ],
        ),
      ],
    );
  }

  /// فحص وجود فاتورة سابقة مطابقة في السجل لمنع تكرار الإدخال
  VehicleExpenseRecord? findDuplicate({
    String? invoiceNumber,
    required DateTime date,
    required double amount,
    required ExpenseCategory category,
    String? title,
  }) {
    final cleanInv = invoiceNumber?.trim().toLowerCase();
    for (final item in history) {
      // 1. فحص تطابق رقم الفاتورة إذا كان متوفراً
      if (cleanInv != null && cleanInv.isNotEmpty) {
        if (item.invoiceNumber != null &&
            item.invoiceNumber!.trim().toLowerCase() == cleanInv) {
          return item;
        }
        if (cleanInv.length >= 3 && item.title.contains(cleanInv)) {
          return item;
        }
      }

      // 2. فحص تطابق التاريخ (نفس اليوم) والمبلغ التقريبي (فرق أقل من نصف شيكل) ونفس الفئة
      final sameDay = item.date.year == date.year &&
          item.date.month == date.month &&
          item.date.day == date.day;
      final sameAmount = (item.amount - amount).abs() < 0.50;

      if (sameDay && sameAmount && item.category == category) {
        return item;
      }

      // 3. فحص تطابق العنوان الدقيق ونفس اليوم
      if (sameDay &&
          title != null &&
          title.trim().isNotEmpty &&
          item.title.trim().toLowerCase() == title.trim().toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  double get currentMonthFuelTotal {
    final now = DateTime.now();
    return history
        .where((e) =>
            e.category == ExpenseCategory.fuel &&
            e.date.year == now.year &&
            e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get currentMonthMaintenanceTotal {
    final now = DateTime.now();
    return history
        .where((e) =>
            e.category == ExpenseCategory.maintenance &&
            e.date.year == now.year &&
            e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  VehicleDataState copyWith({
    String? vehicleName,
    int? currentOdometer,
    List<MaintenancePart>? parts,
    List<VehicleExpenseRecord>? history,
    DateTime? insuranceExpiry,
    DateTime? testExpiry,
  }) {
    return VehicleDataState(
      vehicleName: vehicleName ?? this.vehicleName,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      parts: parts ?? this.parts,
      history: history ?? this.history,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      testExpiry: testExpiry ?? this.testExpiry,
    );
  }

  String toJson() => jsonEncode({
        'vehicleName': vehicleName,
        'currentOdometer': currentOdometer,
        'insuranceExpiry': insuranceExpiry.toIso8601String(),
        'testExpiry': testExpiry.toIso8601String(),
        'parts': parts.map((x) => x.toMap()).toList(),
        'history': history.map((x) => x.toMap()).toList(),
      });

  /// فلترة ومنع التكرار نهائياً في السجل باعتماد رقم الفاتورة كمعرف أساسي فريد
  static List<VehicleExpenseRecord> deduplicateHistory(List<VehicleExpenseRecord> list) {
    final seen = <String>{};
    final unique = <VehicleExpenseRecord>[];

    for (final r in list) {
      final inv = r.invoiceNumber?.trim().toLowerCase();
      final key = (inv != null && inv.isNotEmpty)
          ? 'inv_$inv'
          : 'dt_${r.date.year}_${r.date.month}_${r.date.day}_${r.date.hour}_${r.date.minute}_${r.amount.toStringAsFixed(2)}_${r.category.name}';

      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(r);
      }
    }
    return unique;
  }

  factory VehicleDataState.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final rawList = (map['history'] as List<dynamic>?)
            ?.map((x) =>
                VehicleExpenseRecord.fromMap(x as Map<String, dynamic>))
            .toList() ??
        [];

    return VehicleDataState(
      vehicleName: map['vehicleName'] as String? ?? 'SYM Joyride 200',
      currentOdometer: (map['currentOdometer'] as num?)?.toInt() ?? 14350,
      insuranceExpiry: DateTime.tryParse(map['insuranceExpiry'] as String? ?? '') ??
          DateTime(2026, 11, 22),
      testExpiry: DateTime.tryParse(map['testExpiry'] as String? ?? '') ??
          DateTime(2027, 1, 1),
      parts: (map['parts'] as List<dynamic>?)
              ?.map((x) => MaintenancePart.fromMap(x as Map<String, dynamic>))
              .toList() ??
          VehicleDataState.initial().parts,
      history: deduplicateHistory(rawList),
    );
  }
}
