import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/generated_plan_persistence.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';

class _FirstCommitFailsFirestore extends FakeFirebaseFirestore {
  int commits = 0;

  @override
  WriteBatch batch() => _FirstCommitFailsBatch(super.batch(), () => ++commits);
}

class _FirstCommitFailsBatch implements WriteBatch {
  _FirstCommitFailsBatch(this.delegate, this.countCommit);
  final WriteBatch delegate;
  final int Function() countCommit;

  @override
  Future<void> commit() async {
    if (countCommit() == 1) {
      throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'private diagnostic content');
    }
    await delegate.commit();
  }

  @override
  void delete(DocumentReference document) => delegate.delete(document);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      delegate.set(document, data, options);

  @override
  void update(DocumentReference document, Map<String, dynamic> data) =>
      delegate.update(document, data);
}

UserModel _user(String id) =>
    UserModel(id: id, name: id, email: '$id@example.test');

GeneratedPlanDraft _draft() => GeneratedPlanDraft(
      meals: [
        GeneratedMeal.fromCore(Meal(
          id: 'generated-original-id',
          title: 'Original generated rice',
          subtitle: 'Original recipe description',
          cuisine: 'Filipino',
          mealType: 'Dinner',
          ingredients: const [Ingredient(name: 'Rice', amount: '1 cup')],
          instructions: const ['Cook the rice until tender.'],
          createdAt: DateTime(2026, 10, 19, 10),
        )),
      ],
      familyMembers: const ['Disposable participant'],
      selectedMemberIds: const ['profile-a'],
      cuisinePreferences: const ['Filipino'],
      numberOfDays: 1,
      startDate: DateTime(2026, 10, 19),
      title: 'Generated fixture',
      prioritizePantry: false,
    );

void main() {
  test(
      'failed initial write retains generated data; save-only retry persists it',
      () async {
    final db = _FirstCommitFailsFirestore();
    final account = ValueNotifier<UserModel?>(_user('a'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true);
    final generated = _draft();
    final session = repo.sessionVersion;
    final workspace = repo.workspacePath!;
    expect(workspace, 'users/a');
    Future<String> save(GeneratedPlanDraft draft) => repo.savePlan(
          MealPlan(
            id: '',
            title: draft.title!,
            startDate: draft.startDate,
            numberOfDays: draft.numberOfDays,
            mealTypes: draft.meals.map((meal) => meal.type).toSet().toList(),
            selectedMemberIds: draft.selectedMemberIds,
            cuisinePreferences: draft.cuisinePreferences,
            prioritizePantry: draft.prioritizePantry,
            createdBy: 'a',
            status: 'saved',
          ),
          draft.meals.map((meal) => meal.toCore()).toList(),
        );
    final retained = await persistGeneratedPlanDraft(
      draft: generated,
      sourceSession: session,
      currentSession: () => repo.sessionVersion,
      workspacePath: workspace,
      save: () => save(generated),
    );
    expect(retained, isNotNull);
    expect(retained!.initialSaveFailed, isTrue);
    expect(retained.planPath, isNull);
    expect(retained.sourceSessionVersion, session);
    expect(retained.meals.single, same(generated.meals.single));
    expect(retained.familyMembers, generated.familyMembers);
    expect(retained.selectedMemberIds, generated.selectedMemberIds);
    expect(retained.cuisinePreferences, generated.cuisinePreferences);
    expect(retained.prioritizePantry, isFalse);
    expect((await db.collection('users/a/mealPlans').get()).docs, isEmpty);

    // The editor already has these generated meals; only persistence is retried.
    final saved = await persistGeneratedPlanDraft(
      draft: retained,
      sourceSession: session,
      currentSession: () => repo.sessionVersion,
      workspacePath: workspace,
      save: () => save(retained),
    );
    expect(saved!.initialSaveFailed, isFalse);
    expect(saved.planPath, startsWith('users/a/mealPlans/'));
    final plan = (await db.doc(saved.planPath!).get()).data()!;
    expect(plan['selectedMemberIds'], ['profile-a']);
    expect(plan['mealTypes'], ['Dinner']);
    expect(plan['prioritizePantry'], isFalse);
    expect((plan['startDate'] as Timestamp).toDate(), generated.startDate);
    final meals = await db.collection('${saved.planPath}/meals').get();
    expect(meals.docs.single.id, 'generated-original-id');
    expect(meals.docs.single.data()['title'], generated.meals.single.title);
    expect(meals.docs.single.data()['instructions'],
        generated.meals.single.instructions);
    expect(meals.docs.single.data()['ingredients'], [
      {'name': 'Rice', 'amount': '1 cup'}
    ]);
    expect(meals.docs.single.data()['subtitle'], 'Original recipe description');
    expect(meals.docs.single.data()['cuisine'], 'Filipino');
    expect((meals.docs.single.data()['createdAt'] as Timestamp).toDate(),
        DateTime(2026, 10, 19, 10));
    expect(db.commits, 2);
    repo.dispose();
    account.dispose();
    household.dispose();
  });

  test('obsolete source session prevents the persistence call entirely',
      () async {
    var saves = 0;
    final result = await persistGeneratedPlanDraft(
        draft: _draft(),
        sourceSession: 1,
        currentSession: () => 2,
        workspacePath: 'users/a',
        save: () async {
          saves++;
          return 'p';
        });
    expect(result, isNull);
    expect(saves, 0);
  });

  for (final workspace in <String?>[null, '']) {
    test('missing workspace $workspace prevents persistence and draft exposure',
        () async {
      var saves = 0;
      final result = await persistGeneratedPlanDraft(
          draft: _draft(),
          sourceSession: 1,
          currentSession: () => 1,
          workspacePath: workspace,
          save: () async {
            saves++;
            return 'must-not-save';
          });
      expect(result, isNull);
      expect(saves, 0);
    });
  }

  for (final saveSucceeds in [true, false]) {
    test(
        'account/household change discards delayed ${saveSucceeds ? 'success' : 'failure'}',
        () async {
      var session = 1;
      final gate = Completer<String>();
      final save = persistGeneratedPlanDraft(
          draft: _draft(),
          sourceSession: session,
          currentSession: () => session,
          workspacePath: 'users/a',
          save: () => gate.future);
      session++;
      if (saveSucceeds) {
        gate.complete('persisted-for-a');
      } else {
        gate.completeError(StateError('private backend diagnostic'));
      }
      expect(await save, isNull,
          reason: 'No A draft may be opened under a newer workspace session.');
    });
  }

  test('A to B to A switching still rejects the old generated draft', () async {
    var session = 10;
    final gate = Completer<String>();
    final save = persistGeneratedPlanDraft(
        draft: _draft(),
        sourceSession: session,
        currentSession: () => session,
        workspacePath: 'users/a',
        save: () => gate.future);
    session++; // B
    session++; // A again, with a different source epoch
    gate.completeError(StateError('private backend diagnostic'));
    expect(await save, isNull);
  });

  test('invalid empty persistence identity remains explicitly unsaved',
      () async {
    final retained = await persistGeneratedPlanDraft(
        draft: _draft(),
        sourceSession: 1,
        currentSession: () => 1,
        workspacePath: 'users/a',
        save: () async => '');
    expect(retained!.initialSaveFailed, isTrue);
    expect(retained.planPath, isNull);
  });
}
