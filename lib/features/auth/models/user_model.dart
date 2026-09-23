class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.familySpaceId,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? familySpaceId;
  final String? avatarUrl;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? familySpaceId,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      familySpaceId: familySpaceId ?? this.familySpaceId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
