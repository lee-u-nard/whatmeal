import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/family_member.dart';

class FamilyMemberRepository extends ValueNotifier<List<FamilyMember>> {
  FamilyMemberRepository._() : super([]) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (_uid != null) {
        _listenToMembers();
      } else {
        _sub?.cancel();
        _sub = null;
        value = [];
      }
    });
  }
  static final instance = FamilyMemberRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  StreamSubscription? _sub;
  String? error;

  List<FamilyMember> get members => value;

  CollectionReference<Map<String, dynamic>> get _membersCol =>
      _firestore.collection('users').doc(_uid).collection('familyMembers');

  void _listenToMembers() {
    _sub?.cancel();
    if (_uid == null) return;
    _sub = _membersCol.orderBy('createdAt').snapshots().listen(
      (snapshot) {
        error = null;
        value = snapshot.docs.map((doc) => FamilyMember.fromFirestore(doc)).toList();
      },
      onError: (e) {
        error = 'Failed to load family members: $e';
        notifyListeners();
      },
    );
  }

  void addMember(FamilyMember member) async {
    if (_uid == null) return;
    await _membersCol.add(member.toFirestore());
  }

  void updateMember(FamilyMember updated) async {
    if (_uid == null || updated.id.isEmpty) return;
    await _membersCol.doc(updated.id).update(updated.toFirestore());
  }

  void deleteMember(String id) async {
    if (_uid == null || id.isEmpty) return;
    await _membersCol.doc(id).delete();
  }
}
