/// Allowlisted evidence from the pinned native App Check exception format.
/// Never return the original message: it can contain keys, tokens or URLs.
class AppCheckDiagnostic {
  const AppCheckDiagnostic._(this.httpStatus, this.reason, this.hint);

  static String defaultHint({required bool isWeb}) => isWeb
      ? 'Firebase App Check could not verify this browser. Check the Firebase web app registration, reCAPTCHA configuration, or registered development token. This is separate from Gemini quota and plan saving.'
      : 'Firebase App Check could not obtain or validate this app\'s verification token. Check the Firebase app registration, signing certificate and Play Integrity setup. This is separate from Gemini quota and plan saving.';

  final int? httpStatus;
  final String? reason;
  final String? hint;

  factory AppCheckDiagnostic.fromMessage(String? message) {
    final text = message ?? '';
    final lower = text.toLowerCase();
    final match = RegExp(
            r'Error returned from API\.\s*code:\s*(400|401|403|404|408|409|429|500|502|503|504)\b',
            caseSensitive: false)
        .firstMatch(text);
    final http = match == null ? null : int.parse(match.group(1)!);
    String? reason;
    String? hint;
    if (lower.contains('too many attempts.')) {
      reason = 'APP_CHECK_BACKOFF';
      hint =
          'Firebase App Check is temporarily backing off after a verification failure. '
          'Wait before retrying; repeated taps will not help. Do not clear app data.';
    } else if (RegExp(r'\bAPI_KEY_ANDROID_APP_BLOCKED\b').hasMatch(text) ||
        (lower.contains('requests from this android client application') &&
            lower.contains('are blocked'))) {
      reason = 'API_KEY_ANDROID_APP_BLOCKED';
      hint =
          'Firebase App Check rejected this Android app under the Firebase client API key restrictions. '
          'The owner must verify the allowed package and signing fingerprint; keep the restrictions enabled.';
    } else if (RegExp(r'\bAPI_KEY_SERVICE_BLOCKED\b').hasMatch(text) ||
        (lower.contains(
                'requests to this api firebaseappcheck.googleapis.com') &&
            lower.contains('are blocked'))) {
      reason = 'API_KEY_SERVICE_BLOCKED';
      hint =
          'Firebase App Check requests are blocked by the Firebase client API key restrictions. '
          'The project owner must check the allowed Firebase APIs; keep App Check enforced.';
    } else if (RegExp(r'\bAPI_KEY_INVALID\b').hasMatch(text) ||
        lower.contains('api key not valid')) {
      reason = 'API_KEY_INVALID';
      hint =
          'Firebase App Check rejected the Firebase client configuration key. '
          'Check that the native Firebase configuration belongs to this app and project; '
          'a personal Gemini key is not the fix.';
    } else if (lower.contains('app not registered')) {
      reason = 'APP_NOT_REGISTERED';
      hint =
          'Firebase App Check does not recognize the Firebase app registration. '
          'Check the app ID, package and registered App Check provider for this build.';
    } else if (lower.contains('app attestation failed')) {
      reason = 'APP_ATTESTATION_FAILED';
      hint =
          'Firebase App Check rejected the app attestation. The token response does not '
          'identify a specific device or certificate problem. Check the registered app, '
          'signing certificate and off-Play device-integrity requirements.';
    }

    // This pinned provider uses classic IntegrityManager. Do not interpret
    // Standard Integrity's different numeric meanings as classic errors.
    if (reason == null && !lower.contains('standardintegrity')) {
      final integrity = RegExp(
              r'(?:IntegrityServiceException:\s*|Integrity API error\s*\()(-\d{1,3})(?!\d)',
              caseSensitive: false)
          .firstMatch(text);
      final code = integrity == null ? null : int.tryParse(integrity.group(1)!);
      const classic = {
        -3: (
          'PLAY_INTEGRITY_NETWORK_ERROR',
          'Play Integrity could not reach its service. Check connectivity before retrying.'
        ),
        -4: (
          'PLAY_STORE_ACCOUNT_NOT_FOUND',
          'Play Integrity could not find a supported Play Store account. Check Play Store availability in the current Android profile.'
        ),
        -6: (
          'PLAY_SERVICES_NOT_FOUND',
          'Play Integrity requires available, supported Google Play services.'
        ),
        -8: (
          'PLAY_INTEGRITY_TOO_MANY_REQUESTS',
          'Play Integrity is throttling verification requests. Wait before retrying; this is not Gemini quota.'
        ),
        -14: (
          'PLAY_STORE_VERSION_OUTDATED',
          'Play Integrity requires a newer supported Google Play Store version.'
        ),
        -15: (
          'PLAY_SERVICES_VERSION_OUTDATED',
          'Play Integrity requires a newer supported Google Play services version.'
        ),
        -16: (
          'CLOUD_PROJECT_NUMBER_IS_INVALID',
          'Play Integrity rejected the configured Cloud project number. The app must use the numeric project where Play Integrity is enabled.'
        ),
        -17: (
          'PLAY_INTEGRITY_CLIENT_TRANSIENT_ERROR',
          'Play Integrity reported a temporary client error. Retry later without clearing app data.'
        ),
      };
      final known = classic[code];
      if (known != null) {
        reason = known.$1;
        hint = known.$2;
      }
    }
    return AppCheckDiagnostic._(http, reason, hint);
  }

  String get suffix {
    final parts = [
      if (httpStatus != null) 'HTTP $httpStatus',
      if (reason != null) reason!
    ];
    return parts.isEmpty ? '' : ' [${parts.join('; ')}]';
  }
}
