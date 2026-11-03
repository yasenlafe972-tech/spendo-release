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

  /// عنوان Webhook السحابي لاستقبال دفعات Apple Pay / כאל في الخلفية بدون فتح التطبيق
  static const String cloudWebhookUrl =
      'https://spendo-4813f-default-rtdb.europe-west1.firebasedatabase.app/auto_expenses_inbox.json';

  /// عنوان الرابط المباشر للـ Shortcuts في الآيفون والأندرويد (يقبل كل كروت Apple Pay بدون تحديد كرت)
  static const String shortcutDeepLinkTemplate =
      'spendo://pay?amount={Amount}&merchant={Merchant}';

  static bool _listenerInitialized = false;
  static final ValueNotifier<int> expensesChangedNotifier = ValueNotifier<int>(0);

  /// تهيئة الاستماع التلقائي للروابط (`spendo://pay`) والمزامنة السحابية للدفعات التلقائية
  static Future<void> initAutoSyncListener() async {
    if (_listenerInitialized) return;
    _listenerInitialized = true;

    // 1. الاستماع للروابط القادمة أثناء عمل التطبيق
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments as String?;
        if (link != null && link.isNotEmpty) {
          await handleIncomingShortcutUri(link);
        }
      }
    });

    // 2. فحص إذا تم فتح التطبيق عبر شورتكات Apple Pay
    try {
      final initialLink =
          await _deepLinkChannel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        await handleIncomingShortcutUri(initialLink);
      }
    } catch (_) {}

    // 3. سحب أي دفعات أرسلها شورتكات الآيفون للسحابة بالخلفية
    await pullCloudAutoExpenses();
  }

  /// معالجة الرابط القادم من Apple Pay Shortcut تلقائياً بدون أي تدخل يدوي
  /// يقبل: spendo://pay?amount=45&merchant=BBB أو spendo://pay?text=...
  static Future<bool> handleIncomingShortcutUri(String rawUri) async {
    try {
      final uri = Uri.parse(rawUri);
      final params = uri.queryParameters;

      double? amount;
      String? merchant;
      String source = params['source'] ?? 'apple_pay';

      if (params.containsKey('text') && params['text']!.trim().isNotEmpty) {
        final parsed = parsePaymentNotification(params['text']!);
        amount = parsed.amount;
        merchant = parsed.merchant;
      }

      if (params.containsKey('amount')) {
        final rawAmt =
            params['amount']!.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        amount = double.tryParse(rawAmt) ?? amount;
      }

      if (params.containsKey('merchant') && params['merchant']!.trim().isNotEmpty) {
        merchant = params['merchant']!.trim();
      } else if (params.containsKey('name') && params['name']!.trim().isNotEmpty) {
        merchant = params['name']!.trim();
      }

      if (amount != null && amount > 0) {
        await addExpense(
          merchantName: (merchant != null && merchant.isNotEmpty)
              ? merchant
              : 'دفعة Apple Pay',
          amount: amount,
          source: source,
        );
        expensesChangedNotifier.value++;
        return true;
      }
    } catch (e) {
      debugPrint('Error parsing shortcut URI: $e');
    }
    return false;
  }

  /// سحب الدفعات المرسلة تلقائياً في الخلفية عبر iOS Shortcuts إلى Firebase مع إغلاق المقابس بأمان
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
          if (val['merchant'] != null && val['merchant'].toString().trim().isNotEmpty) {
            merchant = val['merchant'].toString().trim();
          }

          if (amount != null && amount > 0) {
            await addExpense(
              merchantName: (merchant != null && merchant.isNotEmpty)
                  ? merchant
                  : 'دفعة Apple Pay',
              amount: amount,
              source: source,
            );
            importedCount++;
          }
        }
      }

      if (importedCount > 0) {
        // مسح صندوق الوارد السحابي بعد استيراده محلياً لمنع التكرار
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

  /// جلب كافة المصاريف اليومية ودفعات Apple Pay / כאל
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
        final key = '${e.date.year}_${e.date.month}_${e.date.day}_${e.date.hour}_${e.date.minute}_${e.amount.toStringAsFixed(2)}_${e.merchantName.trim()}';
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

  /// حفظ قائمة المصاريف
  static Future<void> saveAllExpenses(List<DailyExpenseModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_expensesKey, encoded);
  }

  /// إضافة دفعة جديدة مع التعرف الذكي على الصنف حسب اسم المحل
  static Future<DailyExpenseModel> addExpense({
    required String merchantName,
    required double amount,
    String? explicitCategory,
    String source = 'apple_pay',
    DateTime? date,
    String? notes,
  }) async {
    final cleanMerchant = merchantName.trim();
    final targetDate = date ?? DateTime.now();

    final current = await getAllExpenses();
    final existingIdx = current.indexWhere((e) =>
        e.amount == amount &&
        e.date.year == targetDate.year &&
        e.date.month == targetDate.month &&
        e.date.day == targetDate.day &&
        e.date.hour == targetDate.hour &&
        e.date.minute == targetDate.minute);
    if (existingIdx != -1) {
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
    );

    current.insert(0, newItem);
    await saveAllExpenses(current);

    if (explicitCategory != null && cleanMerchant.isNotEmpty) {
      await rememberMerchantCategory(cleanMerchant, explicitCategory);
    }

    return newItem;
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

  /// حفظ صنف محل في الذاكرة ليُصنّف تلقائياً في المرات القادمة
  static Future<void> rememberMerchantCategory(
      String merchantName, String category) async {
    final norm = merchantName.trim().toLowerCase();
    if (norm.isEmpty) return;
    final map = await getMerchantCategoryMap();
    map[norm] = category;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_merchantMapKey, jsonEncode(map));
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

  /// محلل ذكي لنص إشعار כאל (Cal) أو Apple Pay
  static ({double? amount, String? merchant}) parsePaymentNotification(
      String text) {
    final clean = text.trim();
    if (clean.isEmpty) return (amount: null, merchant: null);

    double? extractedAmount;
    final amountRegex = RegExp(
        r'(\d+(?:[.,]\d{1,2})?)\s*(?:ש"ח|שח|₪|ILS|شيكل)',
        caseSensitive: false);
    final match = amountRegex.firstMatch(clean);
    if (match != null) {
      extractedAmount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    } else {
      final anyNum = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(clean);
      if (anyNum != null) {
        extractedAmount = double.tryParse(anyNum.group(1)!);
      }
    }

    String? extractedMerchant;
    final hebrewMerchant =
        RegExp(r'ב-?\s*([^\n\r.,]+?)(?:\s+בسך|\s+בתאריך|\s+בכרטיס|$)');
    final mHeb = hebrewMerchant.firstMatch(clean);
    if (mHeb != null && mHeb.group(1) != null) {
      extractedMerchant = mHeb.group(1)!.trim();
    } else {
      final atMerchant =
          RegExp(r'(?:at|في|لدى|محل)\s+([^\n\r.,]+)', caseSensitive: false)
              .firstMatch(clean);
      if (atMerchant != null) {
        extractedMerchant = atMerchant.group(1)!.trim();
      }
    }

    return (amount: extractedAmount, merchant: extractedMerchant);
  }
}
