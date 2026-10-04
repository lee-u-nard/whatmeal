import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';

void main() {
  group('Household Notifications & Recipient Filtering Tests', () {
    test('Household recipient determination respects household boundaries', () {
      final space = FamilySpace(
        id: 'fam_123',
        name: 'The Smiths',
        inviteCode: 'SMTH99',
        members: [
          const SharedSpaceMember(
            id: 'owner_uid_1',
            name: 'Alice',
            email: 'alice@example.com',
            role: FamilyRole.owner,
          ),
          const SharedSpaceMember(
            id: 'member_uid_2',
            name: 'Bob',
            email: 'bob@example.com',
            role: FamilyRole.member,
          ),
          const SharedSpaceMember(
            id: 'member_uid_3',
            name: 'Charlie',
            email: 'charlie@example.com',
            role: FamilyRole.viewOnly,
          ),
        ],
      );

      // Verify all household members are present
      final allRecipients = space.members.map((m) => m.id).toSet();
      expect(allRecipients, containsAll(['owner_uid_1', 'member_uid_2', 'member_uid_3']));
      expect(allRecipients.length, 3);

      // When Alice performs an action and excludes herself:
      final otherRecipients = Set<String>.from(allRecipients)..remove('owner_uid_1');
      expect(otherRecipients, containsAll(['member_uid_2', 'member_uid_3']));
      expect(otherRecipients.contains('owner_uid_1'), isFalse);
      expect(otherRecipients.contains('stranger_uid_4'), isFalse);
    });

    test('AppNotification serializes and deserializes accurately', () {
      final notif = AppNotification(
        id: 'notif_1',
        title: 'Meal Accepted 🍽️',
        body: 'Alice accepted Chicken Adobo for Dinner.',
        type: AppNotificationType.general,
        createdAt: DateTime(2026, 9, 30, 12, 0),
        relatedPlanId: 'plan_abc',
        read: false,
      );

      final map = notif.toFirestore();
      expect(map['title'], 'Meal Accepted 🍽️');
      expect(map['body'], 'Alice accepted Chicken Adobo for Dinner.');
      expect(map['relatedPlanId'], 'plan_abc');
      expect(map['read'], false);
    });
  });

  group('Real-Time Meal Status & Reactive Detail Resolution Tests', () {
    test('SavedMealPlan correctly updates and finds active vs replaced meals', () {
      final originalMeal = GeneratedMeal(
        id: 'meal_1',
        title: 'Sinigang na Baboy',
        type: 'Dinner',
        dayIndex: 0,
        prepTime: '30m',
        calories: '450',
        badgeText: 'Home Cooked',
        imageUrl: '',
        ingredients: ['Pork', 'Tamarind', 'Kangkong'],
        macros: {'Protein': '30g', 'Carbs': '10g', 'Fats': '15g'},
        status: MealStatus.replaced,
        replacedByMealId: 'meal_2',
      );

      final replacementMeal = GeneratedMeal(
        id: 'meal_2',
        title: 'Chicken Adobo',
        type: 'Dinner',
        dayIndex: 0,
        prepTime: '25m',
        calories: '400',
        badgeText: 'AI Replacement',
        imageUrl: '',
        ingredients: ['Chicken', 'Soy Sauce', 'Vinegar', 'Garlic'],
        macros: {'Protein': '35g', 'Carbs': '8g', 'Fats': '12g'},
        status: MealStatus.accepted,
        replacedMealId: 'meal_1',
      );

      final plan = SavedMealPlan(
        id: 'plan_1',
        title: 'Weekly Family Menu',
        dates: 'Sep 29 - Oct 5',
        mealsCount: 2,
        estCost: '₱1,200',
        startDate: DateTime(2026, 9, 29),
        endDate: DateTime(2026, 10, 5),
        familyMembers: ['Alice', 'Bob'],
        meals: [originalMeal, replacementMeal],
        createdAt: DateTime.now(),
      );

      // Active meals filter should only include non-replaced meals
      expect(plan.activeMeals.length, 1);
      expect(plan.activeMeals.first.id, 'meal_2');
      expect(plan.activeMeals.first.title, 'Chicken Adobo');
      expect(plan.activeMeals.first.isAccepted, isTrue);

      // Status helpers
      expect(originalMeal.isReplaced, isTrue);
      expect(replacementMeal.isAccepted, isTrue);
    });
  });
}
