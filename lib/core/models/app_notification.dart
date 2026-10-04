import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of application event that triggered a notification.
enum AppNotificationType {
  mealPlanGenerated,
  mealPlanSaved,
  mealPlanDeleted,
  mealAccepted,
  mealCompleted,
  mealNotCompleted,
  mealReplaced,
  groceryListUpdated,
  groceryItemAdded,
  groceryItemPurchased,
  pantryItemAdded,
  pantryItemDeleted,
  pantryItemUpdated,
  familyUpdate,
  memberAdded,
  memberRemoved,
  memberRoleChanged,
  aiProviderAdded,
  aiProviderRemoved,
  aiProviderChanged,
  aiSuccess,
  general;

  String get displayName {
    switch (this) {
      case AppNotificationType.mealPlanGenerated:
        return 'Meal Plan';
      case AppNotificationType.mealPlanSaved:
        return 'Plan Saved';
      case AppNotificationType.mealPlanDeleted:
        return 'Plan Deleted';
      case AppNotificationType.mealAccepted:
        return 'Meal Accepted';
      case AppNotificationType.mealCompleted:
        return 'Meal Completed';
      case AppNotificationType.mealNotCompleted:
        return 'Meal Not Completed';
      case AppNotificationType.mealReplaced:
        return 'Meal Replaced';
      case AppNotificationType.groceryListUpdated:
        return 'Grocery';
      case AppNotificationType.groceryItemAdded:
        return 'Grocery';
      case AppNotificationType.groceryItemPurchased:
        return 'Grocery';
      case AppNotificationType.pantryItemAdded:
        return 'Pantry';
      case AppNotificationType.pantryItemDeleted:
        return 'Pantry';
      case AppNotificationType.pantryItemUpdated:
        return 'Pantry';
      case AppNotificationType.familyUpdate:
        return 'Family';
      case AppNotificationType.memberAdded:
        return 'Family';
      case AppNotificationType.memberRemoved:
        return 'Family';
      case AppNotificationType.memberRoleChanged:
        return 'Family';
      case AppNotificationType.aiProviderAdded:
        return 'AI Settings';
      case AppNotificationType.aiProviderRemoved:
        return 'AI Settings';
      case AppNotificationType.aiProviderChanged:
        return 'AI Settings';
      case AppNotificationType.aiSuccess:
        return 'AI';
      case AppNotificationType.general:
        return 'Info';
    }
  }

  static AppNotificationType fromId(String? id) {
    return AppNotificationType.values.firstWhere(
      (t) => t.name == id,
      orElse: () => AppNotificationType.general,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
    this.relatedPlanId,
    this.actorName,
    this.actorUid,
    this.actionType,
    this.targetName,
    this.targetId,
    this.navigationRoute,
    this.navigationParameters,
  });

  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool read;

  /// Optional FK to a saved meal plan so cascade deletes can clean these up.
  final String? relatedPlanId;

  /// Household activity: who performed the action
  final String? actorName;
  final String? actorUid;

  /// Household activity: what action was performed
  final String? actionType;

  /// Household activity: what was affected
  final String? targetName;
  final String? targetId;

  /// Navigation: where to take the user when notification is tapped
  final String? navigationRoute;
  final Map<String, dynamic>? navigationParameters;

  factory AppNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppNotification(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: AppNotificationType.fromId(data['type'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      relatedPlanId: data['relatedPlanId'] as String?,
      actorName: data['actorName'] as String?,
      actorUid: data['actorUid'] as String?,
      actionType: data['actionType'] as String?,
      targetName: data['targetName'] as String?,
      targetId: data['targetId'] as String?,
      navigationRoute: data['navigationRoute'] as String?,
      navigationParameters:
          data['navigationParameters'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'read': read,
        if (relatedPlanId != null) 'relatedPlanId': relatedPlanId,
        if (actorName != null) 'actorName': actorName,
        if (actorUid != null) 'actorUid': actorUid,
        if (actionType != null) 'actionType': actionType,
        if (targetName != null) 'targetName': targetName,
        if (targetId != null) 'targetId': targetId,
        if (navigationRoute != null) 'navigationRoute': navigationRoute,
        if (navigationParameters != null)
          'navigationParameters': navigationParameters,
      };

  AppNotification copyWith({
    bool? read,
    String? relatedPlanId,
    String? actorName,
    String? actorUid,
    String? actionType,
    String? targetName,
    String? targetId,
    String? navigationRoute,
    Map<String, dynamic>? navigationParameters,
  }) =>
      AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: read ?? this.read,
        relatedPlanId: relatedPlanId ?? this.relatedPlanId,
        actorName: actorName ?? this.actorName,
        actorUid: actorUid ?? this.actorUid,
        actionType: actionType ?? this.actionType,
        targetName: targetName ?? this.targetName,
        targetId: targetId ?? this.targetId,
        navigationRoute: navigationRoute ?? this.navigationRoute,
        navigationParameters: navigationParameters ?? this.navigationParameters,
      );
}
