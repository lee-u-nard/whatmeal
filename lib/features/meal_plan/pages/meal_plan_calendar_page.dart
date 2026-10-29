import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/meal_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_calendar.dart';
import '../../../core/widgets/listener_recovery_notice.dart';
import '../../meal/widgets/meal_network_image.dart';
import '../../meal/widgets/meal_status_badge.dart';
import '../data/saved_plans_repository.dart';
import '../models/calendar_plan_day.dart';
import '../models/saved_meal_plan.dart';

class MealPlanCalendarPage extends StatefulWidget {
  const MealPlanCalendarPage(
      {super.key, this.initialDate, this.repository, this.now});
  final DateTime? initialDate;
  final SavedPlansRepository? repository;
  final DateTime Function()? now;

  @override
  State<MealPlanCalendarPage> createState() => _MealPlanCalendarPageState();
}

class _MealPlanCalendarPageState extends State<MealPlanCalendarPage> {
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  SavedPlansRepository get _repo =>
      widget.repository ?? SavedPlansRepository.instance;
  late DateTime _selected;
  late DateTime _month;
  DateTime get _today => WeekCalendar.dateOnly((widget.now ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    _select(widget.initialDate ?? _today, rebuild: false);
  }

  @override
  void didUpdateWidget(MealPlanCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null &&
        widget.initialDate != oldWidget.initialDate) {
      _select(widget.initialDate!, rebuild: false);
    }
  }

  void _select(DateTime date, {bool rebuild = true}) {
    void update() {
      _selected = WeekCalendar.dateOnly(date);
      _month = DateTime(date.year, date.month);
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
  }

  void _moveMonth(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    final days = DateTime(target.year, target.month + 1, 0).day;
    _select(DateTime(target.year, target.month, _selected.day.clamp(1, days)));
  }

  String _dateLabel(DateTime date) =>
      '${WeekCalendar.weekdayName(date)}, ${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Meal Plan Calendar')),
        body: ValueListenableBuilder<List<SavedMealPlan>>(
          valueListenable: _repo,
          builder: (context, plans, _) {
            final session = _repo.sessionVersion;
            final selectedPlans = calendarPlansForDay(plans, _selected);
            final undated =
                plans.where((plan) => plan.startDate == null).length;
            return Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _moveMonth(-1),
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                      child: Text('${_months[_month.month - 1]} ${_month.year}',
                          key: const ValueKey('meal-calendar-month'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: AppColors.primary))),
                  IconButton(
                      tooltip: 'Next month',
                      onPressed: () => _moveMonth(1),
                      icon: const Icon(Icons.chevron_right)),
                ]),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => _select(_today),
                        child: const Text('Today'))),
                if (_repo.error != null)
                  ListenerRecoveryNotice(
                      message: _repo.error!,
                      onRetry: _repo.retry,
                      label: 'Retry Calendar'),
                if (_repo.isLoading)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator())),
                Row(children: [
                  for (final day in WeekCalendar.shortDays)
                    Expanded(
                        child: Text(day,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)))
                ]),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio:
                      MediaQuery.sizeOf(context).width > 600 ? 1.5 : .72,
                  children: [
                    for (final date in mealCalendarMonth(_month))
                      if (date == null) const SizedBox() else _day(date, plans)
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Only saved meal plans appear here.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (undated > 0)
                  TextButton(
                      onPressed: () => context.push('/saved-meal-plans'),
                      child: Text(
                          '$undated saved plan(s) have no scheduled date. Review saved plans.')),
                const SizedBox(height: 16),
                Text(_dateLabel(_selected),
                    key: const ValueKey('meal-calendar-selected-date'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (selectedPlans.isEmpty &&
                    !_repo.isLoading &&
                    _repo.error == null)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No meal plans are scheduled for this day.',
                          textAlign: TextAlign.center)),
                for (final entry in selectedPlans) ...[
                  Row(children: [
                    Expanded(
                        child: Text(entry.plan.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16))),
                    TextButton(
                        onPressed: () {
                          if (_repo.sessionVersion != session) return;
                          context.push('/generated-plan',
                              extra: GeneratedPlanDraft.fromSaved(entry.plan,
                                  selectedDate: _selected,
                                  sourceSessionVersion: session));
                        },
                        child: const Text('Open plan'))
                  ]),
                  if (entry.meals.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                            'This plan covers this date; no meals are recorded for this day.')),
                  for (final meal in entry.meals)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppColors.cardSurface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.border)),
                          child: ListTile(
                            key: ValueKey(
                                'calendar-meal:${entry.plan.sourcePath}:${meal.id}'),
                            contentPadding: const EdgeInsets.all(12),
                            leading: SizedBox(
                                width: 56,
                                height: 56,
                                child: MealNetworkImage(
                                    url: meal.imageUrl,
                                    mealTitle: meal.title,
                                    width: 56,
                                    height: 56,
                                    borderRadius: BorderRadius.circular(10))),
                            title: Text(meal.title.isEmpty
                                ? 'Untitled ${meal.type}'
                                : meal.title),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${meal.type} · ${WeekCalendar.formatDayMonth(_selected)}'),
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: MealStatusBadge(
                                              status: meal.status))),
                                ]),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (_repo.sessionVersion != session) return;
                              context.push(
                                  mealRoute(meal.id, entry.plan.sourcePath));
                            },
                          ),
                        )),
                ],
              ]),
            ));
          },
        ),
      );

  Widget _day(DateTime date, List<SavedMealPlan> plans) {
    final entries = calendarPlansForDay(plans, date);
    final count =
        entries.fold<int>(0, (sum, entry) => sum + entry.meals.length);
    final selected = date == _selected;
    return Semantics(
      button: true,
      selected: selected,
      label: '${_dateLabel(date)}: ${entries.length} plans, $count meals',
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.cardSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: selected || date == _today
                    ? AppColors.primary
                    : AppColors.border)),
        child: InkWell(
          key: ValueKey(
              'meal-calendar-day-${date.toIso8601String().split('T').first}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _select(date),
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${date.day}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary)),
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.restaurant_menu,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text('${count == 0 ? entries.length : count}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.primary)),
                  ]),
                ],
              ])),
        ),
      ),
    );
  }
}
