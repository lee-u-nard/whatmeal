import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';
import '../../family/data/family_repository.dart';
import '../../family/models/family_space.dart';
import '../../../core/utils/family_permissions.dart';
import 'pantry_store.dart';

/// Personal or family-scoped pantry. When the user is in a Family Space,
/// reads/writes go to `families/{familyId}/pantryItems`.
class PantryRepository extends ValueNotifier<Map<String, List<PantryItem>>> {
  PantryRepository({
    required FirebaseFirestore firestore,
    required Stream<String?> authIds,
    required ValueListenable<FamilySpace?> household,
    Stream<List<PantryItem>> Function(String path)? watch,
  })  : _firestore = firestore,
        _household = household,
        _watch = watch,
        super({}) {
    _authSub = authIds.listen((uid) {
      _uid = uid;
      _resetListener();
    });
    _household.addListener(_onFamilyChange);
  }

  static final instance = PantryRepository(
    firestore: FirebaseFirestore.instance,
    authIds: FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
    household: FamilyRepository.instance,
  );
  final FirebaseFirestore _firestore;
  final ValueListenable<FamilySpace?> _household;
  final Stream<List<PantryItem>> Function(String path)? _watch;
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

  Map<String, List<PantryItem>> get items => value;

  String? get scopePath => _uid == null
      ? null
      : _familyId == null
          ? 'users/$_uid'
          : 'families/$_familyId';

  bool get isShared => _familyId != null;

  CollectionReference<Map<String, dynamic>> get _pantryCol {
    final familyId = _familyId;
    if (familyId != null) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('pantryItems');
    }
    return _firestore.collection('users').doc(_uid).collection('pantryItems');
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
    value = {};
    if (_uid == null) return;
    _listenToItems();
  }

  void _listenToItems() {
    _sub?.cancel();
    if (_uid == null) return;
    final scope = _scopeVersion;
    _sub = (_watch?.call('$scopePath/pantryItems') ??
            _pantryCol.orderBy('createdAt', descending: true).snapshots().map(
                (snapshot) =>
                    snapshot.docs.map(PantryItem.fromFirestore).toList()))
        .listen(
      (items) {
        if (scope != _scopeVersion || _disposed) return;
        error = null;
        isLoading = false;
        final grouped = <String, List<PantryItem>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.category, () => []).add(item);
        }
        value = grouped;
      },
      onError: (e) {
        if (scope != _scopeVersion) return;
        isLoading = false;
        error = 'Pantry could not be loaded. Please retry.';
        value = {};
      },
      cancelOnError: true,
    );
  }

  Future<void> addItem(String category, PantryItem item) async {
    final scope = _scopeVersion;
    if (_uid == null) throw StateError('Sign in to add ingredients.');
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }
    final itemToSave = item.copyWith(
      category: category,
      addedBy: item.addedBy ?? _uid,
    );
    await PantryStore(_firestore).write(
        item: _pantryCol.doc(),
        actorUid: _uid!,
        action: 'added',
        data: itemToSave.toFirestore());
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }

  Future<void> updateItem(String category, PantryItem updatedItem) async {
    if (_uid == null || updatedItem.id == null || updatedItem.id!.isEmpty) {
      throw StateError('Ingredient is unavailable.');
    }
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }
    final scope = _scopeVersion;
    await PantryStore(_firestore).write(
        item: _pantryCol.doc(updatedItem.id),
        actorUid: _uid!,
        action: 'updated',
        data: updatedItem.copyWith(category: category).toFirestore());
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }

  Future<void> setItemStatus(String id, PantryStatus status) async {
    if (_uid == null) throw StateError('Sign in to update pantry.');
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }
    final scope = _scopeVersion;
    await PantryStore(_firestore).write(
        item: _pantryCol.doc(id),
        actorUid: _uid!,
        action: 'updated',
        data: {'status': status.name});
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }

  /// Cycle available → runningLow → used → needed → available.
  Future<void> cycleStatus(String id) async {
    PantryItem? found;
    for (final list in value.values) {
      try {
        found = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }
    if (found == null) return;
    final next = PantryStatus
        .values[(found.status.index + 1) % PantryStatus.values.length];
    await setItemStatus(id, next);
  }

  Future<void> deleteItem(String id) async {
    final scope = _scopeVersion;
    if (_uid == null) throw StateError('Sign in to update pantry.');
    if (!FamilyPermissions.canManagePantry) {
      error = FamilyPermissions.denialMessage('manage the pantry');
      notifyListeners();
      throw StateError(error!);
    }

    await PantryStore(_firestore)
        .write(item: _pantryCol.doc(id), actorUid: _uid!, action: 'deleted');
    if (scope != _scopeVersion) throw StateError('Workspace changed.');
  }

  int get expiringCount {
    int count = 0;
    for (final list in value.values) {
      count += list.where((item) => item.isExpiringSoon).length;
    }
    return count;
  }

  /// Flat list of available / running-low item names for AI context.
  List<String> get availableNames => value.values
      .expand((list) => list)
      .where((i) =>
          (i.status == PantryStatus.available ||
              i.status == PantryStatus.runningLow) &&
          !i.expirationDate.isBefore(DateTime(
              DateTime.now().year, DateTime.now().month, DateTime.now().day)))
      .map((i) => i.name)
      .where((n) => n.isNotEmpty)
      .toList();
}
