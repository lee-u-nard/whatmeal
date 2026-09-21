import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  const FamilyMember({
    this.id,
    required this.name,
    this.relation,
    required this.age,
    required this.preferences,
    required this.restrictions,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String? relation;
  final int age;
  final List<String> preferences;  // green pills
  final List<String> restrictions; // red pills
  final DateTime? createdAt;

  String get displayName => relation != null ? '$relation ($name)' : name;

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