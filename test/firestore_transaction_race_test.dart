import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as bridge;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercises the real FlutterFire platform bridge through mocked native channels.
// The interleaving is based on upstream issue18551/PR18554, using version6.6.12's codec.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const eventName =
      'plugins.flutter.io/firebase_firestore/transaction/whatmeal-race';
  const eventCodec = StandardMethodCodec();
  const create = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.transactionCreate',
      bridge.FirebaseFirestoreHostApi.codec);
  const store = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.transactionStoreResult',
      bridge.FirebaseFirestoreHostApi.codec);
  late FirebaseApp app;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Completer<void> listened, storeCalled, release;
  setUpAll(() async {
    app = await Firebase.initializeApp(
        name: 'whatmeal-race-test',
        options: const FirebaseOptions(
            apiKey: 'local-test-placeholder',
            appId: 'local-test-app',
            messagingSenderId: 'local',
            projectId: 'demo-whatmeal-audit'));
  });
  setUp(() {
    listened = Completer<void>();
    storeCalled = Completer<void>();
    release = Completer<void>();
    messenger.setMockDecodedMessageHandler(
        create, (_) async => ['whatmeal-race']);
    messenger.setMockDecodedMessageHandler(store, (_) async {
      if (!storeCalled.isCompleted) storeCalled.complete();
      await release.future;
      return [null];
    });
    messenger.setMockMessageHandler(eventName, (_) async {
      if (!listened.isCompleted) listened.complete();
      return eventCodec.encodeSuccessEnvelope(null);
    });
  });
  tearDown(() {
    messenger.setMockDecodedMessageHandler(create, null);
    messenger.setMockDecodedMessageHandler(store, null);
    messenger.setMockMessageHandler(eventName, null);
  });
  // Mock Firebase app is process-local; no native delete channel exists.
  void emit(Map<String, Object?> event) {
    ServicesBinding.instance.channelBuffers
        .push(eventName, eventCodec.encodeSuccessEnvelope(event), (_) {});
  }

  for (final race in [true, false]) {
    test(
        race
            ? 'native error during handler failure completes only once with original error'
            : 'ordinary handler failure is still delivered without suppression',
        () async {
      final future = FirebaseFirestore.instanceFor(app: app)
          .runTransaction<void>(
              (_) => throw StateError('local handler failure'));
      final checked = expectLater(
          future,
          race
              ? throwsA(isA<FirebaseException>()
                  .having((e) => e.code, 'code', 'deadline-exceeded'))
              : throwsStateError);
      await listened.future;
      emit({'appName': app.name});
      await storeCalled.future;
      if (race) {
        emit({
          'error': {
            'code': 'deadline-exceeded',
            'message': 'Local native failure'
          }
        });
        await checked;
      }
      release.complete();
      await checked;
      await Future<void>.delayed(Duration.zero);
    });
  }
}
