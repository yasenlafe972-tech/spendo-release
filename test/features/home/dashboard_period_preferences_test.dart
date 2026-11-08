import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanad_app/features/home/services/dashboard_period_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first launch defaults to the current month', () async {
    expect(await DashboardPeriodPreferences.load(now: DateTime(2026, 11, 9)), '2026-11');
  });

  test('selected month survives preference reload and a later calendar month', () async {
    await DashboardPeriodPreferences.save('2026-08');
    await (await SharedPreferences.getInstance()).reload();
    expect(await DashboardPeriodPreferences.load(now: DateTime(2027, 1, 1)), '2026-08');
  });

  test('all periods is restored as an explicit choice', () async {
    await DashboardPeriodPreferences.save('all');
    await (await SharedPreferences.getInstance()).reload();
    expect(await DashboardPeriodPreferences.load(), 'all');
  });

  test('invalid persisted month falls back to current month', () async {
    SharedPreferences.setMockInitialValues({DashboardPeriodPreferences.storageKey: '2026-13'});
    expect(await DashboardPeriodPreferences.load(now: DateTime(2026, 11, 9)), '2026-11');
  });
}
