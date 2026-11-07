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

  Future<void> addWorkLog(WorkLogModel log) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('work_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      if (log.rateApplied > 0) {
        final wpId = (log.workplaceId ?? '').trim();
        final wpName = log.workplaceName.trim();
        final nowIso = DateTime.now().toIso8601String();

        if (wpId.isNotEmpty) {
          await txn.update(
            'workplaces',
            {
              'daily_rate': log.rateApplied,
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
              'daily_rate': log.rateApplied,
              'updated_at': nowIso,
            },
            where: 'TRIM(name) = ?',
            whereArgs: [wpName],
          );
        }

        if (wpId.isNotEmpty || wpName.isNotEmpty) {
          await txn.rawUpdate(
            '''
            UPDATE work_logs
            SET rate_applied = ?,
                total_earned = ? * COALESCE(day_fraction, 1.0),
                workplace_id = CASE WHEN (workplace_id IS NULL OR workplace_id = '') AND ? != '' THEN ? ELSE workplace_id END
            WHERE (? != '' AND workplace_id = ?)
               OR (? != '' AND TRIM(workplace_name) = ?)
            ''',
            [
              log.rateApplied,
              log.rateApplied,
              wpId,
              wpId,
              wpId,
              wpId,
              wpName,
              wpName,
            ],
          );
        }
      }
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  Future<void> updateWorkLog(WorkLogModel log) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'work_logs',
        log.toMap(),
        where: 'id = ?',
        whereArgs: [log.id],
      );

      if (log.rateApplied > 0) {
        final wpId = (log.workplaceId ?? '').trim();
        final wpName = log.workplaceName.trim();
        final nowIso = DateTime.now().toIso8601String();

        if (wpId.isNotEmpty) {
          await txn.update(
            'workplaces',
            {
              'daily_rate': log.rateApplied,
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
              'daily_rate': log.rateApplied,
              'updated_at': nowIso,
            },
            where: 'TRIM(name) = ?',
            whereArgs: [wpName],
          );
        }

        if (wpId.isNotEmpty || wpName.isNotEmpty) {
          await txn.rawUpdate(
            '''
            UPDATE work_logs
            SET rate_applied = ?,
                total_earned = ? * COALESCE(day_fraction, 1.0),
                workplace_id = CASE WHEN (workplace_id IS NULL OR workplace_id = '') AND ? != '' THEN ? ELSE workplace_id END
            WHERE (? != '' AND workplace_id = ?)
               OR (? != '' AND TRIM(workplace_name) = ?)
            ''',
            [
              log.rateApplied,
              log.rateApplied,
              wpId,
              wpId,
              wpId,
              wpId,
              wpName,
              wpName,
            ],
          );
        }
      }
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
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
