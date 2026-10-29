import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/family_member.dart';
import '../../family/data/family_repository.dart';
import '../../family/models/family_space.dart';

/// Personal or family-scoped family members (people planned for, e.g. children, parents).
/// When in a Family Space: `families/{familyId}/familyMembers`.
/// When personal: `users/{uid}/familyMembers`.
class FamilyMemberRepository extends ValueNotifier<List<FamilyMember>> {
  FamilyMemberRepository({
    required FirebaseFirestore firestore,
    required Stream<String?> authIds,
    required ValueListenable<FamilySpace?> household,
    Stream<List<FamilyMember>> Function(String path)? watch,
  })  : _firestore = firestore,
        _household = household,
        _watch = watch,
        super([]) {
    _authSub = authIds.listen((uid) {
      _uid = uid;
      _resetListener();
    });
    _household.addListener(_onFamilyChange);
  }

  static final instance = FamilyMemberRepository(
    firestore: FirebaseFirestore.instance,
    authIds: FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
    household: FamilyRepository.instance,
  );
  final FirebaseFirestore _firestore;
  final ValueListenable<FamilySpace?> _household;
  final Stream<List<FamilyMember>> Function(String path)? _watch;
  StreamSubscription<String?>? _authSub;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    ++_scopeVersion;
    _authSub?.cancel();
    _sub?.cancel();
    _household.removeListener(_onFamilyChange);
    super.dispose();
  }

  String? _uid;
  String? _familyId;
  StreamSubscription? _sub;
  String? error;
  bool isLoading = false;
  void retry() => _resetListener();
  int _scopeVersion = 0;
  int get scopeVersion => _scopeVersion;

  String? get scopePath => _uid == null
      ? null
      : _familyId == null
          ? 'users/$_uid'
          : 'families/$_familyId';

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
    final newId = _household.value?.id;
    if (_familyId != newId) {
      _familyId = newId;
      _resetListener();
    }
  }

  void _resetListener() {
    if (_disposed) return;
    ++_scopeVersion;
    _sub?.cancel();
    _sub = null;
    error = null;
    isLoading = _uid != null;
    final family = _household.value;
    _familyId = family?.memberForUid(_uid) != null ? family?.id : null;
    value = [];
    if (_uid == null) return;
    _listenToMembers();
  }

  void _listenToMembers() {
    _sub?.cancel();
    if (_uid == null) return;
    final scope = _scopeVersion;
    _sub = (_watch?.call('$scopePath/familyMembers') ??
            _membersCol.orderBy('createdAt').snapshots().map((snapshot) =>
                snapshot.docs.map(FamilyMember.fromFirestore).toList()))
        .listen(
      (items) {
        if (scope != _scopeVersion || _disposed) return;
        error = null;
        isLoading = false;
        value = items;
      },
      onError: (e) {
        if (scope != _scopeVersion) return;
        isLoading = false;
        error = 'Family profiles could not be loaded. Please retry.';
        value = [];
      },
    );
  }

  Future<void> addMember(FamilyMember member) async {
    if (_uid == null) throw StateError('Sign in before adding a profile.');
    final scope = _scopeVersion;
    await _membersCol.add(member.toFirestore());
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }

  Future<void> updateMember(FamilyMember updated) async {
    if (_uid == null || updated.id.isEmpty) {
      throw StateError('Profile is unavailable.');
    }
    final scope = _scopeVersion;
    await _membersCol.doc(updated.id).update(updated.toFirestore());
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }

  Future<void> deleteMember(String id) async {
    if (_uid == null || id.isEmpty) throw StateError('Profile is unavailable.');
    final scope = _scopeVersion;
    await _membersCol.doc(id).delete();
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }
}
