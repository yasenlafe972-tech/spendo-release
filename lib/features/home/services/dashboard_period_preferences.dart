import 'package:shared_preferences/shared_preferences.dart';

/// This device's last dashboard period; data refreshes never change it.
class DashboardPeriodPreferences {
  static const storageKey = 'spendo_dashboard_period_v1';

  static bool isValid(String value) =>
      value == 'all' || RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value);

  static Future<String> load({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);
    if (saved != null && isValid(saved)) return saved;
    final date = now ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static Future<void> save(String value) async {
    if (!isValid(value)) throw ArgumentError.value(value, 'value', 'Invalid period');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }
}
