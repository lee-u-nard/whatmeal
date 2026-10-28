import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_space.dart';
import '../models/household_action_error.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../../core/services/family_service.dart';
import '../../../core/models/family.dart';

class FamilyRepository extends ValueNotifier<FamilySpace?> {
  FamilyRepository({
    required FirebaseFirestore firestore,
    required Stream<String?> authIds,
    required ValueListenable<UserModel?> account,
    FamilyService? service,
  })  : _firestore = firestore,
        _account = account,
        _familyService = service ?? FamilyService(firestore: firestore),
        super(null) {
    _authSub = authIds.distinct().listen(_bindAccount);
    _account.addListener(_showLegacyNotice);
  }
  static final instance = FamilyRepository(
    firestore: FirebaseFirestore.instance,
    authIds: FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
    account: AuthRepository.instance,
  );
  final FirebaseFirestore _firestore;
  final ValueListenable<UserModel?> _account;
  final FamilyService _familyService;
  StreamSubscription<String?>? _authSub;
  bool _disposed = false;

  void _bindAccount(String? uid) {
    if (_disposed) return;
    ++_epoch;
    isLoading = false;
    _uid = uid;
    _userSub?.cancel();
    error = null;
    _clearFamily();
    notifyListeners();
    final epoch = _epoch;
    if (uid == null) {
      notifyListeners();
      return;
    }
    _userSub = _familyService.membershipStream(uid).listen((familyId) {
      if (_disposed || _epoch != epoch) return;
      if (familyId == _currentFamilyId) {
        if (familyId == null) _showLegacyNotice();
        return;
      }
      _clearFamily();
      _currentFamilyId = familyId;
      if (familyId != null) {
        _listenToFamily(familyId, _familyEpoch);
      } else {
        _showLegacyNotice();
      }
    }, onError: (Object failure) {
      if (_disposed || _epoch != epoch) return;
      error = householdActionError(failure);
      _clearFamily();
      notifyListeners();
    }, cancelOnError: true);
  }

  /// A denied Firestore listener is terminal; explicit retry creates new streams.
  void retry() => _bindAccount(_uid);

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    ++_familyEpoch;
    ++_membersEpoch;
    _authSub?.cancel();
    _userSub?.cancel();
    _familySub?.cancel();
    _membersSub?.cancel();
    _transferSub?.cancel();
    _account.removeListener(_showLegacyNotice);
    super.dispose();
  }

  String? _uid;
  String? get currentUid => _uid;
  int get sessionVersion => _epoch;
  String? get scopeId => _currentFamilyId;
  String? _currentFamilyId;
  int _epoch = 0;
  int _familyEpoch = 0;
  int _membersEpoch = 0;
  StreamSubscription? _userSub, _familySub, _membersSub, _transferSub;
  String? error;
  bool isLoading = false;
  String? activeInvitationToken;
  String? pendingTransferToUid;
  bool archived = false;
  bool canRestore = false;
  String? get unavailableFamilyId => value == null ? _currentFamilyId : null;

  void _showLegacyNotice() {
    final account = _account.value;
    if (_uid != null &&
        account?.id == _uid &&
        _currentFamilyId == null &&
        account?.familySpaceId != null) {
      error =
          'An older household link was found. It is not used for access; migration requires separate approval.';
      notifyListeners();
    }
  }

  void _clearFamily() {
    ++_familyEpoch;
    ++_membersEpoch;
    _familySub?.cancel();
    _membersSub?.cancel();
    _transferSub?.cancel();
    _currentFamilyId = null;
    activeInvitationToken = null;
    pendingTransferToUid = null;
    archived = false;
    canRestore = false;
    value = null;
  }

  bool _current(String id, int epoch) =>
      _familyEpoch == epoch && _currentFamilyId == id && _uid != null;
  void _unavailable(String message) {
    ++_membersEpoch;
    _membersSub?.cancel();
    _transferSub?.cancel();
    activeInvitationToken = null;
    pendingTransferToUid = null;
    error = message;
    value = null;
    notifyListeners();
  }

  void _listenToFamily(String id, int epoch) {
    _familySub = _familyService.familyStream(id).listen((family) {
      if (!_current(id, epoch)) return;
      if (family == null) {
        _unavailable(
            'This household no longer exists. You can leave to clear your membership.');
        return;
      }
      if (family.schemaVersion != 2) {
        _unavailable(
            'This household requires an approved migration. Legacy invitation codes are disabled.');
        return;
      }
      if (family.state == 'archived') {
        archived = true;
        canRestore = family.isOwner(_uid);
        _unavailable(
            'This household is archived. Shared data is retained. Restore it or leave.');
        return;
      }
      archived = false;
      canRestore = false;
      _listenToMembers(family, epoch);
      final memberGeneration = _membersEpoch;
      _transferSub?.cancel();
      _transferSub = _firestore
          .doc('families/$id/ownershipTransfers/pending')
          .snapshots()
          .listen((doc) {
        if (!_current(id, epoch) || _membersEpoch != memberGeneration) return;
        final data = doc.data();
        pendingTransferToUid = data != null &&
                (data['expiresAt'] as Timestamp)
                    .toDate()
                    .isAfter(DateTime.now())
            ? data['toUid'] as String?
            : null;
        notifyListeners();
      }, onError: (Object failure) {
        if (!_current(id, epoch)) return;
        pendingTransferToUid = null;
        notifyListeners();
      });
    }, onError: (Object failure) {
      if (!_current(id, epoch)) return;
      _unavailable(
          'Household access is unavailable or revoked. You may leave to clear your membership.');
    }, cancelOnError: true);
  }

  void _listenToMembers(Family family, int epoch) {
    final generation = ++_membersEpoch;
    _membersSub?.cancel();
    _membersSub = _familyService.membersStream(family.id).listen((snapshot) {
      if (!_current(family.id, epoch) || generation != _membersEpoch) return;
      final members = snapshot.docs.map((doc) {
        final data = doc.data();
        final role = FamilyRole.values
                .where((role) => role.name == data['role'])
                .firstOrNull ??
            FamilyRole.viewOnly;
        return SharedSpaceMember(
            id: doc.id,
            name: data['name'] as String? ?? '',
            email: '',
            role: role,
            joinedAt: (data['joinedAt'] as Timestamp?)?.toDate());
      }).toList();
      if (!members.any((member) => member.id == _uid)) {
        // Guard against Firestore's local-cache snapshot arriving before the
        // server confirms the just-completed join transaction.  On mobile,
        // Firestore always delivers a cached snapshot first (isFromCache=true),
        // which may be empty if this device has never seen this members
        // collection before.  Calling _unavailable() here would increment
        // _membersEpoch and permanently filter out the correct server snapshot.
        // We only report a real removal when the snapshot is server-confirmed.
        if (!snapshot.metadata.isFromCache) {
          _unavailable('Your household membership was removed.');
        }
        return;
      }
      if (!members
          .any((member) => member.id == _uid && member.role.canManageMembers)) {
        activeInvitationToken = null;
      }
      error = null;
      value = FamilySpace(
          id: family.id, name: family.name, inviteCode: '', members: members);
    }, onError: (Object failure) {
      if (_current(family.id, epoch) && generation == _membersEpoch) {
        _unavailable('Household membership could not be verified.');
      }
    }, cancelOnError: true);
  }

  Future<bool> _perform(Future<void> Function() operation) async {
    if (_disposed || isLoading) return false;
    final epoch = _epoch;
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await operation();
      return _epoch == epoch;
    } catch (failure) {
      if (_epoch == epoch) {
        error = householdActionError(failure);
      }
      return false;
    } finally {
      if (_epoch == epoch) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createSpace(String name) => _perform(() async {
        final user = _account.value;
        if (_uid == null || user == null || user.id != _uid) {
          throw StateError('Sign in first.');
        }
        final epoch = _epoch;
        final id = await _familyService.createFamily(
            name: name, uid: _uid!, displayName: user.name);
        if (_epoch == epoch && _currentFamilyId != id) {
          _clearFamily();
          _currentFamilyId = id;
          _listenToFamily(id, _familyEpoch);
        }
      });
  Future<bool> joinSpaceWithKey(String token) => _perform(() async {
        final user = _account.value;
        if (_uid == null || user == null || user.id != _uid) {
          throw StateError('Sign in first.');
        }
        final epoch = _epoch;
        final id = await _familyService.joinFamily(
            inviteCode: token, uid: _uid!, displayName: user.name);
        if (_epoch == epoch && _currentFamilyId != id) {
          _clearFamily();
          _currentFamilyId = id;
          _listenToFamily(id, _familyEpoch);
        }
      });
  Stream<QuerySnapshot<Map<String, dynamic>>> invitationRefs() {
    final family = value;
    if (family == null || !family.canManageMembers(_uid)) {
      return const Stream.empty();
    }
    return _firestore
        .collection('families/${family.id}/invitationRefs')
        .orderBy('expiresAt', descending: true)
        .limit(30)
        .snapshots();
  }

  Future<bool> revokeToken(String token) =>
      _perform(() => _familyService.revokeInvitation(token));

  Future<bool> regenerateInviteKey() => _perform(() async {
        final id = _currentFamilyId;
        final uid = _uid;
        final epoch = _epoch;
        final generation = _familyEpoch;
        if (id == null || uid == null) {
          throw StateError('Select a household first.');
        }
        final token =
            await _familyService.createInvitation(familyId: id, uid: uid);
        if (_disposed ||
            _epoch != epoch ||
            _familyEpoch != generation ||
            _uid != uid ||
            _currentFamilyId != id ||
            value?.canManageMembers(uid) != true) {
          throw StateError(
              'Your account or household changed. Reopen household sharing.');
        }
        activeInvitationToken = token;
      });
  Future<bool> revokeInvite() => _perform(() async {
        final token = activeInvitationToken;
        final epoch = _epoch;
        if (token == null) return;
        await _familyService.revokeInvitation(token);
        if (_epoch == epoch && activeInvitationToken == token) {
          activeInvitationToken = null;
        }
      });
  Future<bool> updateMemberRole(String id, FamilyRole role) =>
      _perform(() async {
        if (_currentFamilyId == null) {
          throw StateError('Select a household first.');
        }
        await _familyService.updateMemberRole(
            familyId: _currentFamilyId!, memberUid: id, newRole: role.name);
      });
  Future<bool> removeMember(String id) => _perform(() async {
        if (_currentFamilyId == null) {
          throw StateError('Select a household first.');
        }
        await _familyService.removeMember(
            familyId: _currentFamilyId!, memberUid: id);
      });
  Future<bool> deleteSpace() => _perform(() async {
        if (_currentFamilyId == null) {
          throw StateError('Select a household first.');
        }
        await _familyService
            .deleteFamily(familyId: _currentFamilyId!, memberUids: const []);
      });
  Future<bool> restoreSpace() => _perform(() async {
        if (_currentFamilyId != null) {
          await _familyService.restoreFamily(_currentFamilyId!);
        }
      });
  Future<bool> leaveSpace() => _perform(() async {
        if (value?.isOwner(_uid) == true && !archived) {
          throw StateError(
              'Transfer ownership or archive the household before leaving.');
        }
        final familyId = _currentFamilyId;
        final uid = _uid;
        final epoch = _epoch;
        final generation = _familyEpoch;
        if (familyId == null || uid == null) {
          throw StateError('No active household membership to leave.');
        }
        try {
          await _familyService.leaveFamily(familyId: familyId, uid: uid);
        } on FirebaseException catch (e) {
          // If permission-denied, the family doc may have been deleted externally.
          // Fall back to cleaning up only the dangling membershipIndex entry,
          // which the updated Firestore rules allow when the family doc is gone.
          if (e.code == 'permission-denied') {
            if (_epoch != epoch ||
                _familyEpoch != generation ||
                _uid != uid ||
                _currentFamilyId != familyId) {
              throw StateError(
                  'Your account or household changed. Reopen household sharing.');
            }
            await _familyService.clearOrphanedMembership(uid: uid);
          } else {
            rethrow;
          }
        }
      });
  Future<bool> offerOwnership(String target) => _perform(() async {
        if (_currentFamilyId == null || _uid == null) {
          throw StateError('Select a household first.');
        }
        await _familyService.offerOwnership(
            familyId: _currentFamilyId!, fromUid: _uid!, toUid: target);
      });
  Future<bool> acceptOwnership() => _perform(() async {
        if (_currentFamilyId == null || _uid == null) {
          throw StateError('Select a household first.');
        }
        await _familyService.acceptOwnership(
            familyId: _currentFamilyId!, uid: _uid!);
      });
}
