import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/family/models/household_action_error.dart';

void main() {
  test('household SDK errors are contextual and never expose SDK details', () {
    for (final code in [
      'unavailable',
      'network-request-failed',
      'permission-denied',
      'unauthenticated',
      'aborted',
      'unknown'
    ]) {
      final message = householdActionError(FirebaseException(
          plugin: 'cloud_firestore',
          code: code,
          message: 'private-token secret.example.invalid'));
      expect(message, isNot(contains('private-token')));
      expect(message, isNot(contains('secret.example')));
      expect(message, isNot(contains('AI')));
      expect(message, isNot(contains('plan')));
    }
  });
  test('only known business validation messages are disclosed', () {
    expect(
        householdActionError(StateError('Leave your current household first.')),
        'Leave your current household first.');
    expect(
        householdActionError(
            ArgumentError('Household name must contain 1–100 characters.')),
        'Household name must contain 1–100 characters.');
    expect(householdActionError(StateError('private-token')),
        isNot(contains('private-token')));
    expect(householdActionError(ArgumentError('private-token')),
        isNot(contains('private-token')));
  });
  test('timeouts describe uncertain completion without promising no write', () {
    final message = householdActionError(TimeoutException('private-token'));
    expect(message, contains('Check your household'));
    expect(message, isNot(contains('private-token')));
  });
}
