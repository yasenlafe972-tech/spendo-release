import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/workplaces/models/workplace_model.dart';
import 'package:sanad_app/features/workplaces/models/employer_stats.dart';

void main() {
  group('WorkplaceModel Unit Tests', () {
    final now = DateTime(2026, 10, 22, 20, 0, 0);

    test('WorkplaceModel creation and getters', () {
      final workplace = WorkplaceModel(
        id: 'wp-1',
        name: 'ورشة برج الأمل',
        city: 'القدس',
        personId: 'person-1',
        dailyRate: 400.0,
        hourlyRate: 50.0,
        status: 'active',
        notes: 'ملاحظات الورشة',
        createdAt: now,
        updatedAt: now,
      );

      expect(workplace.id, 'wp-1');
      expect(workplace.employerId, 'wp-1');
      expect(workplace.name, 'ورشة برج الأمل');
      expect(workplace.employerName, 'ورشة برج الأمل');
      expect(workplace.city, 'القدس');
      expect(workplace.personId, 'person-1');
      expect(workplace.dailyRate, 400.0);
      expect(workplace.hourlyRate, 50.0);
      expect(workplace.status, 'active');
      expect(workplace.isActive, isTrue);
      expect(workplace.isCompleted, isFalse);
      expect(workplace.notes, 'ملاحظات الورشة');
      expect(workplace.createdAt, now);
      expect(workplace.updatedAt, now);
    });

    test('WorkplaceModel toMap and fromMap serialization round-trip', () {
      final workplace = WorkplaceModel(
        id: 'wp-2',
        name: 'فيلا حي النرجس',
        city: 'رام الله',
        personId: 'person-2',
        dailyRate: 350.0,
        hourlyRate: 45.0,
        status: 'completed',
        notes: 'تم الانتهاء بنجاح',
        createdAt: now,
        updatedAt: now,
      );

      final map = workplace.toMap();
      final fromMap = WorkplaceModel.fromMap(map);

      expect(fromMap.id, workplace.id);
      expect(fromMap.name, workplace.name);
      expect(fromMap.city, workplace.city);
      expect(fromMap.personId, workplace.personId);
      expect(fromMap.dailyRate, workplace.dailyRate);
      expect(fromMap.hourlyRate, workplace.hourlyRate);
      expect(fromMap.status, workplace.status);
      expect(fromMap.isActive, isFalse);
      expect(fromMap.isCompleted, isTrue);
      expect(fromMap.notes, workplace.notes);
      expect(fromMap.createdAt, workplace.createdAt);
      expect(fromMap.updatedAt, workplace.updatedAt);
    });

    test('WorkplaceModel copyWith works as expected', () {
      final workplace = WorkplaceModel(
        id: 'wp-3',
        name: 'محل تجاري',
        city: 'نابلس',
        createdAt: now,
        updatedAt: now,
      );

      final updated = workplace.copyWith(
        name: 'محل تجاري معدل',
        status: 'completed',
        dailyRate: 500.0,
      );

      expect(updated.id, 'wp-3');
      expect(updated.name, 'محل تجاري معدل');
      expect(updated.city, 'نابلس');
      expect(updated.status, 'completed');
      expect(updated.dailyRate, 500.0);
      expect(updated.hourlyRate, 0.0);
    });
    test('EmployerStats metrics and calculations', () {
      const stats = EmployerStats(
        totalDays: 5,
        totalEarned: 2000.0,
        totalCollected: 1500.0,
        totalRemaining: 500.0,
      );

      expect(stats.totalDays, 5);
      expect(stats.totalEarned, 2000.0);
      expect(stats.totalCollected, 1500.0);
      expect(stats.totalRemaining, 500.0);
      expect(stats.isFullyCollected, isFalse);
      expect(stats.collectionProgress, 0.75);

      const fullyPaidStats = EmployerStats(
        totalDays: 3,
        totalEarned: 1200.0,
        totalCollected: 1200.0,
        totalRemaining: 0.0,
      );
      expect(fullyPaidStats.isFullyCollected, isTrue);
      expect(fullyPaidStats.collectionProgress, 1.0);
    });
  });
}
