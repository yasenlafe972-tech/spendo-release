import 'package:sanad_app/core/database/database_helper.dart';
import 'package:sanad_app/core/services/deletion_sync_service.dart';
import 'package:sanad_app/core/services/firebase_backup_service.dart';
import 'package:sanad_app/features/workplaces/models/workplace_payment_model.dart';

class WorkplacePaymentsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<WorkplacePaymentModel>> getPaymentsForWorkplace(String workplaceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'workplace_payments',
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => WorkplacePaymentModel.fromMap(m)).toList();
  }

  Future<List<WorkplacePaymentModel>> getAllPayments() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'workplace_payments',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((m) => WorkplacePaymentModel.fromMap(m)).toList();
  }

  Future<double> getTotalPaidForWorkplace(String workplaceId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT SUM(amount) as total FROM workplace_payments WHERE workplace_id = ?',
      [workplaceId],
    );
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<void> addPayment(WorkplacePaymentModel payment) async {
    final db = await _dbHelper.database;
    await db.insert('workplace_payments', payment.toMap());
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  Future<void> updatePayment(WorkplacePaymentModel payment) async {
    final db = await _dbHelper.database;
    await db.update(
      'workplace_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  Future<void> deletePayment(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'workplace_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
    await DeletionSyncService.recordDeletion('workplace_payments', id);
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }
}
