import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/family_member.dart';
import '../../family/data/family_repository.dart';

/// Personal or family-scoped family members (people planned for, e.g. children, parents).
/// When in a Family Space: `families/{familyId}/familyMembers`.
/// When personal: `users/{uid}/familyMembers`.
class FamilyMemberRepository extends ValueNotifier<List<FamilyMember>> {
  FamilyMemberRepository._() : super([]) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      _resetListener();
    });
    FamilyRepository.instance.addListener(_onFamilyChange);
  }
  static final instance = FamilyMemberRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  String? _familyId;
  StreamSubscription? _sub;
  String? error;

  List<FamilyMember> get members => value;
  bool get isShared => _familyId != null;

  CollectionReference<Map<String, dynamic>> get _membersCol {
    final familyId = _familyId;
    if (familyId != null) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('familyMembers');
    }
    return _firestore.collection('users').doc(_uid).collection('familyMembers');
  }

  void _onFamilyChange() {
    final newId = FamilyRepository.instance.value?.id;
    if (_familyId != newId) {
      _familyId = newId;
      _resetListener();
    }
  }

  void _resetListener() {
    _sub?.cancel();
    _sub = null;
    value = [];
    error = null;
    if (_uid == null) return;
    _familyId = FamilyRepository.instance.value?.id;
    _listenToMembers();
  }

  void _listenToMembers() {
    _sub?.cancel();
    if (_uid == null) return;
    _sub = _membersCol.orderBy('createdAt').snapshots().listen(
      (snapshot) {
        error = null;
        value = snapshot.docs
            .map((doc) => FamilyMember.fromFirestore(doc))
            .toList();
      },
      onError: (e) {
        error = 'Failed to load family members: $e';
        notifyListeners();
      },
    );
  }

  Future<void> addMember(FamilyMember member) async {
    if (_uid == null) return;
    await _membersCol.add(member.toFirestore());
  }

  Future<void> updateMember(FamilyMember updated) async {
    if (_uid == null || updated.id.isEmpty) return;
    await _membersCol.doc(updated.id).update(updated.toFirestore());
  }

  Future<void> deleteMember(String id) async {
    if (_uid == null || id.isEmpty) return;
    await _membersCol.doc(id).delete();
  }
}
