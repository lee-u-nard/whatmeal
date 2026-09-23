import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family.dart';

/// Service for creating, joining, leaving, and deleting family groups.
/// Handles invite code generation and family membership management.
class FamilyService {
  FamilyService();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _familiesCol =>
      _firestore.collection('families');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  /// Stream the family document for a given [familyId].
  Stream<Family?> familyStream(String familyId) {
    return _familiesCol.doc(familyId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Family.fromFirestore(snap);
    });
  }

  /// Stream the members collection for a given [familyId].
  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String familyId) {
    return _familiesCol.doc(familyId).collection('members').snapshots();
  }

  /// Create a new family group with a generated 6-character invite code.
  /// Returns the created [Family].
  Future<Family> createFamily({
    required String name,
    required String uid,
    required String displayName,
  }) async {
    final inviteCode = await _generateUniqueInviteCode();
    final docRef = _familiesCol.doc();

    final family = Family(
      id: docRef.id,
      name: name,
      inviteCode: inviteCode,
      createdBy: uid,
      memberUids: [uid],
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    // Create family document
    batch.set(docRef, family.toFirestore());

    // Create owner member subdocument
    batch.set(docRef.collection('members').doc(uid), {
      'displayName': displayName,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Update user's familyId safely (creates document if it doesn't exist)
    batch.set(_usersCol.doc(uid), {'familyId': docRef.id}, SetOptions(merge: true));

    await batch.commit();
    return family;
  }

  /// Join an existing family group using an invite code.
  Future<Family> joinFamily({
    required String inviteCode,
    required String uid,
    required String displayName,
  }) async {
    // Look up family by invite code
    final query = await _familiesCol
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code. No family group found.');
    }

    final familyDoc = query.docs.first;
    final familyId = familyDoc.id;
    final existingMembers = List<String>.from(familyDoc.data()['memberUids'] ?? []);

    if (existingMembers.contains(uid)) {
      throw Exception('You are already a member of this family group.');
    }

    final batch = _firestore.batch();

    // Add uid to memberUids array
    batch.update(_familiesCol.doc(familyId), {
      'memberUids': FieldValue.arrayUnion([uid]),
    });

    // Create member subdocument
    batch.set(_familiesCol.doc(familyId).collection('members').doc(uid), {
      'displayName': displayName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // Update user's familyId
    batch.set(_usersCol.doc(uid), {'familyId': familyId}, SetOptions(merge: true));

    await batch.commit();

    // Return updated family
    final updatedDoc = await _familiesCol.doc(familyId).get();
    return Family.fromFirestore(updatedDoc);
  }

  /// Leave the current family group.
  Future<void> leaveFamily({
    required String familyId,
    required String uid,
  }) async {
    final batch = _firestore.batch();

    // Remove uid from memberUids
    batch.update(_familiesCol.doc(familyId), {
      'memberUids': FieldValue.arrayRemove([uid]),
    });

    // Delete member subdocument
    batch.delete(_familiesCol.doc(familyId).collection('members').doc(uid));

    // Clear user's familyId
    batch.set(_usersCol.doc(uid), {'familyId': null}, SetOptions(merge: true));

    await batch.commit();
  }

  /// Delete the entire family group. Only the owner should call this.
  /// Cascade cleanup of subcollections should be handled by a Cloud Function
  /// trigger on `families/{familyId}` deletion.
  Future<void> deleteFamily({
    required String familyId,
    required List<String> memberUids,
  }) async {
    final batch = _firestore.batch();

    // Clear familyId for all members
    for (final uid in memberUids) {
      batch.set(_usersCol.doc(uid), {'familyId': null}, SetOptions(merge: true));
    }

    // Delete the family document (Cloud Function handles subcollection cleanup)
    batch.delete(_familiesCol.doc(familyId));

    await batch.commit();
  }

  /// Generate a unique 6-character alphanumeric invite code.
  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 for readability
    final random = Random.secure();

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
      final existing = await _familiesCol
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    throw Exception('Unable to generate a unique invite code. Please try again.');
  }
}
