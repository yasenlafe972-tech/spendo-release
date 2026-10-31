import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/work_logs/models/work_log_model.dart';

void main() {
  group('WorkLogModel Nullable personId Unit Tests', () {
    final now = DateTime(2026, 10, 22, 21, 0, 0);

    test('WorkLogModel can be created with null personId', () {
      final log = WorkLogModel(
        id: 'wl-1',
        personId: null,
        workplaceId: 'wp-10',
        workplaceName: 'ورشة الأمل',
        city: 'القدس',
        date: '2026-10-22',
        rateType: 'daily',
        rateApplied: 400.0,
        totalEarned: 400.0,
        createdAt: now,
      );

      expect(log.id, 'wl-1');
      expect(log.personId, isNull);
      expect(log.workplaceId, 'wp-10');
      expect(log.workplaceName, 'ورشة الأمل');
      expect(log.totalEarned, 400.0);
      expect(log.amountCollected, 0.0);
      expect(log.remainingToCollect, 400.0);
      expect(log.isFullyCollected, isFalse);
    });

    test('WorkLogModel toMap and fromMap serialization round-trip with null personId', () {
      final log = WorkLogModel(
        id: 'wl-2',
        personId: null,
        workplaceName: 'فيلا رام الله',
        date: '2026-10-22',
        rateType: 'daily',
        rateApplied: 350.0,
        totalEarned: 350.0,
        amountCollected: 350.0,
        createdAt: now,
      );

      final map = log.toMap();
      expect(map['person_id'], isNull);

      final reconstructed = WorkLogModel.fromMap(map);
      expect(reconstructed.id, log.id);
      expect(reconstructed.personId, isNull);
      expect(reconstructed.workplaceName, 'فيلا رام الله');
      expect(reconstructed.isFullyCollected, isTrue);
    });

    test('WorkLogModel with non-null personId still works seamlessly', () {
      final log = WorkLogModel(
        id: 'wl-3',
        personId: 'person-123',
        workplaceName: 'محل تجاري',
        date: '2026-10-22',
        rateType: 'hourly',
        hoursWorked: 8.0,
        rateApplied: 50.0,
        totalEarned: 400.0,
        createdAt: now,
      );

      final map = log.toMap();
      expect(map['person_id'], 'person-123');

      final reconstructed = WorkLogModel.fromMap(map);
      expect(reconstructed.personId, 'person-123');
    });

    test('WorkLogModel copyWith preserves or updates personId', () {
      final log = WorkLogModel(
        id: 'wl-4',
        personId: null,
        workplaceName: 'ورشة نابلس',
        date: '2026-10-22',
        rateType: 'daily',
        rateApplied: 300.0,
        totalEarned: 300.0,
        createdAt: now,
      );

      final updatedWithPerson = log.copyWith(personId: 'contractor-5');
      expect(updatedWithPerson.personId, 'contractor-5');

      final updatedPreservingNull = updatedWithPerson.copyWith(notes: 'ملاحظة جديدة');
      expect(updatedPreservingNull.personId, 'contractor-5');
      expect(updatedPreservingNull.notes, 'ملاحظة جديدة');
    });
    test('WorkLogModel Master-Detail employerId and employerName aliases', () {
      final log = WorkLogModel(
        id: 'wl-5',
        employerId: 'emp-99',
        employerName: 'عمارة القدس التجارية',
        date: '2026-10-23',
        rateType: 'daily',
        rateApplied: 450.0,
        totalEarned: 450.0,
        createdAt: now,
      );

      expect(log.workplaceId, 'emp-99');
      expect(log.employerId, 'emp-99');
      expect(log.workplaceName, 'عمارة القدس التجارية');
      expect(log.employerName, 'عمارة القدس التجارية');

      final updated = log.copyWith(employerId: 'emp-100', employerName: 'برج النور');
      expect(updated.employerId, 'emp-100');
      expect(updated.employerName, 'برج النور');
    });
  });
}
