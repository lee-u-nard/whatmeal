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
}

class SharedSpaceMember {
  const SharedSpaceMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final FamilyRole role;
  final String? avatarUrl;

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
