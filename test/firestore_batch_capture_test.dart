import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/support/firestore_batch_capture.dart';

class _Tagged {
  const _Tagged(this.type, [this.value]);
  final int type;
  final Object? value;
}

/// Synthetic native-wire fixture, not a Firebase emulator or live SDK test.
class _FixtureCodec extends StandardMessageCodec {
  const _FixtureCodec();
  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is _Tagged) {
      buffer.putUint8(value.type);
      if (value.type != 187) writeValue(buffer, value.value);
    } else {
      super.writeValue(buffer, value);
    }
  }
}

class _NativeDelegate extends BinaryMessenger {
  _NativeDelegate(this.reply);
  final ByteData? reply;
  ByteData? forwarded;
  int calls = 0;
  @override
  Future<ByteData?> send(String channel, ByteData? message) async {
    forwarded = message;
    calls++;
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ByteData batch({String owner = 'disposable-owner'}) =>
      const _FixtureCodec().encodeMessage([
        const _Tagged(131, [
          '[DEFAULT]',
          [true, null, null, null, false],
          '(default)'
        ]),
        [
          _Tagged(140, [
            2,
            'users/$owner/mealPlans/test-plan',
            {
              'title': 'Synthetic recipe plan',
              'createdBy': owner,
              'numberOfDays': 1,
              'createdAt': const _Tagged(187),
            },
            [null, null]
          ]),
          _Tagged(140, [
            2,
            'users/$owner/mealPlans/test-plan/meals/test-meal',
            {
              'title': 'Private synthetic meal text',
              'dayIndex': 0,
              'ingredients': [
                {'name': 'Private ingredient text', 'amount': '1 cup'}
              ],
              'instructions': ['Private cooking instruction text'],
              'createdAt': const _Tagged(187),
            },
            [null, null]
          ]),
        ],
      ])!;

  test('outgoing Pigeon payload preserves integers and timestamp sentinels',
      () {
    final captured =
        inspectOwnerPlanBatch(batch(), ownerUid: 'disposable-owner')!;
    final writes = captured.privatePayload['writes'] as List;
    final plan = writes.first['data'] as Map;
    final meal = writes.last['data'] as Map;
    expect(plan['numberOfDays'], isA<int>());
    expect(meal['dayIndex'], isA<int>());
    expect(plan['createdAt'], {'__type': 'serverTimestamp'});
    expect(plan['numberOfDays'], 1);
    expect(meal['dayIndex'], 0);
    expect((meal['ingredients'] as List).single['name'],
        'Private ingredient text');
  });

  test('public summaries contain schema sizes but no recipe or account strings',
      () {
    final captured =
        inspectOwnerPlanBatch(batch(), ownerUid: 'disposable-owner')!;
    final summary = jsonEncode(captured.summary);
    expect(summary, contains('numberOfDays'));
    expect(summary, contains('"type":"int"'));
    expect(summary, contains('serverTimestamp'));
    expect(summary, isNot(contains('disposable-owner')));
    expect(summary, isNot(contains('Private synthetic meal text')));
    expect(summary, isNot(contains('Private ingredient text')));
    expect(summary, isNot(contains('Private cooking instruction text')));
  });

  test('only the requested disposable owner plan scope is captured', () {
    expect(
        inspectOwnerPlanBatch(batch(owner: 'another-account'),
            ownerUid: 'disposable-owner'),
        isNull);
    final unrelated = const _FixtureCodec().encodeMessage([
      const _Tagged(131, ['[DEFAULT]', [], '(default)']),
      [
        const _Tagged(140, [
          2,
          'users/disposable-owner/secrets/llmConfig',
          {'apiKey': 'Synthetic key must not be captured'},
          null
        ])
      ],
    ]);
    expect(
        inspectOwnerPlanBatch(unrelated, ownerUid: 'disposable-owner'), isNull);
  });

  test('observer forwards exact native bytes and permission denial unchanged',
      () async {
    final reply = const StandardMessageCodec().encodeMessage([
      'permission-denied',
      'Private native message must not be published',
      null
    ]);
    final delegate = _NativeDelegate(reply);
    final messenger = TestDefaultBinaryMessenger(delegate);
    final summaries = <Map<String, Object?>>[];
    final capture = FirestoreBatchCapture(
        ownerUid: 'disposable-owner',
        onChanged: (_, current) {
          summaries
            ..clear()
            ..addAll(current);
        });
    capture.install(messenger);
    final original = batch();
    final returned =
        await messenger.send(FirestoreBatchCapture.channel, original);
    expect(identical(delegate.forwarded, original), isTrue);
    expect(identical(returned, reply), isTrue);
    expect(delegate.calls, 1);
    expect(summaries.single['nativeResultCode'], 'permission-denied');
    expect(jsonEncode(summaries), isNot(contains('Private native message')));
    capture.dispose();
    expect(
        messenger.checkMockMessageHandler(FirestoreBatchCapture.channel, null),
        isTrue);
  });

  test('unsupported diagnostic bytes never suppress the native operation',
      () async {
    final reply = const StandardMessageCodec().encodeMessage([null]);
    final delegate = _NativeDelegate(reply);
    final messenger = TestDefaultBinaryMessenger(delegate);
    final errors = <String>[];
    final capture = FirestoreBatchCapture(
        ownerUid: 'disposable-owner',
        onChanged: (_, __) => fail('Unsupported data must not be fabricated.'),
        onDiagnosticError: errors.add);
    capture.install(messenger);
    final invalid = ByteData.sublistView(Uint8List.fromList([255]));
    final returned =
        await messenger.send(FirestoreBatchCapture.channel, invalid);
    expect(identical(returned, reply), isTrue);
    expect(identical(delegate.forwarded, invalid), isTrue);
    expect(delegate.calls, 1);
    expect(errors, ['batch-decode-unavailable']);
    capture.dispose();
  });

  test('an undecodable native reply is also forwarded unchanged', () async {
    final reply = ByteData.sublistView(Uint8List.fromList([255]));
    final delegate = _NativeDelegate(reply);
    final messenger = TestDefaultBinaryMessenger(delegate);
    final errors = <String>[];
    final capture = FirestoreBatchCapture(
        ownerUid: 'disposable-owner',
        onChanged: (_, __) {},
        onDiagnosticError: errors.add);
    capture.install(messenger);
    final returned =
        await messenger.send(FirestoreBatchCapture.channel, batch());
    expect(identical(returned, reply), isTrue);
    expect(errors, ['native-reply-decode-unavailable']);
    capture.dispose();
  });
}
