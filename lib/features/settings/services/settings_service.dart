import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to manage and persist Spendo application settings.
class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  static const String _keyCurrency = 'spendo_currency';
  static const String _keyHaptics = 'spendo_haptics_enabled';
  static const String _keyAutoLock = 'spendo_auto_lock_enabled';
  static const String _keyDailyReminder = 'spendo_daily_reminder_enabled';
  static const String _keyDailyReminderTime = 'spendo_daily_reminder_time';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _safePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Default currency symbol (defaults to ₪)
  Future<String> getCurrency() async {
    final prefs = await _safePrefs;
    return prefs.getString(_keyCurrency) ?? '₪';
  }

  Future<void> setCurrency(String currency) async {
    final prefs = await _safePrefs;
    await prefs.setString(_keyCurrency, currency);
  }

  /// Whether tactile haptic feedback is globally enabled
  Future<bool> isHapticsEnabled() async {
    final prefs = await _safePrefs;
    return prefs.getBool(_keyHaptics) ?? true;
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await _safePrefs;
    await prefs.setBool(_keyHaptics, enabled);
  }

  /// Whether auto-lock is enabled
  Future<bool> isAutoLockEnabled() async {
    final prefs = await _safePrefs;
    return prefs.getBool(_keyAutoLock) ?? false;
  }

  Future<void> setAutoLockEnabled(bool enabled) async {
    final prefs = await _safePrefs;
    await prefs.setBool(_keyAutoLock, enabled);
  }

  /// Whether daily evening work log reminder is enabled
  Future<bool> isDailyReminderEnabled() async {
    final prefs = await _safePrefs;
    return prefs.getBool(_keyDailyReminder) ?? false;
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    final prefs = await _safePrefs;
    await prefs.setBool(_keyDailyReminder, enabled);
  }

  /// The daily reminder time string (e.g. "17:00")
  Future<String> getDailyReminderTime() async {
    final prefs = await _safePrefs;
    return prefs.getString(_keyDailyReminderTime) ?? '17:00';
  }

  Future<void> setDailyReminderTime(String time) async {
    final prefs = await _safePrefs;
    await prefs.setString(_keyDailyReminderTime, time);
  }
}
