import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/core/utils/spendo_haptic_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpendoHaptics Tests', () {
    test('SpendoHaptics methods execute without exceptions', () async {
      await expectLater(SpendoHaptics.light(), completes);
      await expectLater(SpendoHaptics.medium(), completes);
      await expectLater(SpendoHaptics.success(), completes);
      await expectLater(SpendoHaptics.selection(), completes);
    });
  });
}
