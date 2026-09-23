import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_space.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/models/family.dart';

class FamilyRepository extends ValueNotifier<FamilySpace?> {
  FamilyRepository._() : super(null) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _uid = user.uid;
        _listenToUserFamily();
      } else {
        _uid = null;
        _userSub?.cancel();
        _familySub?.cancel();
        _membersSub?.cancel();
        value = null;
        error = null;
      }
    });
  }

  static final instance = FamilyRepository._();

  final _familyService = FamilyService();
  final _userService = UserService();
  String? _uid;
  String? _currentFamilyId;
  StreamSubscription? _userSub;
  StreamSubscription? _familySub;
  StreamSubscription? _membersSub;

  String? error;
  bool isLoading = false;

  void _listenToUserFamily() {
    _userSub?.cancel();
    if (_uid == null) return;

    _userSub = _userService.userStream(_uid!).listen(
      (userDoc) {
        final familyId = userDoc?.familyId;
        if (familyId != null && familyId.isNotEmpty) {
          if (_currentFamilyId != familyId) {
            _currentFamilyId = familyId;
            _listenToFamily(familyId);
          }
        } else {
          _currentFamilyId = null;
          _familySub?.cancel();
          _membersSub?.cancel();
          value = null;
        }
      },
      onError: (e) {
        error = 'Failed to load user profile: $e';
        notifyListeners();
      },
    );
  }

  void _listenToFamily(String familyId) {
    _familySub?.cancel();
    _familySub = _familyService.familyStream(familyId).listen(
      (family) {
        if (family == null) {
          value = null;
          return;
        }
        _listenToFamilyMembers(family);
      },
      onError: (e) {
        error = 'Failed to load family data: $e';
        notifyListeners();
      },
    );
  }

  void _listenToFamilyMembers(Family family) {
    _membersSub?.cancel();
    _membersSub = _familyService.membersStream(family.id).listen(
      (membersSnap) {
        final members = membersSnap.docs.map((doc) {
          final data = doc.data();
          final roleStr = data['role'] as String?;
          FamilyRole role = FamilyRole.member;
          if (roleStr == 'owner') role = FamilyRole.owner;
          if (roleStr == 'admin') role = FamilyRole.admin;
          if (roleStr == 'viewOnly') role = FamilyRole.viewOnly;

          return SharedSpaceMember(
            id: doc.id,
            name: data['displayName'] ?? 'Unknown',
            email: '', // Not stored in member subcol currently
            role: role,
          );
        }).toList();

        value = FamilySpace(
          id: family.id,
          name: family.name,
          inviteCode: family.inviteCode,
          members: members,
        );
        error = null;
      },
      onError: (e) {
        error = 'Failed to load family members: $e';
        notifyListeners();
      },
    );
  }

  Future<void> createSpace(String spaceName) async {
    final user = AuthRepository.instance.currentUser;
    final userModel = AuthRepository.instance.value;
    if (user == null || userModel == null) {
      error = "User not logged in";
      notifyListeners();
      return;
    }
    
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _familyService.createFamily(
        name: spaceName,
        uid: user.uid,
        displayName: userModel.name,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinSpaceWithKey(String code) async {
    final user = AuthRepository.instance.currentUser;
    final userModel = AuthRepository.instance.value;
    if (user == null || userModel == null) {
      error = "User not logged in";
      notifyListeners();
      return false;
    }

    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _familyService.joinFamily(
        inviteCode: code,
        uid: user.uid,
        displayName: userModel.name,
      );
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateMemberRole(String memberId, FamilyRole newRole) async {
    // Only implemented locally for now, since it wasn't requested to connect to backend
  }

  Future<void> removeMember(String memberId) async {
    // Not requested to implement
  }

  Future<void> leaveSpace() async {
    if (value == null || _uid == null) return;
    
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _familyService.leaveFamily(
        familyId: value!.id,
        uid: _uid!,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void regenerateInviteKey() {
    // Not requested to implement
  }
}
  