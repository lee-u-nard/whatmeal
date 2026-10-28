import '../../config/bundled_gemini_keys.dart';
import 'adapters/http_response_support.dart';
import 'ai_models.dart';

/// A request gets a stable, bounded snapshot; concurrent requests cannot change
/// which credentials it has already tried. Keys may still share project quotas.
class BundledKeyPool {
  BundledKeyPool(Iterable<String> keys)
      : _keys = List.unmodifiable(keys
            .map((key) => key.trim())
            .where((key) => key.isNotEmpty)
            .toSet());
  static final instance = BundledKeyPool(BundledGeminiKeys.activeKeys);

  final List<String> _keys;

  int _index = 0;

  /// The key that should be used for the next request. Returns `null` when no
  /// bundled keys are configured.
  String? get currentKey {
    if (_keys.isEmpty) return null;
    return _keys[_index % _keys.length];
  }

  /// Number of configured keys.
  int get count => _keys.length;

  /// Advance to the next key. Returns `true` if the next key is different from
  /// the one that just failed (i.e., there are more keys to try).
  bool advance() {
    if (_keys.length <= 1) return false;
    _index = (_index + 1) % _keys.length;
    return true;
  }

  List<String> requestKeys() {
    if (_keys.isEmpty) return const [];
    final start = _index;
    advance();
    return List.unmodifiable(List.generate(
        _keys.length, (offset) => _keys[(start + offset) % _keys.length]));
  }

  /// Repeating invalid input, malformed content or a timeout with another key
  /// cannot repair it and can duplicate generation or consume more quota.
  static bool canTryNext(Object error) =>
      error is AiHttpFailure &&
      const {
        TestConnectionStatus.invalidKey,
        TestConnectionStatus.permissionDenied,
        TestConnectionStatus.rateLimited,
      }.contains(error.status);
}
