import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/saved_meal_plans_page.dart';
import 'package:whatmeal/features/meal/models/meal.dart';

class DelayedTransactionFirestore extends FakeFirebaseFirestore {
  final gate = Completer<void>();
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    await gate.future;
    return super
        .runTransaction(handler, timeout: timeout, maxAttempts: maxAttempts);
  }
}

UserModel user(String id) =>
    UserModel(id: id, name: id, email: '$id@example.test');
SavedMealPlan plan(String title) => SavedMealPlan(
    id: 'p',
    title: title,
    dates: '',
    mealsCount: 0,
    estCost: '',
    familyMembers: [],
    meals: [],
    sourcePath: 'users/a/mealPlans/p');
void main() {
  test(
      'a delayed meal edit transaction refuses writes after switching away and back',
      () async {
    final db = DelayedTransactionFirestore();
    await db
        .doc('users/a/mealPlans/p')
        .set({'title': 'A', 'createdAt': Timestamp.now()});
    final meal = db.doc('users/a/mealPlans/p/meals/m');
    await meal.set(Meal(id: 'm', title: 'Original A').toFirestore());
    final account = ValueNotifier<UserModel?>(user('a'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    final change = repo.editMeal('users/a/mealPlans/p',
        GeneratedMeal.fromCore(Meal(id: 'm', title: 'Obsolete draft')));
    final assertion = expectLater(change, throwsStateError);
    account.value = user('b');
    account.value = user('a');
    db.gate.complete();
    await assertion;
    expect((await meal.get()).data()!['title'], 'Original A');
    expect((await db.collection('users/b/mealPlans').get()).docs, isEmpty);
    repo.dispose();
    account.dispose();
    household.dispose();
  });
  test(
      'saved plan terminal error stays visible while healthy household feed updates; retry and ABA discard old feed',
      () async {
    final account = ValueNotifier<UserModel?>(user('a'));
    final household = ValueNotifier<FamilySpace?>(
        const FamilySpace(id: 'h', name: 'H', inviteCode: '', members: [
      SharedSpaceMember(id: 'a', name: 'A', email: '', role: FamilyRole.owner)
    ]));
    final feeds = <StreamController<List<SavedMealPlan>>>[];
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) {
          final c = StreamController<List<SavedMealPlan>>.broadcast(sync: true);
          feeds.add(c);
          return c.stream;
        });
    feeds[0].add([plan('Personal')]);
    feeds[1].add([]);
    expect(repo.isLoading, false);
    feeds[0].addError(StateError('private diagnostic'));
    await feeds[0].close();
    expect(repo.error, isNotNull);
    expect(repo.error, isNot(contains('private diagnostic')));
    expect(repo.value, isEmpty);
    feeds[1].add([plan('Healthy household')]);
    expect(repo.error, isNotNull);
    expect(repo.value.single.title, 'Healthy household');
    final sessionBeforeRetry = repo.sessionVersion;
    repo.retry();
    expect(repo.sessionVersion, sessionBeforeRetry,
        reason: 'A listener retry must not invalidate an unrelated draft');
    expect(feeds.length, 4);
    feeds[2].add([plan('Recovered')]);
    feeds[3].add([]);
    expect(repo.error, isNull);
    expect(repo.value.single.title, 'Recovered');
    account.value = user('b');
    account.value = user('a');
    feeds[2].add([plan('Late A')]);
    feeds[3].addError(StateError('late old error'));
    expect(repo.value, isEmpty);
    feeds[5].add([plan('New A')]);
    feeds[6].add([]);
    expect(repo.value.single.title, 'New A');
    expect(repo.error, isNull);
    repo.dispose();
    account.dispose();
    household.dispose();
    for (final c in feeds) {
      await c.close();
    }
  });
  testWidgets(
      'saved page exposes terminal error and operative Retry instead of only an empty state',
      (tester) async {
    final account = ValueNotifier<UserModel?>(user('a'));
    final household = ValueNotifier<FamilySpace?>(null);
    final feeds = <StreamController<List<SavedMealPlan>>>[];
    final repo = SavedPlansRepository(
        firestore: FakeFirebaseFirestore(),
        account: account,
        household: household,
        canEditShared: () => true,
        watch: (_) {
          final c = StreamController<List<SavedMealPlan>>.broadcast(sync: true);
          feeds.add(c);
          return c.stream;
        });
    feeds.single.addError(StateError('private diagnostic'));
    await feeds.single.close();
    await tester
        .pumpWidget(MaterialApp(home: SavedMealPlansPage(repository: repo)));
    expect(find.text('Retry Saved Plans'), findsOneWidget);
    expect(find.text('No Saved Meal Plans'), findsNothing);
    expect(find.textContaining('private diagnostic'), findsNothing);
    await tester.tap(find.text('Retry Saved Plans'));
    await tester.pump();
    expect(feeds.length, 2);
    feeds.last.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Retry Saved Plans'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    account.dispose();
    household.dispose();
    for (final c in feeds) {
      await c.close();
    }
  });
}
