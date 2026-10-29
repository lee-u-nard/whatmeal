import '../../features/meal_plan/models/saved_meal_plan.dart';

String mealOverviewRoute(DateTime date) =>
    Uri(path: '/meal-calendar', queryParameters: {
      'date': DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first,
    }).toString();

String mealCalendarRoute(DateTime date) =>
    Uri(path: '/meal-plan', queryParameters: {
      'date': DateTime(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first,
    }).toString();

String mealRoute(String mealId, String? planPath) => Uri(
      path: '/meal/${Uri.encodeComponent(mealId)}',
      queryParameters: planPath == null ? null : {'plan': planPath},
    ).toString();

/// Never resolve an ID by first-match order or follow links into another plan.
({SavedMealPlan plan, GeneratedMeal meal})? resolveSavedMeal(
  List<SavedMealPlan> plans, {
  required String mealId,
  required String? planPath,
  required int openedSession,
  required int currentSession,
}) {
  if (openedSession != currentSession) return null;
  final matches = plans
      .where((p) =>
          (planPath == null || p.sourcePath == planPath) &&
          p.meals.any((m) => m.id == mealId))
      .toList();
  if (matches.length != 1) return null;
  final plan = matches.single;
  var meal = plan.meals.singleWhere((m) => m.id == mealId);
  final seen = <String>{};
  while (meal.replacedByMealId?.isNotEmpty == true) {
    if (!seen.add(meal.id)) return null;
    final successors =
        plan.meals.where((m) => m.id == meal.replacedByMealId).toList();
    if (successors.length != 1) return null;
    meal = successors.single;
  }
  return (plan: plan, meal: meal);
}
