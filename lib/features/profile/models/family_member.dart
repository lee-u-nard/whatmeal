class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    this.relation,
    required this.age,
    required this.preferences,
    required this.restrictions,
  });

  final String id;
  final String name;
  final String? relation;
  final int age;
  final List<String> preferences;  // green pills
  final List<String> restrictions; // red pills

  String get displayName => (relation != null && relation!.isNotEmpty) ? '$relation ($name)' : name;

  FamilyMember copyWith({
    String? id,
    String? name,
    String? relation,
    int? age,
    List<String>? preferences,
    List<String>? restrictions,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      age: age ?? this.age,
      preferences: preferences ?? this.preferences,
      restrictions: restrictions ?? this.restrictions,
    );
  }
}