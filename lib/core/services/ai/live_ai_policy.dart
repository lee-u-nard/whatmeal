import 'generation_failure.dart';

/// Demo Auth/Firestore approval never grants permission for external AI calls.
void requireLiveAiEnvironment(bool useEmulators) {
  if (useEmulators) {
    throw const GenerationFailure(GenerationFailureKind.localOnly);
  }
}
