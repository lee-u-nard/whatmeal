import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/services/notification_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationService.instance,
      builder: (context, notifications, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Notifications & Alerts',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            actions: [
              if (notifications.any((n) => !n.read))
                TextButton(
                  onPressed: () => NotificationService.instance.markAllRead(),
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
          body: notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return _NotificationCard(
                      notification: n,
                      onTap: () {
                        if (!n.read) {
                          NotificationService.instance.markRead(n.id);
                        }
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'You\'ll be notified when your meal plan is generated, '
              'grocery lists are updated, or pantry items are expiring.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(notification.type);
    final bgColor = _bgColorForType(notification.type);
    final icon = _iconForType(notification.type);
    final isUnread = !notification.read;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primaryLight.withValues(alpha: 0.4)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
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
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: isUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _timeAgo(notification.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.groceryListUpdated:
      case AppNotificationType.groceryItemAdded:
      case AppNotificationType.groceryItemPurchased:
        return AppColors.primary;
      case AppNotificationType.mealPlanGenerated:
      case AppNotificationType.mealPlanSaved:
      case AppNotificationType.mealAccepted:
      case AppNotificationType.mealCompleted:
      case AppNotificationType.mealReplaced:
        return AppColors.primary;
      case AppNotificationType.pantryItemAdded:
      case AppNotificationType.pantryItemDeleted:
      case AppNotificationType.pantryItemUpdated:
        return AppColors.danger;
      case AppNotificationType.familyUpdate:
      case AppNotificationType.memberAdded:
      case AppNotificationType.memberRemoved:
      case AppNotificationType.memberRoleChanged:
        return AppColors.info;
      case AppNotificationType.aiProviderAdded:
      case AppNotificationType.aiProviderRemoved:
      case AppNotificationType.aiProviderChanged:
      case AppNotificationType.aiSuccess:
        return AppColors.primary;
      case AppNotificationType.general:
        return AppColors.textSecondary;
      case AppNotificationType.mealPlanDeleted:
      case AppNotificationType.mealNotCompleted:
        return AppColors.danger;
    }
  }

  Color _bgColorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.pantryItemAdded:
      case AppNotificationType.pantryItemDeleted:
      case AppNotificationType.pantryItemUpdated:
        return AppColors.dangerLight;
      case AppNotificationType.familyUpdate:
      case AppNotificationType.memberAdded:
      case AppNotificationType.memberRemoved:
      case AppNotificationType.memberRoleChanged:
        return AppColors.infoLight;
      default:
        return AppColors.primaryLight;
    }
  }

  IconData _iconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.pantryItemAdded:
      case AppNotificationType.pantryItemDeleted:
      case AppNotificationType.pantryItemUpdated:
        return Icons.warning_amber_rounded;
      case AppNotificationType.groceryListUpdated:
      case AppNotificationType.groceryItemAdded:
      case AppNotificationType.groceryItemPurchased:
        return Icons.shopping_cart;
      case AppNotificationType.mealPlanGenerated:
        return Icons.auto_awesome;
      case AppNotificationType.mealPlanSaved:
        return Icons.bookmark_added_outlined;
      case AppNotificationType.mealAccepted:
        return Icons.check_circle_outline;
      case AppNotificationType.mealCompleted:
        return Icons.done_all;
      case AppNotificationType.mealNotCompleted:
        return Icons.cancel;
      case AppNotificationType.mealReplaced:
        return Icons.refresh;
      case AppNotificationType.mealPlanDeleted:
        return Icons.delete;
      case AppNotificationType.aiProviderAdded:
      case AppNotificationType.aiProviderRemoved:
      case AppNotificationType.aiProviderChanged:
      case AppNotificationType.aiSuccess:
        return Icons.check_circle_outline;
      case AppNotificationType.familyUpdate:
      case AppNotificationType.memberAdded:
      case AppNotificationType.memberRemoved:
      case AppNotificationType.memberRoleChanged:
        return Icons.health_and_safety_outlined;
      case AppNotificationType.general:
        return Icons.info_outline;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
