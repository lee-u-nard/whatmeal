import '../../../core/widgets/listener_recovery_notice.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../../profile/data/family_member_repository.dart';
import '../widgets/saved_plan_actions.dart';

class SavedMealPlansPage extends StatelessWidget {
  const SavedMealPlansPage({super.key, this.repository});
  final SavedPlansRepository? repository;
  SavedPlansRepository get _repo => repository ?? SavedPlansRepository.instance;

  void _confirmDeletePlan(BuildContext context, SavedMealPlan plan) {
    final session = _repo.sessionVersion;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete "${plan.title}"?'),
          content: const Text(
            'Are you sure you want to delete this saved meal plan? '
            'Its meals and related recommendations will also be removed. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _repo.deletePlan(plan.id,
                      planPath: plan.sourcePath, expectedSession: session);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Deleted "${plan.title}" and its meal recommendations.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Could not delete plan. Please retry.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete Plan',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedMealPlan>>(
      valueListenable: _repo,
      builder: (context, plans, _) {
        if (plans.isEmpty && _repo.error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Saved Meal Plans')),
            body: ListenerRecoveryNotice(
                message: _repo.error!,
                onRetry: _repo.retry,
                label: 'Retry Saved Plans'),
          );
        }
        return AnimatedBuilder(
          animation: plans.isEmpty
              ? const AlwaysStoppedAnimation(0)
              : FamilyMemberRepository.instance,
          builder: (context, _) {
            final members = plans.isEmpty
                ? const <dynamic>[]
                : FamilyMemberRepository.instance.members;
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                actions: [
                  IconButton(
                      tooltip: 'Meal History',
                      icon: const Icon(Icons.history),
                      onPressed: () => context.push('/meal-history'))
                ],
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
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
                      child:
                          const Icon(Icons.eco, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Saved Meal Plans',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              body: Column(children: [
                if (_repo.error != null)
                  ListenerRecoveryNotice(
                      message: _repo.error!,
                      onRetry: _repo.retry,
                      label: 'Retry Saved Plans'),
                Expanded(
                    child: _repo.isLoading && plans.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : plans.isEmpty
                            ? (_repo.error == null
                                ? _buildEmptyState(context)
                                : const SizedBox.shrink())
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  const Text(
                                    'Reload and schedule previous generated plans your family loved.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  for (final plan in plans) ...[
                                    _buildSavedPlanCard(
                                        context: context,
                                        plan: plan,
                                        members: members),
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              )),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No Saved Meal Plans',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate an AI meal plan and tap the bookmark icon to save it here for quick reloading.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/meal-plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate Meal Plan',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPlanCard({
    required BuildContext context,
    required SavedMealPlan plan,
    required List<dynamic> members,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(27, 42, 30, 0.05),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan.dates,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bookmark,
                    color: AppColors.primary, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${plan.mealsCount} meals planned',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Est. ${plan.estCost}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final resolvedNames = plan.familyMembers
                  .map((member) {
                    final byId = members
                        .where((m) => m.id == member)
                        .firstOrNull
                        ?.displayName;
                    if (byId != null) return byId;
                    final byName = members
                        .where((m) =>
                            m.displayName.toLowerCase() == member.toLowerCase())
                        .firstOrNull
                        ?.displayName;
                    if (byName != null) return byName;
                    final isRawId =
                        RegExp(r'^[a-zA-Z0-9_-]{18,}$').hasMatch(member.trim());
                    if (isRawId) return null;
                    return member;
                  })
                  .whereType<String>()
                  .toList();

              if (resolvedNames.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Text('For: ',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(width: 4),
                    Wrap(
                      spacing: 6,
                      children: resolvedNames
                          .map((name) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          SavedPlanActions(
            key: ValueKey('actions:${plan.sourcePath}'),
            onDelete: () => _confirmDeletePlan(context, plan),
            onReuse: () => context.push('/generated-plan',
                extra: GeneratedPlanDraft.fromSaved(plan, reuse: true)),
            onLoad: () => context.push('/generated-plan',
                extra: GeneratedPlanDraft.fromSaved(plan)),
          ),
        ],
      ),
    );
  }
}
