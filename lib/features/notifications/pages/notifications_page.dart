import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const _notifications = [
    {
      'title': 'Pantry Alert: Spinach Expiring Soon',
      'body': 'Your 200g Spinach expires in 1 day. Consider using it in today\'s Avocado & Spinach Salad!',
      'time': '10 mins ago',
      'icon': Icons.warning_amber_rounded,
      'color': AppColors.danger,
      'bg': AppColors.dangerLight,
    },
    {
      'title': 'Sarah added Salmon to Grocery List',
      'body': '500g Fresh Atlantic Salmon was added to Meat & Seafood by Sarah.',
      'time': '1 hour ago',
      'icon': Icons.shopping_cart,
      'color': AppColors.primary,
      'bg': AppColors.primaryLight,
    },
    {
      'title': 'Leo\'s Allergy Profile Updated',
      'body': 'Peanut Allergy restriction was verified for Leo Miller.',
      'time': '3 hours ago',
      'icon': Icons.health_and_safety_outlined,
      'color': AppColors.info,
      'bg': AppColors.infoLight,
    },
    {
      'title': 'New Meal Plan Saved',
      'body': 'David Miller saved "Winter Cozy Warmers" to shared family plans.',
      'time': 'Yesterday',
      'icon': Icons.bookmark_added_outlined,
      'color': AppColors.primary,
      'bg': AppColors.primaryLight,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _notifications[index];
          final color = item['color'] as Color;
          final bg = item['bg'] as Color;
          final icon = item['icon'] as IconData;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            item['time'] as String,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['body'] as String,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
