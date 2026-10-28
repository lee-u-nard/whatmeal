import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';

UserModel user(String uid) =>
    UserModel(id: uid, name: uid, email: '$uid@example.test');
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('create invite join remove rejoin and A-B-A reload canonical membership',
      () async {
    final db = FakeFirebaseFirestore();
    final service = FamilyService(firestore: db);
    final authA = StreamController<String?>.broadcast(sync: true);
    final authB = StreamController<String?>.broadcast(sync: true);
    final accountA = ValueNotifier<UserModel?>(user('a'));
    final accountB = ValueNotifier<UserModel?>(user('b'));
    final owner = FamilyRepository(
        firestore: db, authIds: authA.stream, account: accountA);
    final member = FamilyRepository(
        firestore: db, authIds: authB.stream, account: accountB);
    authA.add('a');
    authB.add('b');
    await settle();
    expect(await owner.createSpace('Shared home'), isTrue);
    await settle();
    final id = owner.value!.id;
    expect(owner.value!.isOwner('a'), isTrue);
    expect(await owner.regenerateInviteKey(), isTrue);
    expect(await member.joinSpaceWithKey(owner.activeInvitationToken!), isTrue);
    await settle();
    expect(member.value!.id, id);
    expect(owner.value!.members.length, 2);
    expect(member.value!.members.length, 2);
    expect(await owner.removeMember('b'), isTrue);
    await settle();
    expect(member.value, isNull);
    final token = await service.createInvitation(familyId: id, uid: 'a');
    expect(await member.joinSpaceWithKey(token), isTrue);
    await settle();
    expect(member.value!.id, id);
    authB.add(null);
    accountB.value = null;
    expect(member.value, isNull);
    accountB.value = user('outsider');
    authB.add('outsider');
    await db.doc('families/$id').update({'name': 'Late owner update'});
    await settle();
    expect(member.value, isNull);
    accountB.value = user('b');
    authB.add('b');
    await settle();
    expect(member.value!.name, 'Late owner update');
    expect(await member.leaveSpace(), isTrue);
    await settle();
    expect(member.value, isNull);
    expect(owner.value!.members.length, 1);
    owner.dispose();
    member.dispose();
    accountA.dispose();
    accountB.dispose();
    await authA.close();
    await authB.close();
  });

  test('profile/auth UID mismatch refuses mutation and retry reloads state',
      () async {
    final db = FakeFirebaseFirestore();
    final auth = StreamController<String?>.broadcast(sync: true);
    final account = ValueNotifier<UserModel?>(user('old'));
    final repo =
        FamilyRepository(firestore: db, authIds: auth.stream, account: account);
    auth.add('new');
    await settle();
    expect(await repo.createSpace('Must not create'), isFalse);
    expect((await db.collection('families').get()).docs, isEmpty);
    account.value = user('new');
    expect(await repo.createSpace('Valid'), isTrue);
    await settle();
    final id = repo.value!.id;
    repo.retry();
    expect(repo.value, isNull);
    await settle();
    expect(repo.value!.id, id);
    repo.dispose();
    account.dispose();
    await auth.close();
  });
}
