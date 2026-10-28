import '../../../core/routing/meal_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_calendar.dart';
import '../../../core/widgets/listener_recovery_notice.dart';
import '../../profile/data/family_member_repository.dart';
import '../models/home_meals.dart';
import '../../family/data/family_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../meal_plan/data/saved_plans_repository.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../meal/widgets/meal_status_badge.dart';
import '../../meal/widgets/meal_network_image.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _calendarExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Shared Family Banner Indicator
        ValueListenableBuilder(
          valueListenable: FamilyRepository.instance,
          builder: (context, space, _) {
            if (space == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Active Family Space: ${space.name} (${space.members.length} members)',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/family-space'),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30)),
                      child: const Text('Manage',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // AI Meal Planner Banner Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(27, 42, 30, 0.1),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text(
                    'Smart Family Planner',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Generate a customized 5-day meal plan based on your family preferences and expiring pantry items.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/meal-plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text(
                    'Generate AI Plan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Quick Actions Row
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: PantryRepository.instance,
                builder: (context, pantryMap, _) {
                  final allItems =
                      pantryMap.values.expand((items) => items).toList();
                  final totalCount = allItems.length;
                  final expiringCount =
                      allItems.where((item) => item.isExpiringSoon).length;

                  final subtitle = totalCount == 0
                      ? 'Pantry is empty'
                      : (expiringCount > 0
                          ? '$totalCount item${totalCount > 1 ? 's' : ''} ($expiringCount expiring)'
                          : '$totalCount item${totalCount > 1 ? 's' : ''} in stock');

                  return _buildQuickActionCard(
                    context,
                    title: 'View Pantry',
                    subtitle: subtitle,
                    icon: Icons.kitchen,
                    color: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    onTap: () => context.go('/pantry'),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: SavedPlansRepository.instance,
                builder: (context, savedPlans, _) {
                  return _buildQuickActionCard(
                    context,
                    title: 'Saved Plans',
                    subtitle: '${savedPlans.length} plans saved',
                    icon: Icons.bookmarks_outlined,
                    color: AppColors.infoLight,
                    iconColor: AppColors.info,
                    onTap: () => context.push('/saved-meal-plans'),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // This Week overview — Mon–Sun schedule for the current calendar week
        ValueListenableBuilder<List<SavedMealPlan>>(
          valueListenable: SavedPlansRepository.instance,
          builder: (context, savedPlans, _) {
            final weekMonday = WeekCalendar.mondayOf(DateTime.now());
            final weekEnd = weekMonday.add(const Duration(days: 6));
            final weekEntries =
                <({SavedMealPlan plan, GeneratedMeal meal, DateTime date})>[];
            for (final plan in savedPlans) {
              if (plan.sourcePath?.isNotEmpty != true ||
                  plan.startDate == null) {
                continue;
              }
              for (final meal in plan.activeMeals) {
                final date = plan.dateForMeal(meal);
                if (WeekCalendar.isInWeek(date, weekMonday)) {
                  weekEntries.add((plan: plan, meal: meal, date: date));
                }
              }
            }
            final weekMeals = weekEntries.map((e) => e.meal).toList();
            final pending = weekMeals.where((m) => m.isPending).length;
            final accepted = weekMeals.where((m) => m.isAccepted).length;
            final completed = weekMeals.where((m) => m.isCompleted).length;
            final favorites = weekMeals.where((m) => m.isFavorite).length;
            final todayIndex = WeekCalendar.dayIndexOf(DateTime.now());

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This Week',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            WeekCalendar.formatRange(weekMonday, weekEnd),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        children: [
                          IconButton(
                            tooltip: _calendarExpanded
                                ? 'Compact calendar'
                                : 'Expand calendar',
                            onPressed: () => setState(
                                () => _calendarExpanded = !_calendarExpanded),
                            icon: Icon(_calendarExpanded
                                ? Icons.expand_less
                                : Icons.expand_more),
                          ),
                          TextButton(
                            onPressed: () => context.push('/meal-calendar'),
                            child: const Text(
                              'Calendar',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push('/household-dashboard'),
                            child: const Text(
                              'Household',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _weekStat(context, 'Pending', pending, AppColors.warning,
                          'pending'),
                      const SizedBox(width: 8),
                      _weekStat(context, 'Accepted', accepted,
                          AppColors.primary, 'accepted'),
                      const SizedBox(width: 8),
                      _weekStat(context, 'Done', completed, AppColors.info,
                          'completed'),
                      const SizedBox(width: 8),
                      _weekStat(context, 'Favorites', favorites,
                          AppColors.danger, 'favorites'),
                    ],
                  ),
                  if (_calendarExpanded) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Weekly Schedule',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(7, (day) {
                      final dayDate =
                          WeekCalendar.dateForDayIndex(weekMonday, day);
                      final dayMeals = weekEntries
                          .where((e) =>
                              WeekCalendar.dateOnly(e.date) ==
                              WeekCalendar.dateOnly(dayDate))
                          .toList();
                      final isToday = day == todayIndex;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primaryLight
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 44,
                              child: InkWell(
                                  onTap: () =>
                                      context.push(mealOverviewRoute(dayDate)),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        WeekCalendar.shortDays[day],
                                        style: TextStyle(
                                          color: isToday
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${dayDate.day}',
                                        style: TextStyle(
                                          color: isToday
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  )),
                            ),
                            Expanded(
                              child: dayMeals.isEmpty
                                  ? const Text(
                                      'No meals planned',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: dayMeals.map((entry) {
                                        final m = entry.meal;
                                        final label = m.title.trim().isEmpty
                                            ? m.type
                                            : m.title;
                                        return GestureDetector(
                                          onTap: () => context.push(
                                            mealRoute(
                                                m.id, entry.plan.sourcePath),
                                            extra: m,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.cardSurface,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: AppColors.border),
                                            ),
                                            child: Text(
                                              '${m.type}: $label',
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (weekMeals.isEmpty) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => context.go('/meal-plan'),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Create this week\'s plan',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Recommended Meals Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
                child: Text(
              'Recommended for Today',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            )),
            TextButton(
              onPressed: () => context.push('/saved-meal-plans'),
              child: const Text(
                'See All',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Dynamic Recommendations
        AnimatedBuilder(
          animation: Listenable.merge(
              [SavedPlansRepository.instance, FamilyMemberRepository.instance]),
          builder: (context, _) {
            final repository = SavedPlansRepository.instance;
            final profiles = FamilyMemberRepository.instance;
            if (repository.error != null || profiles.error != null) {
              return ListenerRecoveryNotice(
                  message: repository.error ?? profiles.error!,
                  label: 'Retry Recommendations',
                  onRetry: () {
                    repository.retry();
                    profiles.retry();
                  });
            }
            if (repository.isLoading || profiles.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = homeRecommendations(
                repository.value, profiles.members, DateTime.now());
            if (entries.isEmpty) {
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
                    const Icon(Icons.restaurant_menu,
                        color: AppColors.textMuted, size: 36),
                    const SizedBox(height: 10),
                    const Text(
                      'No Meal Recommendations',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Generate an AI meal plan or create your custom plan to see today\'s recommendations here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/meal-plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Plan Meals Now',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              );
            }

            final displayMeals = entries.take(4).toList();

            return Column(
              children: displayMeals.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMealCard(
                    context,
                    meal: entry.meal,
                    planPath: entry.plan.sourcePath,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _weekStat(BuildContext context, String label, int count, Color color,
      String filter) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(Uri(path: '/meal-history', queryParameters: {
          'filter': filter,
          'week': WeekCalendar.mondayOf(DateTime.now())
              .toIso8601String()
              .split('T')
              .first,
        }).toString()),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(
    BuildContext context, {
    required GeneratedMeal meal,
    required String? planPath,
  }) {
    final subtitle =
        '${meal.type} • ${meal.prepTime.isEmpty ? "Quick prep" : meal.prepTime}';
    final calories = meal.calories.isEmpty ? 'Balanced' : meal.calories;
    final badgeText = meal.badgeText.isEmpty ? 'Recommended' : meal.badgeText;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(27, 42, 30, 0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: MealNetworkImage(
                url: meal.imageUrl,
                mealTitle: meal.title,
                width: 56,
                height: 56,
              ),
            ),
            title: Text(
              meal.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    MealStatusBadge(status: meal.status, compact: true),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(calories,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () =>
                context.push(mealRoute(meal.id, planPath), extra: meal),
          )),
    );
  }
}
