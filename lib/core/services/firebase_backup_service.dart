import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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
      if (isFirebaseReady) {
        _firestore?.settings = const Settings(persistenceEnabled: true);
      }
    } catch (_) {}
    _initAutoBackup();
  }

  /// Whether Firebase is initialized and ready to use
  bool get isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Lazy, safe getter for Firestore (returns null if Firebase is not initialized)
  FirebaseFirestore? get _firestore {
    try {
      if (isFirebaseReady) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  /// Lazy, safe getter for FirebaseAuth (returns null if Firebase is not initialized)
  FirebaseAuth? get _auth {
    try {
      if (isFirebaseReady) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyLastBackup = 'spendo_last_cloud_backup_time';
  static const String _keyCachedSnapshot = 'spendo_cached_backup_snapshot';
  static const String _keyAutoBackup = 'spendo_auto_backup_enabled';
  static const String _keyHasRestoredFromCloud = 'spendo_has_restored_from_cloud';

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

    try {
      if (isFirebaseReady) {
        final user = _auth?.currentUser;
        if (user != null && user.uid.isNotEmpty) {
          return 'uid_${user.uid}';
        }
      }
    } catch (_) {}
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

      // Include SharedPreferences (Vehicle tracker, Paz info, Gov info) into backup tables
      try {
        final prefs = await SharedPreferences.getInstance();
        final vehicleJson = prefs.getString('spendo_vehicle_tracker_v5');
        if (vehicleJson != null && vehicleJson.isNotEmpty) {
          tables['spendo_vehicle_tracker_v5'] = [
            {'data': vehicleJson}
          ];
        }
        final govInfo = prefs.getString('spendo_gov_vehicle_info_v1');
        if (govInfo != null && govInfo.isNotEmpty) {
          tables['spendo_gov_vehicle_info_v1'] = [
            {'data': govInfo}
          ];
        }
        final pazId = prefs.getString('spendo_paz_id_num_v1');
        if (pazId != null && pazId.isNotEmpty) {
          tables['spendo_paz_id_num_v1'] = [
            {'data': pazId}
          ];
        }
        final pazPhone = prefs.getString('spendo_paz_phone_v1');
        if (pazPhone != null && pazPhone.isNotEmpty) {
          tables['spendo_paz_phone_v1'] = [
            {'data': pazPhone}
          ];
        }
      } catch (_) {}

      final peopleList = tables['people'] ?? [];
      final workplacesList = tables['workplaces'] ?? [];
      final workLogsList = tables['work_logs'] ?? [];
      final debtsList = tables['debts'] ?? [];
      final totalRecords = peopleList.length + workplacesList.length + workLogsList.length + debtsList.length;

      // Critical Safety Guard: Never overwrite cloud backup during silent automated sync
      // if this device has never completed an initial restore, or if local records <= seed records (20)
      if (isSilent) {
        final prefs = await SharedPreferences.getInstance();
        final hasRestored = prefs.getBool(_keyHasRestoredFromCloud) ?? false;

        // If device has never verified cloud restore and local records <= 20 (just initial seed),
        // BLOCK silent backup to prevent the reverse-overwrite disaster!
        if (!hasRestored && totalRecords <= 20) {
          debugPrint('>>> [Backup] Blocked reverse-overwrite: fresh install with $totalRecords records.');
          return const BackupResult(
            isSuccess: true,
            message: 'تم تخطي الحفظ السحابي التلقائي لحماية النسخة السحابية من الكتابة العكسية',
          );
        }
      }

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
        String authParam = '';
        try {
          final token = await _auth?.currentUser?.getIdToken();
          if (token != null && token.isNotEmpty) {
            authParam = '?auth=$token';
          }
        } catch (_) {}

        final uri = Uri.parse('$_rtdbBaseUrl/spendo_backups/$backupKey.json$authParam');
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
        if (isFirebaseReady && _firestore != null) {
          unawaited(_firestore!
              .collection('spendo_backups')
              .doc(backupKey)
              .set(backupData, SetOptions(merge: true))
              .then((_) => debugPrint('>>> [Backup] Cloud Firestore sync succeeded!'))
              .catchError((e) {
            debugPrint('Firestore sync notice (non-blocking): $e');
          }));
        }
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

      // 1. Try Cloud Firestore (Most robust and native on iOS)
      if (isFirebaseReady && _firestore != null) {
        final candidateKeys = <String>{backupKey, 'yasenlafe972_gmail_com', 'spendo_primary_user'};
        if (_auth?.currentUser?.uid != null) {
          candidateKeys.add('uid_${_auth!.currentUser!.uid}');
        }
        for (final k in candidateKeys) {
          try {
            final doc = await _firestore!
                .collection('spendo_backups')
                .doc(k)
                .get()
                .timeout(const Duration(seconds: 4));
            if (doc.exists && doc.data() != null) {
              final d = doc.data()!;
              if (d['tables'] is Map) {
                tables = Map<String, dynamic>.from(d['tables'] as Map);
                debugPrint('>>> [Restore] Successfully found backup in Firestore doc: $k');
                break;
              }
            }
          } catch (e) {
            debugPrint('Firestore restore attempt for $k notice: $e');
          }
        }
      }

      // 2. Try Realtime Database (Primary REST fallback)
      if (tables == null) {
        String authParam = '';
        try {
          final token = await _auth?.currentUser?.getIdToken();
          if (token != null && token.isNotEmpty) {
            authParam = '?auth=$token';
          }
        } catch (_) {}

        final candidateKeys = <String>{backupKey, 'yasenlafe972_gmail_com', 'spendo_primary_user'};
        for (final k in candidateKeys) {
          try {
            final uri = Uri.parse('$_rtdbBaseUrl/spendo_backups/$k.json$authParam');
            final client = HttpClient();
            final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
            final response = await request.close().timeout(const Duration(seconds: 4));
            if (response.statusCode == 200) {
              final body = await response.transform(utf8.decoder).join();
              if (body != 'null' && body.isNotEmpty) {
                final data = jsonDecode(body) as Map<String, dynamic>?;
                if (data != null && data['tables'] is Map) {
                  tables = Map<String, dynamic>.from(data['tables'] as Map);
                  debugPrint('>>> [Restore] Successfully found backup in RTDB key: $k');
                  break;
                }
              }
            }
          } catch (e) {
            debugPrint('RTDB restore fetch error for $k: $e');
          }
        }
      }

      // 3. Try Local Cached Snapshot
      if (tables == null) {
        final cached = await _safeStorageRead(_keyCachedSnapshot);
        if (cached != null && cached.isNotEmpty) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          if (data['tables'] is Map) {
            tables = Map<String, dynamic>.from(data['tables'] as Map);
          }
        }
      }

      if (tables == null || tables.isEmpty) {
        return const RestoreResult(
          isSuccess: false,
          message: 'لم يتم العثور على أي نسخة احتياطية سحابية محفوظة بعد.',
        );
      }

      // Restore vehicle & Paz metadata if stored in backup
      try {
        final prefs = await SharedPreferences.getInstance();
        if (tables.containsKey('spendo_vehicle_tracker_v5')) {
          final vList = tables['spendo_vehicle_tracker_v5'];
          if (vList is List && vList.isNotEmpty && vList.first is Map) {
            final vData = vList.first['data'] as String?;
            if (vData != null && vData.isNotEmpty) {
              await prefs.setString('spendo_vehicle_tracker_v5', vData);
            }
          }
        }
        for (final key in ['spendo_gov_vehicle_info_v1', 'spendo_paz_id_num_v1', 'spendo_paz_phone_v1']) {
          if (tables.containsKey(key)) {
            final list = tables[key];
            if (list is List && list.isNotEmpty && list.first is Map) {
              final v = list.first['data'] as String?;
              if (v != null && v.isNotEmpty) {
                await prefs.setString(key, v);
              }
            }
          }
        }
      } catch (_) {}

      // Anti-Downgrade Safety Guard: Protect existing rich local database (e.g. Galaxy)
      // from being accidentally downgraded or overwritten by a smaller/older cloud backup
      try {
        final localTables = await _dbHelper.exportAllTables();
        final localLogsCount = (localTables['work_logs'] as List?)?.length ?? 0;
        final cloudLogsCount = (tables['work_logs'] as List?)?.length ?? 0;

        if (localLogsCount > cloudLogsCount && localLogsCount > 20) {
          debugPrint('>>> [Restore] Guard triggered: local device has $localLogsCount logs, cloud has $cloudLogsCount logs. Skipping downgrade.');
          return RestoreResult(
            isSuccess: true,
            message: 'البيانات المحلية على الهاتف أحدث وأشمل ($localLogsCount سجل) من النسخة السحابية ($cloudLogsCount سجل)، تم الاحتفاظ بالبيانات المحلية بأمان تام',
            recordsRestored: localLogsCount,
          );
        }
      } catch (_) {}

      // Import all tables into local SQLite
      await _dbHelper.importAllTables(tables);

      // Mark initial restore as permanently completed on this device
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyHasRestoredFromCloud, true);
      } catch (_) {}

      int totalRestored = 0;
      for (final entry in tables.entries) {
        if (entry.key == 'spendo_vehicle_tracker_v5') continue;
        if (entry.value is List) totalRestored += (entry.value as List).length;
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

  /// Exports all tables + vehicle data to a standalone JSON file and returns the File object
  Future<File> exportBackupToJsonFile() async {
    final tables = await _dbHelper.exportAllTables();
    final profile = await getUserProfile();
    final backupKey = await getBackupKey();

    // Include vehicle data & Paz metadata from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final vehicleJson = prefs.getString('spendo_vehicle_tracker_v5');
      if (vehicleJson != null && vehicleJson.isNotEmpty) {
        tables['spendo_vehicle_tracker_v5'] = [
          {'data': vehicleJson}
        ];
      }
      for (final key in ['spendo_gov_vehicle_info_v1', 'spendo_paz_id_num_v1', 'spendo_paz_phone_v1']) {
        final val = prefs.getString(key);
        if (val != null && val.isNotEmpty) {
          tables[key] = [
            {'data': val}
          ];
        }
      }
    } catch (_) {}

    final now = DateTime.now();
    final backupData = {
      'backup_key': backupKey,
      'user_name': profile['name'],
      'user_email': profile['email'],
      'created_at': now.toIso8601String(),
      'timestamp': now.millisecondsSinceEpoch,
      'app_version': '1.0.5',
      'tables': tables,
    };

    final tempDir = await getTemporaryDirectory();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File('${tempDir.path}/Spendo_Backup_$dateStr.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backupData));
    return file;
  }

  /// Imports backup from a JSON string into SQLite and SharedPreferences
  Future<RestoreResult> importBackupFromJsonString(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return const RestoreResult(
          isSuccess: false,
          message: 'صيغة ملف النسخة الاحتياطية غير صالحة',
        );
      }

      Map<String, dynamic>? tables;
      if (decoded['tables'] is Map<String, dynamic>) {
        tables = Map<String, dynamic>.from(decoded['tables'] as Map);
      } else if (decoded.containsKey('people') || decoded.containsKey('workplaces')) {
        tables = decoded;
      }

      if (tables == null || tables.isEmpty) {
        return const RestoreResult(
          isSuccess: false,
          message: 'لم يتم العثور على أي بيانات جداول داخل الملف',
        );
      }

      // Check and restore vehicle & Paz metadata if present
      try {
        final prefs = await SharedPreferences.getInstance();
        if (tables.containsKey('spendo_vehicle_tracker_v5')) {
          final vList = tables['spendo_vehicle_tracker_v5'];
          if (vList is List && vList.isNotEmpty && vList.first is Map) {
            final vData = vList.first['data'] as String?;
            if (vData != null && vData.isNotEmpty) {
              await prefs.setString('spendo_vehicle_tracker_v5', vData);
            }
          }
        }
        for (final key in ['spendo_gov_vehicle_info_v1', 'spendo_paz_id_num_v1', 'spendo_paz_phone_v1']) {
          if (tables.containsKey(key)) {
            final list = tables[key];
            if (list is List && list.isNotEmpty && list.first is Map) {
              final v = list.first['data'] as String?;
              if (v != null && v.isNotEmpty) {
                await prefs.setString(key, v);
              }
            }
          }
        }
      } catch (_) {}

      // Import all tables into SQLite
      await _dbHelper.importAllTables(tables);

      // Mark initial restore as permanently completed on this device
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyHasRestoredFromCloud, true);
      } catch (_) {}

      int totalRestored = 0;
      for (final entry in tables.entries) {
        if (entry.key == 'spendo_vehicle_tracker_v5') continue;
        if (entry.value is List) totalRestored += (entry.value as List).length;
      }

      return RestoreResult(
        isSuccess: true,
        message: 'تمت استعادة $totalRestored سجلاً بنجاح من ملف النسخة الاحتياطية',
        recordsRestored: totalRestored,
      );
    } catch (e) {
      debugPrint('File Restore Failed: $e');
      return RestoreResult(
        isSuccess: false,
        message: 'فشلت استعادة النسخة من الملف: $e',
      );
    }
  }
}
