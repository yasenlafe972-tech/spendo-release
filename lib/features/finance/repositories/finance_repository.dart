import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/deletion_sync_service.dart';
import '../../../core/services/firebase_backup_service.dart';
import '../models/payment_model.dart';
import '../models/debt_model.dart';
import '../models/debt_payment_model.dart';
import '../models/debt_stats_model.dart';

export '../models/debt_stats_model.dart';
export '../models/debt_payment_model.dart';

class FinanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // =================== DEBTS & PERSONAL LOANS ===================

  Future<List<DebtModel>> getAllDebts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debts',
      orderBy: 'transaction_date DESC, created_at DESC',
    );
    return maps.map((map) => DebtModel.fromMap(map)).toList();
  }

  Future<List<DebtModel>> getDebtsForPerson(String personId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debts',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'transaction_date DESC, created_at DESC',
    );
    return maps.map((map) => DebtModel.fromMap(map)).toList();
  }

  Future<DebtModel?> getDebtById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DebtModel.fromMap(maps.first);
  }

  Future<void> addDebt(DebtModel debt) async {
    final db = await _dbHelper.database;
    await db.insert('debts', debt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  Future<void> updateDebt(DebtModel debt) async {
    final db = await _dbHelper.database;
    final debtToSave = debt.copyWith(updatedAt: DateTime.now());
    await db.update(
      'debts',
      debtToSave.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  Future<void> deleteDebt(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final payments = await txn.query(
        'debt_payments',
        columns: ['id'],
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      await txn.delete('debt_payments', where: 'debt_id = ?', whereArgs: [id]);
      for (final p in payments) {
        final pid = p['id']?.toString();
        if (pid != null) {
          await DeletionSyncService.recordDeletion('debt_payments', pid);
        }
      }
      await txn.delete('debts', where: 'id = ?', whereArgs: [id]);
      await DeletionSyncService.recordDeletion('debts', id);
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup();
  }

  /// تسجيل دفعة سداد جزئية أو كاملة وتحديث المبلغ المتبقي وحالة السداد تلقائياً داخل Transaction
  /// في حال وصل المبلغ المتبقي إلى 0.0 أو أقل تتغير حالة الدين فورياً إلى settled
  Future<void> recordDebtRepayment({
    required DebtPaymentModel payment,
    required DebtModel parentDebt,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. جلب أحدث بيانات للدين مباشرة من قاعدة البيانات داخل نفس المعاملة (Atomic Transaction)
      final debtRows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [parentDebt.id],
        limit: 1,
      );

      final currentDebt = debtRows.isNotEmpty
          ? DebtModel.fromMap(debtRows.first)
          : parentDebt;

      // تنظيف أي دفعات يتيمة قديمة غير محتسبة إذا كان الدين لم يُخصم منه شيء بعد
      if (currentDebt.paidAmount <= 0.01) {
        final oldPayments = await txn.query(
          'debt_payments',
          columns: ['id'],
          where: 'debt_id = ?',
          whereArgs: [currentDebt.id],
        );
        if (oldPayments.isNotEmpty) {
          await txn.delete(
            'debt_payments',
            where: 'debt_id = ?',
            whereArgs: [currentDebt.id],
          );
          for (final op in oldPayments) {
            final opId = op['id']?.toString();
            if (opId != null) {
              await DeletionSyncService.recordDeletion('debt_payments', opId);
            }
          }
        }
      }

      // 2. إدراج الدفعة في جدول debt_payments
      await txn.insert(
        'debt_payments',
        payment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. احتساب المبلغ المتبقي بدقة (طرح مبلغ الدفعة من المتبقي الحالي)
      final calculatedRemaining = currentDebt.remainingAmount - payment.amount;
      final newRemaining = calculatedRemaining <= 0.01
          ? 0.0
          : calculatedRemaining.clamp(0.0, currentDebt.originalAmount);

      // 4. تحديد الحالة فوراً: إذا وصل إلى 0.0 أو أقل يصبح مسدداً بالكامل settled
      final newStatus = newRemaining <= 0.01 ? 'settled' : 'active';
      final nowStr = DateTime.now().toIso8601String();

      // 5. تحديث جدول debts (وتحديث طريقة الدفع الفعلية إذا كانت الدفعة مؤجلة عالحساب)
      final updatedMethod = (currentDebt.isPayLater || currentDebt.paymentMethod == 'pending')
          ? payment.paymentMethod
          : currentDebt.paymentMethod;

      await txn.update(
        'debts',
        {
          'remaining_amount': newRemaining,
          'payment_method': updatedMethod,
          'status': newStatus,
          'updated_at': nowStr,
        },
        where: 'id = ?',
        whereArgs: [currentDebt.id],
      );
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  /// حذف دفعة سداد وإعادة احتساب المبلغ المتبقي وحالة الدين تلقائياً داخل Transaction
  Future<void> deleteDebtRepayment({
    required String paymentId,
    required String debtId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final paymentRows = await txn.query(
        'debt_payments',
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );
      if (paymentRows.isEmpty) return;
      final payment = DebtPaymentModel.fromMap(paymentRows.first);

      await txn.delete(
        'debt_payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      );
      await DeletionSyncService.recordDeletion('debt_payments', paymentId);

      final debtRows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
        limit: 1,
      );
      if (debtRows.isEmpty) return;
      final currentDebt = DebtModel.fromMap(debtRows.first);

      final calculatedRemaining = currentDebt.remainingAmount + payment.amount;
      final newRemaining = calculatedRemaining.clamp(0.0, currentDebt.originalAmount);
      final newStatus = newRemaining <= 0.01 ? 'settled' : 'active';
      final nowStr = DateTime.now().toIso8601String();

      await txn.update(
        'debts',
        {
          'remaining_amount': newRemaining,
          'status': newStatus,
          'updated_at': nowStr,
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );
    });
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  Future<List<DebtPaymentModel>> getPaymentsForDebt(String debtId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'debt_payments',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'created_at DESC, payment_date DESC',
    );
    final allPayments = maps.map((map) => DebtPaymentModel.fromMap(map)).toList();
    if (allPayments.isEmpty) return [];

    // مطابقة الدفعات مع المبلغ المسدد الفعلي في جدول الديون وتنظيف أي سجلات يتيمة سابقة
    final debt = await getDebtById(debtId);
    if (debt == null) return allPayments;

    final totalRecorded = allPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final actualPaid = debt.paidAmount;

    if (totalRecorded > actualPaid + 0.01) {
      final validPayments = <DebtPaymentModel>[];
      final orphanIds = <String>[];
      double runningSum = 0.0;

      for (final p in allPayments) {
        if (runningSum + p.amount <= actualPaid + 0.01) {
          validPayments.add(p);
          runningSum += p.amount;
        } else {
          orphanIds.add(p.id);
        }
      }

      if (orphanIds.isNotEmpty) {
        await db.transaction((txn) async {
          for (final id in orphanIds) {
            await txn.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
            await DeletionSyncService.recordDeletion('debt_payments', id);
          }
        });
        FirebaseBackupService.instance.scheduleAutoBackup(
          debounce: const Duration(seconds: 1),
        );
      }
      return validPayments;
    }

    return allPayments;
  }

  // =================== STATISTICAL DOMAIN FUNCTIONS ===================

  /// إجمالي ما لي عند الناس (أخذوا مني مصاري) - المتبقي غير المسدد
  Future<double> getTotalTheyOwe({String? personId}) async {
    final debts = personId != null ? await getDebtsForPerson(personId) : await getAllDebts();
    return calculateTotalTheyOwe(debts);
  }

  /// إجمالي ما علي للناس (أخذت منهم مصاري) - المتبقي غير المسدد
  Future<double> getTotalIOwe({String? personId}) async {
    final debts = personId != null ? await getDebtsForPerson(personId) : await getAllDebts();
    return calculateTotalIOwe(debts);
  }

  /// صافي الرصيد المالي (إجمالي ما لي - إجمالي ما علي)
  Future<double> getNetDebtBalance({String? personId}) async {
    final debts = personId != null ? await getDebtsForPerson(personId) : await getAllDebts();
    return calculateNetDebtBalance(debts);
  }

  /// ملخص إحصائي شامل ودقيق للديون والسلف
  Future<DebtSummaryStats> getDebtSummaryStats({String? personId}) async {
    final debts = personId != null ? await getDebtsForPerson(personId) : await getAllDebts();
    return calculateSummaryStats(debts);
  }

  // ================= STATIC SYNCHRONOUS DOMAIN HELPERS =================
  // تتيح لواجهات المستخدم حساب الإحصائيات الفورية من القوائم المحملة مسبقاً دون استعلامات قاعدة بيانات إضافية

  /// حساب إجمالي ما لي عند الناس (أخذوا مني) بالاعتماد حصراً على remainingAmount للديون غير المسددة
  static double calculateTotalTheyOwe(List<DebtModel> debts) {
    return debts
        .where((d) => d.isTheyOwe && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// حساب إجمالي ما علي للناس (أخذت منهم) بالاعتماد حصراً على remainingAmount للديون غير المسددة
  static double calculateTotalIOwe(List<DebtModel> debts) {
    return debts
        .where((d) => d.isIOwe && !d.isSettled)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);
  }

  /// حساب إجمالي المبالغ المستلمة (مبالغ مستلمة / خالص ومسدد)
  static double calculateTotalReceived(List<DebtModel> debts) {
    return debts
        .where((d) => d.isReceived)
        .fold(0.0, (sum, d) => sum + d.originalAmount);
  }

  /// حساب صافي الرصيد: ما لي عند الناس - ما علي للناس
  static double calculateNetDebtBalance(List<DebtModel> debts) {
    return calculateTotalTheyOwe(debts) - calculateTotalIOwe(debts);
  }

  /// حساب كائن الإحصائيات الشامل للديون
  static DebtSummaryStats calculateSummaryStats(List<DebtModel> debts) {
    final theyOwe = calculateTotalTheyOwe(debts);
    final iOwe = calculateTotalIOwe(debts);
    final settledCount = debts.where((d) => d.isSettled).length;
    final activeCount = debts.length - settledCount;
    return DebtSummaryStats(
      totalTheyOwe: theyOwe,
      totalIOwe: iOwe,
      netBalance: theyOwe - iOwe,
      activeCount: activeCount,
      settledCount: settledCount,
    );
  }

  // =================== WORK COLLECTIONS / PAYMENTS ===================

  Future<List<PaymentModel>> getAllPayments() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => PaymentModel.fromMap(map)).toList();
  }

  Future<List<PaymentModel>> getPaymentsForPerson(String personId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'date DESC, created_at DESC',
    );
    return maps.map((map) => PaymentModel.fromMap(map)).toList();
  }

  Future<void> addPayment(PaymentModel payment) async {
    final db = await _dbHelper.database;
    await db.insert('payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }

  Future<void> deletePayment(String id) async {
    final db = await _dbHelper.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
    await DeletionSyncService.recordDeletion('payments', id);
    DatabaseHelper.notifyDataChanged();
    FirebaseBackupService.instance.scheduleAutoBackup(
      debounce: const Duration(seconds: 1),
    );
  }
}
