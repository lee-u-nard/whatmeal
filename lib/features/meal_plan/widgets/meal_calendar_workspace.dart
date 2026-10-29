import '../../../core/routing/meal_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/utils/week_calendar.dart';
import '../../meal/models/meal.dart';
import '../../meal/widgets/meal_status_badge.dart';
import '../../meal/widgets/meal_network_image.dart';
import '../../meal/widgets/meal_ingredients_panel.dart';
import '../../pantry/data/pantry_repository.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../models/calendar_plan_day.dart';

/// Monday–Sunday meal calendar workspace (real weekdays + dates).
///
/// Loads meals from saved/shared household plans whose dates fall in the
/// selected week. Create/AI actions are provided by the parent page.
class MealCalendarWorkspace extends StatefulWidget {
  const MealCalendarWorkspace({
    super.key,
    required this.onCreatePlan,
    required this.onGenerateGrocery,
    this.selectedDate,
    this.onDateSelected,
    this.repository,
  });

  final VoidCallback onCreatePlan;
  final VoidCallback onGenerateGrocery;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final SavedPlansRepository? repository;

  @override
  State<MealCalendarWorkspace> createState() => _MealCalendarWorkspaceState();
}

class _MealCalendarWorkspaceState extends State<MealCalendarWorkspace> {
  SavedPlansRepository get _repo =>
      widget.repository ?? SavedPlansRepository.instance;
  late DateTime _weekMonday;
  late int _selectedDayIndex; // 0=Mon … 6=Sun

  @override
  void initState() {
    super.initState();
    final now = widget.selectedDate ?? DateTime.now();
    _weekMonday = WeekCalendar.mondayOf(now);
    _selectedDayIndex =
        widget.selectedDate == null ? 0 : WeekCalendar.dayIndexOf(now);
  }

  @override
  void didUpdateWidget(covariant MealCalendarWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final date = widget.selectedDate;
    if (date != null && date != oldWidget.selectedDate) {
      _weekMonday = WeekCalendar.mondayOf(date);
      _selectedDayIndex = WeekCalendar.dayIndexOf(date);
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _weekMonday = WeekCalendar.mondayOf(date);
      _selectedDayIndex = WeekCalendar.dayIndexOf(date);
    });
    widget.onDateSelected?.call(WeekCalendar.dateOnly(date));
  }

  DateTime get _selectedDate =>
      WeekCalendar.dateForDayIndex(_weekMonday, _selectedDayIndex);

  List<_CalendarMeal> _mealsForWeek(List<SavedMealPlan> plans) {
    final out = <_CalendarMeal>[];
    final seen = <(String, String)>{};
    for (final plan in plans) {
      final path = plan.sourcePath;
      if (path == null || path.isEmpty || plan.startDate == null) continue;
      for (final meal in plan.activeMeals) {
        final date = plan.dateForMeal(meal);
        if (WeekCalendar.isInWeek(date, _weekMonday) &&
            seen.add((path, meal.id))) {
          out.add(_CalendarMeal(plan: plan, meal: meal, date: date));
        }
      }
    }
    // Keep all saved meals, with the newest plans first for each day and type.
    out.sort((a, b) {
      final byDay = a.date.compareTo(b.date);
      if (byDay != 0) return byDay;
      final byType = a.meal.type.compareTo(b.meal.type);
      if (byType != 0) return byType;
      final aCreated =
          a.plan.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreated =
          b.plan.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreated.compareTo(aCreated);
    });
    return out;
  }

  List<_CalendarMeal> _mealsForSelectedDay(List<_CalendarMeal> weekMeals) {
    final day = WeekCalendar.dateOnly(_selectedDate);
    final forDay = weekMeals.where((m) => WeekCalendar.dateOnly(m.date) == day);
    final result = forDay.toList();
    const order = ['breakfast', 'lunch', 'dinner', 'snack', 'dessert'];
    result.sort((a, b) {
      final ai = order.indexOf(a.meal.type.toLowerCase());
      final bi = order.indexOf(b.meal.type.toLowerCase());
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });
    return result;
  }

  Future<void> _setStatus(_CalendarMeal item, MealStatus status) async {
    if (status == MealStatus.completed) {
      final problem = mealCookingProblem(item.meal, PantryRepository.instance,
          expectedScope: _repo.workspacePath);
      if (problem != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
    }
    if (!FamilyPermissions.canAcceptMeal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FamilyPermissions.denialMessage('update meal status')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final repo = _repo;
    final session = repo.sessionVersion;
    try {
      await repo.updateMealStatus(item.meal.id, status,
          planPath: item.plan.sourcePath, expectedSession: session);
    } catch (_) {
      if (mounted && session == repo.sessionVersion) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Meal status was not saved. Please retry.')));
      }
      return;
    }
    if (session != repo.sessionVersion) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${item.meal.title.isEmpty ? item.meal.type : item.meal.title} → ${status.label}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _openMeal(_CalendarMeal item) {
    context.push(mealRoute(item.meal.id, item.plan.sourcePath),
        extra: item.meal);
  }

  void _openFullPlan(SavedMealPlan plan) {
    context.push(
      '/generated-plan',
      extra: GeneratedPlanDraft.fromSaved(plan,
          selectedDate: _selectedDate,
          sourceSessionVersion: _repo.sessionVersion),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedMealPlan>>(
      valueListenable: _repo,
      builder: (context, plans, _) {
        final weekMeals = _mealsForWeek(plans);
        final dayMeals = _mealsForSelectedDay(weekMeals);
        final emptyPlans = calendarPlansForDay(plans, _selectedDate)
            .where((entry) => entry.meals.isEmpty);
        final weekEnd = _weekMonday.add(const Duration(days: 6));
        final isCurrentWeek = WeekCalendar.dateOnly(_weekMonday) ==
            WeekCalendar.mondayOf(DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: week range + navigation ───────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Meal Calendar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/saved-meal-plans'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.bookmark_outline, size: 16),
                  label: const Text('Saved',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous week',
                    onPressed: () => _selectDate(
                        _selectedDate.subtract(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_left,
                        color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          WeekCalendar.formatRange(_weekMonday, weekEnd),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          isCurrentWeek ? 'This week' : 'Planned week',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next week',
                    onPressed: () =>
                        _selectDate(_selectedDate.add(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_right,
                        color: AppColors.textPrimary),
                  ),
                  if (!isCurrentWeek)
                    TextButton(
                      onPressed: () => _selectDate(DateTime.now()),
                      child: const Text('Today',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Mon–Sun selector ──────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (index) {
                  final date = WeekCalendar.dateForDayIndex(_weekMonday, index);
                  final isSelected = _selectedDayIndex == index;
                  final isToday = WeekCalendar.dateOnly(date) ==
                      WeekCalendar.dateOnly(DateTime.now());
                  final count = weekMeals
                      .where((m) =>
                          WeekCalendar.dateOnly(m.date) ==
                          WeekCalendar.dateOnly(date))
                      .length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      key: ValueKey('calendar-day-${date.toIso8601String()}'),
                      onTap: () => _selectDate(date),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isToday
                                    ? AppColors.primary.withValues(alpha: 0.45)
                                    : AppColors.border),
                            width: isToday && !isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              WeekCalendar.shortDays[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              count == 0 ? '—' : '$count',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── Selected day heading ──────────────────────────────────────
            Text(
              '${WeekCalendar.weekdayName(_selectedDate)} · ${WeekCalendar.formatDayMonth(_selectedDate)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayMeals.isEmpty
                  ? 'No meals planned for this day'
                  : '${dayMeals.length} meal${dayMeals.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            // ── Day meal cards ────────────────────────────────────────────
            for (final entry in emptyPlans)
              Container(
                key: ValueKey('calendar-empty-plan:${entry.plan.sourcePath}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.plan.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('No dishes added for this day.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => _openFullPlan(entry.plan),
                            child: const Text('Edit plan'))),
                  ],
                ),
              ),
            if (dayMeals.isEmpty && emptyPlans.isEmpty)
              _EmptyDayCard(onCreatePlan: widget.onCreatePlan)
            else
              ...dayMeals.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DayMealCard(
                      key: ValueKey(
                          '${item.plan.sourcePath}:${item.meal.id}:${item.meal.title}:${item.meal.imageUrl}:${item.meal.imageSearchQuery}'),
                      item: item,
                      onOpen: () => _openMeal(item),
                      onAccept: () => _setStatus(item, MealStatus.accepted),
                      onComplete: () => _setStatus(item, MealStatus.completed),
                      onNotCompleted: () =>
                          _setStatus(item, MealStatus.notCompleted),
                      onEditPlan: () => _openFullPlan(item.plan),
                    ),
                  )),

            const SizedBox(height: 8),

            // ── Quick actions ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCreatePlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Create / Generate',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        weekMeals.isEmpty ? null : widget.onGenerateGrocery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('Grocery List',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CalendarMeal {
  const _CalendarMeal({
    required this.plan,
    required this.meal,
    required this.date,
  });

  final SavedMealPlan plan;
  final GeneratedMeal meal;
  final DateTime date;
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          const Text(
            'Nothing planned yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate with AI or create meals manually for this week. No random default meals are shown.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onCreatePlan,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create meal plan',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DayMealCard extends StatefulWidget {
  const _DayMealCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onAccept,
    required this.onComplete,
    required this.onNotCompleted,
    required this.onEditPlan,
  });

  final _CalendarMeal item;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onComplete;
  final VoidCallback onNotCompleted;
  final VoidCallback onEditPlan;

  @override
  State<_DayMealCard> createState() => _DayMealCardState();
}

class _DayMealCardState extends State<_DayMealCard> {
  @override
  Widget build(BuildContext context) {
    final meal = widget.item.meal;
    final title =
        meal.title.trim().isEmpty ? 'Untitled ${meal.type}' : meal.title;

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MealNetworkImage(
                        url: meal.imageUrl,
                        mealTitle: meal.title,
                        width: 64,
                        height: 64),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                meal.type,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Spacer(),
                            MealStatusBadge(status: meal.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (meal.prepTime.isNotEmpty) meal.prepTime,
                            if (meal.calories.isNotEmpty) meal.calories,
                            widget.item.plan.title,
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (meal.isPending || meal.isAccepted)
                    _ActionChip(
                      label: meal.isAccepted ? 'Accepted' : 'Accept',
                      icon: Icons.check_circle_outline,
                      onTap: meal.isAccepted ? null : widget.onAccept,
                      filled: meal.isAccepted,
                    ),
                  if (meal.isAccepted || meal.isCompleted)
                    _ActionChip(
                      label: meal.isCompleted ? 'Done' : 'Complete',
                      icon: Icons.done_all,
                      onTap: meal.isCompleted ? null : widget.onComplete,
                      filled: meal.isCompleted,
                    ),
                  if (meal.isAccepted)
                    _ActionChip(
                      label: 'Not Done',
                      icon: Icons.close,
                      onTap: widget.onNotCompleted,
                    ),
                  _ActionChip(
                    label: 'Edit plan',
                    icon: Icons.edit_calendar_outlined,
                    onTap: widget.onEditPlan,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: filled ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
