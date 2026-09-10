import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, size: 20, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: ListView(
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
          _buildSavedPlanCard(
            context: context,
            title: 'Winter Cozy Warmers',
            dates: 'Oct 1 - Oct 7',
            mealsCount: 15,
            estCost: '\$112.50',
            familyMembers: ['Dad', 'Mom', 'Leo', 'Emma'],
          ),
          const SizedBox(height: 16),
          _buildSavedPlanCard(
            context: context,
            title: 'Eco Pantry Cleanout',
            dates: 'Sep 24 - Sep 30',
            mealsCount: 12,
            estCost: '\$84.20',
            familyMembers: ['Dad', 'Mom', 'Leo'],
          ),
          const SizedBox(height: 16),
          _buildSavedPlanCard(
            context: context,
            title: 'High-Protein Strength Week',
            dates: 'Sep 15 - Sep 21',
            mealsCount: 14,
            estCost: '\$145.00',
            familyMembers: ['Dad', 'Mom'],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPlanCard({
    required BuildContext context,
    required String title,
    required String dates,
    required int mealsCount,
    required String estCost,
    required List<String> familyMembers,
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
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dates,
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
                child: const Icon(Icons.bookmark_outline, color: AppColors.primary, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '$mealsCount meals planned',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Est. $estCost',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('For: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 4),
              Wrap(
                spacing: 6,
                children: familyMembers.map((member) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      member,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted $title')),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/meal/1');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.folder_open, color: Colors.white, size: 14),
                label: const Text(
                  'Load Plan',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
