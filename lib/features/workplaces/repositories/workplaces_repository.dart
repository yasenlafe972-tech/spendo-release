import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
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

  /// Updates an existing workplace/employer
  Future<void> updateWorkplace(WorkplaceModel workplace) async {
    final db = await _dbHelper.database;
    final workplaceToSave = workplace.copyWith(
      updatedAt: DateTime.now(),
    );
    await db.update(
      'workplaces',
      workplaceToSave.toMap(),
      where: 'id = ?',
      whereArgs: [workplace.id],
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// Deletes a workplace by ID and optionally cascades to its work logs
  Future<void> deleteWorkplace(String id, {String? workplaceName, bool deleteLogs = true}) async {
    final db = await _dbHelper.database;
    if (deleteLogs) {
      if (workplaceName != null && workplaceName.trim().isNotEmpty) {
        await db.delete(
          'work_logs',
          where: 'workplace_id = ? OR workplace_name = ?',
          whereArgs: [id, workplaceName.trim()],
        );
      } else {
        await db.delete(
          'work_logs',
          where: 'workplace_id = ?',
          whereArgs: [id],
        );
      }
    }
    await db.delete(
      'workplaces',
      where: 'id = ?',
      whereArgs: [id],
    );
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
