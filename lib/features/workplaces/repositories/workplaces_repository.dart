import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/deletion_sync_service.dart';
import '../../../core/services/firebase_backup_service.dart';
import '../../work_logs/models/work_log_model.dart';
import '../models/workplace_model.dart';
import '../models/employer_stats.dart';

export '../models/employer_stats.dart';

class WorkplacesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Fetches all workplaces/employers, optionally filtering for only active ones
  Future<List<WorkplaceModel>> getAllWorkplaces({bool onlyActive = false}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps;
    if (onlyActive) {
      maps = await db.query(
        'workplaces',
        where: 'status = ?',
        whereArgs: ['active'],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'workplaces',
        orderBy: 'status ASC, created_at DESC',
      );
    }
    return maps.map((map) => WorkplaceModel.fromMap(map)).toList();
  }

  /// Fetches a single workplace by its ID
  Future<WorkplaceModel?> getWorkplaceById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workplaces',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WorkplaceModel.fromMap(maps.first);
  }

  /// Inserts a new workplace/employer
  Future<void> addWorkplace(WorkplaceModel workplace) async {
    final db = await _dbHelper.database;
    await db.insert(
      'workplaces',
      workplace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Updates an existing workplace/employer and cascades its dailyRate and name
  /// to all work_logs belonging to this employer.
  Future<void> updateWorkplace(WorkplaceModel workplace) async {
    final db = await _dbHelper.database;
    final workplaceToSave = workplace.copyWith(
      updatedAt: DateTime.now(),
    );
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'workplaces',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [workplace.id],
        limit: 1,
      );
      final oldName = existingRows.isNotEmpty
          ? (existingRows.first['name']?.toString().trim() ?? '')
          : '';
      final newName = workplace.name.trim();

      await txn.update(
        'workplaces',
        workplaceToSave.toMap(),
        where: 'id = ?',
        whereArgs: [workplace.id],
      );

      if (workplace.dailyRate > 0) {
        await txn.rawUpdate(
          '''
          UPDATE work_logs
          SET workplace_id = ?,
              workplace_name = ?,
              rate_applied = ?,
              total_earned = ? * COALESCE(day_fraction, 1.0)
          WHERE workplace_id = ?
             OR TRIM(workplace_name) = ?
             OR (? != '' AND TRIM(workplace_name) = ?)
          ''',
          [
            workplace.id,
            newName,
            workplace.dailyRate,
            workplace.dailyRate,
            workplace.id,
            newName,
            oldName,
            oldName,
          ],
        );
      } else {
        await txn.rawUpdate(
          '''
          UPDATE work_logs
          SET workplace_id = ?,
              workplace_name = ?
          WHERE workplace_id = ?
             OR TRIM(workplace_name) = ?
             OR (? != '' AND TRIM(workplace_name) = ?)
          ''',
          [
            workplace.id,
            newName,
            workplace.id,
            newName,
            oldName,
            oldName,
          ],
        );
      }
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Atomically updates an employer's daily rate and cascades it across all historical and current work logs
  Future<void> cascadeEmployerDailyRate({
    required String workplaceId,
    required String workplaceName,
    required double newRate,
  }) async {
    if (newRate <= 0) return;
    final db = await _dbHelper.database;
    final cleanId = workplaceId.trim();
    final cleanName = workplaceName.trim();
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Update workplaces table
      if (cleanId.isNotEmpty) {
        await txn.update(
          'workplaces',
          {
            'daily_rate': newRate,
            'updated_at': nowIso,
          },
          where: 'id = ?',
          whereArgs: [cleanId],
        );
      }
      if (cleanName.isNotEmpty) {
        await txn.update(
          'workplaces',
          {
            'daily_rate': newRate,
            'updated_at': nowIso,
          },
          where: 'TRIM(name) = ?',
          whereArgs: [cleanName],
        );
      }

      // 2. Cascade update to all matching work_logs
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
          newRate,
          newRate,
          cleanId,
          cleanId,
          cleanId,
          cleanId,
          cleanName,
          cleanName,
        ],
      );
    });

    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Deletes a workplace by ID and optionally cascades to its work logs
  Future<void> deleteWorkplace(String id, {String? workplaceName, bool deleteLogs = true}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      if (deleteLogs) {
        final List<Map<String, dynamic>> logsToDelete;
        if (workplaceName != null && workplaceName.trim().isNotEmpty) {
          logsToDelete = await txn.query(
            'work_logs',
            columns: ['id'],
            where: 'workplace_id = ? OR workplace_name = ?',
            whereArgs: [id, workplaceName.trim()],
          );
          await txn.delete(
            'work_logs',
            where: 'workplace_id = ? OR workplace_name = ?',
            whereArgs: [id, workplaceName.trim()],
          );
        } else {
          logsToDelete = await txn.query(
            'work_logs',
            columns: ['id'],
            where: 'workplace_id = ?',
            whereArgs: [id],
          );
          await txn.delete(
            'work_logs',
            where: 'workplace_id = ?',
            whereArgs: [id],
          );
        }
        for (final row in logsToDelete) {
          final logId = row['id']?.toString();
          if (logId != null) {
            await DeletionSyncService.recordDeletion('work_logs', logId);
          }
        }
      }
      await txn.delete(
        'workplaces',
        where: 'id = ?',
        whereArgs: [id],
      );
      await DeletionSyncService.recordDeletion('workplaces', id);
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Toggles workplace status between 'active' and 'completed'
  Future<void> toggleWorkplaceStatus(String id, String currentStatus) async {
    final db = await _dbHelper.database;
    final newStatus = currentStatus == 'active' ? 'completed' : 'active';
    await db.update(
      'workplaces',
      {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fetches all workplaces associated with a specific person/contractor
  Future<List<WorkplaceModel>> getWorkplacesForPerson(String personId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workplaces',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'status ASC, created_at DESC',
    );
    return maps.map((map) => WorkplaceModel.fromMap(map)).toList();
  }

  // =================== MASTER-DETAIL EMPLOYER STATS & LOGS ===================

  /// تحسب من جدول work_logs عدد الأيام والمستحق والمقبوض والمتبقي لكل ورشة/مشغل دفعة واحدة
  Future<Map<String, EmployerStats>> getStatsForAllEmployers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        workplace_id,
        COUNT(*) as total_days,
        COALESCE(SUM(total_earned), 0.0) as total_earned,
        COALESCE(SUM(amount_collected), 0.0) as total_collected
      FROM work_logs
      WHERE workplace_id IS NOT NULL AND workplace_id != ''
      GROUP BY workplace_id
    ''');

    final Map<String, EmployerStats> statsMap = {};
    for (final row in results) {
      final wpId = row['workplace_id'] as String;
      final days = (row['total_days'] as num? ?? 0).toInt();
      final earned = (row['total_earned'] as num? ?? 0.0).toDouble();
      final collected = (row['total_collected'] as num? ?? 0.0).toDouble();
      final remaining = (earned - collected).clamp(0.0, double.infinity);

      statsMap[wpId] = EmployerStats(
        totalDays: days,
        totalEarned: earned,
        totalCollected: collected,
        totalRemaining: remaining,
      );
    }
    return statsMap;
  }

  /// إحصائيات مفصلة لمشغّل / ورشة محددة
  Future<EmployerStats> getStatsForEmployer(String employerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_days,
        COALESCE(SUM(total_earned), 0.0) as total_earned,
        COALESCE(SUM(amount_collected), 0.0) as total_collected
      FROM work_logs
      WHERE workplace_id = ?
    ''', [employerId]);

    if (results.isEmpty) return EmployerStats.empty;
    final row = results.first;
    final days = (row['total_days'] as num? ?? 0).toInt();
    final earned = (row['total_earned'] as num? ?? 0.0).toDouble();
    final collected = (row['total_collected'] as num? ?? 0.0).toDouble();
    final remaining = (earned - collected).clamp(0.0, double.infinity);

    return EmployerStats(
      totalDays: days,
      totalEarned: earned,
      totalCollected: collected,
      totalRemaining: remaining,
    );
  }

  /// تجلب أيام العمل الخاصة بهذا المشغل فقط مرتبة حسب التاريخ تنازلياً
  Future<List<WorkLogModel>> getLogsForEmployer(String employerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_logs',
      where: 'workplace_id = ?',
      whereArgs: [employerId],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => WorkLogModel.fromMap(map)).toList();
  }
}
