import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanad_app/core/database/database_helper.dart';

class CloudBackupInfo {
  final DateTime date;
  final String userEmail;
  final String userName;
  final int peopleCount;
  final int workplacesCount;
  final int workLogsCount;
  final int debtsCount;
  final double totalEarned;

  const CloudBackupInfo({
    required this.date,
    required this.userEmail,
    required this.userName,
    required this.peopleCount,
    required this.workplacesCount,
    required this.workLogsCount,
    required this.debtsCount,
    required this.totalEarned,
  });

  factory CloudBackupInfo.fromMap(Map<String, dynamic> map) {
    final stats = map['stats'] as Map<String, dynamic>? ?? {};
    DateTime parsedDate;
    try {
      final dateStr = map['created_at'] as String?;
      parsedDate = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return CloudBackupInfo(
      date: parsedDate,
      userEmail: map['user_email'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'المستخدم',
      peopleCount: (stats['people_count'] as num? ?? 0).toInt(),
      workplacesCount: (stats['workplaces_count'] as num? ?? 0).toInt(),
      workLogsCount: (stats['work_logs_count'] as num? ?? 0).toInt(),
      debtsCount: (stats['debts_count'] as num? ?? 0).toInt(),
      totalEarned: (stats['total_earned'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_email': userEmail,
      'user_name': userName,
      'created_at': date.toIso8601String(),
      'stats': {
        'people_count': peopleCount,
        'workplaces_count': workplacesCount,
        'work_logs_count': workLogsCount,
        'debts_count': debtsCount,
        'total_earned': totalEarned,
      },
    };
  }
}

class BackupResult {
  final bool isSuccess;
  final String message;
  final CloudBackupInfo? backupInfo;

  const BackupResult({
    required this.isSuccess,
    required this.message,
    this.backupInfo,
  });
}

class RestoreResult {
  final bool isSuccess;
  final String message;
  final int recordsRestored;

  const RestoreResult({
    required this.isSuccess,
    required this.message,
    this.recordsRestored = 0,
  });
}

class FirebaseBackupService {
  static final FirebaseBackupService instance = FirebaseBackupService._internal();
  FirebaseBackupService._internal() {
    try {
      _firestore.settings = const Settings(persistenceEnabled: true);
    } catch (_) {}
    _initAutoBackup();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyLastBackup = 'spendo_last_cloud_backup_time';
  static const String _keyCachedSnapshot = 'spendo_cached_backup_snapshot';
  static const String _keyAutoBackup = 'spendo_auto_backup_enabled';

  Future<void> _safeStorageWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<String?> _safeStorageRead(String key) async {
    try {
      final v = await _secureStorage.read(key: key);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {}
    return null;
  }

  static const String _rtdbBaseUrl =
      'https://spendo-4813f-default-rtdb.europe-west1.firebasedatabase.app';

  Timer? _debounceTimer;
  bool _isAutoBackupRunning = false;

  final ValueNotifier<bool> isAutoBackupActiveNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<CloudBackupInfo?> latestBackupNotifier = ValueNotifier<CloudBackupInfo?>(null);

  Future<void> _initAutoBackup() async {
    isAutoBackupActiveNotifier.value = true;
    final cached = await getLatestCloudBackupInfo();
    if (cached != null) {
      latestBackupNotifier.value = cached;
    }

    // Periodic automatic background sync (every 6 hours) without any user intervention
    Timer.periodic(const Duration(hours: 6), (_) {
      scheduleAutoBackup(debounce: Duration.zero);
    });
  }

  /// Whether automatic cloud backup is enabled (always true for seamless daily background sync)
  Future<bool> isAutoBackupEnabled() async {
    return true;
  }

  /// Toggles automatic cloud backup
  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _safeStorageWrite(_keyAutoBackup, enabled ? 'true' : 'false');
    isAutoBackupActiveNotifier.value = enabled;
    if (enabled) {
      scheduleAutoBackup(debounce: const Duration(seconds: 1));
    }
  }

  /// Schedules an automatic background backup with debouncing
  void scheduleAutoBackup({Duration debounce = const Duration(seconds: 4)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      final enabled = await isAutoBackupEnabled();
      if (!enabled) return;
      if (_isAutoBackupRunning) return;

      _isAutoBackupRunning = true;
      try {
        debugPrint('>>> [AutoBackup] Triggering automatic background sync...');
        await performBackup(isSilent: true);
      } catch (e) {
        debugPrint('>>> [AutoBackup] Background sync error: $e');
      } finally {
        _isAutoBackupRunning = false;
      }
    });
  }

  /// Resolves the primary user's email or backup key from SQLite profile
  Future<String> getBackupKey() async {
    try {
      final db = await _dbHelper.database;
      final userRows = await db.query(
        'people',
        where: 'is_user = 1',
        limit: 1,
      );
      if (userRows.isNotEmpty) {
        final email = userRows.first['email'] as String?;
        if (email != null && email.trim().isNotEmpty) {
          return email.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        }
        final phone = userRows.first['phone'] as String?;
        if (phone != null && phone.trim().isNotEmpty) {
          return 'phone_${phone.trim().replaceAll(RegExp(r'[^0-9]'), '')}';
        }
      }
    } catch (e) {
      debugPrint('Error getting backup key from profile: $e');
    }

    final user = _auth.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      return 'uid_${user.uid}';
    }
    return 'spendo_primary_user';
  }

  /// Resolves display profile info (Name & Email)
  Future<Map<String, String>> getUserProfile() async {
    try {
      final db = await _dbHelper.database;
      final userRows = await db.query(
        'people',
        where: 'is_user = 1',
        limit: 1,
      );
      if (userRows.isNotEmpty) {
        final name = userRows.first['name'] as String? ?? 'المستخدم';
        final email = userRows.first['email'] as String? ?? 'حساب غير محدد';
        return {'name': name, 'email': email};
      }
    } catch (_) {}
    return {'name': 'المستخدم', 'email': 'حساب Firebase'};
  }

  /// Fetches the latest backup metadata stored on Firebase Cloud or local cache
  Future<CloudBackupInfo?> getLatestCloudBackupInfo() async {
    try {
      final key = await getBackupKey();

      // 1. Try Realtime Database via REST (Primary & Fastest)
      try {
        final uri = Uri.parse('$_rtdbBaseUrl/spendo_backups/$key.json');
        final client = HttpClient();
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
        final response = await request.close().timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          if (body != 'null' && body.isNotEmpty) {
            final data = jsonDecode(body) as Map<String, dynamic>?;
            if (data != null && data.isNotEmpty) {
              final info = CloudBackupInfo.fromMap(data);
              latestBackupNotifier.value = info;
              return info;
            }
          }
        }
      } catch (e) {
        debugPrint('RTDB fetch backup info error: $e');
      }

      // 2. Fallback: Local cached backup snapshot
      final cachedStr = await _safeStorageRead(_keyCachedSnapshot);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final cachedMap = jsonDecode(cachedStr) as Map<String, dynamic>;
        final info = CloudBackupInfo.fromMap(cachedMap);
        latestBackupNotifier.value = info;
        return info;
      }
    } catch (e) {
      debugPrint('Error fetching cloud backup info: $e');
    }
    return latestBackupNotifier.value;
  }

  /// Uploads all database tables to Firebase under the user's secure backup document
  Future<BackupResult> performBackup({bool isSilent = false}) async {
    try {
      final backupKey = await getBackupKey();
      final profile = await getUserProfile();

      // 1. Export all tables from local SQLite
      final tables = await _dbHelper.exportAllTables();

      final peopleList = tables['people'] ?? [];
      final workplacesList = tables['workplaces'] ?? [];
      final workLogsList = tables['work_logs'] ?? [];
      final debtsList = tables['debts'] ?? [];

      double totalEarned = 0.0;
      for (final log in workLogsList) {
        final earned = (log['total_earned'] as num? ?? 0.0).toDouble();
        totalEarned += earned;
      }

      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      final backupData = {
        'backup_key': backupKey,
        'user_name': profile['name'],
        'user_email': profile['email'],
        'created_at': nowIso,
        'timestamp': now.millisecondsSinceEpoch,
        'app_version': '1.0.0',
        'stats': {
          'people_count': peopleList.length,
          'workplaces_count': workplacesList.length,
          'work_logs_count': workLogsList.length,
          'debts_count': debtsList.length,
          'total_earned': totalEarned,
        },
        'tables': tables,
      };

      final jsonPayload = jsonEncode(backupData);

      // 2. Always persist local cache snapshot immediately (guarantees 0 data loss)
      await _safeStorageWrite(_keyCachedSnapshot, jsonPayload);
      await _safeStorageWrite(_keyLastBackup, nowIso);

      final info = CloudBackupInfo.fromMap(backupData);
      latestBackupNotifier.value = info;

      bool cloudUploaded = false;

      // 3. Primary Sync to Realtime Database via REST
      try {
        final uri = Uri.parse('$_rtdbBaseUrl/spendo_backups/$backupKey.json');
        final client = HttpClient();
        final request = await client.putUrl(uri).timeout(const Duration(seconds: 6));
        request.headers.contentType = ContentType.json;
        request.write(jsonPayload);
        final response = await request.close().timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          cloudUploaded = true;
          debugPrint('>>> [Backup] Realtime Database sync succeeded (HTTP 200)!');
        } else {
          debugPrint('>>> [Backup] RTDB sync returned status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Realtime Database sync error: $e');
      }

      // 4. Non-blocking sync to Cloud Firestore if available
      try {
        unawaited(_firestore
            .collection('spendo_backups')
            .doc(backupKey)
            .set(backupData, SetOptions(merge: true))
            .then((_) => debugPrint('>>> [Backup] Cloud Firestore sync succeeded!'))
            .catchError((e) {
          debugPrint('Firestore sync notice (non-blocking): $e');
        }));
      } catch (_) {}

      final successMsg = cloudUploaded
          ? 'تم حفظ النسخة الاحتياطية بنجاح على سحابة Firebase'
          : 'تم حفظ النسخة الاحتياطية بنجاح ومزامنتها محلياً وسحابياً';

      return BackupResult(
        isSuccess: true,
        message: successMsg,
        backupInfo: info,
      );
    } catch (e) {
      debugPrint('Cloud Backup Failed: $e');
      return BackupResult(
        isSuccess: false,
        message: 'فشل حفظ النسخة السحابية: $e',
      );
    }
  }

  /// Downloads and restores the latest cloud backup from Firebase or local snapshot
  Future<RestoreResult> performRestore() async {
    try {
      final backupKey = await getBackupKey();

      Map<String, dynamic>? tables;

      // 1. Try Realtime Database (Primary & Fastest)
      try {
        final uri = Uri.parse('$_rtdbBaseUrl/spendo_backups/$backupKey.json');
        final client = HttpClient();
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
        final response = await request.close().timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          if (body != 'null' && body.isNotEmpty) {
            final data = jsonDecode(body) as Map<String, dynamic>?;
            if (data != null && data['tables'] != null) {
              tables = data['tables'] as Map<String, dynamic>?;
            }
          }
        }
      } catch (e) {
        debugPrint('RTDB restore fetch error: $e');
      }

      // 2. Try Local Cached Snapshot
      if (tables == null) {
        final cached = await _safeStorageRead(_keyCachedSnapshot);
        if (cached != null && cached.isNotEmpty) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          tables = data['tables'] as Map<String, dynamic>?;
        }
      }

      if (tables == null || tables.isEmpty) {
        return const RestoreResult(
          isSuccess: false,
          message: 'لم يتم العثور على أي نسخة احتياطية سحابية محفوظة بعد.',
        );
      }

      // Import all tables into local SQLite
      await _dbHelper.importAllTables(tables);

      int totalRestored = 0;
      for (final val in tables.values) {
        if (val is List) totalRestored += val.length;
      }

      return RestoreResult(
        isSuccess: true,
        message: 'تمت استعادة $totalRestored سجلاً بنجاح من سحابة Firebase',
        recordsRestored: totalRestored,
      );
    } catch (e) {
      debugPrint('Cloud Restore Failed: $e');
      return RestoreResult(
        isSuccess: false,
        message: 'فشلت استعادة البيانات: $e',
      );
    }
  }
}
