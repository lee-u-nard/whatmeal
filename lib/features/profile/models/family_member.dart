

class FamilyMember {
  const FamilyMember({
    required this.name,
    this.relation,
    required this.age,
    required this.preferences,
    required this.restrictions,
  });

  final String name;
  final String? relation;
  final int age;
  final List<String> preferences;  // green pills
  final List<String> restrictions; // red pills

  String get displayName => relation != null ? '$relation ($name)' : name;
}