import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/main.dart';

void main() {
  testWidgets('Spendo app initialization test', (WidgetTester tester) async {
    expect(const SanadApp(initialRouteIsLoggedIn: false), isNotNull);
  });
}
