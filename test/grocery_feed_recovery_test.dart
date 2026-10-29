import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/grocery/pages/grocery_page.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));
void main() {
  test(
      'failed saved-plan dependency is visible in groceries and Retry reopens both feeds',
      () async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('users/a/groceryLists/default')
        .set({'createdAt': Timestamp.now()});
    await db
        .doc('users/a/groceryLists/default/items/milk')
        .set(GroceryItem(name: 'Milk', quantity: '1').toFirestore());
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'a', name: 'A', email: 'a@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final pantry = ValueNotifier<Map<String, List<PantryItem>>>({});
    final feeds = <StreamController<List<SavedMealPlan>>>[];
    final plans = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) {
          final c = StreamController<List<SavedMealPlan>>.broadcast(sync: true);
          feeds.add(c);
          return c.stream;
        });
    feeds.single.add([]);
    final ids = StreamController<String?>.broadcast(sync: true);
    final repo = GroceryRepository(
        firestore: db,
        authIds: ids.stream,
        household: household,
        plans: plans,
        pantry: pantry,
        pantryScope: () => null,
        canEdit: () => true);
    ids.add('a');
    await settle();
    expect(repo.allItems.single.name, 'Milk');
    feeds.single.addError(StateError('synthetic private plan failure'));
    await feeds.single.close();
    expect(repo.error, isNotNull,
        reason:
            'Incomplete meal requirements must not look like a complete shopping list');
    expect(repo.error, isNot(contains('synthetic private')));
    repo.retry();
    await settle();
    expect(feeds.length, 2);
    expect(repo.isLoading, true);
    feeds.last.add([]);
    await settle();
    expect(repo.error, isNull);
    expect(repo.allItems.single.name, 'Milk');
    expect(
        (await db.doc('users/a/groceryLists/default/items/milk').get()).exists,
        true);
    repo.dispose();
    plans.dispose();
    account.dispose();
    household.dispose();
    pantry.dispose();
    await ids.close();
    for (final c in feeds) {
      await c.close();
    }
  });
  testWidgets(
      'old remove and clear confirmations cannot mutate the newly active grocery list',
      (tester) async {
    for (final clear in [false, true]) {
      final db = FakeFirebaseFirestore();
      for (final uid in ['a', 'b']) {
        await db
            .doc('users/$uid/groceryLists/default')
            .set({'createdAt': Timestamp.now()});
        await db.doc('users/$uid/groceryLists/default/items/shared-id').set(
            GroceryItem(
                    name: 'Milk',
                    quantity: '1',
                    status: GroceryStatus.used,
                    checked: true)
                .toFirestore());
      }
      final ids = StreamController<String?>.broadcast(sync: true);
      final household = ValueNotifier<FamilySpace?>(null);
      final plans = ValueNotifier<List<SavedMealPlan>>([]);
      final pantry = ValueNotifier<Map<String, List<PantryItem>>>({});
      final repo = GroceryRepository(
          firestore: db,
          authIds: ids.stream,
          household: household,
          plans: plans,
          pantry: pantry,
          pantryScope: () => null,
          canEdit: () => true);
      ids.add('a');
      await tester.pumpWidget(MaterialApp(home: GroceryPage(repository: repo)));
      await tester.pumpAndSettle();
      await tester
          .tap(clear ? find.text('Clear Used') : find.byTooltip('Remove item'));
      await tester.pumpAndSettle();
      ids.add('b');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
              ElevatedButton, clear ? 'Clear Used' : 'Delete')));
      await tester.pumpAndSettle();
      for (final uid in ['a', 'b']) {
        expect(
            (await db
                    .doc('users/$uid/groceryLists/default/items/shared-id')
                    .get())
                .exists,
            true);
      }
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await ids.close();
      household.dispose();
      plans.dispose();
      pantry.dispose();
    }
  });
  testWidgets(
      'an open grocery editor cannot submit its old draft into B or a later A session',
      (tester) async {
    for (final returnToA in [false, true]) {
      final db = FakeFirebaseFirestore();
      for (final uid in ['a', 'b']) {
        await db
            .doc('users/$uid/groceryLists/default')
            .set({'createdAt': Timestamp.now()});
      }
      final ids = StreamController<String?>.broadcast(sync: true);
      final household = ValueNotifier<FamilySpace?>(null);
      final plans = ValueNotifier<List<SavedMealPlan>>([]);
      final pantry = ValueNotifier<Map<String, List<PantryItem>>>({});
      final repo = GroceryRepository(
          firestore: db,
          authIds: ids.stream,
          household: household,
          plans: plans,
          pantry: pantry,
          pantryScope: () => null,
          canEdit: () => true);
      ids.add('a');
      await tester.pumpWidget(MaterialApp(home: GroceryPage(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Item Name'), 'Old account draft');
      ids.add('b');
      if (returnToA) ids.add('a');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to List'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Your account or household changed. Close this editor and reopen it.'),
          findsOneWidget);
      for (final uid in ['a', 'b']) {
        expect(
            (await db.collection('users/$uid/groceryLists/default/items').get())
                .docs,
            isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      await ids.close();
      household.dispose();
      plans.dispose();
      pantry.dispose();
    }
  });
  test(
      'grocery item and parent terminal feeds reopen, publish safe failures, and dispose sources',
      () async {
    final db = FakeFirebaseFirestore();
    await db
        .doc('users/a/groceryLists/default')
        .set({'title': 'A', 'createdAt': Timestamp.now()});
    final ids = StreamController<String?>.broadcast(sync: true);
    final household = ValueNotifier<FamilySpace?>(null);
    final plans = ValueNotifier<List<SavedMealPlan>>([]);
    final pantry = ValueNotifier<Map<String, List<PantryItem>>>({});
    final parents = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
    final items = <StreamController<List<GroceryItem>>>[];
    final repo = GroceryRepository(
        firestore: db,
        authIds: ids.stream,
        household: household,
        plans: plans,
        pantry: pantry,
        pantryScope: () => null,
        canEdit: () => false,
        watchParents: (_) {
          final c =
              StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
                  sync: true);
          parents.add(c);
          return c.stream;
        },
        watchItems: (_) {
          final c = StreamController<List<GroceryItem>>.broadcast(sync: true);
          items.add(c);
          return c.stream;
        });
    ids.add('a');
    await settle();
    items.last.add([GroceryItem(name: 'A', quantity: '1')]);
    final published = <String?>[];
    repo.addListener(() => published.add(repo.error));
    items.last.addError(StateError('private diagnostic'));
    await items.last.close();
    expect(repo.value, isEmpty);
    expect(
        published.every((e) => e != null && !e.contains('private diagnostic')),
        true);
    repo.retry();
    await settle();
    items.last.add([GroceryItem(name: 'Recovered A', quantity: '2')]);
    expect(repo.allItems.single.name, 'Recovered A');
    expect(repo.error, isNull);
    parents.last.addError(StateError('private diagnostic'));
    await parents.last.close();
    expect(repo.error, isNotNull);
    expect(repo.activeList, isNull);
    expect(repo.value, isEmpty);
    repo.retry();
    await settle();
    items.last.add([GroceryItem(name: 'Recovered again', quantity: '3')]);
    expect(repo.error, isNull);
    expect(repo.allItems.single.name, 'Recovered again');
    repo.dispose();
    final count = items.length;
    ids.add('b');
    plans.value = [];
    pantry.value = {};
    expect(items.length, count);
    await ids.close();
    household.dispose();
    plans.dispose();
    pantry.dispose();
    for (final c in parents) {
      await c.close();
    }
    for (final c in items) {
      await c.close();
    }
  });
  test(
      'delayed successful or failing A initialization and add cannot attach or write after A B A',
      () async {
    for (final failure in [false, true]) {
      final db = FakeFirebaseFirestore();
      for (final uid in ['a', 'b']) {
        await db
            .doc('users/$uid/groceryLists/default')
            .set({'createdAt': Timestamp.now()});
      }
      final ids = StreamController<String?>.broadcast(sync: true);
      final household = ValueNotifier<FamilySpace?>(null);
      final plans = ValueNotifier<List<SavedMealPlan>>([]);
      final pantry = ValueNotifier<Map<String, List<PantryItem>>>({});
      final gate = Completer<void>();
      var count = 0;
      final paths = <String>[];
      final repo = GroceryRepository(
          firestore: db,
          authIds: ids.stream,
          household: household,
          plans: plans,
          pantry: pantry,
          pantryScope: () => null,
          canEdit: () => true,
          initialize: (_, __) async {
            if (count++ == 0) await gate.future;
          },
          watchItems: (col) {
            paths.add(col.path);
            return const Stream.empty();
          });
      ids.add('a');
      final add = repo
          .addMultipleItems([GroceryItem(name: 'Old A draft', quantity: '4')]);
      final assertion = expectLater(add, throwsStateError);
      ids.add('b');
      await settle();
      expect(repo.scopePath, 'users/b');
      ids.add('a');
      await settle();
      if (failure) {
        gate.completeError(StateError('private old failure'));
      } else {
        gate.complete();
      }
      await assertion;
      expect(repo.error, isNull);
      expect(paths.length, 2);
      expect(
          (await db.collection('users/a/groceryLists/default/items').get())
              .docs,
          isEmpty);
      expect(
          (await db.collection('users/b/groceryLists/default/items').get())
              .docs,
          isEmpty);
      repo.dispose();
      await ids.close();
      household.dispose();
      plans.dispose();
      pantry.dispose();
    }
  });
}
