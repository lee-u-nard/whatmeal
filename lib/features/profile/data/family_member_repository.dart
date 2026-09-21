import 'package:flutter/foundation.dart';
import '../models/family_member.dart';

class FamilyMemberRepository extends ValueNotifier<List<FamilyMember>> {
  FamilyMemberRepository._()
      : super(const [
          FamilyMember(
            id: 'fm_1',
            name: 'David',
            relation: 'Dad',
            age: 42,
            preferences: ['Keto', 'High Protein'],
            restrictions: ['No Spicy'],
          ),
          FamilyMember(
            id: 'fm_2',
            name: 'Sarah',
            relation: 'Mom',
            age: 39,
            preferences: ['Vegetarian Friendly', 'Low Carb'],
            restrictions: [],
          ),
          FamilyMember(
            id: 'fm_3',
            name: 'Leo',
            age: 8,
            preferences: [],
            restrictions: ['Peanut Allergy'],
          ),
          FamilyMember(
            id: 'fm_4',
            name: 'Emma',
            age: 5,
            preferences: ['Dairy Free', 'Sweet Lover'],
            restrictions: [],
          ),
        ]);

  static final instance = FamilyMemberRepository._();

  void addMember(FamilyMember member) {
    value = [...value, member];
  }

  void updateMember(FamilyMember updated) {
    value = value.map((m) => m.id == updated.id ? updated : m).toList();
  }

  void deleteMember(String id) {
    value = value.where((m) => m.id != id).toList();
  }
}
