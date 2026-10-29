import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/grocery/pages/grocery_page.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/data/generation_inventory.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

class Fixture {
  final db = FakeFirebaseFirestore();
  final ids = StreamController<String?>.broadcast(sync: true);
  final household = ValueNotifier<FamilySpace?>(null);
  final feeds = <StreamController<List<PantryItem>>>[];
  final plans = ValueNotifier<List<SavedMealPlan>>([
    SavedMealPlan(
        id: 'plan',
        sourcePath: 'users/a/mealPlans/plan',
        title: 'Dinner',
        dates: '',
        mealsCount: 1,
        estCost: '',
        familyMembers: [],
        meals: [
          GeneratedMeal.fromCore(Meal(
              id: 'meal',
              title: 'Rice bowl',
              status: MealStatus.accepted,
              ingredients: [const Ingredient(name: 'rice', amount: '3 cups')]))
        ])
  ]);
  late final pantry = PantryRepository(
      firestore: db,
      authIds: ids.stream,
      household: household,
      watch: (_) {
        final feed = StreamController<List<PantryItem>>.broadcast(sync: true);
        feeds.add(feed);
        return feed.stream;
      });
  late final groceries = GroceryRepository(
      firestore: db,
      authIds: ids.stream,
      household: household,
      plans: plans,
      pantry: pantry,
      pantryScope: () => pantry.scopePath,
      canEdit: () => true);
  Future<void> start({bool wait = true}) async {
    await db
        .doc('users/a/groceryLists/default')
        .set({'createdAt': Timestamp.now()});
    groceries;
    ids.add('a');
    if (wait) await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  void stock() =>
      feeds.last.add([PantryItem(name: 'rice', quantity: '2 cups')]);
  void close() {
    groceries.dispose();
    pantry.dispose();
    household.dispose();
    plans.dispose();
    unawaited(ids.close());
    for (final feed in feeds) {
      unawaited(feed.close());
    }
  }
}

void main() {
  GenerationInventory capture(Fixture f, {String workspace = 'users/a'}) =>
      GenerationInventory.capture(
          workspacePath: workspace,
          pantry: f.pantry,
          groceries: f.groceries,
          now: DateTime.now());

  test('generation rejects loading or failed pantry and recovers after Retry',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    expect(() => capture(f), throwsA(isA<GenerationInventoryUnavailable>()));
    f.stock();
    expect(capture(f).pantryItems, contains('2 cups rice'));
    f.feeds.last.addError(StateError('simulated terminal pantry failure'));
    await Future<void>.delayed(Duration.zero);
    expect(f.pantry.items, isEmpty);
    expect(() => capture(f), throwsA(isA<GenerationInventoryUnavailable>()));
    f.pantry.retry();
    f.groceries.retry();
    f.stock();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(capture(f).pantryItems, contains('2 cups rice'));
    expect(capture(f).groceryItems, contains('rice'));
  });

  test('generation rejects failed/loading groceries and another account scope',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    f.stock();
    f.groceries.isLoading = true;
    expect(() => capture(f), throwsA(isA<GenerationInventoryUnavailable>()));
    f.groceries.isLoading = false;
    f.groceries.error = 'simulated failure';
    expect(() => capture(f), throwsA(isA<GenerationInventoryUnavailable>()));
    f.groceries.error = null;
    expect(() => capture(f, workspace: 'users/b'),
        throwsA(isA<GenerationInventoryUnavailable>()));
    f.ids.add('b');
    expect(() => capture(f), throwsA(isA<GenerationInventoryUnavailable>()));
  });

  test('successfully loaded empty inventory is valid for generation', () async {
    final f = Fixture();
    addTearDown(f.close);
    f.plans.value = [];
    await f.start();
    f.feeds.last.add([]);
    final input = capture(f);
    expect(input.pantryItems, isEmpty);
    expect(input.groceryItems, isEmpty);
  });

  test(
      'loading pantry cannot publish an inflated complete shopping requirement',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    expect(f.groceries.isLoading, isTrue);
    expect(f.groceries.allItems, isEmpty);
    f.stock();
    expect(f.groceries.isLoading, isFalse);
    expect(f.groceries.allItems.single.quantity, '1 cup');
  });
  testWidgets(
      'pantry failure is visible in grocery UI and Retry restores the real shortage',
      (tester) async {
    final f = Fixture();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      f.close();
      await tester.pump();
    });
    await f.start(wait: false);
    f.stock();
    await tester
        .pumpWidget(MaterialApp(home: GroceryPage(repository: f.groceries)));
    await tester.pumpAndSettle();
    f.feeds.last.addError(StateError('private pantry endpoint'));
    await f.feeds.last.close();
    await tester.pumpAndSettle();
    expect(find.text('Pantry stock could not be loaded. Please retry.'),
        findsOneWidget);
    expect(f.groceries.allItems, isEmpty);
    expect(find.textContaining('private pantry'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(f.feeds.length, 2);
    expect(f.groceries.isLoading, isTrue);
    f.stock();
    await tester.pumpAndSettle();
    expect(f.groceries.error, isNull);
    expect(f.groceries.allItems.single.quantity, '1 cup');
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'delayed purchase callback cannot persist an inflated receipt after pantry denial',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    f.stock();
    final id = f.groceries.allItems.single.id!;
    f.feeds.last.addError(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'private'));
    await expectLater(f.groceries.setPurchased(id, true), throwsStateError);
    expect(
        (await f.db.doc('users/a/groceryLists/default/items/$id').get()).exists,
        isFalse);
  });
  test('obsolete pantry callback cannot recover a terminal feed without Retry',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    f.stock();
    f.feeds.last.addError(StateError('private'));
    f.feeds.last.add([PantryItem(name: 'rice', quantity: '50 cups')]);
    await Future<void>.delayed(Duration.zero);
    expect(f.pantry.error, isNotNull);
    expect(f.groceries.error, isNotNull);
    expect(f.groceries.allItems, isEmpty);
  });
  test('pantry A B A cannot publish stock from a cancelled account feed',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    f.stock();
    final first = f.feeds.single;
    f.ids.add('b');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    first.add([PantryItem(name: 'rice', quantity: '50 cups')]);
    expect(f.groceries.isLoading, isTrue);
    expect(f.groceries.allItems, isEmpty);
    f.ids.add('a');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    first.add([PantryItem(name: 'rice', quantity: '50 cups')]);
    expect(f.groceries.isLoading, isTrue);
    f.stock();
    expect(f.groceries.allItems.single.quantity, '1 cup');
    expect(f.groceries.allItems.single.sourceMealPaths.single,
        'users/a/mealPlans/plan/meals/meal');
  });
  test(
      'delayed delete cannot erase a purchase receipt while pantry stock is unknown',
      () async {
    final f = Fixture();
    addTearDown(f.close);
    await f.start();
    f.stock();
    final id = f.groceries.allItems.single.id!;
    await f.groceries.setPurchased(id, true);
    f.feeds.last.addError(StateError('private'));
    await expectLater(f.groceries.deleteItem(id), throwsStateError);
    expect(
        (await f.db.doc('users/a/groceryLists/default/items/$id').get()).exists,
        isTrue);
  });
}
