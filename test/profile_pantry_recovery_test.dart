import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'package:whatmeal/features/pantry/widgets/add_pantry_item_sheet.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';
import 'package:whatmeal/features/profile/widgets/add_edit_family_member_sheet.dart';

Future<void> open(WidgetTester tester, Widget sheet) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => sheet),
                  child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await tester.pump();
}

void main() {
  for (final pantry in [true, false]) {
    testWidgets(
        '${pantry ? 'pantry' : 'profile'} save retains draft on failure and retries once',
        (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      Future<void> save(Object value) async {
        calls++;
        if (calls == 1) await pending.future;
      }

      await open(
          tester,
          pantry
              ? AddPantryItemSheet(
                  existingItem: PantryItem(
                      id: 'stable',
                      name: 'Rice',
                      quantity: '2 kg',
                      category: 'Pantry Staples',
                      expirationDate: DateTime(2027)),
                  onSave: save)
              : AddEditFamilyMemberSheet(
                  existingMember: const FamilyMember(
                      id: 'stable',
                      name: 'Child',
                      age: 8,
                      preferences: ['Vegan'],
                      restrictions: ['Peanut Allergy']),
                  onSave: save));
      await submit(tester);
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = pantry
          ? tester.widget<FilledButton>(find.byType(FilledButton))
          : tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
          pantry
              ? (button as FilledButton).onPressed
              : (button as ElevatedButton).onPressed,
          isNull);
      pending.completeError(StateError('PRIVATE_DETAIL'));
      await tester.pumpAndSettle();
      expect(
          find.text(pantry
              ? 'Ingredient was not saved. Please retry.'
              : 'Profile was not saved. Please retry.'),
          findsOneWidget);
      expect(find.textContaining('PRIVATE_DETAIL'), findsNothing);
      expect(find.text(pantry ? 'Rice' : 'Child'), findsOneWidget);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets(
      'profile age cannot silently default for nonnumeric or out-of-range input',
      (tester) async {
    var saves = 0;
    await open(
        tester,
        AddEditFamilyMemberSheet(
            existingMember: const FamilyMember(
                id: 'child',
                name: 'Child',
                age: 8,
                preferences: [],
                restrictions: []),
            onSave: (_) async {
              saves++;
            }));
    final age = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Age');
    for (final invalid in ['abc', '-1', '131']) {
      await tester.ensureVisible(age);
      await tester.enterText(age, invalid);
      await submit(tester);
      expect(saves, 0);
      expect(find.text('Enter an age from 0 to 130'), findsOneWidget);
    }
  });

  testWidgets('pantry edit displays and preserves an existing custom category',
      (tester) async {
    NewPantryItem? result;
    await open(
        tester,
        AddPantryItemSheet(
            existingItem: PantryItem(
                id: 'stable',
                name: 'Herbs',
                quantity: '3 g',
                category: 'Other',
                expirationDate: DateTime(2027)),
            onSave: (v) async {
              result = v;
            }));
    expect(find.text('Other'), findsWidgets);
    await submit(tester);
    expect(result!.category, 'Other');
    expect(result!.item.id, 'stable');
  });
  testWidgets('dietary editor fits narrow enlarged text without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: const Scaffold(body: AddEditFamilyMemberSheet())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
