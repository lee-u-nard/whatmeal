import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'package:whatmeal/features/pantry/widgets/add_pantry_item_sheet.dart';

void main() {
  testWidgets(
      'editing category retains identity, author, creation and exact expiry',
      (tester) async {
    final expiry = DateTime.now().add(const Duration(days: 3, hours: 7));
    final created = DateTime(2026, 1, 1);
    final item = PantryItem(
        id: 'existing',
        name: 'Rice',
        quantity: '2 kg',
        expirationDate: expiry,
        addedBy: 'owner',
        createdAt: created,
        status: PantryStatus.runningLow,
        category: 'Proteins');
    NewPantryItem? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<NewPantryItem>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => AddPantryItemSheet(
                              existingItem: item,
                              existingCategory: item.category));
                    },
                    child: const Text('Edit'))))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pantry Staples').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(result!.category, 'Pantry Staples');
    expect(result!.item.category, 'Pantry Staples');
    expect(result!.item.id, 'existing');
    expect(result!.item.expirationDate, expiry);
    expect(result!.item.createdAt, created);
    expect(result!.item.addedBy, 'owner');
    expect(result!.item.status, PantryStatus.runningLow);
  });

  testWidgets(
      'expired ingredient opens date picker without an invalid-date crash',
      (tester) async {
    final item = PantryItem(
        id: 'expired',
        name: 'Milk',
        quantity: '1 L',
        expirationDate: DateTime.now().subtract(const Duration(days: 8)),
        category: 'Dairy');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AddPantryItemSheet(
                existingItem: item, existingCategory: item.category))));
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
