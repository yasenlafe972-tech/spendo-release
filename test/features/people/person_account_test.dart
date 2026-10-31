import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/people/models/person_account_model.dart';

void main() {
  group('PersonAccountModel Unit Tests', () {
    test('creates model and verifies properties', () {
      final now = DateTime.now();
      final acc = PersonAccountModel(
        id: 'acc_1',
        personId: 'person_1',
        service: 'mail.ru',
        email: 'user@mail.ru',
        password: 'SecretPassword123!',
        createdAt: now,
        updatedAt: now,
      );

      expect(acc.id, 'acc_1');
      expect(acc.personId, 'person_1');
      expect(acc.service, 'mail.ru');
      expect(acc.email, 'user@mail.ru');
      expect(acc.password, 'SecretPassword123!');
      expect(acc.createdAt, now);
      expect(acc.updatedAt, now);
    });

    test('toMap and fromMap serialization round-trip', () {
      final now = DateTime(2026, 10, 23, 7, 0, 0);
      final acc = PersonAccountModel(
        id: 'acc_2',
        personId: 'person_2',
        service: 'Apple',
        email: 'user@apple.com',
        password: 'ApplePassword!',
        createdAt: now,
        updatedAt: now,
      );

      final map = acc.toMap();
      expect(map['id'], 'acc_2');
      expect(map['person_id'], 'person_2');
      expect(map['service'], 'Apple');
      expect(map['email'], 'user@apple.com');
      expect(map['password'], 'ApplePassword!');

      final restored = PersonAccountModel.fromMap(map);
      expect(restored.id, acc.id);
      expect(restored.personId, acc.personId);
      expect(restored.service, acc.service);
      expect(restored.email, acc.email);
      expect(restored.password, acc.password);
      expect(restored.createdAt, acc.createdAt);
      expect(restored.updatedAt, acc.updatedAt);
    });

    test('copyWith works correctly', () {
      final now = DateTime.now();
      final acc = PersonAccountModel(
        id: 'acc_3',
        personId: 'person_3',
        service: 'DaVinci AI',
        email: 'test@gmail.com',
        password: 'OldPass',
        createdAt: now,
        updatedAt: now,
      );

      final updated = acc.copyWith(
        service: 'DaVinci Pro',
        password: 'NewPass',
      );

      expect(updated.id, 'acc_3');
      expect(updated.personId, 'person_3');
      expect(updated.service, 'DaVinci Pro');
      expect(updated.email, 'test@gmail.com');
      expect(updated.password, 'NewPass');
    });
  });
}
