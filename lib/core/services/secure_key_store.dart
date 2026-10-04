/// In-memory session cache for AI API keys.
///
/// Keys are also persisted under the owner-only Firestore path
/// `users/{uid}/secrets/llmConfig` (see [LlmService]).
///
/// We intentionally avoid `flutter_secure_storage` here: its native hooks
/// break on Windows usernames that contain spaces (e.g. `ASUS V16`).
class SecureKeyStore {
  SecureKeyStore._();

  static final instance = SecureKeyStore._();

  final Map<String, String> _memory = {};

  Future<void> saveApiKey(String uid, String? apiKey) async {
    final trimmed = apiKey?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _memory.remove(uid);
      return;
    }
    _memory[uid] = trimmed;
  }

  Future<String?> readApiKey(String uid) async {
    final value = _memory[uid];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> clearApiKey(String uid) async {
    _memory.remove(uid);
  }
}
