import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/home/presentation/widgets/spendo_income_chart.dart';

void main() {
  group('SpendoIncomeChart Widget Tests', () {
    testWidgets('Renders empty state when dataPoints < 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendoIncomeChart(
              dataPoints: [500.0],
              labels: ['السبت'],
              totalIncome: 500.0,
              selectedPeriod: 'هذا الأسبوع',
            ),
          ),
        ),
      );

      expect(
        find.text('بانتظار تسجيل المزيد من أيام العمل لرسم المنحنى'),
        findsOneWidget,
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders chart canvas with >= 2 dataPoints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendoIncomeChart(
              dataPoints: [200.0, 450.0, 700.0, 300.0, 850.0],
              labels: ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء'],
              totalIncome: 2500.0,
              selectedPeriod: 'هذا الأسبوع',
            ),
          ),
        ),
      );

      // Empty state message should NOT be present
      expect(
        find.text('بانتظار تسجيل المزيد من أيام العمل لرسم المنحنى'),
        findsNothing,
      );

      // Total amount formatted should be rendered
      expect(find.text('2,500'), findsOneWidget);
      expect(find.text('₪'), findsOneWidget);
      expect(find.text('صافي الدخل'), findsOneWidget);
    });

    testWidgets('Period tabs are interactive and call onPeriodChanged', (tester) async {
      String? changedPeriod;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendoIncomeChart(
              dataPoints: const [100.0, 200.0],
              labels: const ['1', '2'],
              totalIncome: 300.0,
              selectedPeriod: 'هذا الأسبوع',
              onPeriodChanged: (period) {
                changedPeriod = period;
              },
            ),
          ),
        ),
      );

      expect(find.text('هذا الشهر'), findsOneWidget);

      await tester.tap(find.text('هذا الشهر'));
      await tester.pump();

      expect(changedPeriod, 'هذا الشهر');
    });

    testWidgets('Pan and scrubbing interaction triggers point selection', (tester) async {
      int? selectedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendoIncomeChart(
              dataPoints: const [100.0, 200.0, 300.0, 400.0, 500.0],
              labels: const ['ن1', 'ن2', 'ن3', 'ن4', 'ن5'],
              totalIncome: 1500.0,
              selectedPeriod: 'هذا الأسبوع',
              onPointScrubbed: (idx) {
                selectedIndex = idx;
              },
            ),
          ),
        ),
      );

      // Find the chart canvas GestureDetector inside Expanded
      final chartFinder = find.descendant(
        of: find.byType(Expanded),
        matching: find.byType(GestureDetector),
      );
      expect(chartFinder, findsOneWidget);

      // Simulate a drag gesture across the chart canvas
      await tester.drag(chartFinder, const Offset(60.0, 0.0));
      await tester.pump();

      expect(selectedIndex != null, isTrue);
    });
  });
}
