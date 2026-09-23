import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  const FamilyMember({
    this.id = '', // Provide default to satisfy `required` String while being optional when adding
    required this.name,
    this.relation,
    required this.age,
    required this.preferences,
    required this.restrictions,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? relation;
  final int age;
  final List<String> preferences;
  final List<String> restrictions;
  final DateTime? createdAt;

  String get displayName => (relation != null && relation!.isNotEmpty) ? '$relation ($name)' : name;

  FamilyMember copyWith({
    String? id,
    String? name,
    String? relation,
    int? age,
    List<String>? preferences,
    List<String>? restrictions,
    DateTime? createdAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      age: age ?? this.age,
      preferences: preferences ?? this.preferences,
      restrictions: restrictions ?? this.restrictions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FamilyMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FamilyMember(
      id: doc.id,
      name: data['name'] ?? '',
      relation: data['relation'],
      age: data['age'] ?? 0,
      preferences: List<String>.from(data['preferences'] ?? []),
      restrictions: List<String>.from(data['restrictions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'relation': relation,
    'age': age,
    'preferences': preferences,
    'restrictions': restrictions,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}