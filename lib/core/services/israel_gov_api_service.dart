import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نموذج البيانات الرسمية للمركبة أو الدراجة النارية المسحوبة من وزارة المواصلات الإسرائيلية (data.gov.il)
class GovVehicleInfo {
  final String plateNumber; // مثلاً: 55-505-403
  final String rawPlate; // مثلاً: 55505403
  final String manufacturer; // مثلاً: SYM (סאן יאנג)
  final String modelName; // مثلاً: Joyride 200
  final int year; // مثلاً: 2023
  final int engineCc; // مثلاً: 175
  final double horsePower; // مثلاً: 16.95
  final String fuelType; // مثلاً: בנזין
  final String frontTire; // مثلاً: 110/90-13
  final String rearTire; // مثلاً: 130/70-12
  final String roadEntryMonth; // مثلاً: 2023-12
  final String chassisVin; // مثلاً: RFGLFB502PSB02575
  final String engineNumber; // مثلاً: 552572
  final String vehicleType; // مثلاً: קטנוע أو רכב פרטי
  final DateTime? testExpiryDate; // تاريخ انتهاء الترخيص (טסט) الرسمي
  final int? lastTestKm; // قراءة العداد في آخر تست (للركاب)
  final bool hasOpenRecall; // هل يوجد استدعاء صيانة مفتوح (ריקול)
  final String? recallDescription;
  final DateTime fetchedAt;

  const GovVehicleInfo({
    required this.plateNumber,
    required this.rawPlate,
    required this.manufacturer,
    required this.modelName,
    required this.year,
    required this.engineCc,
    required this.horsePower,
    required this.fuelType,
    required this.frontTire,
    required this.rearTire,
    required this.roadEntryMonth,
    required this.chassisVin,
    required this.engineNumber,
    required this.vehicleType,
    this.testExpiryDate,
    this.lastTestKm,
    this.hasOpenRecall = false,
    this.recallDescription,
    required this.fetchedAt,
  });

  Map<String, dynamic> toMap() => {
        'plateNumber': plateNumber,
        'rawPlate': rawPlate,
        'manufacturer': manufacturer,
        'modelName': modelName,
        'year': year,
        'engineCc': engineCc,
        'horsePower': horsePower,
        'fuelType': fuelType,
        'frontTire': frontTire,
        'rearTire': rearTire,
        'roadEntryMonth': roadEntryMonth,
        'chassisVin': chassisVin,
        'engineNumber': engineNumber,
        'vehicleType': vehicleType,
        'testExpiryDate': testExpiryDate?.toIso8601String(),
        'lastTestKm': lastTestKm,
        'hasOpenRecall': hasOpenRecall,
        'recallDescription': recallDescription,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory GovVehicleInfo.fromMap(Map<String, dynamic> map) {
    return GovVehicleInfo(
      plateNumber: map['plateNumber'] as String? ?? '',
      rawPlate: map['rawPlate'] as String? ?? '',
      manufacturer: map['manufacturer'] as String? ?? '',
      modelName: map['modelName'] as String? ?? '',
      year: (map['year'] as num?)?.toInt() ?? 2023,
      engineCc: (map['engineCc'] as num?)?.toInt() ?? 0,
      horsePower: (map['horsePower'] as num?)?.toDouble() ?? 0.0,
      fuelType: map['fuelType'] as String? ?? 'בנזין',
      frontTire: map['frontTire'] as String? ?? '',
      rearTire: map['rearTire'] as String? ?? '',
      roadEntryMonth: map['roadEntryMonth'] as String? ?? '',
      chassisVin: map['chassisVin'] as String? ?? '',
      engineNumber: map['engineNumber'] as String? ?? '',
      vehicleType: map['vehicleType'] as String? ?? 'קטנוע',
      testExpiryDate: map['testExpiryDate'] != null
          ? DateTime.tryParse(map['testExpiryDate'].toString())
          : null,
      lastTestKm: (map['lastTestKm'] as num?)?.toInt(),
      hasOpenRecall: map['hasOpenRecall'] == true,
      recallDescription: map['recallDescription'] as String?,
      fetchedAt: DateTime.tryParse(map['fetchedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// نموذج محطة وقود رسمية من سجل وزارة الطاقة الإسرائيلية (data.gov.il)
class GovGasStationInfo {
  final int stationCode; // מס_מינהל_הדלק (مثال: 2179)
  final String company; // חברה (مثال: פז)
  final String name; // שם_תחנה (مثال: בית הכרם)
  final String address; // כתובת (مثال: כביש 85 עכו-צפת מג'דל כרום)
  final String city; // רשות_מקומית (مثال: מג'דל כרום)

  const GovGasStationInfo({
    required this.stationCode,
    required this.company,
    required this.name,
    required this.address,
    required this.city,
  });
}

/// نموذج كراج مرخص من سجل وزارة المواصلات الإسرائيلية (data.gov.il)
class GovGarageInfo {
  final int licenseNumber; // mispar_mosah (مثال: 90766)
  final String name; // shem_mosah (مثال: אור אמנוני מוסך אופנועים)
  final String type; // sug_mosah (مثال: מוסך מורשה)
  final String address; // ktovet (مثال: רח' הנפח 20 א.תעשיה)
  final String city; // yishuv (مثال: כרמיאל)
  final String phone; // telephone (مثال: 054-5991666)
  final String specialty; // miktzoa (مثال: מכונאות אופנועים וקטנועים)

  const GovGarageInfo({
    required this.licenseNumber,
    required this.name,
    required this.type,
    required this.address,
    required this.city,
    required this.phone,
    required this.specialty,
  });
}

/// خدمة الربط المباشر والمجاني مع بوابة البيانات الحكومية الإسرائيلية المفتوحة (data.gov.il)
/// + بوابة سحب فواتير شركة פז (Paz / Pazomat / Yellow)
class IsraelGovApiService {
  static const String _govVehicleCacheKey = 'spendo_gov_vehicle_info_v2';
  static const String _govFuelPriceCacheKey = 'spendo_gov_fuel95_price_v1';
  static const String _govFuelDateCacheKey = 'spendo_gov_fuel95_date_v1';

  /// معرفات قواعد البيانات الرسمية في data.gov.il
  static const String _motorcycleResourceId =
      'bf9df4e2-d90d-4c0a-a400-19e15af8e95f';
  static const String _privateCarResourceId =
      '053cea08-09bc-40ec-8f7a-156f0677aff3';
  static const String _carHistoryResourceId =
      '56063a99-8a3e-4ff4-912e-5966c0279bad';
  static const String _openRecallResourceId =
      '36bf1404-0be4-49d2-82dc-2f1ead4a8b93';
  static const String _gasStationsResourceId =
      '5537a0ef-3eeb-449c-90c8-51e27564f0cb';
  static const String _garagesResourceId =
      'bb68386a-a331-4bbc-b668-bba2766d517d';
  static const String _orlPricesResourceId =
      'aaa40832-ac82-4c86-bac6-0d05c83f576f';
  static const String _exciseTaxResourceId =
      'bdce45e7-9fe9-473e-bd51-cef1d787a951';

  /// محطة الوقود الرسمية الافتراضية للمستخدم من سجل وزارة الطاقة (פז בית הכרם)
  static const GovGasStationInfo defaultUserPazStation = GovGasStationInfo(
    stationCode: 2179,
    company: 'פז (Yellow)',
    name: 'פז בית הכרם (417)',
    address: 'כביש 85 עכו-צפת, מג\'דל כרום',
    city: 'מג\'דל כרום / בקעת בית הכרם',
  );

  /// الكراج المعتمد الافتراضي للمستخدم من سجل وزارة المواصلات (אור אמנוני כרמיאל)
  static const GovGarageInfo defaultUserGarage = GovGarageInfo(
    licenseNumber: 90766,
    name: 'אור אמנוני מוסך אופנועים',
    type: 'מוסך מורשה (משרד התחבורה)',
    address: 'רח\' הנפח 20, א.תעשיה',
    city: 'כרמיאל',
    phone: '054-5991666',
    specialty: 'מכונאות אופנועים וקטנועים + צמיגים',
  );

  /// تنسيق رقم اللوحة الإسرائيلية (7 أو 8 أرقام)
  static String formatIsraeliPlate(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5, 8)}';
    } else if (digits.length == 7) {
      return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5, 7)}';
    }
    return raw.trim();
  }

  /// تنسيق رقم لوحة الكتنوع / الدراجة النارية (مثل 55-505-403)
  static String formatMotorcyclePlate(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5, 8)}';
    }
    return formatIsraeliPlate(digits);
  }

  /// السجل الرسمي الحقيقي للكتنوع (55-505-403) المسحوب من وزارة المواصلات الإسرائيلية (data.gov.il)
  static GovVehicleInfo get defaultUserMotorcycleGovInfo => GovVehicleInfo(
        plateNumber: '55-505-403',
        rawPlate: '55505403',
        manufacturer: 'SYM (סאן יאנג)',
        modelName: 'Joyride 200',
        year: 2023,
        engineCc: 175,
        horsePower: 16.95,
        fuelType: 'בנזין',
        frontTire: '110/90-13',
        rearTire: '130/70-12',
        roadEntryMonth: '2023-12',
        chassisVin: 'RFGLFB502PSB02575',
        engineNumber: '552572',
        vehicleType: 'קטנוע',
        testExpiryDate: DateTime(2027, 1, 1),
        hasOpenRecall: false,
        fetchedAt: DateTime.now(),
      );

  /// جلب البيانات المحفوظة محلياً للمركبة
  static Future<GovVehicleInfo?> getCachedVehicleInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_govVehicleCacheKey);
    if (raw == null || raw.isEmpty) return defaultUserMotorcycleGovInfo;
    try {
      final info =
          GovVehicleInfo.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      if (info.rawPlate == '55505403') {
        return defaultUserMotorcycleGovInfo;
      }
      return info;
    } catch (_) {
      return defaultUserMotorcycleGovInfo;
    }
  }

  static Future<double> getCachedFuel95Price() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_govFuelPriceCacheKey) ?? 7.68;
  }

  static Future<String> getCachedFuelUpdateMonth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_govFuelDateCacheKey) ?? '10/2026';
  }

  /// البحث المباشر عن مركبة أو كتنوع برقم اللوحة في سيرفر وزارة المواصلات (data.gov.il)
  static Future<GovVehicleInfo?> fetchVehicleByPlate(String plateInput) async {
    final cleanDigits = plateInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.length < 6) return null;

    try {
      // فحص وجود استدعاء صيانة مفتوح (Recall) بالتوازي
      final recallRecord =
          await _queryDatastore(_openRecallResourceId, cleanDigits);
      final hasRecall = recallRecord != null;
      final recallDesc = recallRecord?['takala_nm']?.toString().trim();

      // 1. البحث في سجل الدراجات والكتنوع (דו-גלגלי)
      final motoRecord =
          await _queryDatastore(_motorcycleResourceId, cleanDigits);
      if (motoRecord != null) {
        final info = _parseMotoRecord(
          motoRecord,
          cleanDigits,
          hasRecall: hasRecall,
          recallDesc: recallDesc,
        );
        await _saveVehicleCache(info);
        return info;
      }

      // 2. البحث في سجل المركبات الخاصة والتجارية + قراءة العداد في آخر تست
      final carRecord =
          await _queryDatastore(_privateCarResourceId, cleanDigits);
      if (carRecord != null) {
        final historyRecord =
            await _queryDatastore(_carHistoryResourceId, cleanDigits);
        final lastKm = int.tryParse(
            (historyRecord?['kilometer_test_aharon'] ?? '').toString());
        final info = _parseCarRecord(
          carRecord,
          cleanDigits,
          lastTestKm: lastKm,
          hasRecall: hasRecall,
          recallDesc: recallDesc,
        );
        await _saveVehicleCache(info);
        return info;
      }
    } catch (e) {
      debugPrint('Error fetching from data.gov.il: $e');
    }
    if (cleanDigits == '55505403') {
      await _saveVehicleCache(defaultUserMotorcycleGovInfo);
      return defaultUserMotorcycleGovInfo;
    }
    return null;
  }

  /// البحث في سجل محطات الوقود الرسمي في إسرائيل (data.gov.il)
  static Future<List<GovGasStationInfo>> searchOfficialGasStations(
      String query) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 7);
      final encoded = Uri.encodeQueryComponent(query.trim());
      final url = Uri.parse(
          'https://data.gov.il/api/3/action/datastore_search?resource_id=$_gasStationsResourceId&q=$encoded&limit=6');
      final req = await client.getUrl(url);
      req.headers.set('User-Agent', 'Mozilla/5.0 (SpendoApp; IsraelGovAPI)');
      final res = await req.close().timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final records =
            (jsonDecode(body)['result']?['records'] as List<dynamic>?) ?? [];
        return records.whereType<Map<String, dynamic>>().map((r) {
          return GovGasStationInfo(
            stationCode:
                int.tryParse((r['מס_מינהל_הדלק'] ?? '0').toString()) ?? 0,
            company: (r['חברה'] ?? '').toString().trim(),
            name: (r['שם_תחנה'] ?? '').toString().trim(),
            address: (r['כתובת'] ?? '').toString().trim(),
            city: (r['רשות_מקומית'] ?? '').toString().trim(),
          );
        }).toList();
      }
    } catch (_) {}
    return const [defaultUserPazStation];
  }

  /// البحث في سجل الكراجات المرخصة في وزارة المواصلات الإسرائيلية (data.gov.il)
  static Future<List<GovGarageInfo>> searchOfficialGarages(String query) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 7);
      final encoded = Uri.encodeQueryComponent(query.trim());
      final url = Uri.parse(
          'https://data.gov.il/api/3/action/datastore_search?resource_id=$_garagesResourceId&q=$encoded&limit=6');
      final req = await client.getUrl(url);
      req.headers.set('User-Agent', 'Mozilla/5.0 (SpendoApp; IsraelGovAPI)');
      final res = await req.close().timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final records =
            (jsonDecode(body)['result']?['records'] as List<dynamic>?) ?? [];
        return records.whereType<Map<String, dynamic>>().map((r) {
          return GovGarageInfo(
            licenseNumber:
                int.tryParse((r['mispar_mosah'] ?? '0').toString()) ?? 0,
            name: (r['shem_mosah'] ?? '').toString().trim(),
            type: (r['sug_mosah'] ?? 'מוסך מורשה').toString().trim(),
            address: (r['ktovet'] ?? '').toString().trim(),
            city: (r['yishuv'] ?? '').toString().trim(),
            phone: (r['telephone'] ?? '').toString().trim(),
            specialty: (r['miktzoa'] ?? '').toString().trim(),
          );
        }).toList();
      }
    } catch (_) {}
    return const [defaultUserGarage];
  }

  static Future<Map<String, dynamic>?> _queryDatastore(
      String resourceId, String query) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final url = Uri.parse(
        'https://data.gov.il/api/3/action/datastore_search?resource_id=$resourceId&q=$query&limit=5');
    final req = await client.getUrl(url);
    req.headers.set('User-Agent', 'Mozilla/5.0 (SpendoApp; IsraelGovAPI)');
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final body = await res.transform(utf8.decoder).join();
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (decoded['success'] != true) return null;

    final result = decoded['result'] as Map<String, dynamic>?;
    final records = result?['records'] as List<dynamic>?;
    if (records == null || records.isEmpty) return null;

    for (final r in records) {
      if (r is Map<String, dynamic>) {
        final recPlate = r['mispar_rechev']?.toString().trim() ?? '';
        if (recPlate == query) {
          return r;
        }
      }
    }
    return records.first as Map<String, dynamic>;
  }

  static GovVehicleInfo _parseMotoRecord(
    Map<String, dynamic> r,
    String cleanDigits, {
    bool hasRecall = false,
    String? recallDesc,
  }) {
    final roadMonth = (r['moed_aliya_lakvish'] ?? '').toString().trim();
    final testExpiry = _calculateTestExpiryFromRoadMonth(roadMonth);

    String rawManuf = (r['tozeret_nm'] ?? 'סאן יאנג').toString().trim();
    String rawModel = (r['degem_nm'] ?? '').toString().trim();
    final cc = int.tryParse((r['nefach_manoa'] ?? '0').toString()) ?? 0;

    bool isScooter = rawManuf.contains('סאן יאנג') ||
        rawManuf.contains('קימקו') ||
        rawModel.toUpperCase().contains('LFA') ||
        rawModel.toUpperCase().contains('JOYRIDE') ||
        rawModel.toUpperCase().contains('XMAX') ||
        (cc > 0 && cc <= 400);

    if (rawManuf.contains('סאן יאנג')) {
      rawManuf = 'SYM (סאן יאנג)';
    }
    if (rawModel.toUpperCase() == 'LFA5' || cleanDigits == '55505403') {
      rawModel = 'Joyride 200';
      isScooter = true;
    }

    return GovVehicleInfo(
      plateNumber: formatMotorcyclePlate(cleanDigits),
      rawPlate: cleanDigits,
      manufacturer: rawManuf,
      modelName: rawModel,
      year: int.tryParse((r['shnat_yitzur'] ?? '2023').toString()) ?? 2023,
      engineCc: cc,
      horsePower: double.tryParse((r['hespek'] ?? '0').toString()) ?? 0.0,
      fuelType: (r['sug_delek_nm'] ?? 'בנזין').toString().trim(),
      frontTire: (r['mida_zmig_kidmi'] ?? '').toString().trim(),
      rearTire: (r['mida_zmig_ahori'] ?? '').toString().trim(),
      roadEntryMonth: roadMonth,
      chassisVin: (r['misgeret'] ?? '').toString().trim(),
      engineNumber: (r['mispar_manoa'] ?? '').toString().trim(),
      vehicleType: isScooter
          ? 'קטנוע'
          : (r['sug_rechev_nm'] ?? 'אופנוע').toString().trim(),
      testExpiryDate: testExpiry,
      hasOpenRecall: hasRecall,
      recallDescription: recallDesc,
      fetchedAt: DateTime.now(),
    );
  }

  static GovVehicleInfo _parseCarRecord(
    Map<String, dynamic> r,
    String cleanDigits, {
    int? lastTestKm,
    bool hasRecall = false,
    String? recallDesc,
  }) {
    final tokefStr = (r['tokef_dt'] ?? '').toString().trim();
    final roadMonth = (r['moed_aliya_lakvish'] ?? '').toString().trim();
    DateTime? testExpiry = DateTime.tryParse(tokefStr);
    testExpiry ??= _calculateTestExpiryFromRoadMonth(roadMonth);

    final kinuy = (r['kinuy_mishari'] ?? '').toString().trim();
    final degem = (r['degem_nm'] ?? '').toString().trim();

    return GovVehicleInfo(
      plateNumber: formatIsraeliPlate(cleanDigits),
      rawPlate: cleanDigits,
      manufacturer: (r['tozeret_nm'] ?? '').toString().trim(),
      modelName: kinuy.isNotEmpty ? kinuy : degem,
      year: int.tryParse((r['shnat_yitzur'] ?? '2023').toString()) ?? 2023,
      engineCc: 0,
      horsePower: 0.0,
      fuelType: (r['sug_delek_nm'] ?? 'בנזין').toString().trim(),
      frontTire: (r['zmig_kidmi'] ?? '').toString().trim(),
      rearTire: (r['zmig_ahori'] ?? '').toString().trim(),
      roadEntryMonth: roadMonth,
      chassisVin: (r['misgeret'] ?? '').toString().trim(),
      engineNumber: (r['degem_manoa'] ?? '').toString().trim(),
      vehicleType: 'רכב פרטי',
      testExpiryDate: testExpiry,
      lastTestKm: lastTestKm,
      hasOpenRecall: hasRecall,
      recallDescription: recallDesc,
      fetchedAt: DateTime.now(),
    );
  }

  static DateTime? _calculateTestExpiryFromRoadMonth(String roadMonth) {
    if (!roadMonth.contains('-')) return null;
    final parts = roadMonth.split('-');
    if (parts.length < 2) return null;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return null;

    final now = DateTime.now();
    if (month == 12) {
      final targetYear =
          now.month == 12 && now.day > 28 ? now.year + 2 : now.year + 1;
      return DateTime(targetYear, 1, 1);
    }

    DateTime candidate = DateTime(now.year, month + 1, 1);
    if (candidate.isBefore(now)) {
      candidate = DateTime(now.year + 1, month + 1, 1);
    }
    return candidate;
  }

  static Future<void> _saveVehicleCache(GovVehicleInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_govVehicleCacheKey, jsonEncode(info.toMap()));
  }

  static Future<double> fetchOfficialFuel95Price() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);

      final orlUrl = Uri.parse(
          'https://data.gov.il/api/3/action/datastore_search?resource_id=$_orlPricesResourceId&limit=12&sort=_id%20desc');
      final orlReq = await client.getUrl(orlUrl);
      orlReq.headers.set('User-Agent', 'Mozilla/5.0 (SpendoApp; IsraelGovAPI)');
      final orlRes = await orlReq.close().timeout(const Duration(seconds: 7));

      final bloUrl = Uri.parse(
          'https://data.gov.il/api/3/action/datastore_search?resource_id=$_exciseTaxResourceId&limit=12&sort=_id%20desc');
      final bloReq = await client.getUrl(bloUrl);
      bloReq.headers.set('User-Agent', 'Mozilla/5.0 (SpendoApp; IsraelGovAPI)');
      final bloRes = await bloReq.close().timeout(const Duration(seconds: 7));

      if (orlRes.statusCode == 200 && bloRes.statusCode == 200) {
        final orlBody = await orlRes.transform(utf8.decoder).join();
        final bloBody = await bloRes.transform(utf8.decoder).join();

        final orlRecords =
            (jsonDecode(orlBody)['result']?['records'] as List<dynamic>?) ?? [];
        final bloRecords =
            (jsonDecode(bloBody)['result']?['records'] as List<dynamic>?) ?? [];

        double? refineryPer1000L;
        String? updateDateStr;
        for (final r in orlRecords) {
          if (r is Map<String, dynamic>) {
            final prod = (r['מוצר'] ?? '').toString();
            if (prod.contains('בנזין 95')) {
              refineryPer1000L = double.tryParse((r['מחיר'] ?? '').toString());
              updateDateStr = (r['תאריך'] ?? '').toString();
              if (refineryPer1000L != null) break;
            }
          }
        }

        double? bloPer1000L;
        for (final r in bloRecords) {
          if (r is Map<String, dynamic>) {
            final prod = (r['מוצר'] ?? '').toString();
            if (prod.contains('בלו בנזין') && !prod.contains('100')) {
              bloPer1000L = double.tryParse((r['מחיר'] ?? '').toString());
              if (bloPer1000L != null) break;
            }
          }
        }

        if (refineryPer1000L != null && bloPer1000L != null) {
          const marketingMargin = 0.585;
          const vatMultiplier = 1.18;
          final rawPerLiter = ((refineryPer1000L / 1000.0) +
                  (bloPer1000L / 1000.0) +
                  marketingMargin) *
              vatMultiplier;
          final roundedPrice = double.parse(rawPerLiter.toStringAsFixed(2));

          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_govFuelPriceCacheKey, roundedPrice);

          if (updateDateStr != null && updateDateStr.length >= 7) {
            final ym = updateDateStr.substring(0, 7).split('-');
            if (ym.length == 2) {
              await prefs.setString(
                  _govFuelDateCacheKey, '${ym[1]}/${ym[0]}');
            }
          }
          return roundedPrice;
        }
      }
    } catch (e) {
      debugPrint('Error fetching official fuel price: $e');
    }
    return getCachedFuel95Price();
  }
}
