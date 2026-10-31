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
