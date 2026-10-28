import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-only decoder for the pinned Firestore Pigeon batch wire format.
/// Sentinels stay explicit; they are never replaced by guessed timestamps.
class CloudBatchWireCodec extends StandardMessageCodec {
  const CloudBatchWireCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) => switch (type) {
        // Pigeon app/settings/transaction commands wrap standard lists.
        131 || 135 || 140 => readValue(buffer),
        180 => {'__type': 'dateTimeMillis', 'value': buffer.getInt64()},
        187 => {'__type': 'serverTimestamp'},
        188 => {
            '__type': 'timestamp',
            'seconds': buffer.getInt64(),
            'nanoseconds': buffer.getInt32(),
          },
        _ => super.readValueOfType(type, buffer),
      };
}

/// Exact owner plan/meal payload goes only to an ignored private driver file.
/// Public diagnostics contain field types, sizes and the native result code.
class CapturedFirestoreBatch {
  CapturedFirestoreBatch(this.privatePayload);
  final Map<String, Object?> privatePayload;

  Map<String, Object?> get summary => {
        'originalWriteCount': privatePayload['originalWriteCount'],
        'capturedWriteCount': (privatePayload['writes'] as List).length,
        if (privatePayload.containsKey('nativeResultCode'))
          'nativeResultCode': privatePayload['nativeResultCode'],
        'documents': [
          for (final write in privatePayload['writes'] as List)
            {
              'kind': (write['path'] as String).split('/').length == 4
                  ? 'plan'
                  : 'meal',
              'operation': write['operation'],
              'fields': describeBatchValue(write['data']),
              'schemaScalars': {
                for (final field in ['numberOfDays', 'dayIndex'])
                  if (write['data'] is Map &&
                      (write['data'] as Map).containsKey(field))
                    field: (write['data'] as Map)[field],
              },
            },
        ],
      };
}

Object describeBatchValue(Object? value) {
  if (value == null) return {'type': 'null'};
  if (value is String) return {'type': 'string', 'length': value.length};
  if (value is bool) return {'type': 'bool'};
  if (value is int) return {'type': 'int'};
  if (value is double) return {'type': 'double', 'finite': value.isFinite};
  if (value is List) {
    return {
      'type': 'list',
      'length': value.length,
      'items': value.map(describeBatchValue).toList()
    };
  }
  if (value is Map) {
    if (value['__type'] is String) return {'type': value['__type']};
    return {
      'type': 'map',
      'fields': {
        for (final entry in value.entries)
          entry.key.toString(): describeBatchValue(entry.value),
      }
    };
  }
  return {'type': value.runtimeType.toString()};
}

CapturedFirestoreBatch? inspectOwnerPlanBatch(ByteData? bytes,
    {required String ownerUid}) {
  if (bytes == null || ownerUid.isEmpty) return null;
  final args = const CloudBatchWireCodec().decodeMessage(bytes);
  if (args is! List || args.length != 2 || args[1] is! List) return null;
  final commands = args[1] as List;
  final matching = <Map<String, Object?>>[];
  for (final command in commands) {
    if (command is! List || command.length != 4 || command[1] is! String) {
      continue;
    }
    final path = command[1] as String;
    final parts = path.split('/');
    if ((parts.length != 4 && parts.length != 6) ||
        parts[0] != 'users' ||
        parts[1] != ownerUid ||
        parts[2] != 'mealPlans' ||
        (parts.length == 6 && parts[4] != 'meals')) {
      continue;
    }
    matching.add({
      'operation': switch (command[0]) {
        2 => 'set',
        1 => 'update',
        3 => 'delete',
        _ => 'other'
      },
      'path': path,
      'data': command[2],
      'options': command[3],
    });
  }
  if (matching.isEmpty) return null;
  return CapturedFirestoreBatch({
    'originalWriteCount': commands.length,
    'writes': matching,
  });
}

/// Observes one channel only and always forwards its original bytes and native
/// reply unchanged. No successful write, Auth result or rule decision is mocked.
class FirestoreBatchCapture {
  FirestoreBatchCapture(
      {required this.ownerUid,
      required this.onChanged,
      this.onDiagnosticError});
  final String ownerUid;
  final void Function(List<Map<String, Object?>> privateBatches,
      List<Map<String, Object?>> summaries) onChanged;
  final void Function(String code)? onDiagnosticError;
  static const channel =
      'dev.flutter.pigeon.cloud_firestore_platform_interface.'
      'FirebaseFirestoreHostApi.writeBatchCommit';
  final _captured = <CapturedFirestoreBatch>[];
  TestDefaultBinaryMessenger? _messenger;
  MessageHandler? _handler;

  void install(TestDefaultBinaryMessenger messenger) {
    if (_messenger != null ||
        !messenger.checkMockMessageHandler(channel, null)) {
      throw StateError('Refuse to replace an existing batch-channel observer.');
    }
    _messenger = messenger;
    _handler = (bytes) async {
      CapturedFirestoreBatch? captured;
      try {
        captured = inspectOwnerPlanBatch(bytes, ownerUid: ownerUid);
        if (captured != null) {
          _captured.add(captured);
          _publish();
        }
      } catch (_) {
        // Decoder diagnostics must not alter or bypass the actual native call.
        captured = null;
        _diagnosticError('batch-decode-unavailable');
      }
      try {
        final reply = await messenger.delegate.send(channel, bytes);
        if (captured != null) {
          try {
            final decoded = reply == null
                ? null
                : const StandardMessageCodec().decodeMessage(reply);
            captured.privatePayload['nativeResultCode'] =
                decoded is List && decoded.length > 1 && decoded.first is String
                    ? decoded.first
                    : 'native-reply-returned';
          } catch (_) {
            captured.privatePayload['nativeResultCode'] =
                'native-reply-decode-unavailable';
            _diagnosticError('native-reply-decode-unavailable');
          }
          _publish();
        }
        return reply;
      } catch (error) {
        if (captured != null) {
          captured.privatePayload['nativeResultCode'] =
              error is PlatformException
                  ? error.code
                  : 'native-transport-error';
          _publish();
        }
        rethrow;
      }
    };
    messenger.setMockMessageHandler(channel, _handler);
  }

  void _publish() {
    try {
      onChanged([for (final batch in _captured) batch.privatePayload],
          [for (final batch in _captured) batch.summary]);
    } catch (_) {
      _diagnosticError('batch-capture-publish-failed');
    }
  }

  void _diagnosticError(String code) {
    try {
      onDiagnosticError?.call(code);
    } catch (_) {
      // An observer callback may never change the native operation's result.
    }
  }

  void dispose() {
    final messenger = _messenger;
    if (messenger != null &&
        messenger.checkMockMessageHandler(channel, _handler)) {
      messenger.setMockMessageHandler(channel, null);
    }
    _messenger = null;
    _handler = null;
  }
}
