import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/meal_route.dart';
import '../../meal/pages/meal_detail_page.dart';
import '../../meal_plan/data/saved_plans_repository.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../meal_plan/pages/generated_meal_plan_page.dart';

/// Resolve IDs only within the current account's authorized, loaded plan feed.
SavedMealPlan? resolveNotificationPlan(List<SavedMealPlan> plans,
    {required String? planPath, required String? planId}) {
  if (planPath == null && planId == null) return null;
  final matches = plans.where((plan) =>
      (planPath == null || plan.sourcePath == planPath) &&
      (planId == null || plan.id == planId));
  return matches.length == 1 ? matches.single : null;
}

/// A notification never opens an empty generated draft or guesses among plans.
class NotificationTargetPage extends StatefulWidget {
  const NotificationTargetPage(
      {super.key, this.planPath, this.planId, this.mealId, this.repository});
  final String? planPath, planId, mealId;
  final SavedPlansRepository? repository;

  @override
  State<NotificationTargetPage> createState() => _NotificationTargetPageState();
}

class _NotificationTargetPageState extends State<NotificationTargetPage> {
  late final SavedPlansRepository _repo =
      widget.repository ?? SavedPlansRepository.instance;
  late final int _session = _repo.sessionVersion;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<SavedMealPlan>>(
        valueListenable: _repo,
        builder: (context, plans, _) {
          final active = _session == _repo.sessionVersion;
          final plan = active
              ? resolveNotificationPlan(plans,
                  planPath: widget.planPath, planId: widget.planId)
              : null;
          if (active && _repo.error == null && plan != null) {
            if (widget.mealId != null) {
              final resolved = resolveSavedMeal(plans,
                  mealId: widget.mealId!,
                  planPath: plan.sourcePath,
                  openedSession: _session,
                  currentSession: _repo.sessionVersion);
              if (resolved != null) {
                return MealDetailPage(
                    mealId: resolved.meal.id,
                    planPath: resolved.plan.sourcePath);
              }
            } else {
              return GeneratedMealPlanPage(
                  draft: GeneratedPlanDraft.fromSaved(plan));
            }
          }
          final loading = active && _repo.error == null && _repo.isLoading;
          return Scaffold(
            appBar: AppBar(
                title: const Text('Notification'),
                leading: BackButton(onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/notifications');
                  }
                })),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: loading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  !active
                                      ? 'Your account or household changed. Reopen notifications.'
                                      : _repo.error != null
                                          ? 'This notification could not be loaded. Please retry.'
                                          : 'This item is no longer available. It may have been deleted or access was removed.',
                                  textAlign: TextAlign.center),
                              if (active && _repo.error != null)
                                TextButton(
                                    onPressed: _repo.retry,
                                    child: const Text('Retry')),
                              TextButton(
                                  onPressed: () => context.go('/notifications'),
                                  child: const Text('Back to notifications')),
                            ],
                          ))),
          );
        },
      );
}
