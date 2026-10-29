import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family.dart';

/// Schema-v2 household operations. Authorization is enforced independently by rules.
/// No operation writes another user's private document or performs a cascade.
class FamilyService {
  FamilyService(
      {FirebaseFirestore? firestore,
      DateTime Function()? now,
      Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String id)?
          watchFamily})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _watchFamily = watchFamily,
        _now = now ?? DateTime.now;
  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String id)?
      _watchFamily;
  DocumentReference<Map<String, dynamic>> _family(String id) =>
      _firestore.doc('families/$id');
  DocumentReference<Map<String, dynamic>> _index(String uid) =>
      _firestore.doc('membershipIndex/$uid');

  Stream<String?> membershipStream(String uid) =>
      _index(uid).snapshots().map((doc) => doc.data()?['familyId'] as String?);
  Stream<Family?> familyStream(String id) => (_watchFamily?.call(id) ??
          _family(id).snapshots(includeMetadataChanges: true))
      // Cache absence is not proof of deletion; request metadata-only updates
      // so a later server-confirmed absence still reaches the repository.
      .where((doc) => doc.exists || !doc.metadata.isFromCache)
      .map((doc) => doc.exists ? Family.fromFirestore(doc) : null);
  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String id) =>
      _family(id).collection('members').snapshots(includeMetadataChanges: true);

  static String newInvitationToken() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(24, (_) => random.nextInt(256)));
  }

  static void validateToken(String token) {
    if (!RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(token)) {
      throw StateError(
          'Use a new single-use invitation token. Legacy short codes are no longer supported.');
    }
  }

  Map<String, dynamic> _member(String uid, String name, String role,
          String invitedBy, String? token) =>
      {
        'uid': uid,
        'name': name.trim(),
        'role': role,
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': invitedBy,
        'invitationId': token,
      };

  Future<String> createFamily(
      {required String name,
      required String uid,
      required String displayName}) async {
    if (name.trim().isEmpty || name.trim().length > 100) {
      throw ArgumentError('Household name must contain 1–100 characters.');
    }
    final ref = _firestore.collection('families').doc();
    await _firestore.runTransaction((tx) async {
      if ((await tx.get(_index(uid))).exists) {
        throw StateError('Leave your current household first.');
      }
      tx.set(ref, {
        'schemaVersion': 2,
        'name': name.trim(),
        'createdBy': uid,
        'ownerUid': uid,
        'state': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
      tx.set(ref.collection('members').doc(uid),
          _member(uid, displayName, 'owner', uid, null));
      tx.set(_index(uid), {
        'uid': uid,
        'familyId': ref.id,
        'joinedAt': FieldValue.serverTimestamp()
      });
    });
    // The transaction commit is the success boundary; listeners load the data.
    return ref.id;
  }

  Future<String> createInvitation(
      {required String familyId,
      required String uid,
      String role = 'member',
      String? recipientUid,
      Duration lifetime = const Duration(hours: 48)}) async {
    if (!['admin', 'member', 'viewOnly'].contains(role) ||
        lifetime <= Duration.zero ||
        lifetime > const Duration(days: 7)) {
      throw ArgumentError('Invalid invitation role or expiration.');
    }
    final token = newInvitationToken();
    final expiresAt = Timestamp.fromDate(_now().add(lifetime));
    final batch = _firestore.batch();
    batch.set(_firestore.doc('householdInvitations/$token'), {
      'familyId': familyId,
      'issuedBy': uid,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'state': 'pending',
      'recipientUid': recipientUid,
      'redeemedBy': null,
      'redeemedAt': null,
    });
    batch.set(_family(familyId).collection('invitationRefs').doc(token), {
      'issuedBy': uid,
      'expiresAt': expiresAt,
    });
    await batch.commit();
    return token;
  }

  Future<void> revokeInvitation(String token) async {
    validateToken(token);
    await _firestore
        .doc('householdInvitations/$token')
        .update({'state': 'revoked'});
  }

  Future<String> joinFamily(
      {required String inviteCode,
      required String uid,
      required String displayName}) async {
    final token = inviteCode.trim(); // Tokens are case-sensitive.
    validateToken(token);
    final invite = _firestore.doc('householdInvitations/$token');
    final familyId = await _firestore.runTransaction<String>((tx) async {
      final index = await tx.get(_index(uid));
      final snapshot = await tx.get(invite);
      if (index.exists) throw StateError('Leave your current household first.');
      final data = snapshot.data();
      if (data == null ||
          data['state'] != 'pending' ||
          (data['recipientUid'] != null && data['recipientUid'] != uid) ||
          !(data['expiresAt'] as Timestamp).toDate().isAfter(_now())) {
        throw StateError(
            'Invitation is unavailable or expired. Ask for a new one.');
      }
      final id = data['familyId'] as String;
      tx.update(invite, {
        'state': 'redeemed',
        'redeemedBy': uid,
        'redeemedAt': FieldValue.serverTimestamp()
      });
      tx.set(
          _family(id).collection('members').doc(uid),
          _member(uid, displayName, data['role'] as String,
              data['issuedBy'] as String, token));
      tx.set(_index(uid), {
        'uid': uid,
        'familyId': id,
        'joinedAt': FieldValue.serverTimestamp()
      });
      return id;
    });
    return familyId;
  }

  Future<void> leaveFamily({required String familyId, required String uid}) =>
      removeMember(familyId: familyId, memberUid: uid);

  /// Deletes only the membershipIndex entry for [uid].
  /// Used as a fallback when the family document has been externally deleted and
  /// the normal batch leave (which also deletes the member subdoc) would be
  /// rejected by Firestore rules because they can no longer read the family doc.
  /// The updated rules allow self-deletion of a dangling index entry when the
  /// family document no longer exists.
  Future<void> clearOrphanedMembership({required String uid}) =>
      _index(uid).delete();

  Future<void> removeMember(
      {required String familyId, required String memberUid}) async {
    final batch = _firestore.batch();
    batch.delete(_family(familyId).collection('members').doc(memberUid));
    batch.delete(_index(memberUid));
    await batch.commit();
  }

  Future<void> updateMemberRole(
      {required String familyId,
      required String memberUid,
      required String newRole}) async {
    if (!['admin', 'member', 'viewOnly'].contains(newRole)) {
      throw StateError(
          'Ownership requires a transfer accepted by the new owner.');
    }
    await _family(familyId)
        .collection('members')
        .doc(memberUid)
        .update({'role': newRole});
  }

  /// Archive only. Retains all nested data and indexes for explicit departure or restore.
  Future<void> deleteFamily(
          {required String familyId, required List<String> memberUids}) =>
      _family(familyId).update(
          {'state': 'archived', 'updatedAt': FieldValue.serverTimestamp()});
  Future<void> restoreFamily(String familyId) => _family(familyId)
      .update({'state': 'active', 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> offerOwnership(
          {required String familyId,
          required String fromUid,
          required String toUid}) =>
      _family(familyId).collection('ownershipTransfers').doc('pending').set({
        'fromUid': fromUid,
        'toUid': toUid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(_now().add(const Duration(hours: 48))),
      });
  Future<void> acceptOwnership(
      {required String familyId, required String uid}) async {
    final family = _family(familyId);
    final offer = family.collection('ownershipTransfers').doc('pending');
    await _firestore.runTransaction((tx) async {
      final data = (await tx.get(offer)).data();
      if (data == null || data['toUid'] != uid) {
        throw StateError('No ownership offer for this account.');
      }
      final fromUid = data['fromUid'] as String;
      tx.update(
          family, {'ownerUid': uid, 'updatedAt': FieldValue.serverTimestamp()});
      tx.update(family.collection('members').doc(fromUid), {'role': 'admin'});
      tx.update(family.collection('members').doc(uid), {'role': 'owner'});
      tx.delete(offer);
    });
  }
}
