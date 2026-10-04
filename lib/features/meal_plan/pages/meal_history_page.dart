import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../../meal/widgets/meal_status_badge.dart';

/// Shows previously completed, skipped, and favorited meals across saved plans.
class MealHistoryPage extends StatelessWidget {
  const MealHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedMealPlan>>(
      valueListenable: SavedPlansRepository.instance,
      builder: (context, plans, _) {
        final history = plans
            .expand((p) => p.activeMeals.map((m) => (plan: p, meal: m)))
            .where((e) =>
                e.meal.isCompleted ||
                e.meal.isNotCompleted ||
                e.meal.isFavorite ||
                e.meal.isAccepted)
            .toList()
          ..sort((a, b) {
            // Favorites and completed first
            final aScore = (a.meal.isFavorite ? 4 : 0) +
                (a.meal.isCompleted ? 3 : 0) +
                (a.meal.isAccepted ? 1 : 0);
            final bScore = (b.meal.isFavorite ? 4 : 0) +
                (b.meal.isCompleted ? 3 : 0) +
                (b.meal.isAccepted ? 1 : 0);
            return bScore.compareTo(aScore);
          });

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Meal History',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          body: history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'No Meal History Yet',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accepted, completed, skipped, and favorite meals from your saved plans will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/meal-plan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('Plan Meals',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    final meal = entry.meal;
                    return InkWell(
                      onTap: () => context.push(
                        '/meal/${meal.id}',
                        extra: meal,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                meal.isFavorite
                                    ? Icons.favorite
                                    : Icons.restaurant,
                                color: meal.isFavorite
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meal.title.isEmpty
                                        ? 'Untitled ${meal.type}'
                                        : meal.title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${entry.plan.title} · ${meal.type}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            MealStatusBadge(
                              status: meal.status,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
