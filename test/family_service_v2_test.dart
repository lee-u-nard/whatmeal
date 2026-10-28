import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/services/family_service.dart';
import 'package:whatmeal/core/models/family.dart';

// These verify client operations, NOT authorization or real transaction contention.
void main() {
  late FakeFirebaseFirestore db;
  late FamilyService service;
  setUp(() {
    db = FakeFirebaseFirestore();
    service = FamilyService(firestore: db);
  });
  Future<String> household() async =>
      service.createFamily(name: 'Home', uid: 'owner', displayName: 'Owner');

  test('bootstrap uses canonical membership/index without private-user writes',
      () async {
    final id = await household();
    final data = (await db.doc('families/$id').get()).data()!;
    expect(data['schemaVersion'], 2);
    final serialized =
        Family.fromFirestore(await db.doc('families/$id').get()).toFirestore();
    expect(serialized['schemaVersion'], 2);
    expect(serialized.containsKey('inviteCode'), isFalse);
    expect(serialized.containsKey('memberUids'), isFalse);
    expect(data['ownerUid'], 'owner');
    expect(data.containsKey('memberUids'), isFalse);
    expect(data.containsKey('inviteCode'), isFalse);
    expect(
        (await db.doc('membershipIndex/owner').get()).data()?['familyId'], id);
    expect((await db.doc('families/$id/members/owner').get()).data()?['uid'],
        'owner');
    expect((await db.collection('users').get()).docs, isEmpty);
  });
  test('wrong recipient leaves token and membership untouched', () async {
    final id = await household();
    final token = await service.createInvitation(
        familyId: id, uid: 'owner', recipientUid: 'recipient');
    await expectLater(
        service.joinFamily(
            inviteCode: token, uid: 'other', displayName: 'Other'),
        throwsStateError);
    expect((await db.doc('membershipIndex/other').get()).exists, isFalse);
    expect((await db.doc('families/$id/members/other').get()).exists, isFalse);
    expect((await db.doc('householdInvitations/$token').get()).data()?['state'],
        'pending');
    expect(
        await service.joinFamily(
            inviteCode: token, uid: 'recipient', displayName: 'Recipient'),
        id);
  });
  test('second household blocked by existing index', () async {
    await household();
    await expectLater(household(), throwsStateError);
    expect((await db.collection('families').get()).size, 1);
  });
  test('tokens have 192-bit encoding and legacy codes are rejected', () {
    final tokens =
        List.generate(100, (_) => FamilyService.newInvitationToken());
    expect(tokens.toSet().length, 100);
    for (final token in tokens) {
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]{32}$')));
      FamilyService.validateToken(token);
    }
    expect(() => FamilyService.validateToken('ABC123'), throwsStateError);
  });
  test('single-use invitation creates member/index and consumption together',
      () async {
    final id = await household();
    final token = await service.createInvitation(
        familyId: id, uid: 'owner', role: 'viewOnly');
    await service.joinFamily(
        inviteCode: token, uid: 'joined', displayName: 'Reader');
    final invite = (await db.doc('householdInvitations/$token').get()).data()!;
    expect(invite['state'], 'redeemed');
    expect(invite['redeemedBy'], 'joined');
    expect((await db.doc('families/$id/members/joined').get()).data()?['role'],
        'viewOnly');
    await service.leaveFamily(familyId: id, uid: 'joined');
    await expectLater(
        service.joinFamily(
            inviteCode: token, uid: 'joined', displayName: 'Reader'),
        throwsStateError);
  });
  test('revoked and expired invitations fail before local membership writes',
      () async {
    final id = await household();
    final revoked = await service.createInvitation(familyId: id, uid: 'owner');
    await service.revokeInvitation(revoked);
    await expectLater(
        service.joinFamily(
            inviteCode: revoked, uid: 'outsider', displayName: 'X'),
        throwsStateError);
    final token = await service.createInvitation(familyId: id, uid: 'owner');
    final future = FamilyService(
        firestore: db, now: () => DateTime.now().add(const Duration(days: 3)));
    await expectLater(
        future.joinFamily(inviteCode: token, uid: 'outsider', displayName: 'X'),
        throwsStateError);
    expect((await db.doc('membershipIndex/outsider').get()).exists, isFalse);
  });
  test('removal preserves private account and archival retains nested data',
      () async {
    final id = await household();
    final token = await service.createInvitation(familyId: id, uid: 'owner');
    await service.joinFamily(
        inviteCode: token, uid: 'member', displayName: 'Member');
    await db.doc('users/member').set({'displayName': 'Private'});
    await db.doc('families/$id/pantryItems/rice').set({'name': 'Rice'});
    await service.removeMember(familyId: id, memberUid: 'member');
    expect((await db.doc('users/member').get()).data(),
        {'displayName': 'Private'});
    expect((await db.doc('membershipIndex/member').get()).exists, isFalse);
    await service.deleteFamily(familyId: id, memberUids: ['owner']);
    expect((await db.doc('families/$id').get()).data()?['state'], 'archived');
    expect(
        (await db.doc('families/$id/pantryItems/rice').get()).exists, isTrue);
    await service.restoreFamily(id);
    expect((await db.doc('families/$id').get()).data()?['state'], 'active');
  });
  test('ownership requires offer acceptance; creator remains immutable',
      () async {
    final id = await household();
    final token = await service.createInvitation(familyId: id, uid: 'owner');
    await service.joinFamily(
        inviteCode: token, uid: 'member', displayName: 'Member');
    await expectLater(
        service.updateMemberRole(
            familyId: id, memberUid: 'member', newRole: 'owner'),
        throwsStateError);
    await service.offerOwnership(
        familyId: id, fromUid: 'owner', toUid: 'member');
    await expectLater(service.acceptOwnership(familyId: id, uid: 'someoneElse'),
        throwsStateError);
    await service.acceptOwnership(familyId: id, uid: 'member');
    final data = (await db.doc('families/$id').get()).data()!;
    expect(data['ownerUid'], 'member');
    expect(data['createdBy'], 'owner');
    expect((await db.doc('families/$id/members/owner').get()).data()?['role'],
        'admin');
  });
}
