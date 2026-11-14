import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/deletion_sync_service.dart';
import '../../../core/services/firebase_backup_service.dart';
import '../models/work_log_model.dart';

class WorkLogsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<WorkLogModel>> getAllLogs() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_logs',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => WorkLogModel.fromMap(map)).toList();
  }

  Future<List<WorkLogModel>> getLogsForPerson(String personId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_logs',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => WorkLogModel.fromMap(map)).toList();
  }

  Future<List<WorkLogModel>> getLogsForWorkplace(String workplaceId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_logs',
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => WorkLogModel.fromMap(map)).toList();
  }

  Future<List<WorkLogModel>> getLogsForWorkplaceOrName(String workplaceId, [String? workplaceName]) async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> maps;
    if (workplaceName != null && workplaceName.trim().isNotEmpty) {
      maps = await db.query(
        'work_logs',
        where: 'workplace_id = ? OR LOWER(TRIM(workplace_name)) = LOWER(TRIM(?))',
        whereArgs: [workplaceId, workplaceName.trim()],
        orderBy: 'date DESC, created_at DESC',
      );
    } else {
      maps = await db.query(
        'work_logs',
        where: 'workplace_id = ?',
        whereArgs: [workplaceId],
        orderBy: 'date DESC, created_at DESC',
      );
    }
    return maps.map((map) => WorkLogModel.fromMap(map)).toList();
  }

  Future<List<String>> getDistinctCities() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT city 
      FROM work_logs 
      WHERE city IS NOT NULL AND TRIM(city) != '' 
      ORDER BY city ASC 
      LIMIT 40
    ''');
    return maps.map((m) => (m['city'] as String).trim()).where((c) => c.isNotEmpty).toList();
  }

  Future<List<WorkLogModel>> getLogsForEmployer(String employerId) =>
      getLogsForWorkplace(employerId);

  Future<void> addWorkLog(WorkLogModel log, {bool cascadeRate = false}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    await db.transaction((txn) async {
      final wpId = (log.workplaceId ?? '').trim();
      final wpName = log.workplaceName.trim();

      double effectiveRate = log.rateApplied;
      if (!cascadeRate && (wpId.isNotEmpty || wpName.isNotEmpty)) {
        final wpRows = await txn.query(
          'workplaces',
          columns: ['daily_rate'],
          where: wpId.isNotEmpty ? 'id = ?' : 'TRIM(name) = ?',
          whereArgs: [wpId.isNotEmpty ? wpId : wpName],
          limit: 1,
        );
        if (wpRows.isNotEmpty) {
          final wpRate = (wpRows.first['daily_rate'] as num? ?? 0.0).toDouble();
          if (wpRate > 0) {
            effectiveRate = wpRate;
          }
        }
      }

      final logToSave = log.copyWith(
        rateApplied: effectiveRate,
        totalEarned: effectiveRate * log.dayFraction,
        updatedAt: now,
      );

      await txn.insert(
        'work_logs',
        logToSave.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (effectiveRate > 0 && (wpId.isNotEmpty || wpName.isNotEmpty)) {
        if (wpId.isNotEmpty) {
          await txn.update(
            'workplaces',
            {
              'daily_rate': effectiveRate,
              'updated_at': nowIso,
            },
            where: 'id = ?',
            whereArgs: [wpId],
          );
        }
        if (wpName.isNotEmpty) {
          await txn.update(
            'workplaces',
            {
              'daily_rate': effectiveRate,
              'updated_at': nowIso,
            },
            where: 'TRIM(name) = ?',
            whereArgs: [wpName],
          );
        }

        await txn.rawUpdate(
          '''
          UPDATE work_logs
          SET rate_applied = ?,
              total_earned = ? * COALESCE(day_fraction, 1.0),
              updated_at = ?,
              workplace_id = CASE WHEN (workplace_id IS NULL OR workplace_id = '') AND ? != '' THEN ? ELSE workplace_id END
          WHERE (? != '' AND workplace_id = ?)
             OR (? != '' AND TRIM(workplace_name) = ?)
          ''',
          [
            effectiveRate,
            effectiveRate,
            nowIso,
            wpId,
            wpId,
            wpId,
            wpId,
            wpName,
            wpName,
          ],
        );
      }
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  Future<void> updateWorkLog(WorkLogModel log, {bool cascadeRate = false}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    await db.transaction((txn) async {
      final wpId = (log.workplaceId ?? '').trim();
      final wpName = log.workplaceName.trim();

      double effectiveRate = log.rateApplied;
      if (!cascadeRate && (wpId.isNotEmpty || wpName.isNotEmpty)) {
        final wpRows = await txn.query(
          'workplaces',
          columns: ['daily_rate'],
          where: wpId.isNotEmpty ? 'id = ?' : 'TRIM(name) = ?',
          whereArgs: [wpId.isNotEmpty ? wpId : wpName],
          limit: 1,
        );
        if (wpRows.isNotEmpty) {
          final wpRate = (wpRows.first['daily_rate'] as num? ?? 0.0).toDouble();
          if (wpRate > 0) {
            effectiveRate = wpRate;
          }
        }
      }

      final logToSave = log.copyWith(
        rateApplied: effectiveRate,
        totalEarned: effectiveRate * log.dayFraction,
        updatedAt: now,
      );

      await txn.update(
        'work_logs',
        logToSave.toMap(),
        where: 'id = ?',
        whereArgs: [log.id],
      );

      if (effectiveRate > 0 && (wpId.isNotEmpty || wpName.isNotEmpty)) {
        if (wpId.isNotEmpty) {
          await txn.update(
            'workplaces',
            {
              'daily_rate': effectiveRate,
              'updated_at': nowIso,
            },
            where: 'id = ?',
            whereArgs: [wpId],
          );
        }
        if (wpName.isNotEmpty) {
          await txn.update(
            'workplaces',
            {
              'daily_rate': effectiveRate,
              'updated_at': nowIso,
            },
            where: 'TRIM(name) = ?',
            whereArgs: [wpName],
          );
        }

        await txn.rawUpdate(
          '''
          UPDATE work_logs
          SET rate_applied = ?,
              total_earned = ? * COALESCE(day_fraction, 1.0),
              updated_at = ?,
              workplace_id = CASE WHEN (workplace_id IS NULL OR workplace_id = '') AND ? != '' THEN ? ELSE workplace_id END
          WHERE (? != '' AND workplace_id = ?)
             OR (? != '' AND TRIM(workplace_name) = ?)
          ''',
          [
            effectiveRate,
            effectiveRate,
            nowIso,
            wpId,
            wpId,
            wpId,
            wpId,
            wpName,
            wpName,
          ],
        );
      }
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  Future<void> updateWorkLogAmountCollected(String id, double amountCollected) async {
    final db = await _dbHelper.database;
    await db.update(
      'work_logs',
      {'amount_collected': amountCollected},
      where: 'id = ?',
      whereArgs: [id],
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  Future<void> deleteWorkLog(String id) async {
    final db = await _dbHelper.database;
    await db.delete('work_logs', where: 'id = ?', whereArgs: [id]);
    await DeletionSyncService.recordDeletion('work_logs', id);
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }
}
