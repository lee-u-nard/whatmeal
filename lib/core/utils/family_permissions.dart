import '../../features/auth/data/auth_repository.dart';
import '../../features/family/data/family_repository.dart';
import '../../features/family/models/family_space.dart';

/// Resolves the current user's [FamilyRole] and permission helpers.
///
/// When the user is not in a family space, they are treated as a personal
/// workspace owner (full permissions on their own data).
class FamilyPermissions {
  FamilyPermissions._();

  static FamilyRole get currentRole {
    final uid = AuthRepository.instance.currentUser?.uid;
    final space = FamilyRepository.instance.value;
    if (space == null || uid == null) return FamilyRole.owner;
    return space.roleForUid(uid);
  }

  static bool get canAcceptMeal => currentRole.canAcceptMeal;
  static bool get canReplaceMeal => currentRole.canReplaceMeal;
  static bool get canManagePantry => currentRole.canManagePantry;
  static bool get canGenerateGroceryList => currentRole.canGenerateGroceryList;
  static bool get canManageMembers => currentRole.canManageMembers;
  static bool get canDeleteHousehold => currentRole.canDeleteHousehold;
  static bool get canViewMealPlan => currentRole.canViewMealPlan;
  static bool get isViewOnly => currentRole == FamilyRole.viewOnly;

  /// Human-readable denial message for gated actions.
  static String denialMessage(String action) =>
      'Your role (${currentRole.label}) cannot $action. Ask a household admin for access.';
}
