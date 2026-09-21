import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/meal_plan_repository.dart';
import '../models/meal_plan.dart';

class SavedMealPlansPage extends StatelessWidget {
  const SavedMealPlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Saved Meal Plans',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<MealPlanRepository>(
        builder: (context, repo, _) {
          final plans = repo.savedPlans;

          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark_border, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No Saved Meal Plans Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Generate a custom meal plan using our AI planner to save and reuse meals for your family.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.go('/meal-plan'),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Create Meal Plan'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Reload and schedule previous generated plans your family loved.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              for (final plan in plans) ...[
                _buildSavedPlanCard(context: context, plan: plan, repo: repo),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavedPlanCard({
    required BuildContext context,
    required MealPlan plan,
    required MealPlanRepository repo,
  }) {
    final startStr = plan.startDate != null
        ? '${plan.startDate!.month}/${plan.startDate!.day}'
        : 'Day 1';
    final endStr = plan.endDate != null
        ? '${plan.endDate!.month}/${plan.endDate!.day}'
        : 'Day ${plan.numberOfDays}';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                onPressed: () => _confirmDelete(context, repo, plan),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$startStr - $endStr • ${plan.numberOfDays} Days',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.estimatedCost ?? '\$85.00 est.',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                plan.mealTypes.join(', '),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () async {
                final meals = await repo.getMealsForPlan(plan.id);
                if (meals.isNotEmpty && context.mounted) {
                  context.push('/meal/${meals.first.id}?planId=${plan.id}');
                } else if (context.mounted) {
                  context.push('/meal/sample_1?planId=${plan.id}');
                }
              },
              child: const Text('View Plan Meals'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, MealPlanRepository repo, MealPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meal Plan?'),
        content: Text('Are you sure you want to delete "${plan.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              repo.deletePlan(plan.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
