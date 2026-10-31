import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/finance/models/debt_model.dart';
import 'package:sanad_app/features/finance/models/debt_payment_model.dart';
import 'package:sanad_app/features/finance/repositories/finance_repository.dart';

void main() {
  group('Finance Domain & Statistics Unit Tests', () {
    final now = DateTime(2026, 10, 22, 21, 0, 0);

    final debt1 = DebtModel(
      id: 'd1',
      personId: 'p1',
      type: 'they_owe',
      originalAmount: 1000.0,
      remainingAmount: 600.0, // 400 paid
      paymentMethod: 'bit',
      transactionDate: '2026-10-20',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    final debt2 = DebtModel(
      id: 'd2',
      personId: 'p2',
      type: 'i_owe',
      originalAmount: 500.0,
      remainingAmount: 200.0, // 300 paid
      paymentMethod: 'cash',
      transactionDate: '2026-10-21',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    final debtSettled = DebtModel(
      id: 'd3',
      personId: 'p3',
      type: 'they_owe',
      originalAmount: 800.0,
      remainingAmount: 0.0,
      paymentMethod: 'bank_transfer',
      transactionDate: '2026-10-15',
      status: 'settled',
      createdAt: now,
      updatedAt: now,
    );

    final debtNearlySettled = DebtModel(
      id: 'd4',
      personId: 'p4',
      type: 'they_owe',
      originalAmount: 300.0,
      remainingAmount: 0.005, // negligible residual float -> should be treated as settled
      paymentMethod: 'cash',
      transactionDate: '2026-10-18',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    test('DebtModel properties and helper getters', () {
      expect(debt1.isTheyOwe, isTrue);
      expect(debt1.isIOwe, isFalse);
      expect(debt1.paidAmount, 400.0);
      expect(debt1.progress, 0.4);
      expect(debt1.isSettled, isFalse);

      expect(debt2.isTheyOwe, isFalse);
      expect(debt2.isIOwe, isTrue);
      expect(debt2.paidAmount, 300.0);
      expect(debt2.progress, 0.6);
      expect(debt2.isSettled, isFalse);

      expect(debtSettled.isSettled, isTrue);
      expect(debtNearlySettled.isSettled, isTrue);
    });

    test('DebtModel copyWith works correctly', () {
      final updated = debt1.copyWith(
        remainingAmount: 0.0,
        status: 'settled',
      );

      expect(updated.id, debt1.id);
      expect(updated.personId, debt1.personId);
      expect(updated.type, debt1.type);
      expect(updated.originalAmount, 1000.0);
      expect(updated.remainingAmount, 0.0);
      expect(updated.status, 'settled');
      expect(updated.isSettled, isTrue);
    });

    test('DebtPaymentModel copyWith works correctly', () {
      final payment = DebtPaymentModel(
        id: 'pm-1',
        debtId: 'd1',
        amount: 250.0,
        paymentMethod: 'bit',
        paymentDate: '2026-10-22',
        createdAt: now,
      );

      final updated = payment.copyWith(amount: 300.0, notes: 'دفعة إضافية');
      expect(updated.id, 'pm-1');
      expect(updated.amount, 300.0);
      expect(updated.notes, 'دفعة إضافية');
    });

    test('calculateTotalTheyOwe considers only active remaining amounts', () {
      final debts = [debt1, debt2, debtSettled, debtNearlySettled];
      // debt1: 600.0 (active, they_owe)
      // debt2: 200.0 (active, i_owe -> excluded)
      // debtSettled: 0.0 (settled -> excluded)
      // debtNearlySettled: remaining 0.005 -> isSettled is true -> excluded
      final totalTheyOwe = FinanceRepository.calculateTotalTheyOwe(debts);
      expect(totalTheyOwe, 600.0);
    });

    test('calculateTotalIOwe considers only active remaining amounts', () {
      final debts = [debt1, debt2, debtSettled, debtNearlySettled];
      // debt2: 200.0 (active, i_owe)
      final totalIOwe = FinanceRepository.calculateTotalIOwe(debts);
      expect(totalIOwe, 200.0);
    });

    test('calculateNetDebtBalance accurately calculates (They Owe - I Owe)', () {
      final debts = [debt1, debt2, debtSettled, debtNearlySettled];
      // 600.0 - 200.0 = +400.0 (Net positive balance for user)
      final net = FinanceRepository.calculateNetDebtBalance(debts);
      expect(net, 400.0);
    });

    test('calculateSummaryStats generates complete and accurate metrics', () {
      final debts = [debt1, debt2, debtSettled, debtNearlySettled];
      final stats = FinanceRepository.calculateSummaryStats(debts);

      expect(stats.totalTheyOwe, 600.0);
      expect(stats.totalIOwe, 200.0);
      expect(stats.netBalance, 400.0);
      expect(stats.hasPositiveBalance, isTrue);
      expect(stats.hasNegativeBalance, isFalse);
      expect(stats.isBalanced, isFalse);
      expect(stats.settledCount, 2); // debtSettled and debtNearlySettled
      expect(stats.activeCount, 2); // debt1 and debt2
    });
  });
}
