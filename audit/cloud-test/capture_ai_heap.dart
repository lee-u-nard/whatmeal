// Read-only diagnostic capture for the already-running disposable cloud app.
// Never invokes application methods, requests GC, pauses/resumes an isolate,
// retries generation, or prints the private VM URI or captured object values.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

const _classNames = ['Meal', 'GeneratedMeal', 'AiMealResponse', 'MealPlan'];
const _maximumObjects = 100;
const _maximumDepth = 5;
const _privateDirectory = 'build/cloudtest-private';

Future<void> main() async {
  // VM/network failures sometimes contain an authenticated endpoint. No raw
  // exception or stack trace is permitted on this diagnostic's public output.
  await runZonedGuarded(() async {
    await _capture();
  }, (Object error, StackTrace _) {
    stdout.writeln(jsonEncode(
        {'captureFailed': true, 'errorType': error.runtimeType.toString()}));
    exitCode = 1;
  });
}

Future<void> _capture() async {
  VmService? service;
  try {
    final log = File('$_privateDirectory/android-generate-private.log');
    final privateText = await log.readAsString();
    final candidates = RegExp(
      r'(?:VM [Ss]ervice[^\r\n]*?(?:available at:|listening on)|Dart VM service is listening on)\s*((?:http|ws)s?://(?:127\.0\.0\.1|localhost):\d+/[^\s]+)',
      caseSensitive: false,
    ).allMatches(privateText).toList();
    final fallback = RegExp(
      r'(?:^|\s)((?:http|ws)s?://(?:127\.0\.0\.1|localhost):\d+/[A-Za-z0-9=_-]+/?)\s',
      multiLine: true,
    ).allMatches(privateText).toList();
    final matches = candidates.isNotEmpty ? candidates : fallback;
    if (matches.isEmpty) {
      throw StateError('No private loopback VM endpoint found.');
    }
    final original = Uri.parse(matches.last.group(1)!);
    if (!const ['127.0.0.1', 'localhost'].contains(original.host) ||
        original.port <= 0 ||
        original.userInfo.isNotEmpty ||
        original.query.isNotEmpty ||
        !const ['http', 'https', 'ws', 'wss'].contains(original.scheme)) {
      throw StateError('Only the private loopback VM endpoint is allowed.');
    }
    final path = original.path.endsWith('/ws')
        ? original.path
        : '${original.path.endsWith('/') ? original.path : '${original.path}/'}ws';
    final websocket = original.replace(
      scheme: const ['https', 'wss'].contains(original.scheme) ? 'wss' : 'ws',
      path: path,
    );
    service = await vmServiceConnectUri(websocket.toString())
        .timeout(const Duration(seconds: 15));
    final vm = await service.getVM().timeout(const Duration(seconds: 15));
    final isolates = vm.isolates ?? <IsolateRef>[];
    final main =
        isolates.where((isolate) => isolate.name == 'main').firstOrNull ??
            isolates
                .where((isolate) => isolate.name?.contains('main') == true)
                .firstOrNull;
    final isolateId = main?.id;
    if (isolateId == null) throw StateError('Main isolate not found.');
    final classes = await service
        .getClassList(isolateId)
        .timeout(const Duration(seconds: 15));
    final captures = <String, Map<String, Object?>>{};
    final references = <String, List<ObjRef>>{};
    for (final name in _classNames) {
      final selected = (classes.classes ?? <ClassRef>[])
          .where((classRef) => classRef.name == name)
          .toList();
      final refs = <ObjRef>[];
      var totalCount = 0;
      for (final classRef in selected) {
        final id = classRef.id;
        if (id == null || refs.length >= _maximumObjects) continue;
        final set = await service
            .getInstances(
              isolateId,
              id,
              _maximumObjects - refs.length,
              includeSubclasses: false,
              includeImplementers: false,
            )
            .timeout(const Duration(seconds: 15));
        totalCount += set.totalCount ?? 0;
        refs.addAll(set.instances ?? <ObjRef>[]);
      }
      references[name] = refs;
      captures[name] = {
        'classMatches': selected.length,
        'totalCount': totalCount,
        'sampledCount': refs.length,
        'objects': <Object?>[],
      };
    }
    final reader = _HeapReader(service, isolateId);
    // Interleave classes so one large meal list cannot consume the entire
    // read budget before a MealPlan or normalized AI response is inspected.
    for (var index = 0; index < _maximumObjects; index++) {
      var found = false;
      for (final name in _classNames) {
        final refs = references[name]!;
        if (index >= refs.length) continue;
        found = true;
        final captured = await reader.read(refs[index], depth: 0);
        (captures[name]!['objects'] as List<Object?>).add(captured);
      }
      if (!found || reader.objectsRead >= _maximumObjects) break;
    }
    final output = File('$_privateDirectory/heap-capture.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'readOnly': true,
      'maximumObjects': _maximumObjects,
      'maximumDepth': _maximumDepth,
      'objectsRead': reader.objectsRead,
      'classes': captures,
    }));
    stdout.writeln(jsonEncode({
      'classes': [
        for (final name in _classNames)
          {
            'class': name,
            'totalCount': captures[name]!['totalCount'],
            'capturedCount': (captures[name]!['objects'] as List).length,
            'fieldLengths': [
              for (final object in captures[name]!['objects'] as List)
                _fieldLengths(object),
            ],
          }
      ],
      'objectsRead': reader.objectsRead,
    }));
  } catch (error) {
    stdout.writeln(jsonEncode(
        {'captureFailed': true, 'errorType': error.runtimeType.toString()}));
    exitCode = 1;
  } finally {
    await service?.dispose();
  }
}

Map<String, Object?> _fieldLengths(Object? object) {
  if (object is! Map || object['fields'] is! Map) return {};
  return {
    for (final field in (object['fields'] as Map).entries)
      field.key.toString(): switch (field.value) {
        String text => {'stringLength': text.length},
        List list => {'listLength': list.length},
        Map map => {'fieldCount': map.length},
        _ => {'primitiveCount': field.value == null ? 0 : 1},
      },
  };
}

class _HeapReader {
  _HeapReader(this.service, this.isolateId);
  final VmService service;
  final String isolateId;
  int objectsRead = 0;
  final Map<String, Object?> _cache = {};
  final Set<String> _reading = {};

  Future<Object?> read(Object? reference, {required int depth}) async {
    if (reference == null ||
        reference is num ||
        reference is bool ||
        reference is String) {
      return reference;
    }
    if (reference is Sentinel) return {'unavailable': true};
    if (reference is! InstanceRef) return {'unsupportedReference': true};
    switch (reference.kind) {
      case 'Null':
        return null;
      case 'Bool':
        return reference.valueAsString == 'true';
      case 'Int':
        return int.tryParse(reference.valueAsString ?? '');
      case 'Double':
        final number = double.tryParse(reference.valueAsString ?? '');
        return number?.isFinite == true ? number : null;
    }
    final id = reference.id;
    if (id == null) return {'unavailable': true};
    if (_cache.containsKey(id)) return _cache[id];
    if (_reading.contains(id)) return {'cycle': true};
    if (depth > _maximumDepth || objectsRead >= _maximumObjects) {
      return {'bounded': true, 'class': reference.classRef?.name};
    }
    _reading.add(id);
    try {
      objectsRead++;
      final object = await service
          .getObject(isolateId, id, offset: 0, count: 100)
          .timeout(const Duration(seconds: 10));
      if (object is! Instance) return {'unavailable': true};
      Object? value;
      if (object.kind == 'String') {
        final length = object.length ?? object.valueAsString?.length ?? 0;
        final string = StringBuffer();
        for (var offset = 0; offset < length; offset += 1024) {
          final remaining = length - offset;
          final chunk = await service
              .getObject(isolateId, id,
                  offset: offset, count: remaining < 1024 ? remaining : 1024)
              .timeout(const Duration(seconds: 10));
          if (chunk is! Instance || chunk.valueAsString == null) {
            throw StateError('String became unavailable.');
          }
          string.write(chunk.valueAsString);
        }
        value = string.toString();
      } else if (object.elements != null) {
        value = [
          for (final element in object.elements!)
            await read(element, depth: depth + 1),
        ];
      } else if (object.associations != null) {
        value = {
          'mapEntries': [
            for (final association in object.associations!)
              {
                'key': await read(association.key, depth: depth + 1),
                'value': await read(association.value, depth: depth + 1),
              }
          ],
        };
      } else {
        value = {
          'class': object.classRef?.name,
          'fields': {
            for (final field in object.fields ?? <BoundField>[])
              (field.name ?? field.decl?.name ?? 'unknown').toString():
                  await read(field.value, depth: depth + 1),
          },
        };
      }
      _cache[id] = value;
      return value;
    } catch (_) {
      return {'unavailable': true, 'class': reference.classRef?.name};
    } finally {
      _reading.remove(id);
    }
  }
}
