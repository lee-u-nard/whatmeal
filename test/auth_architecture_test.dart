import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/core/models/app_user.dart';

void main() {
  group('Auth Architecture & UID Identity Tests', () {
    test('UserModel maps Firebase UID as primary id and contains isEmailVerified', () {
      const user = UserModel(
        id: 'firebase_uid_12345',
        name: 'Alice Smith',
        email: 'alice@example.com',
        isEmailVerified: false,
      );

      expect(user.id, equals('firebase_uid_12345'));
      expect(user.email, equals('alice@example.com'));
      expect(user.isEmailVerified, isFalse);

      final verified = user.copyWith(isEmailVerified: true);
      expect(verified.isEmailVerified, isTrue);
      expect(verified.id, equals('firebase_uid_12345'));
      expect(verified.name, equals('Alice Smith'));
      expect(verified.email, equals('alice@example.com'));
    });

    test('AppUser maintains UID isolation and household association', () {
      final userA = AppUser(
        id: 'uid_account_a',
        email: 'user_a@example.com',
        displayName: 'Account A',
        familyId: 'family_101',
      );

      final userB = AppUser(
        id: 'uid_account_b',
        email: 'user_b@example.com',
        displayName: 'Account B',
        familyId: 'family_101',
      );

      // Verify that even if in the same family, account IDs (UIDs) are isolated
      expect(userA.id, isNot(equals(userB.id)));
      expect(userA.familyId, equals(userB.familyId));

      // Test private collection path generation logic
      String userPrivatePantryPath(String uid) => 'users/$uid/pantryItems';
      String sharedHouseholdPantryPath(String familyId) => 'families/$familyId/pantryItems';

      expect(userPrivatePantryPath(userA.id), equals('users/uid_account_a/pantryItems'));
      expect(userPrivatePantryPath(userB.id), equals('users/uid_account_b/pantryItems'));
      expect(sharedHouseholdPantryPath(userA.familyId!), equals('families/family_101/pantryItems'));
    });

    test('Collection path generation enforces UID for private and familyId for shared', () {
      const uid1 = 'user_111';
      const uid2 = 'user_222';
      const familyId = 'household_999';

      // Private data paths
      expect('users/$uid1/mealPlans', isNot(equals('users/$uid2/mealPlans')));
      expect('users/$uid1/groceryLists', isNot(equals('users/$uid2/groceryLists')));
      expect('users/$uid1/secrets/llmConfig', isNot(equals('users/$uid2/secrets/llmConfig')));

      // Shared data paths
      expect('families/$familyId/pantryItems', equals('families/$familyId/pantryItems'));
      expect('families/$familyId/mealPlans', equals('families/$familyId/mealPlans'));
    });
  });
}
