import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_app/features/finance/models/debt_model.dart';
import 'package:sanad_app/features/finance/presentation/widgets/add_debt_sheet.dart';
import 'package:sanad_app/features/people/models/person_model.dart';

void main() {
  testWidgets('search selects the exact existing person when names match', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 11, 8);
    final people = [
      PersonModel(id: 'first', name: 'أحمد', phone: '0501111111',
          createdAt: now, updatedAt: now),
      PersonModel(id: 'second', name: 'أحمد', phone: '0502222222',
          createdAt: now, updatedAt: now),
    ];
    DebtModel? saved;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context, isScrollControlled: true,
          builder: (_) => AddDebtSheet(people: people, onSave: (debt) => saved = debt)),
        child: const Text('فتح'),
      ))),
    ));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختيار شخص موجود'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'بحث بالاسم أو رقم الهاتف'), '050222');
    await tester.pumpAndSettle();
    expect(find.text('0501111111'), findsNothing);
    await tester.tap(find.text('0502222222'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عليّ إله'));
    final amount = find.widgetWithText(TextFormField, 'المبلغ الأصلي (من أصل قديش) *');
    await tester.enterText(amount, '50');
    await tester.ensureVisible(find.text('حفظ في كشف المالية'));
    await tester.tap(find.text('حفظ في كشف المالية'));
    await tester.pumpAndSettle();
    expect(saved?.personId, 'second');
    expect(saved?.type, 'i_owe');
    expect(saved?.originalAmount, 50);
  });
}
