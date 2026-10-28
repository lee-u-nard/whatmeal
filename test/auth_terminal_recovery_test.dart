import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/data/auth_repository.dart';
import 'package:whatmeal/features/auth/models/account_action_failure.dart';

class LocalAuth extends Fake implements FirebaseAuth {
  final events = StreamController<User?>.broadcast(sync: true);
  User? user;
  int signouts = 0;
  void emit(User? next) {
    user = next;
    events.add(next);
  }

  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  Future<void> signOut() async {
    signouts++;
    emit(null);
  }
}

class LocalUser extends Fake implements User {
  LocalUser(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.test';
  @override
  String get displayName => 'Auth $uid';
  @override
  bool get emailVerified => true;
  @override
  List<UserInfo> get providerData =>
      [LocalInfo()];
  Completer<UserCredential>? reauth;
  int passwordWrites = 0;
  @override
  Future<UserCredential> reauthenticateWithCredential(
          AuthCredential credential) =>
      reauth!.future;
  @override
  Future<void> updatePassword(String password) async {
    passwordWrites++;
  }
}

class LocalCredential extends Fake implements UserCredential {}

void main() {
  test(
      'Auth terminal profile error is safe; retry reopens without changing account session',
      () async {
    final auth = LocalAuth();
    final db = FakeFirebaseFirestore();
    await db.doc('users/a').set({'displayName': 'Canonical A'});
    final feeds = <StreamController<DocumentSnapshot<Map<String, dynamic>>>>[];
    final repo = AuthRepository(
        auth: auth,
        firestore: db,
        watchProfile: (_) {
          final c = StreamController<
              DocumentSnapshot<Map<String, dynamic>>>.broadcast(sync: true);
          feeds.add(c);
          return c.stream;
        });
    auth.emit(LocalUser('a'));
    feeds.last.add(await db.doc('users/a').get());
    expect(repo.value!.name, 'Canonical A');
    final session = repo.sessionVersion;
    feeds.last.addError(StateError('private diagnostic'));
    await feeds.last.close();
    expect(repo.profileError, isNot(contains('private diagnostic')));
    expect(repo.profileError, isNotNull);
    expect(repo.value!.id, 'a');
    repo.retryProfile();
    expect(feeds.length, 2);
    expect(repo.sessionVersion, session);
    feeds.last.add(await db.doc('users/a').get());
    expect(repo.profileError, isNull);
    expect(repo.value!.name, 'Canonical A');
    auth.emit(LocalUser('b'));
    auth.emit(LocalUser('a'));
    feeds[1].addError(StateError('late A'));
    feeds.last.add(await db.doc('users/a').get());
    expect(repo.profileError, isNull);
    expect(repo.value!.id, 'a');
    repo.dispose();
    final count = feeds.length;
    auth.emit(LocalUser('b'));
    expect(feeds.length, count);
    await auth.events.close();
    for (final c in feeds) {
      await c.close();
    }
  });
  test('delayed logout cleanup cannot sign out B or a new A session', () async {
    for (final returnToA in [false, true]) {
      final auth = LocalAuth();
      final gate = Completer<void>();
      final cleared = <String>[];
      final repo = AuthRepository(
          auth: auth,
          firestore: FakeFirebaseFirestore(),
          watchProfile: (_) => const Stream.empty(),
          cleanupNotifications: () => gate.future,
          clearKey: (uid) async {
            cleared.add(uid);
          });
      auth.emit(LocalUser('a'));
      final logout = repo.logout();
      final assertion = expectLater(
          logout,
          throwsA(isA<AccountActionFailure>().having(
              (e) => e.kind, 'kind', AccountFailureKind.sessionChanged)));
      auth.emit(LocalUser('b'));
      if (returnToA) auth.emit(LocalUser('a'));
      gate.complete();
      await assertion;
      expect(auth.signouts, 0);
      expect(auth.currentUser!.uid, returnToA ? 'a' : 'b');
      expect(cleared, isEmpty);
      repo.dispose();
      await auth.events.close();
    }
  });
  test(
      'delayed or failing reauthentication never changes a later session password',
      () async {
    for (final fail in [false, true]) {
      final auth = LocalAuth();
      final a = LocalUser('a')..reauth = Completer<UserCredential>();
      final repo = AuthRepository(
          auth: auth,
          firestore: FakeFirebaseFirestore(),
          watchProfile: (_) => const Stream.empty());
      auth.emit(a);
      final change =
          repo.updatePassword(currentPassword: 'test', newPassword: 'new-test');
      final assertion =
          expectLater(change, throwsA(isA<AccountActionFailure>()));
      auth.emit(LocalUser('b'));
      auth.emit(LocalUser('a'));
      if (fail) {
        a.reauth!.completeError(FirebaseAuthException(
            code: 'network-request-failed', message: 'private diagnostic'));
      } else {
        a.reauth!.complete(LocalCredential());
      }
      await assertion;
      expect(a.passwordWrites, 0);
      repo.dispose();
      await auth.events.close();
    }
  });
}

class LocalInfo extends Fake implements UserInfo {
  @override String get providerId => 'password';
}
