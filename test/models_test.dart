import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'package:whatmeal/features/grocery/models/grocery_item.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/core/models/family.dart';
import 'package:whatmeal/core/models/app_user.dart';

void main() {
  group('Model Serialization & Logic Tests', () {
    test('PantryItem computes expiration correctly', () {
      final now = DateTime.now();
      final expiringItem = PantryItem(
        id: '1',
        name: 'Milk',
        quantity: '1 gallon',
        category: 'Dairy',
        expirationDate: now.add(const Duration(days: 3)),
      );

      expect(expiringItem.isExpiringSoon, isTrue);
      expect(expiringItem.expiresInDays, inInclusiveRange(2, 3));

      final freshItem = PantryItem(
        id: '2',
        name: 'Rice',
        quantity: '5 kg',
        category: 'Grains',
        expirationDate: now.add(const Duration(days: 30)),
      );

      expect(freshItem.isExpiringSoon, isFalse);
    });

    test('GroceryItem default values', () {
      final item = GroceryItem(
        name: 'Avocado',
        quantity: '2 units',
      );

      expect(item.category, equals('Other'));
      expect(item.checked, isFalse);
    });

    test('FamilyMember displayName and fields', () {
      const member = FamilyMember(
        name: 'David',
        relation: 'Dad',
        age: 42,
        preferences: ['Keto'],
        restrictions: ['No Spicy'],
      );

      expect(member.displayName, equals('Dad (David)'));
      expect(member.preferences, contains('Keto'));
      expect(member.restrictions, contains('No Spicy'));
    });

    test('Meal and Ingredient mapping', () {
      final meal = Meal(
        id: 'm1',
        title: 'Salmon Bowl',
        mealType: 'Dinner',
        ingredients: const [
          Ingredient(name: 'Salmon', amount: '200g'),
          Ingredient(name: 'Rice', amount: '1 cup'),
        ],
      );

      expect(meal.ingredients.length, equals(2));
      expect(meal.ingredients.first.name, equals('Salmon'));
      final map = meal.toFirestore();
      expect(map['title'], equals('Salmon Bowl'));
      expect(map['mealType'], equals('Dinner'));
    });

    test('Family inviteCode and fields', () {
      final family = Family(
        id: 'f1',
        name: 'The Smiths',
        inviteCode: 'AB3K7X',
        createdBy: 'u1',
        memberUids: ['u1'],
      );

      expect(family.inviteCode, equals('AB3K7X'));
      expect(family.memberUids, contains('u1'));
      final map = family.toFirestore();
      expect(map['name'], equals('The Smiths'));
      expect(map['inviteCode'], equals('AB3K7X'));
    });

    test('AppUser copyWith familyId', () {
      final user = AppUser(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      expect(user.familyId, isNull);
      final updated = user.copyWith(familyId: 'f1');
      expect(updated.familyId, equals('f1'));

      final cleared = updated.copyWith(clearFamilyId: true);
      expect(cleared.familyId, isNull);
    });
  });
}
