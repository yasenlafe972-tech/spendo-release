import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/core/widgets/spendo_shimmer.dart';

void main() {
  group('SpendoShimmer & SpendoShimmerCard Tests', () {
    testWidgets('SpendoShimmer renders child correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendoShimmer(
              child: SizedBox(
                width: 100,
                height: 50,
                key: Key('test_box'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('test_box')), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('SpendoShimmer when disabled does not use ShaderMask', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendoShimmer(
              enabled: false,
              child: SizedBox(
                width: 100,
                height: 50,
                key: Key('disabled_box'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('disabled_box')), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('SpendoShimmerCard standalone works and creates own shimmer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendoShimmerCard(
              width: 120,
              height: 40,
            ),
          ),
        ),
      );

      expect(find.byType(SpendoShimmer), findsOneWidget);
      expect(find.byType(SpendoShimmerCard), findsOneWidget);
    });

    testWidgets('SpendoShimmerCard inside SpendoShimmer inherits parent scope without duplicate shimmer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendoShimmer(
              child: Column(
                children: [
                  SpendoShimmerCard(width: 100, height: 20),
                  SpendoShimmerCard.circular(size: 40),
                  SpendoShimmerCard.rectangular(width: 80, height: 16),
                ],
              ),
            ),
          ),
        ),
      );

      // Exactly 1 SpendoShimmer at the root
      expect(find.byType(SpendoShimmer), findsOneWidget);
      expect(find.byType(SpendoShimmerCard), findsNWidgets(3));
    });
  });
}
