import '../../../core/utils/week_calendar.dart';
import 'saved_meal_plan.dart';

typedef CalendarPlanDay = ({SavedMealPlan plan, List<GeneratedMeal> meals});

/// Uses scheduled dates only; creation time is not a cooking date.
List<CalendarPlanDay> calendarPlansForDay(
    Iterable<SavedMealPlan> plans, DateTime selected) {
  final date = WeekCalendar.dateOnly(selected);
  final byPath = <String, SavedMealPlan>{
    for (final plan in plans)
      if (plan.sourcePath?.isNotEmpty == true) plan.sourcePath!: plan,
  };
  final result = <CalendarPlanDay>[];
  for (final plan in byPath.values) {
    if (plan.startDate == null) continue;
    final start = WeekCalendar.dateOnly(plan.startDate!);
    var end = plan.endDate == null
        ? DateTime(
            start.year, start.month, start.day + (plan.numberOfDays ?? 1) - 1)
        : WeekCalendar.dateOnly(plan.endDate!);
    if (end.isBefore(start)) end = start;
    final active = <String, GeneratedMeal>{
      for (final meal in plan.activeMeals) meal.id: meal,
    }.values;
    for (final meal in active) {
      final scheduled = plan.dateForMeal(meal);
      if (scheduled.isAfter(end)) end = scheduled;
    }
    final meals = active
        .where((meal) => WeekCalendar.dateOnly(plan.dateForMeal(meal)) == date)
        .toList();
    if ((!date.isBefore(start) && !date.isAfter(end)) || meals.isNotEmpty) {
      result.add((plan: plan, meals: meals));
    }
  }
  result.sort((a, b) {
    final title = a.plan.title.compareTo(b.plan.title);
    return title == 0
        ? a.plan.sourcePath!.compareTo(b.plan.sourcePath!)
        : title;
  });
  return result;
}

List<DateTime?> mealCalendarMonth(DateTime month) {
  final first = DateTime(month.year, month.month);
  final leading = first.weekday - DateTime.monday;
  final days = DateTime(month.year, month.month + 1, 0).day;
  final cells = ((leading + days + 6) ~/ 7) * 7;
  return List.generate(
      cells,
      (index) => index < leading || index >= leading + days
          ? null
          : DateTime(month.year, month.month, index - leading + 1));
}
