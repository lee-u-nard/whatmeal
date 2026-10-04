import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/family/models/family_space.dart';

void main() {
  group('Problem 1: Meal Acceptance, Replacement, and Completion Lifecycle', () {
    test('MealStatus string parsing and legacy backwards compatibility', () {
      expect(MealStatus.fromString('pending'), MealStatus.pending);
      expect(MealStatus.fromString('accepted'), MealStatus.accepted);
      expect(MealStatus.fromString('completed'), MealStatus.completed);
      expect(MealStatus.fromString('done'), MealStatus.completed);
      expect(MealStatus.fromString('notCompleted'), MealStatus.notCompleted);
      expect(MealStatus.fromString('not_completed'), MealStatus.notCompleted);
      expect(MealStatus.fromString('skipped'), MealStatus.notCompleted);
      expect(MealStatus.fromString('replaced'), MealStatus.replaced);

      // Legacy fallback: null status with legacy accepted boolean
      expect(MealStatus.fromString(null, legacyAccepted: true), MealStatus.accepted);
      expect(MealStatus.fromString(null, legacyAccepted: false), MealStatus.pending);
    });

    test('Meal model lifecycle transitions and getters', () {
      final meal = Meal(
        id: 'meal_1',
        title: 'Chicken Tinola',
        mealType: 'Dinner',
        status: MealStatus.pending,
      );

      expect(meal.isPending, isTrue);
      expect(meal.isAccepted, isFalse);
      expect(meal.accepted, isFalse);

      final acceptedMeal = meal.copyWith(status: MealStatus.accepted);
      expect(acceptedMeal.isAccepted, isTrue);
      expect(acceptedMeal.accepted, isTrue);

      final completedMeal = acceptedMeal.copyWith(status: MealStatus.completed);
      expect(completedMeal.isCompleted, isTrue);

      final skippedMeal = acceptedMeal.copyWith(status: MealStatus.notCompleted);
      expect(skippedMeal.isNotCompleted, isTrue);
    });

    test('Replacement flow tracks old vs new active meal', () {
      // 1. Initial pending meal
      final original = GeneratedMeal(
        id: 'gen_orig',
        title: 'Pork Adobo',
        type: 'Dinner',
        prepTime: '30m',
        calories: '450 kcal',
        badgeText: 'Suggested',
        imageUrl: '',
        ingredients: ['Pork', 'Soy Sauce', 'Vinegar'],
        macros: const {},
        status: MealStatus.pending,
      );

      // 2. User replaces meal with AI suggestion
      final replacement = GeneratedMeal(
        id: 'gen_replacement',
        title: 'Chicken Sinigang',
        type: original.type,
        prepTime: '25m',
        calories: '380 kcal',
        badgeText: 'AI Replacement',
        imageUrl: '',
        ingredients: ['Chicken', 'Tamarind', 'Kangkong'],
        macros: const {},
        status: MealStatus.pending,
        replacedMealId: original.id,
      );

      final archivedOriginal = original.copyWith(
        status: MealStatus.replaced,
        replacedByMealId: replacement.id,
      );

      // 3. User accepts the newly generated meal
      final acceptedReplacement = replacement.copyWith(
        status: MealStatus.accepted,
      );

      final plan = SavedMealPlan(
        id: 'plan_1',
        title: 'Weekly Dinner Plan',
        dates: 'Oct 1 - Oct 5',
        mealsCount: 2,
        estCost: '\$25.00',
        familyMembers: ['user_1'],
        meals: [archivedOriginal, acceptedReplacement],
      );

      // Invariant: activeMeals only returns the replacement meal, NOT the archived original
      expect(plan.activeMeals.length, equals(1));
      expect(plan.activeMeals.first.id, equals('gen_replacement'));
      expect(plan.activeMeals.first.isAccepted, isTrue);

      expect(plan.replacedMeals.length, equals(1));
      expect(plan.replacedMeals.first.id, equals('gen_orig'));
      expect(plan.replacedMeals.first.isReplaced, isTrue);
      expect(plan.replacedMeals.first.replacedByMealId, equals('gen_replacement'));
    });
  });

  group('Problem 2: Household Owner and Authorized Member RBAC', () {
    test('Role capabilities align with permission matrix', () {
      // Owner capabilities
      const owner = FamilyRole.owner;
      expect(owner.canViewMealPlan, isTrue);
      expect(owner.canAcceptMeal, isTrue);
      expect(owner.canReplaceMeal, isTrue);
      expect(owner.canViewMembers, isTrue);
      expect(owner.canManagePantry, isTrue);
      expect(owner.canGenerateGroceryList, isTrue);
      expect(owner.canManageMembers, isTrue);
      expect(owner.canDeleteHousehold, isTrue);

      // Household Admin capabilities
      const admin = FamilyRole.admin;
      expect(admin.canViewMealPlan, isTrue);
      expect(admin.canAcceptMeal, isTrue);
      expect(admin.canReplaceMeal, isTrue);
      expect(admin.canViewMembers, isTrue);
      expect(admin.canManagePantry, isTrue);
      expect(admin.canGenerateGroceryList, isTrue);
      expect(admin.canManageMembers, isTrue);
      expect(admin.canDeleteHousehold, isFalse); // Non-owners cannot delete!

      // Family Member capabilities
      const member = FamilyRole.member;
      expect(member.canViewMealPlan, isTrue);
      expect(member.canAcceptMeal, isTrue);
      expect(member.canReplaceMeal, isTrue);
      expect(member.canViewMembers, isTrue);
      expect(member.canManagePantry, isTrue);
      expect(member.canGenerateGroceryList, isTrue);
      expect(member.canManageMembers, isFalse); // Basic members cannot kick/role-edit
      expect(member.canDeleteHousehold, isFalse); // Non-owners cannot delete!

      // View Only capabilities
      const viewOnly = FamilyRole.viewOnly;
      expect(viewOnly.canViewMealPlan, isTrue);
      expect(viewOnly.canAcceptMeal, isFalse);
      expect(viewOnly.canReplaceMeal, isFalse);
      expect(viewOnly.canViewMembers, isTrue);
      expect(viewOnly.canManagePantry, isFalse);
      expect(viewOnly.canGenerateGroceryList, isFalse);
      expect(viewOnly.canManageMembers, isFalse);
      expect(viewOnly.canDeleteHousehold, isFalse);
    });

    test('FamilySpace helper methods evaluate user permissions correctly', () {
      const space = FamilySpace(
        id: 'space_123',
        name: 'The Santos Family',
        inviteCode: 'WM-STOS1',
        members: [
          SharedSpaceMember(
            id: 'uid_owner',
            name: 'Maria (Parent)',
            email: 'maria@example.com',
            role: FamilyRole.owner,
          ),
          SharedSpaceMember(
            id: 'uid_member',
            name: 'Carlos (Teen)',
            email: 'carlos@example.com',
            role: FamilyRole.member,
          ),
        ],
      );

      // Owner queries
      expect(space.isOwner('uid_owner'), isTrue);
      expect(space.canManageMembers('uid_owner'), isTrue);
      expect(space.canDeleteHousehold('uid_owner'), isTrue);

      // Member queries
      expect(space.isOwner('uid_member'), isFalse);
      expect(space.canManageMembers('uid_member'), isFalse);
      expect(space.canDeleteHousehold('uid_member'), isFalse);

      // Unknown user
      expect(space.isOwner('uid_stranger'), isFalse);
      expect(space.canManageMembers('uid_stranger'), isFalse);
      expect(space.canDeleteHousehold('uid_stranger'), isFalse);
    });
  });
}
