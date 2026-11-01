import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
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
    await db.insert('work_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  Future<void> updateWorkLog(WorkLogModel log) async {
    final db = await _dbHelper.database;
    await db.update(
      'work_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
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
    FirebaseBackupService.instance.scheduleAutoBackup();
  }
}
