import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/ai/adapters/http_response_support.dart';
import 'package:whatmeal/core/services/ai/ai_models.dart';
import 'package:whatmeal/core/services/ai/bundled_key_pool.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';

void main() {
  test('empty pool has no attempts', () {
    final pool = BundledKeyPool(const []);
    expect(pool.count, 0);
    expect(pool.currentKey, isNull);
    expect(pool.advance(), isFalse);
    expect(pool.requestKeys(), isEmpty);
  });

  test('each request snapshots distinct configured keys once', () {
    final pool =
        BundledKeyPool([' synthetic-a ', '', 'synthetic-b', 'synthetic-a']);
    expect(pool.count, 2);
    final first = pool.requestKeys();
    final second = pool.requestKeys();
    expect(first, ['synthetic-a', 'synthetic-b']);
    expect(second, ['synthetic-b', 'synthetic-a']);
    expect(first, ['synthetic-a', 'synthetic-b']);
    expect(() => first.add('synthetic-c'), throwsUnsupportedError);
  });

  test('interleaved requests retain their own complete attempt order', () {
    final pool = BundledKeyPool(['synthetic-a', 'synthetic-b', 'synthetic-c']);
    final first = pool.requestKeys();
    final second = pool.requestKeys();
    pool.advance();
    expect(first.toSet().length, pool.count);
    expect(second.toSet().length, pool.count);
    expect(first, ['synthetic-a', 'synthetic-b', 'synthetic-c']);
    expect(second, ['synthetic-b', 'synthetic-c', 'synthetic-a']);
  });

  test('only credential-specific HTTP failures allow another attempt', () {
    for (final status in TestConnectionStatus.values) {
      expect(
          BundledKeyPool.canTryNext(AiHttpFailure('Fixed safe error', status)),
          const {
            TestConnectionStatus.invalidKey,
            TestConnectionStatus.permissionDenied,
            TestConnectionStatus.rateLimited,
          }.contains(status));
    }
    expect(
        BundledKeyPool.canTryNext(
            const GenerationFailure(GenerationFailureKind.quota)),
        isFalse);
    expect(
        BundledKeyPool.canTryNext(
            const GenerationFailure(GenerationFailureKind.malformed)),
        isFalse);
  });
}
