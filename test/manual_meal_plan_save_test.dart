import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ValueNotifier<UserModel?> account;
  late ValueNotifier<FamilySpace?> household;
  late SavedPlansRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    account = ValueNotifier<UserModel?>(
      UserModel(id: 'manual-owner', name: 'Owner', email: 'owner@example.test'),
    );
    household = ValueNotifier<FamilySpace?>(null);
    repository = SavedPlansRepository(
      firestore: firestore,
      account: account,
      household: household,
      canEditShared: () => true,
    );
  });

  tearDown(() {
    repository.dispose();
    account.dispose();
    household.dispose();
  });

  test('manual plan and meal details persist under the signed-in user',
      () async {
    final start = DateTime(2026, 10, 19);
    final id = await repository.savePlan(
      MealPlan(
        id: '',
        title: 'Manual Family Dinners',
        startDate: start,
        endDate: start,
        numberOfDays: 1,
        mealTypes: const ['Dinner'],
        selectedMemberIds: const ['profile-1'],
        prioritizePantry: false,
        createdBy: 'manual-owner',
        status: 'saved',
      ),
      [
        Meal(
          id: 'manual-dinner-0',
          title: 'Vegetable rice bowl',
          mealType: 'Dinner',
          dayIndex: 0,
          prepTime: '15m',
          cookTime: '25m',
          servings: '4',
          calories: '450 kcal',
          protein: '18g',
          carbs: '62g',
          fats: '12g',
          ingredients: const [
            Ingredient(name: 'Rice', amount: '2 cups'),
            Ingredient(name: 'Carrots', amount: '1 cup'),
          ],
          instructions: const ['Cook rice.', 'Steam the vegetables.'],
          status: MealStatus.accepted,
        ),
      ],
    );

    final planPath = 'users/manual-owner/mealPlans/$id';
    final plan = (await firestore.doc(planPath).get()).data()!;
    final meal =
        (await firestore.doc('$planPath/meals/manual-dinner-0').get()).data()!;

    expect(plan['title'], 'Manual Family Dinners');
    expect((plan['startDate'] as Timestamp).toDate(), start);
    expect((plan['endDate'] as Timestamp).toDate(), start);
    expect(plan['mealTypes'], ['Dinner']);
    expect(plan['selectedMemberIds'], ['profile-1']);
    expect(plan['createdBy'], 'manual-owner');
    expect(meal['title'], 'Vegetable rice bowl');
    expect(meal['servings'], '4');
    expect(meal['cookTime'], '25m');
    expect(meal['ingredients'], [
      {'name': 'Rice', 'amount': '2 cups'},
      {'name': 'Carrots', 'amount': '1 cup'},
    ]);
    expect(meal['instructions'], ['Cook rice.', 'Steam the vegetables.']);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(repository.value.single.sourcePath, planPath);
    expect(repository.value.single.meals.single.title, 'Vegetable rice bowl');
  });

  test('new draft extends its dates to include later added meals', () async {
    final monday = DateTime(2026, 10, 19);
    final id = await repository.savePlan(
      MealPlan(
          id: '',
          title: 'Extended',
          startDate: monday,
          endDate: monday,
          numberOfDays: 1,
          selectedMemberIds: const ['profile-1']),
      [
        Meal(id: 'monday', title: 'Rice', dayIndex: 0),
        Meal(id: 'sunday', title: 'Soup', dayIndex: 6)
      ],
    );
    final data =
        (await firestore.doc('users/manual-owner/mealPlans/$id').get()).data()!;
    expect(data['numberOfDays'], 7);
    expect((data['startDate'] as Timestamp).toDate(), monday);
    expect((data['endDate'] as Timestamp).toDate(), DateTime(2026, 10, 25));
    expect(data['selectedMemberIds'], ['profile-1']);
  });

  test(
      'adding to a saved plan extends dates atomically and never shortens them',
      () async {
    final monday = DateTime(2026, 10, 19);
    final id = await repository.savePlan(
      MealPlan(
          id: '',
          title: 'Keep title',
          startDate: monday,
          endDate: monday,
          numberOfDays: 1,
          selectedMemberIds: const ['profile-1']),
      [Meal(id: 'original', title: 'Original', dayIndex: 0)],
    );
    final path = 'users/manual-owner/mealPlans/$id';
    for (final day in [1, 6, 2]) {
      await repository.editMeal(
          path,
          GeneratedMeal.fromCore(
              Meal(id: 'added-$day', title: 'Dish $day', dayIndex: day)));
      final data = (await firestore.doc(path).get()).data()!;
      final expectedDays = day == 1 ? 2 : 7;
      expect(data['numberOfDays'], expectedDays);
      expect((data['endDate'] as Timestamp).toDate(),
          monday.add(Duration(days: expectedDays - 1)));
      expect(data['title'], 'Keep title');
      expect(data['selectedMemberIds'], ['profile-1']);
    }
    expect(
        (await firestore.collection('$path/meals').get()).docs, hasLength(4));
    expect((await firestore.doc('$path/meals/original').get()).data()!['title'],
        'Original');
  });

  test('blank meal names are rejected before any Firestore write', () async {
    await expectLater(
      repository.savePlan(
        MealPlan(id: '', title: 'Incomplete', numberOfDays: 1),
        [Meal(id: 'blank', title: '  ')],
      ),
      throwsStateError,
    );
    expect(
      (await firestore.collection('users/manual-owner/mealPlans').get()).docs,
      isEmpty,
    );
  });

  test('only an explicitly requested empty draft can persist without meals',
      () async {
    final start = DateTime(2026, 10, 26);
    MealPlan plan(String status) => MealPlan(
        id: '',
        title: 'Unfinished week',
        startDate: start,
        endDate: DateTime(2026, 11, 1),
        numberOfDays: 7,
        mealTypes: const ['Breakfast', 'Lunch', 'Dinner'],
        status: status);
    await expectLater(repository.savePlan(plan('draft'), []), throwsStateError);
    await expectLater(
        repository.savePlan(plan('saved'), [], allowEmptyDraft: true),
        throwsStateError);
    final id =
        await repository.savePlan(plan('draft'), [], allowEmptyDraft: true);
    final parent = firestore.doc('users/manual-owner/mealPlans/$id');
    expect((await parent.get()).data()!['status'], 'draft');
    expect((await parent.collection('meals').get()).docs, isEmpty);
    await repository.editMeal(
        parent.path,
        GeneratedMeal.fromCore(
            Meal(id: 'dinner', title: 'Adobo', dayIndex: 2)));
    expect(
        (await parent.collection('meals').get()).docs.single.data()['dayIndex'],
        2);
    expect((await parent.get()).data()!['title'], 'Unfinished week');
  });

  test('editing a manual meal updates its existing plan instead of duplicating',
      () async {
    final start = DateTime(2026, 10, 19);
    final planId = await repository.savePlan(
      MealPlan(
        id: '',
        title: 'Manual Plan',
        startDate: start,
        numberOfDays: 1,
        mealTypes: const ['Dinner'],
        createdBy: 'manual-owner',
        status: 'saved',
      ),
      [
        Meal(
          id: 'manual-dinner-0',
          title: 'Original dish',
          mealType: 'Dinner',
          servings: '2',
          status: MealStatus.accepted,
          isFavorite: true,
          instructions: const ['Original instructions.'],
        ),
      ],
    );
    final path = 'users/manual-owner/mealPlans/$planId';
    final originalCreatedAt =
        (await firestore.doc('$path/meals/manual-dinner-0').get())
            .data()!['createdAt'];

    await repository.editMeal(
      path,
      const GeneratedMeal(
        id: 'manual-dinner-0',
        title: 'Updated dish',
        type: 'Dinner',
        prepTime: '',
        calories: '',
        badgeText: '',
        imageUrl: '',
        ingredients: ['2 cups rice'],
        macros: {'Protein': '12g'},
        servings: '3',
        cookTime: '20m',
        instructions: ['Updated instructions.'],
        status: MealStatus.accepted,
      ),
    );

    expect(
      (await firestore.collection('users/manual-owner/mealPlans').get())
          .docs
          .map((doc) => doc.id),
      [planId],
    );
    final updated =
        (await firestore.doc('$path/meals/manual-dinner-0').get()).data()!;
    expect(updated['title'], 'Updated dish');
    expect(updated['servings'], '3');
    expect(updated['cookTime'], '20m');
    expect(updated['protein'], '12g');
    expect(updated['instructions'], ['Updated instructions.']);
    expect(updated['status'], 'accepted');
    expect(updated['isFavorite'], isTrue);
    expect(updated['createdAt'], originalCreatedAt);
    expect(updated['ingredients'], [
      {'name': '2 cups rice', 'amount': ''}
    ]);
  });
}
