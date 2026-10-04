import '../models/app_notification.dart';
import '../../features/family/data/family_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import 'notification_service.dart';

/// Service for generating and sending household activity notifications.
///
/// Handles dynamic message generation based on actor, action, and target,
/// and ensures notifications are only sent to authorized household members.
///
/// On Firebase Spark (free) plan, notifications are delivered via Firestore
/// realtime listeners (in-app notifications). Server-side push notifications
/// require Cloud Functions (Blaze plan).
class HouseholdNotificationService {
  HouseholdNotificationService._();

  static final instance = HouseholdNotificationService._();

  final _notificationService = NotificationService.instance;

  /// Get the current user's display name for notification messages.
  Future<String> _getCurrentUserName() async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return 'Someone';

    // Try to get from family members first (more likely to be household name)
    final familySpace = FamilyRepository.instance.value;
    if (familySpace != null) {
      final member = familySpace.memberForUid(currentUser.uid);
      if (member != null) return member.name;
    }

    // Fallback to auth user display name
    return currentUser.displayName ??
        currentUser.email?.split('@')[0] ??
        'Someone';
  }

  /// Send a household notification for meal plan creation.
  Future<void> notifyMealPlanCreated({
    required String planId,
    required String planTitle,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Meal Plan Created',
      body: '$actorName created a meal plan for your household.',
      type: AppNotificationType.mealPlanGenerated,
      relatedPlanId: planId,
      excludeUid: actorUid,
      navigationRoute: '/meal-plan',
      navigationParameters: {'planId': planId},
      actorName: actorName,
      actorUid: actorUid,
      actionType: 'created',
      targetName: planTitle,
      targetId: planId,
    );
  }

  /// Send a household notification for meal plan deletion.
  Future<void> notifyMealPlanDeleted({
    required String planId,
    required String planTitle,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Meal Plan Deleted',
      body: '$actorName deleted the meal plan "$planTitle".',
      type: AppNotificationType.mealPlanDeleted,
      relatedPlanId: planId,
      excludeUid: actorUid,
      navigationRoute: '/meal-plan',
      actorName: actorName,
      actorUid: actorUid,
      actionType: 'deleted',
      targetName: planTitle,
      targetId: planId,
    );
  }

  /// Send a household notification for meal acceptance.
  Future<void> notifyMealAccepted({
    required String planId,
    required String mealId,
    required String mealTitle,
    required String mealType,
    required String targetMemberName,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Meal Accepted',
      body: '$actorName accepted $targetMemberName\'s $mealType: $mealTitle.',
      type: AppNotificationType.mealAccepted,
      relatedPlanId: planId,
      excludeUid: actorUid,
      navigationRoute: '/generated-plan',
      navigationParameters: {'planId': planId, 'mealId': mealId},
      actorName: actorName,
      actorUid: actorUid,
      actionType: 'accepted',
      targetName: mealTitle,
      targetId: mealId,
    );
  }

  /// Send a household notification for meal completion.
  Future<void> notifyMealCompleted({
    required String planId,
    required String mealId,
    required String mealTitle,
    required String mealType,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Meal Completed',
      body: '$actorName completed $mealType: $mealTitle.',
      type: AppNotificationType.mealCompleted,
      relatedPlanId: planId,
      excludeUid: actorUid,
      navigationRoute: '/generated-plan',
      navigationParameters: {'planId': planId, 'mealId': mealId},
      actorName: actorName,
      actorUid: actorUid,
      actionType: 'completed',
      targetName: mealTitle,
      targetId: mealId,
    );
  }

  /// Send a household notification for meal not completed.
  Future<void> notifyMealNotCompleted({
    required String planId,
    required String mealId,
    required String mealTitle,
    required String mealType,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Meal Not Completed',
      body: '$actorName marked $mealType as not completed: $mealTitle.',
      type: AppNotificationType.mealNotCompleted,
      relatedPlanId: planId,
      excludeUid: actorUid,
      navigationRoute: '/generated-plan',
      navigationParameters: {'planId': planId, 'mealId': mealId},
      actorName: actorName,
      actorUid: actorUid,
      actionType: 'marked as not completed',
      targetName: mealTitle,
      targetId: mealId,
    );
  }

  /// Send a household notification for meal replacement.
  Future<void> notifyMealReplaced({
    required String planId,
    required String mealId,
    required String oldMealTitle,
    required String newMealTitle,
    required String mealType,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Meal Replaced',
      body: '$actorName replaced $mealType with a new AI recommendation.',
      type: AppNotificationType.mealReplaced,
      relatedPlanId: planId,
      excludeUid: actorUid,
      navigationRoute: '/generated-plan',
      navigationParameters: {'planId': planId, 'mealId': mealId},
      actorName: actorName,
      actorUid: actorUid,
      actionType: 'replaced',
      targetName: newMealTitle,
      targetId: mealId,
    );
  }

  /// Send a household notification for grocery list activity.
  Future<void> notifyGroceryActivity({
    required String action,
    required String itemName,
    int? itemCount,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    final body = itemCount != null && itemCount > 1
        ? '$actorName $action $itemCount items to the grocery list.'
        : '$actorName $action "$itemName" to the grocery list.';

    await _notificationService.notifyHouseholdMembers(
      title: 'Grocery List Updated',
      body: body,
      type: AppNotificationType.groceryListUpdated,
      excludeUid: actorUid,
      navigationRoute: '/grocery',
      actorName: actorName,
      actorUid: actorUid,
      actionType: action,
      targetName: itemCount != null ? '$itemCount items' : itemName,
    );
  }

  /// Send a household notification for pantry activity.
  Future<void> notifyPantryActivity({
    required String action,
    required String itemName,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    await _notificationService.notifyHouseholdMembers(
      title: 'Pantry Updated',
      body: '$actorName $action "$itemName" to the pantry.',
      type: action == 'added'
          ? AppNotificationType.pantryItemAdded
          : action == 'deleted'
              ? AppNotificationType.pantryItemDeleted
              : AppNotificationType.pantryItemUpdated,
      excludeUid: actorUid,
      navigationRoute: '/pantry',
      actorName: actorName,
      actorUid: actorUid,
      actionType: action,
      targetName: itemName,
    );
  }

  /// Send a household notification for AI provider changes.
  Future<void> notifyAiProviderChanged({
    required String action,
    required String providerName,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    final type = action == 'added'
        ? AppNotificationType.aiProviderAdded
        : action == 'removed'
            ? AppNotificationType.aiProviderRemoved
            : AppNotificationType.aiProviderChanged;

    await _notificationService.notifyHouseholdMembers(
      title: 'AI Provider Updated',
      body: '$actorName $action the $providerName AI provider.',
      type: type,
      excludeUid: actorUid,
      navigationRoute: '/ai-settings',
      actorName: actorName,
      actorUid: actorUid,
      actionType: action,
      targetName: providerName,
    );
  }

  /// Send a household notification for family member changes.
  Future<void> notifyMemberChanged({
    required String action,
    required String memberName,
  }) async {
    final actorUid = AuthRepository.instance.currentUser?.uid;
    final actorName = await _getCurrentUserName();

    final type = action == 'added'
        ? AppNotificationType.memberAdded
        : action == 'removed'
            ? AppNotificationType.memberRemoved
            : AppNotificationType.memberRoleChanged;

    await _notificationService.notifyHouseholdMembers(
      title: 'Household Members Updated',
      body: '$actorName $action $memberName to the household.',
      type: type,
      excludeUid: actorUid,
      navigationRoute: '/profile',
      actorName: actorName,
      actorUid: actorUid,
      actionType: action,
      targetName: memberName,
    );
  }
}
