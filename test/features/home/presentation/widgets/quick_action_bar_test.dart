import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/home/presentation/widgets/quick_action_bar.dart';

void main() {
  testWidgets('QuickActionBar renders all 4 actions and triggers callbacks on tap', (WidgetTester tester) async {
    bool workLogTapped = false;
    bool workplaceTapped = false;
    bool debtTapped = false;
    bool cloudBackupTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickActionBar(
            onAddWorkLog: () => workLogTapped = true,
            onAddWorkplace: () => workplaceTapped = true,
            onAddDebt: () => debtTapped = true,
            onOpenCloudBackup: () => cloudBackupTapped = true,
          ),
        ),
      ),
    );

    // Verify all labels are displayed
    expect(find.text('تسجيل يومية'), findsOneWidget);
    expect(find.text('مكان عمل جديد'), findsOneWidget);
    expect(find.text('دين أو سلفة'), findsOneWidget);
    expect(find.text('نسخ سحابي'), findsOneWidget);

    // Verify all icons are displayed
    expect(find.byIcon(Icons.add_task_rounded), findsOneWidget);
    expect(find.byIcon(Icons.domain_add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cloud_sync_rounded), findsOneWidget);

    // Tap each action and check callbacks
    await tester.tap(find.text('تسجيل يومية'));
    await tester.pumpAndSettle();
    expect(workLogTapped, isTrue);

    await tester.tap(find.text('مكان عمل جديد'));
    await tester.pumpAndSettle();
    expect(workplaceTapped, isTrue);

    await tester.tap(find.text('دين أو سلفة'));
    await tester.pumpAndSettle();
    expect(debtTapped, isTrue);

    await tester.tap(find.text('نسخ سحابي'));
    await tester.pumpAndSettle();
    expect(cloudBackupTapped, isTrue);
  });
}
