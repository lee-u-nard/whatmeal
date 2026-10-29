import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/widgets/add_meal_dialog.dart';

void main() {
  Future<void> open(
      WidgetTester tester, Future<void> Function(GeneratedMeal) submit) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                AddMealDialog(dayIndex: 1, dayLabel: 'Tuesday', onAdd: submit)),
        child: const Text('Open'),
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Dish Name'), 'Rice');
  }

  testWidgets('repeated taps submit once while a write is delayed',
      (tester) async {
    final gate = Completer<void>();
    final calls = <GeneratedMeal>[];
    await open(tester, (meal) async {
      calls.add(meal);
      await gate.future;
    });
    // Same-frame taps exercise the synchronous guard as well as disabled UI.
    await tester.tap(find.text('Add Dish'));
    await tester.tap(find.text('Add Dish'));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single.dayIndex, 1);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AddMealDialog), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AddMealDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed write keeps fields and permits retry with the same ID',
      (tester) async {
    final calls = <GeneratedMeal>[];
    await open(tester, (meal) async {
      calls.add(meal);
      if (calls.length == 1) throw StateError('Simulated unavailable');
    });
    await tester.tap(find.text('Add Dish'));
    await tester.pumpAndSettle();
    expect(find.text('Meal was not added. Please retry.'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    await tester.tap(find.text('Add Dish'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(calls[0].id, calls[1].id);
    expect(find.byType(AddMealDialog), findsNothing);
  });

  testWidgets(
      'retry after a committed but failed acknowledgement creates one meal',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'a', name: 'Owner', email: 'a@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) => const Stream.empty());
    addTearDown(() {
      repo.dispose();
      account.dispose();
      household.dispose();
    });
    const path = 'users/a/mealPlans/plan';
    await db.doc(path).set({'numberOfDays': 1});
    var calls = 0;
    await open(tester, (meal) async {
      await repo.editMeal(path, meal);
      if (++calls == 1) throw StateError('Acknowledgement lost');
    });
    await tester.tap(find.text('Add Dish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Dish'));
    await tester.pumpAndSettle();
    final meals = await db.collection('$path/meals').get();
    expect(calls, 2);
    expect(meals.docs, hasLength(1));
    expect(meals.docs.single.data()['title'], 'Rice');
  });
}
