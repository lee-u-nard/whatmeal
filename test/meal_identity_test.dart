import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/routing/meal_route.dart';
import 'package:whatmeal/core/routing/notification_route.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';

void main() {
  test(
      'duplicate IDs stay within selected plan through favorite, status and replacement',
      () async {
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'a', name: 'A', email: 'a@test.invalid'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    addTearDown(() {
      repo.dispose();
      account.dispose();
      household.dispose();
    });
    for (final id in ['one', 'two']) {
      await db
          .doc('users/a/mealPlans/$id')
          .set({'title': id, 'createdAt': Timestamp.now()});
      await db
          .doc('users/a/mealPlans/$id/meals/same')
          .set(Meal(id: 'same', title: id).toFirestore());
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final session = repo.sessionVersion;
    const path = 'users/a/mealPlans/two';
    expect(
        resolveSavedMeal(repo.value,
            mealId: 'same',
            planPath: null,
            openedSession: session,
            currentSession: session),
        isNull);
    expect(
        resolveSavedMeal(repo.value,
                mealId: 'same',
                planPath: path,
                openedSession: session,
                currentSession: session)!
            .meal
            .title,
        'two');
    await expectLater(repo.toggleFavorite('same', true), throwsStateError);
    await repo.toggleFavorite('same', true,
        planPath: path, expectedSession: session);
    await repo.updateMealStatus('same', MealStatus.accepted,
        planPath: path, expectedSession: session);
    final replacement = await repo.replaceMeal(
        'same', GeneratedMeal.fromCore(Meal(id: 'next', title: 'Successor')),
        planPath: path, expectedSession: session);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final resolved = resolveSavedMeal(repo.value,
        mealId: 'same',
        planPath: path,
        openedSession: session,
        currentSession: session)!;
    expect(resolved.meal.id, replacement.id);
    await repo.toggleFavorite(resolved.meal.id, true,
        planPath: resolved.plan.sourcePath, expectedSession: session);
    final other =
        (await db.doc('users/a/mealPlans/one/meals/same').get()).data()!;
    expect(other['status'], 'pending');
    expect(other['isFavorite'], false);
    account.value = null;
    account.value = UserModel(id: 'a', name: 'A', email: 'a@test.invalid');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
        resolveSavedMeal(repo.value,
            mealId: 'same',
            planPath: path,
            openedSession: session,
            currentSession: repo.sessionVersion),
        isNull);
    await expectLater(
        repo.toggleFavorite('same', false,
            planPath: path, expectedSession: session),
        throwsStateError);
    await expectLater(
        repo.updateMealStatus('same', MealStatus.completed,
            planPath: path, expectedSession: session),
        throwsStateError);
    await expectLater(
        repo.replaceMeal('same', replacement,
            planPath: path, expectedSession: session),
        throwsStateError);
  });

  test('meal and notification routes preserve explicit plan identity', () {
    const path = 'families/shared/mealPlans/two';
    final route = mealRoute('same', path);
    expect(Uri.parse(route).path, '/meal/same');
    expect(Uri.parse(route).queryParameters['plan'], path);
    final notification =
        Uri.parse(notificationRoute({'mealId': 'same', 'planPath': path}));
    expect(notification.path, '/notification-target');
    expect(notification.queryParameters, {'plan': path, 'mealId': 'same'});
  });

  test('replacement cycles and missing successors fail closed', () {
    SavedMealPlan plan(List<GeneratedMeal> meals) => SavedMealPlan(
        id: 'p',
        title: 'P',
        dates: '',
        mealsCount: meals.length,
        estCost: '',
        familyMembers: [],
        meals: meals,
        sourcePath: 'users/a/mealPlans/p');
    final original = GeneratedMeal.fromCore(Meal(id: 'old', title: 'Old'))
        .copyWith(replacedByMealId: 'next');
    final next = GeneratedMeal.fromCore(Meal(id: 'next', title: 'Next'))
        .copyWith(replacedByMealId: 'old');
    for (final meals in [
      [original],
      [original, next]
    ]) {
      expect(
          resolveSavedMeal([plan(meals)],
              mealId: 'old',
              planPath: 'users/a/mealPlans/p',
              openedSession: 1,
              currentSession: 1),
          isNull);
    }
  });
}
