import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/utils/week_calendar.dart';
import '../../../core/services/unsplash_service.dart';
import '../../meal/models/meal.dart';
import '../../meal/widgets/meal_status_badge.dart';
import '../../meal/widgets/meal_network_image.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';

/// Monday–Sunday meal calendar workspace (real weekdays + dates).
///
/// Loads meals from saved/shared household plans whose dates fall in the
/// selected week. Create/AI actions are provided by the parent page.
class MealCalendarWorkspace extends StatefulWidget {
  const MealCalendarWorkspace({
    super.key,
    required this.onCreatePlan,
    required this.onGenerateGrocery,
  });

  final VoidCallback onCreatePlan;
  final VoidCallback onGenerateGrocery;

  @override
  State<MealCalendarWorkspace> createState() => _MealCalendarWorkspaceState();
}

class _MealCalendarWorkspaceState extends State<MealCalendarWorkspace> {
  late DateTime _weekMonday;
  late int _selectedDayIndex; // 0=Mon … 6=Sun

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekMonday = WeekCalendar.mondayOf(now);
    _selectedDayIndex = WeekCalendar.dayIndexOf(now);
  }

  DateTime get _selectedDate =>
      WeekCalendar.dateForDayIndex(_weekMonday, _selectedDayIndex);

  List<_CalendarMeal> _mealsForWeek(List<SavedMealPlan> plans) {
    final out = <_CalendarMeal>[];
    for (final plan in plans) {
      for (final meal in plan.activeMeals) {
        final date = plan.dateForMeal(meal);
        if (WeekCalendar.isInWeek(date, _weekMonday)) {
          out.add(_CalendarMeal(plan: plan, meal: meal, date: date));
        }
      }
    }
    // Prefer most recently created plan when same day+type collide.
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
    // Dedupe by meal type keeping first (newest plan due to sort).
    final seenTypes = <String>{};
    final result = <_CalendarMeal>[];
    for (final m in forDay) {
      final key = m.meal.type.toLowerCase();
      if (seenTypes.add(key)) result.add(m);
    }
    const order = ['breakfast', 'lunch', 'dinner', 'snack', 'dessert'];
    result.sort((a, b) {
      final ai = order.indexOf(a.meal.type.toLowerCase());
      final bi = order.indexOf(b.meal.type.toLowerCase());
      return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
    });
    return result;
  }

  Future<void> _setStatus(_CalendarMeal item, MealStatus status) async {
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
    await SavedPlansRepository.instance.updateMealStatus(item.meal.id, status);
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
    context.push('/meal/${item.meal.id}', extra: item.meal);
  }

  void _openFullPlan(SavedMealPlan plan) {
    final days = plan.meals.isEmpty
        ? 7
        : plan.meals.map((m) => m.dayIndex).reduce((a, b) => a > b ? a : b) + 1;
    context.push(
      '/generated-plan',
      extra: GeneratedPlanDraft(
        meals: List<GeneratedMeal>.from(plan.meals),
        familyMembers: List<String>.from(plan.familyMembers),
        numberOfDays: days.clamp(1, 7),
        startDate: plan.weekStart,
        title: plan.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedMealPlan>>(
      valueListenable: SavedPlansRepository.instance,
      builder: (context, plans, _) {
        final weekMeals = _mealsForWeek(plans);
        final dayMeals = _mealsForSelectedDay(weekMeals);
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
                    onPressed: () => setState(() {
                      _weekMonday =
                          _weekMonday.subtract(const Duration(days: 7));
                    }),
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
                    onPressed: () => setState(() {
                      _weekMonday = _weekMonday.add(const Duration(days: 7));
                    }),
                    icon: const Icon(Icons.chevron_right,
                        color: AppColors.textPrimary),
                  ),
                  if (!isCurrentWeek)
                    TextButton(
                      onPressed: () => setState(() {
                        final now = DateTime.now();
                        _weekMonday = WeekCalendar.mondayOf(now);
                        _selectedDayIndex = WeekCalendar.dayIndexOf(now);
                      }),
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
                      onTap: () => setState(() => _selectedDayIndex = index),
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
            if (dayMeals.isEmpty)
              _EmptyDayCard(onCreatePlan: widget.onCreatePlan)
            else
              ...dayMeals.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DayMealCard(
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
  String? _imageUrl;
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (_fetched) return;
    _fetched = true;
    final meal = widget.item.meal;
    if (meal.imageUrl.isNotEmpty) {
      if (mounted) setState(() => _imageUrl = meal.imageUrl);
      return;
    }
    final photo = await UnsplashService.instance.fetchMealImage(
      meal.imageSearchQuery,
      mealTitle: meal.title,
    );
    if (photo != null && mounted) {
      setState(() => _imageUrl = photo.smallUrl);
    }
  }

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
                    child: _imageUrl != null
                        ? MealNetworkImage(
                            url: _imageUrl!,
                            width: 64,
                            height: 64,
                          )
                        : _placeholder(),
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

  Widget _placeholder() => Container(
        width: 64,
        height: 64,
        color: AppColors.primaryLight,
        child: const Icon(Icons.restaurant, color: AppColors.primary),
      );
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
