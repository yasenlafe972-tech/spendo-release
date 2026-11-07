import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/services/firebase_backup_service.dart';

/// Centralized service to record, persist, and synchronize deletions across devices.
/// Implements distributed tombstones so that when an entity is deleted on Device A (Galaxy),
/// it is permanently deleted on Device B (iPhone) and NEVER resurrected by additive sync.
class DeletionSyncService {
  static const String prefKey = 'spendo_deleted_records_v1';
  static final Set<String> _deletedKeys = <String>{};
  static List<Map<String, dynamic>> _records = [];
  static bool _initialized = false;

  DeletionSyncService._();

  static String _makeKey(String table, String id) => '${table.trim().toLowerCase()}:${id.trim()}';

  /// Initializes the local deletion tombstone set from SharedPreferences
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _records = decoded.cast<Map<String, dynamic>>();
          for (final r in _records) {
            final table = r['table']?.toString() ?? '';
            final id = r['id']?.toString() ?? '';
            if (table.isNotEmpty && id.isNotEmpty) {
              _deletedKeys.add(_makeKey(table, id));
            }
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing DeletionSyncService: $e');
    }
  }

  /// Checks if a record in a given table has been marked as deleted
  static bool isDeleted(String table, String id) {
    if (id.isEmpty) return false;
    return _deletedKeys.contains(_makeKey(table, id));
  }

  /// Records a deletion event, purges local references, and triggers an auto-backup
  static Future<void> recordDeletion(
    String table,
    String id, {
    bool scheduleBackup = true,
  }) async {
    await init();
    final cleanTable = table.trim();
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;

    final key = _makeKey(cleanTable, cleanId);
    if (!_deletedKeys.contains(key)) {
      _deletedKeys.add(key);
      _records.add({
        'table': cleanTable,
        'id': cleanId,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Keep tombstones bounded to latest 2000 records to prevent infinite growth
      if (_records.length > 2000) {
        _records.sort((a, b) =>
            ((b['deleted_at'] as num?) ?? 0).compareTo((a['deleted_at'] as num?) ?? 0));
        _records = _records.sublist(0, 2000);
        _deletedKeys.clear();
        for (final r in _records) {
          _deletedKeys.add(_makeKey(r['table'].toString(), r['id'].toString()));
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, jsonEncode(_records));
      } catch (_) {}
    }

    // Schedule immediate debounced cloud sync so the deletion is propagated to Firebase
    if (scheduleBackup) {
      FirebaseBackupService.instance.scheduleAutoBackup(
        debounce: const Duration(milliseconds: 500),
      );
    }
  }

  /// Returns the current list of deleted records for inclusion in cloud backups
  static Future<List<Map<String, dynamic>>> getExportableDeletedRecords() async {
    await init();
    return List<Map<String, dynamic>>.from(_records);
  }

  /// Applies deleted tombstones received from cloud backup and purges local storage
  static Future<int> applyCloudDeletedRecords(dynamic rawCloudData) async {
    await init();
    if (rawCloudData == null) return 0;

    List<dynamic> cloudList = [];
    if (rawCloudData is List) {
      cloudList = rawCloudData;
    } else if (rawCloudData is String) {
      try {
        final dec = jsonDecode(rawCloudData);
        if (dec is List) cloudList = dec;
      } catch (_) {}
    } else if (rawCloudData is Map) {
      if (rawCloudData.containsKey('data')) {
        return applyCloudDeletedRecords(rawCloudData['data']);
      }
      cloudList = rawCloudData.values.toList();
    }

    if (cloudList.isEmpty) return 0;

    int newTombstonesCount = 0;
    for (final item in cloudList) {
      if (item is! Map) continue;
      final table = item['table']?.toString() ?? '';
      final id = item['id']?.toString() ?? '';
      final ts = (item['deleted_at'] as num?)?.toInt() ?? 0;
      if (table.isEmpty || id.isEmpty) continue;

      final key = _makeKey(table, id);
      if (!_deletedKeys.contains(key)) {
        _deletedKeys.add(key);
        _records.add({
          'table': table,
          'id': id,
          'deleted_at': ts > 0 ? ts : DateTime.now().millisecondsSinceEpoch,
        });
        newTombstonesCount++;
      }
    }

    if (newTombstonesCount > 0) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, jsonEncode(_records));
      } catch (_) {}
    }

    // Purge local SQLite database of any records that are marked as deleted
    await purgeDeletedRowsFromDatabase();

    return newTombstonesCount;
  }

  /// Executes batch DELETE in local SQLite for all tombstoned records
  static Future<void> purgeDeletedRowsFromDatabase([DatabaseExecutor? executor]) async {
    await init();
    if (_deletedKeys.isEmpty) return;

    final db = executor ?? await DatabaseHelper.instance.database;

    // Group deleted IDs by table name
    final map = <String, List<String>>{};
    for (final r in _records) {
      final table = r['table']?.toString();
      final id = r['id']?.toString();
      if (table != null && id != null && table.isNotEmpty && id.isNotEmpty) {
        map.putIfAbsent(table, () => []).add(id);
      }
    }

    const sqliteTables = {
      'workplaces',
      'work_logs',
      'people',
      'person_accounts',
      'debts',
      'debt_payments',
      'workplace_payments',
      'payments',
      'vault_items',
    };

    for (final entry in map.entries) {
      final table = entry.key;
      if (!sqliteTables.contains(table)) continue;
      final ids = entry.value;
      if (ids.isEmpty) continue;

      // Execute in chunks of 100 to stay within SQLite variable limits
      for (var i = 0; i < ids.length; i += 100) {
        final chunk = ids.sublist(i, (i + 100 > ids.length) ? ids.length : i + 100);
        final placeholders = List.filled(chunk.length, '?').join(',');
        try {
          await db.delete(
            table,
            where: 'id IN ($placeholders)',
            whereArgs: chunk,
          );
        } catch (e) {
          debugPrint('Error purging deleted rows from $table: $e');
        }
      }
    }
  }
}
