import '../../../core/services/firebase_backup_service.dart';
import '../../../core/services/location_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_expense_model.dart';

class DailyExpenseService {
  static const String _expensesKey = 'spendo_daily_expenses_v1';
  static const String _merchantMapKey = 'spendo_merchant_categories_v1';
  static const MethodChannel _deepLinkChannel =
      MethodChannel('com.finance.spendo/deeplink');

  /// عنوان Webhook السحابي لاستقبال دفعات المحفظة في الخلفية بدون فتح التطبيق (داخل مسار spendo_backups المصرح)
  static const String cloudWebhookUrl =
      'https://spendo-4813f-default-rtdb.europe-west1.firebasedatabase.app/spendo_backups/auto_expenses_inbox.json';

  /// عنوان الرابط المباشر للـ Shortcuts في الآيفون والأندرويد (يقبل الدفعة تلقائياً بدون أسئلة يدوية)
  static const String shortcutDeepLinkTemplate =
      'spendo://pay?tx=';

  /// الأمر الجاهز للصقه في خانة Describe a change في اختصار الآيفون لإلغاء الأسئلة اليدوية نهائياً
  static const String iosShortcutAutoFixCommand =
      'Remove Ask for payment amount, Ask for merchant name, and Get current location. Get Amount and Merchant directly from Shortcut Input Transaction and open URL spendo://pay?amount=[Amount]&merchant=[Merchant]';

  static bool _listenerInitialized = false;
  static final ValueNotifier<int> expensesChangedNotifier = ValueNotifier<int>(0);

  /// التحقق مما إذا كان التقاط دفعات المحفظة التلقائي مفعلاً على الجهاز (Android)
  static Future<bool> isWalletListenerEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      final enabled = await _deepLinkChannel
          .invokeMethod<bool>('isNotificationListenerEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// فتح إعدادات صلاحية التقاط إشعارات المحفظة تلقائياً (Android)
  static Future<bool> openWalletListenerSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final opened = await _deepLinkChannel
          .invokeMethod<bool>('openNotificationListenerSettings');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// فتح تطبيق المحفظة الرسمي على الهاتف (Google Wallet / Samsung Wallet / Apple Wallet)
  static Future<bool> openDeviceWalletApp() async {
    try {
      final opened =
          await _deepLinkChannel.invokeMethod<bool>('openWalletApp');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// فتح تطبيق الاختصارات (Shortcuts) في الآيفون لإضافة الاختصار التلقائي الجديد مباشرة
  static Future<bool> openIosShortcutsApp() async {
    try {
      await Clipboard.setData(
        const ClipboardData(text: shortcutDeepLinkTemplate),
      );
      final opened =
          await _deepLinkChannel.invokeMethod<bool>('openShortcutsApp');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// تهيئة الاستماع التلقائي للروابط (`spendo://pay`) وإشعارات المحفظة والمزامنة السحابية
  static Future<void> initAutoSyncListener() async {
    if (!_listenerInitialized) {
      _listenerInitialized = true;

      _deepLinkChannel.setMethodCallHandler((call) async {
        if (call.method == 'onDeepLink') {
          final link = call.arguments as String?;
          if (link != null && link.isNotEmpty) {
            await handleIncomingShortcutUri(link);
          }
        } else if (call.method == 'onWalletNotification') {
          final payloadJson = call.arguments as String?;
          if (payloadJson != null && payloadJson.isNotEmpty) {
            await _handleWalletNotificationJson(payloadJson);
          }
        }
      });
    }

    // 1. فحص إذا تم فتح التطبيق عبر شورتكات المحفظة
    try {
      final initialLink =
          await _deepLinkChannel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        await handleIncomingShortcutUri(initialLink);
      }
    } catch (_) {}

    // 2. سحب أي دفعات التقطتها محفظة الأندرويد بالخلفية
    await pullPendingAndroidWalletNotifications();

    // 3. سحب أي دفعات أرسلها شورتكات الآيفون للسحابة بالخلفية
    await pullCloudAutoExpenses();
  }

  /// سحب دفعات محفظة الأندرويد (Google Wallet / Samsung Pay / כאל / Max) الملتقطة في الخلفية
  static Future<int> pullPendingAndroidWalletNotifications() async {
    if (!Platform.isAndroid) return 0;
    try {
      final raw = await _deepLinkChannel
          .invokeMethod<String>('getPendingWalletNotifications');
      if (raw == null || raw.isEmpty || raw == '[]') return 0;

      final list = jsonDecode(raw) as List<dynamic>;
      int count = 0;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final ok = await _processWalletNotificationMap(item);
          if (ok) count++;
        }
      }
      if (count > 0) {
        expensesChangedNotifier.value++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> _handleWalletNotificationJson(String payloadJson) async {
    try {
      final map = jsonDecode(payloadJson) as Map<String, dynamic>;
      final ok = await _processWalletNotificationMap(map);
      if (ok) {
        expensesChangedNotifier.value++;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _processWalletNotificationMap(
      Map<String, dynamic> map) async {
    final title = map['title']?.toString().trim() ?? '';
    final body = map['body']?.toString().trim() ?? '';
    final text = map['text']?.toString().trim() ?? '$title\n$body';
    final source = map['source']?.toString().trim() ??
        (Platform.isAndroid ? 'google_pay' : 'apple_pay');
    final ts = map['timestamp'] as int?;
    final date = ts != null && ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : DateTime.now();

    final parsed = parsePaymentNotification(
      text,
      notificationTitle: title,
      notificationBody: body,
    );

    if (parsed.amount != null && parsed.amount! > 0) {
      await addExpense(
        merchantName: (parsed.merchant != null && parsed.merchant!.isNotEmpty)
            ? parsed.merchant!
            : 'دفعة محفظة',
        amount: parsed.amount!,
        source: source,
        date: date,
      );
      return true;
    }
    return false;
  }

  /// معالجة الرابط القادم من Shortcut أو محفظة الهاتف تلقائياً مع التقاط الموقع الجغرافي
  /// يقبل:
  /// - `spendo://pay?tx=Transaction`
  /// - `spendo://pay?amount=45&merchant=BBB`
  /// - `spendo://pay?text=...`
  static Future<bool> handleIncomingShortcutUri(String rawUri) async {
    try {
      final decodedRaw = Uri.decodeFull(rawUri);
      final uri = Uri.parse(rawUri);
      final params = uri.queryParameters;

      double? amount;
      String? merchant;
      String source = params['source'] ??
          (Platform.isAndroid ? 'google_pay' : 'apple_pay');

      // 1. Check raw transaction / text parameters (`tx`, `transaction`, `input`, `text`, `body`)
      for (final key in ['tx', 'transaction', 'input', 'text', 'body', 'data']) {
        if (params.containsKey(key) && params[key]!.trim().isNotEmpty) {
          final parsed = parsePaymentNotification(params[key]!);
          amount ??= parsed.amount;
          if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
            merchant ??= parsed.merchant;
          }
        }
      }

      // 2. Check explicit amount parameter
      if (params.containsKey('amount') && params['amount']!.trim().isNotEmpty) {
        final rawAmt = params['amount']!
            .replaceAll(RegExp(r'[^0-9.,]'), '')
            .replaceAll(',', '.');
        amount = double.tryParse(rawAmt) ?? amount;
        if (amount == null) {
          final parsedAmt = parsePaymentNotification(params['amount']!);
          amount = parsedAmt.amount;
          merchant ??= parsedAmt.merchant;
        }
      }

      // 3. Check explicit merchant / name / store / cardOrMerchant parameter
      for (final mKey in ['merchant', 'name', 'store', 'shop', 'title']) {
        if (params.containsKey(mKey) && params[mKey]!.trim().isNotEmpty) {
          final candidate = params[mKey]!.trim();
          if (!candidate.contains('{') && !candidate.contains('[')) {
            merchant = candidate;
            break;
          }
        }
      }

      // 4. Fallback: if the user passed raw Transaction directly after `spendo://pay?` or `spendo://pay/`
      if (amount == null) {
        final payloadPart = decodedRaw
            .replaceFirst(RegExp(r'^spendo://pay/?\??', caseSensitive: false), '')
            .replaceFirst(RegExp(r'^tx=', caseSensitive: false), '')
            .trim();
        if (payloadPart.isNotEmpty) {
          final parsed = parsePaymentNotification(payloadPart);
          amount = parsed.amount;
          merchant ??= parsed.merchant;
        }
      }

      String? location;
      for (final lKey in ['location', 'city', 'place', 'address']) {
        if (params.containsKey(lKey) && params[lKey]!.trim().isNotEmpty) {
          final locVal = params[lKey]!.trim();
          if (!locVal.contains('{') && !locVal.contains('[')) {
            location = locVal;
            break;
          }
        }
      }

      if (amount != null && amount > 0) {
        await addExpense(
          merchantName: (merchant != null && merchant.isNotEmpty)
              ? merchant
              : 'دفعة المحفظة',
          amount: amount,
          source: source,
          location: location,
        );
        expensesChangedNotifier.value++;
        return true;
      }
    } catch (e) {
      debugPrint('Error parsing shortcut URI: $e');
    }
    return false;
  }

  /// سحب الدفعات المرسلة تلقائياً في الخلفية عبر Shortcuts إلى Firebase مع إغلاق المقابس بأمان
  static Future<int> pullCloudAutoExpenses() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(Uri.parse(cloudWebhookUrl));
      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return 0;

      final body = await res.transform(utf8.decoder).join();
      if (body.isEmpty || body == 'null') return 0;

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return 0;

      int importedCount = 0;
      for (final entry in decoded.entries) {
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          double? amount;
          String? merchant;
          String source = (val['source'] as String?) ?? 'apple_pay';

          if (val['text'] != null) {
            final parsed = parsePaymentNotification(val['text'].toString());
            amount = parsed.amount;
            merchant = parsed.merchant;
          }
          if (val['amount'] != null) {
            final rawAmt = val['amount']
                .toString()
                .replaceAll(RegExp(r'[^0-9.,]'), '')
                .replaceAll(',', '.');
            amount = double.tryParse(rawAmt) ?? amount;
          }
          if (val['merchant'] != null &&
              val['merchant'].toString().trim().isNotEmpty) {
            merchant = val['merchant'].toString().trim();
          }

          String? location = val['location']?.toString() ??
              val['city']?.toString() ??
              val['address']?.toString() ??
              val['place']?.toString();

          if (amount != null && amount > 0) {
            await addExpense(
              merchantName: (merchant != null && merchant.isNotEmpty)
                  ? merchant
                  : 'دفعة المحفظة',
              amount: amount,
              source: source,
              location: location,
            );
            importedCount++;
          }
        }
      }

      if (importedCount > 0) {
        final delReq = await client.deleteUrl(Uri.parse(cloudWebhookUrl));
        await delReq.close().timeout(const Duration(seconds: 5));
        expensesChangedNotifier.value++;
      }
      return importedCount;
    } catch (_) {
      return 0;
    } finally {
      client.close(force: true);
    }
  }

  /// جلب كافة المصاريف اليومية ودفعات المحفظة
  static Future<List<DailyExpenseModel>> getAllExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_expensesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map((e) => DailyExpenseModel.fromMap(e as Map<String, dynamic>))
          .toList();

      final seen = <String>{};
      final unique = <DailyExpenseModel>[];
      for (final e in items) {
        final key =
            '${e.date.year}_${e.date.month}_${e.date.day}_${e.date.hour}_${e.date.minute}_${e.amount.toStringAsFixed(2)}_${e.merchantName.trim()}';
        if (!seen.contains(key)) {
          seen.add(key);
          unique.add(e);
        }
      }
      unique.sort((a, b) => b.date.compareTo(a.date));
      if (unique.length < items.length) {
        await saveAllExpenses(unique);
      }
      return unique;
    } catch (_) {
      return [];
    }
  }

  /// حفظ قائمة المصاريف ومزامنتها سحابياً فوراً بين الجلاكسي والآيفون
  static Future<void> saveAllExpenses(List<DailyExpenseModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_expensesKey, encoded);
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  /// إضافة دفعة جديدة مع التعرف الذكي على الصنف وحفظ الموقع الجغرافي تلقائياً
  static Future<DailyExpenseModel> addExpense({
    required String merchantName,
    required double amount,
    String? explicitCategory,
    String source = 'apple_pay',
    DateTime? date,
    String? notes,
    String? location,
  }) async {
    final cleanMerchant = merchantName.trim();
    final targetDate = date ?? DateTime.now();

    String? resolvedLocation = location?.trim();
    if (resolvedLocation == null || resolvedLocation.isEmpty) {
      try {
        final locRes = await LocationService.instance
            .getCurrentLocation()
            .timeout(const Duration(seconds: 6), onTimeout: () => null);
        if (locRes != null) {
          resolvedLocation = locRes.address ??
              '${locRes.latitude.toStringAsFixed(4)}, ${locRes.longitude.toStringAsFixed(4)}';
        }
      } catch (_) {}
    }

    final current = await getAllExpenses();
    final existingIdx = current.indexWhere((e) =>
        e.amount == amount &&
        e.date.year == targetDate.year &&
        e.date.month == targetDate.month &&
        e.date.day == targetDate.day &&
        e.date.hour == targetDate.hour &&
        e.date.minute == targetDate.minute);
    if (existingIdx != -1) {
      if ((current[existingIdx].location == null ||
              current[existingIdx].location!.isEmpty) &&
          resolvedLocation != null &&
          resolvedLocation.isNotEmpty) {
        current[existingIdx] =
            current[existingIdx].copyWith(location: resolvedLocation);
        await saveAllExpenses(current);
      }
      return current[existingIdx];
    }

    final resolvedCategory =
        explicitCategory ?? await resolveMerchantCategory(cleanMerchant);

    final newItem = DailyExpenseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      merchantName: cleanMerchant,
      amount: amount,
      category: resolvedCategory,
      source: source,
      date: targetDate,
      notes: notes,
      location: resolvedLocation,
    );

    current.insert(0, newItem);
    await saveAllExpenses(current);

    if (explicitCategory != null && cleanMerchant.isNotEmpty) {
      await rememberMerchantCategory(cleanMerchant, explicitCategory);
    }

    return newItem;
  }

  /// تحديث موقع دفعة مسجلة باستخدام الـ GPS الحالي
  static Future<String?> updateExpenseLocationWithCurrentGps(
      String expenseId) async {
    final locRes = await LocationService.instance
        .getCurrentLocation()
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
    if (locRes == null) return null;

    final resolvedLocation = locRes.address ??
        '${locRes.latitude.toStringAsFixed(4)}, ${locRes.longitude.toStringAsFixed(4)}';
    final current = await getAllExpenses();
    final updated = current.map((e) {
      if (e.id == expenseId) {
        return e.copyWith(location: resolvedLocation);
      }
      return e;
    }).toList();
    await saveAllExpenses(updated);
    expensesChangedNotifier.value++;
    return resolvedLocation;
  }

  /// حذف حركة مصروف
  static Future<void> deleteExpense(String id) async {
    final current = await getAllExpenses();
    final updated = current.where((e) => e.id != id).toList();
    await saveAllExpenses(updated);
  }

  /// تغيير صنف حركة وتحديث ذاكرة المحل لجميع حركاته بنفس الاسم
  static Future<void> updateExpenseCategory({
    required String expenseId,
    required String merchantName,
    required String newCategory,
  }) async {
    await rememberMerchantCategory(merchantName, newCategory);
    final current = await getAllExpenses();
    final norm = merchantName.trim().toLowerCase();

    final updated = current.map((e) {
      if (e.id == expenseId || e.merchantName.trim().toLowerCase() == norm) {
        return e.copyWith(category: newCategory);
      }
      return e;
    }).toList();

    await saveAllExpenses(updated);
  }

  /// جلب قاموس ذاكرة المحلات المحفوظة (اسم المحل -> الصنف)
  static Future<Map<String, String>> getMerchantCategoryMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_merchantMapKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// حفظ صنف محل في الذاكرة ليُصنّف تلقائياً في المرات القادمة ومزامنته سحابياً
  static Future<void> rememberMerchantCategory(
      String merchantName, String category) async {
    final norm = merchantName.trim().toLowerCase();
    if (norm.isEmpty) return;
    final map = await getMerchantCategoryMap();
    map[norm] = category;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_merchantMapKey, jsonEncode(map));
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  /// معرفة صنف المحل تلقائياً من الذاكرة أو من الكلمات المفتاحية الذكية
  static Future<String> resolveMerchantCategory(String merchantName) async {
    final norm = merchantName.trim().toLowerCase();
    if (norm.isEmpty) return 'shopping';

    final savedMap = await getMerchantCategoryMap();
    if (savedMap.containsKey(norm)) {
      return savedMap[norm]!;
    }

    for (final entry in savedMap.entries) {
      if (entry.key.length >= 3 && norm.contains(entry.key)) {
        return entry.value;
      }
    }

    if (norm.contains('פז') ||
        norm.contains('yellow') ||
        norm.contains('סונול') ||
        norm.contains('דלק') ||
        norm.contains('דור אלון') ||
        norm.contains('ten') ||
        norm.contains('وقود') ||
        norm.contains('بنزين')) {
      return 'fuel';
    }

    if (norm.contains('מסעדת') ||
        norm.contains('פיצה') ||
        norm.contains('שווארמה') ||
        norm.contains('בורגר') ||
        norm.contains('קפה') ||
        norm.contains('מאפה') ||
        norm.contains('bbb') ||
        norm.contains('mcdonald') ||
        norm.contains('مطعم') ||
        norm.contains('أكل') ||
        norm.contains('شاورما')) {
      return 'food';
    }

    return 'shopping';
  }

  /// محلل ذكي لنص إشعار Google Wallet / Samsung Pay / Apple Pay / כאל / Max
  static ({double? amount, String? merchant}) parsePaymentNotification(
    String text, {
    String? notificationTitle,
    String? notificationBody,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return (amount: null, merchant: null);

    double? extractedAmount;
    // 1. صيغة العملة قبل الرقم: ₪120.00 أو ₪ 120
    final prefixCurrency = RegExp(
      r'(?:₪|ש"ח|שח|ILS)\s*(\d+(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(clean);
    // 2. صيغة الرقم قبل العملة: 120.00 ₪ أو 120 ש"ח
    final suffixCurrency = RegExp(
      r'(\d+(?:[.,]\d{1,2})?)\s*(?:ש"ח|שח|₪|ILS|شيكل)',
      caseSensitive: false,
    ).firstMatch(clean);

    if (prefixCurrency != null) {
      extractedAmount =
          double.tryParse(prefixCurrency.group(1)!.replaceAll(',', '.'));
    } else if (suffixCurrency != null) {
      extractedAmount =
          double.tryParse(suffixCurrency.group(1)!.replaceAll(',', '.'));
    } else {
      final anyNum = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(clean);
      if (anyNum != null) {
        extractedAmount = double.tryParse(anyNum.group(1)!);
      }
    }

    String? extractedMerchant;
    // في Google Wallet و Apple Pay غالباً يكون عنوان الإشعار (title) هو اسم المحل مباشرة
    if (notificationTitle != null &&
        notificationTitle.trim().isNotEmpty &&
        !notificationTitle.contains('₪') &&
        !notificationTitle.toLowerCase().contains('google') &&
        !notificationTitle.toLowerCase().contains('wallet') &&
        !notificationTitle.toLowerCase().contains('samsung')) {
      extractedMerchant = notificationTitle.trim();
    }

    if (extractedMerchant == null || extractedMerchant.isEmpty) {
      final hebrewMerchant = RegExp(
        r'(?:ב-?|ל-?)\s*([^\n\r.,]+?)(?:\s+בסך|\s+בתאריך|\s+בכרטיס|\s+עם|$)',
      );
      final mHeb = hebrewMerchant.firstMatch(clean);
      if (mHeb != null && mHeb.group(1) != null) {
        extractedMerchant = mHeb.group(1)!.trim();
      } else {
        final atMerchant = RegExp(
          r'(?:at|في|لدى|محل)\s+([^\n\r.,]+)',
          caseSensitive: false,
        ).firstMatch(clean);
        if (atMerchant != null) {
          extractedMerchant = atMerchant.group(1)!.trim();
        } else {
          // Strip out numbers, currencies, and common verbs to extract the merchant directly (e.g. "שופרסל דיל 120 ₪" or "55 שווארמה")
          final stripped = clean
              .replaceAll(RegExp(r'(?:₪|ש"ח|שח|ILS|NIS|شيكل|\$)', caseSensitive: false), ' ')
              .replaceAll(RegExp(r'\d+(?:[.,]\d{1,2})?'), ' ')
              .replaceAll(RegExp(r'[-–—•|_:,]+'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (stripped.length >= 2) {
            extractedMerchant = stripped;
          }
        }
      }
    }

    return (amount: extractedAmount, merchant: extractedMerchant);
  }
}
