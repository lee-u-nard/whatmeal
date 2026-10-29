enum FamilyRole {
  owner,
  admin,
  member,
  viewOnly,
}

extension FamilyRoleX on FamilyRole {
  String get label {
    switch (this) {
      case FamilyRole.owner:
        return 'Space Owner';
      case FamilyRole.admin:
        return 'Household Admin';
      case FamilyRole.member:
        return 'Family Member';
      case FamilyRole.viewOnly:
        return 'View Only';
    }
  }

  bool get isOwner => this == FamilyRole.owner;
  bool get isAdmin => this == FamilyRole.admin;
  bool get isAuthorized =>
      this == FamilyRole.owner ||
      this == FamilyRole.admin ||
      this == FamilyRole.member;

  // ── Permission capabilities ───────────────────────────────────────────────
  bool get canViewMealPlan => true;
  bool get canAcceptMeal => isAuthorized;
  bool get canReplaceMeal => isAuthorized;
  bool get canViewMembers => true;
  bool get canManagePantry => isAuthorized;
  bool get canGenerateGroceryList => isAuthorized;
  bool get canManageMembers =>
      this == FamilyRole.owner || this == FamilyRole.admin;
  bool get canDeleteHousehold => this == FamilyRole.owner;
}

class SharedSpaceMember {
  const SharedSpaceMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String email;
  final FamilyRole role;
  final String? avatarUrl;
  final DateTime? joinedAt;

  SharedSpaceMember copyWith({
    String? id,
    String? name,
    String? email,
    FamilyRole? role,
    String? avatarUrl,
  }) {
    return SharedSpaceMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt,
    );
  }
}

class FamilySpace {
  const FamilySpace({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String name;
  final String inviteCode;
  final List<SharedSpaceMember> members;

  SharedSpaceMember? memberForUid(String? uid) {
    if (uid == null) return null;
    return members.cast<SharedSpaceMember?>().firstWhere(
          (m) => m?.id == uid,
          orElse: () => null,
        );
  }

  FamilyRole roleForUid(String? uid) {
    return memberForUid(uid)?.role ?? FamilyRole.viewOnly;
  }

  bool isOwner(String? uid) => roleForUid(uid).isOwner;
  bool canManageMembers(String? uid) => roleForUid(uid).canManageMembers;
  bool canDeleteHousehold(String? uid) => roleForUid(uid).canDeleteHousehold;

  FamilySpace copyWith({
    String? id,
    String? name,
    String? inviteCode,
    List<SharedSpaceMember>? members,
  }) {
    return FamilySpace(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
    );
  }
}
