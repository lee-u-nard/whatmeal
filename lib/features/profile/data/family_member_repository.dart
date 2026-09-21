import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/family_member.dart';

/// Repository for family member profiles scoped to a family group.
class FamilyMemberRepository extends ChangeNotifier {
  FamilyMemberRepository();

  final _firestore = FirebaseFirestore.instance;
  String? _familyId;
  List<FamilyMember> _members = [];

  List<FamilyMember> get members => _members;

  void setFamilyId(String? familyId) {
    if (_familyId == familyId) return;
    _familyId = familyId;
    if (familyId != null) {
      _listenToMembers();
    } else {
      _members = [];
      notifyListeners();
    }
  }

  CollectionReference<Map<String, dynamic>> get _membersCol =>
      _firestore.collection('families').doc(_familyId).collection('familyMembers');

  void _listenToMembers() {
    _membersCol.orderBy('createdAt').snapshots().listen((snapshot) {
      _members = snapshot.docs.map((doc) => FamilyMember.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  /// Add a family member profile.
  Future<void> addMember(FamilyMember member) async {
    if (_familyId == null) return;
    await _membersCol.add(member.toFirestore());
  }

  /// Update a family member.
  Future<void> updateMember(String memberId, Map<String, dynamic> data) async {
    if (_familyId == null) return;
    await _membersCol.doc(memberId).update(data);
  }

  /// Delete a family member profile.
  Future<void> deleteMember(String memberId) async {
    if (_familyId == null) return;
    await _membersCol.doc(memberId).delete();
  }
}
