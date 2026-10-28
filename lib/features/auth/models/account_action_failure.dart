enum AccountFailureKind {
  signedOut,
  sessionChanged,
  invalidName,
  credentials,
  weakPassword,
  recentLogin,
  passwordProvider,
  network,
  unavailable,
  profileSync
}

/// Only fixed, public messages may cross the account editor boundary.
class AccountActionFailure implements Exception {
  const AccountActionFailure(this.kind);
  final AccountFailureKind kind;
  String get message => switch (kind) {
        AccountFailureKind.signedOut => 'Sign in before changing your account.',
        AccountFailureKind.sessionChanged =>
          'Your account changed. Reopen this editor.',
        AccountFailureKind.invalidName =>
          'Enter a name of at most 120 characters.',
        AccountFailureKind.credentials =>
          'Current password is incorrect. Please retry.',
        AccountFailureKind.weakPassword =>
          'Use a password of at least 6 characters.',
        AccountFailureKind.recentLogin =>
          'Sign in again before changing your password.',
        AccountFailureKind.passwordProvider =>
          'This account does not use an email/password sign-in.',
        AccountFailureKind.network => 'Check your connection and retry.',
        AccountFailureKind.profileSync =>
          'Display name saved. Account name sync failed. Retry to finish.',
        AccountFailureKind.unavailable =>
          'Account changes could not be saved. Please retry.',
      };
  factory AccountActionFailure.forCode(String code) =>
      AccountActionFailure(switch (code) {
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          AccountFailureKind.credentials,
        'weak-password' => AccountFailureKind.weakPassword,
        'requires-recent-login' => AccountFailureKind.recentLogin,
        'network-request-failed' => AccountFailureKind.network,
        _ => AccountFailureKind.unavailable,
      });
}
