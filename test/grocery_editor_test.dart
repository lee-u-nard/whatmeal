import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/grocery/widgets/grocery_item_editor.dart';
import 'package:whatmeal/features/grocery/widgets/clear_used_dialog.dart';
import 'package:whatmeal/features/grocery/pages/grocery_page.dart';

void main() {
  testWidgets('manual grocery controls fit narrow screen with enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: GroceryItemTile(
                item: GroceryItem(
                    name: 'Long local ingredient name', quantity: '500 grams'),
                onTogglePurchased: (_) {},
                onCycleStatus: () {},
                onDelete: () {},
                onEdit: () {}))));
    expect(tester.takeException(), isNull);
  });
  Future<void> open(
      WidgetTester tester, Future<void> Function(GroceryItem) save,
      {double scale = 1, double keyboard = 0}) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => GroceryItemEditor(onSave: save)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('blank item shows validation; missing quantity remains unknown',
      (tester) async {
    GroceryItem? saved;
    await open(tester, (item) async {
      saved = item;
    });
    await tester.tap(find.text('Add to List'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an item name.'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(find.byType(TextFormField).first, 'Rice');
    await tester.tap(find.text('Add to List'));
    await tester.pumpAndSettle();
    expect(saved?.quantity, '');
    expect(saved?.name, 'Rice');
  });

  testWidgets(
      'pending write submits once and failed write retains draft for retry',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await open(tester, (_) {
      calls++;
      return calls == 1 ? pending.future : Future.value();
    });
    await tester.enterText(find.byType(TextFormField).first, 'Milk');
    await tester.enterText(find.byType(TextFormField).last, '2 cups');
    await tester.tap(find.text('Add to List'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    expect(calls, 1);
    pending.completeError(StateError('Private failure must not display'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save grocery item. Please retry.'),
        findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.textContaining('Private failure'), findsNothing);
    await tester.tap(find.text('Add to List'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('editor scrolls at enlarged text with keyboard inset',
      (tester) async {
    await open(tester, (_) async {}, scale: 2, keyboard: 220);
    await tester.ensureVisible(find.text('Add to List'));
    await tester.pumpAndSettle();
    expect(find.text('Add to List').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear purchased items requires explicit confirmation',
      (tester) async {
    var cleared = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      if (await confirmClearUsed(context)) cleared++;
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cleared, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Used'));
    await tester.pumpAndSettle();
    expect(cleared, 1);
  });
}
