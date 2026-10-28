import '../../../core/services/ai/ingredient_restrictions.dart';
import '../../../core/utils/week_calendar.dart';
import '../../../core/utils/ingredient_matcher.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../profile/models/family_member.dart';

typedef HomeMeal = ({SavedMealPlan plan, GeneratedMeal meal});

bool matchesMealFilter(GeneratedMeal meal, String? filter) => switch (filter) {
      'pending' => meal.isPending,
      'accepted' => meal.isAccepted,
      'completed' => meal.isCompleted,
      'favorites' => meal.isFavorite,
      _ => meal.isCompleted ||
          meal.isNotCompleted ||
          meal.isFavorite ||
          meal.isAccepted,
    };

/// Recommendations use authorized saved recipes, with current participant
/// restrictions checked again instead of making an implicit paid AI request.
List<HomeMeal> homeRecommendations(
    List<SavedMealPlan> plans, List<FamilyMember> members, DateTime today) {
  final result = <HomeMeal>[];
  if (members.isEmpty) return result;
  final preferenceScores = <String, int>{};
  for (final plan in plans) {
    final participants = plan.familyMembers.isEmpty
        ? members
        : members
            .where((member) => plan.familyMembers.any((id) =>
                id == member.id ||
                id.toLowerCase() == member.name.toLowerCase() ||
                id.toLowerCase() == member.displayName.toLowerCase()))
            .toList();
    if (plan.familyMembers.isNotEmpty &&
        participants.length != plan.familyMembers.toSet().length) {
      continue;
    }
    for (final meal in plan.activeMeals) {
      if (meal.title.trim().isEmpty ||
          IngredientMatcher.allIngredients(
                  ingredients: meal.ingredients,
                  availableIngredients: meal.availableIngredients,
                  missingIngredients: meal.missingIngredients)
              .isEmpty ||
          (!meal.isPending && !meal.isAccepted) ||
          WeekCalendar.dateOnly(plan.dateForMeal(meal)) !=
              WeekCalendar.dateOnly(today)) {
        continue;
      }
      try {
        IngredientRestrictions.validate(meal.ingredients,
            participants.expand((member) => member.restrictions));
      } on FormatException {
        continue;
      }
      final description =
          '${meal.title} ${meal.ingredients.join(' ')}'.toLowerCase();
      preferenceScores['${plan.sourcePath}/${meal.id}'] = participants
          .expand((member) => member.preferences)
          .where((preference) =>
              preference.trim().isNotEmpty &&
              description.contains(preference.trim().toLowerCase()))
          .length;
      result.add((plan: plan, meal: meal));
    }
  }
  result.sort((a, b) {
    final favorite =
        (b.meal.isFavorite ? 1 : 0).compareTo(a.meal.isFavorite ? 1 : 0);
    return favorite != 0
        ? favorite
        : preferenceScores['${b.plan.sourcePath}/${b.meal.id}']!
            .compareTo(preferenceScores['${a.plan.sourcePath}/${a.meal.id}']!);
  });
  return result;
}
