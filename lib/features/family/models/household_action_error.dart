import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

/// Only known business messages may be shown; SDK/unknown details stay private.
String householdActionError(Object failure) {
  const messages = {
    'Sign in first.',
    'Leave your current household first.',
    'Household name must contain 1–100 characters.',
    'Invalid invitation role or expiration.',
    'Use a new single-use invitation token. Legacy short codes are no longer supported.',
    'Invitation is unavailable or expired. Ask for a new one.',
    'Ownership requires a transfer accepted by the new owner.',
    'No ownership offer for this account.',
  };
  final message = failure is StateError
      ? failure.message
      : failure is ArgumentError
          ? failure.message
          : null;
  if (message is String && messages.contains(message)) return message;
  if (failure is TimeoutException) {
    return 'The household request timed out. Check your household and retry.';
  }
  if (failure is FirebaseException) {
    return switch (failure.code) {
      'unavailable' ||
      'network-request-failed' =>
        'The household service is unavailable. Check your connection and retry.',
      'deadline-exceeded' =>
        'The household request timed out. Check your household and retry.',
      'permission-denied' =>
        'Household access was denied. Check your membership or invitation and retry.',
      'unauthenticated' ||
      'user-token-expired' =>
        'Your session needs refreshing. Sign in again.',
      'aborted' ||
      'already-exists' =>
        'Household data changed. Check your household and retry.',
      _ =>
        'Household change could not be confirmed. Check your household and retry.',
    };
  }
  return 'Household change could not be confirmed. Check your household and retry.';
}
