class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.familySpaceId,
    this.avatarUrl,
    this.isEmailVerified = false,
  });

  final String id;
  final String name;
  final String email;
  final String? familySpaceId;
  final String? avatarUrl;
  final bool isEmailVerified;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? familySpaceId,
    String? avatarUrl,
    bool? isEmailVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      familySpaceId: familySpaceId ?? this.familySpaceId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
