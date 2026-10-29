import '../../family/models/family_space.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../pantry/models/pantry_item.dart';
import 'dart:async';
import 'grocery_store.dart';
import 'meal_grocery_projection.dart';
import '../../meal_plan/data/saved_plans_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/grocery_item.dart';
import '../models/grocery_list.dart';
import '../../family/data/family_repository.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/services/household_notification_service.dart';

/// Personal or family-scoped grocery list.
/// When in a Family Space: `families/{familyId}/groceryLists`.
class GroceryRepository extends ValueNotifier<Map<String, List<GroceryItem>>> {
  GroceryRepository({
    required FirebaseFirestore firestore,
    required Stream<String?> authIds,
    required ValueListenable<FamilySpace?> household,
    required ValueListenable<List<SavedMealPlan>> plans,
    required ValueListenable<Map<String, List<PantryItem>>> pantry,
    required String? Function() pantryScope,
    bool Function()? canEdit,
    Future<void> Function(CollectionReference<Map<String, dynamic>>, String)?
        initialize,
    Stream<QuerySnapshot<Map<String, dynamic>>> Function(
            Query<Map<String, dynamic>>)?
        watchParents,
    Stream<List<GroceryItem>> Function(
            CollectionReference<Map<String, dynamic>>)?
        watchItems,
  })  : _firestore = firestore,
        _household = household,
        _plans = plans,
        _pantry = pantry,
        _pantryScope = pantryScope,
        _canEdit = canEdit ?? (() => FamilyPermissions.canGenerateGroceryList),
        _initialize = initialize,
        _watchParents = watchParents,
        _watchItems = watchItems,
        super({}) {
    _authSub = authIds.listen((uid) {
      _uid = uid;
      _resetListener();
    });
    _household.addListener(_onFamilyChange);
    _plans.addListener(_publish);
    _pantry.addListener(_publish);
  }
  static final instance = GroceryRepository(
      firestore: FirebaseFirestore.instance,
      authIds:
          FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
      household: FamilyRepository.instance,
      plans: SavedPlansRepository.instance,
      pantry: PantryRepository.instance,
      pantryScope: () => PantryRepository.instance.scopePath);
  final FirebaseFirestore _firestore;
  final ValueListenable<FamilySpace?> _household;
  final ValueListenable<List<SavedMealPlan>> _plans;
  final ValueListenable<Map<String, List<PantryItem>>> _pantry;
  final String? Function() _pantryScope;
  final bool Function() _canEdit;
  final Future<void> Function(
      CollectionReference<Map<String, dynamic>>, String)? _initialize;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(
      Query<Map<String, dynamic>>)? _watchParents;
  final Stream<List<GroceryItem>> Function(
      CollectionReference<Map<String, dynamic>>)? _watchItems;
  StreamSubscription<String?>? _authSub;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    ++_scope;
    ++_listEpoch;
    _authSub?.cancel();
    _sub?.cancel();
    _parentSub?.cancel();
    _household.removeListener(_onFamilyChange);
    _plans.removeListener(_publish);
    _pantry.removeListener(_publish);
    super.dispose();
  }

  String? _uid;
  String? _familyId;
  GroceryList? _activeList;
  StreamSubscription? _sub;
  StreamSubscription? _parentSub;
  int _listEpoch = 0;
  String? _error;
  bool _isLoading = false;
  SavedPlansRepository? get _savedPlansDependency {
    final source = _plans;
    return source is SavedPlansRepository ? source : null;
  }

  PantryRepository? get _pantryDependency {
    final source = _pantry;
    return source is PantryRepository ? source : null;
  }

  bool get _dependenciesLoading =>
      _savedPlansDependency?.isLoading == true ||
      (_pantryDependency != null &&
          (_pantryDependency!.isLoading || _pantryScope() != scopePath));

  // A failed/loading plan feed cannot establish complete meal requirements.
  String? get error =>
      _error ??
      (_uid != null && _savedPlansDependency?.error != null
          ? 'Meal shopping requirements could not be loaded. Please retry.'
          : null) ??
      (_uid != null && _pantryDependency?.error != null
          ? 'Pantry stock could not be loaded. Please retry.'
          : null);
  set error(String? message) => _error = message;
  bool get isLoading =>
      _isLoading || (_uid != null && error == null && _dependenciesLoading);
  set isLoading(bool loading) => _isLoading = loading;
  void retry() {
    if (_disposed) return;
    if (_savedPlansDependency?.error != null) _savedPlansDependency!.retry();
    if (_pantryDependency?.error != null) _pantryDependency!.retry();
    _resetListener();
  }

  List<GroceryItem> _stored = [];
  Map<String, MealGroceryRequirement> _requirements = {};
  String? get scopePath => _uid == null
      ? null
      : _familyId == null
          ? 'users/$_uid'
          : 'families/$_familyId';

  void _publish() {
    if (_disposed) return;
    final root = scopePath;
    if (root == null || error != null || _dependenciesLoading) {
      _requirements = {};
      value = {};
      return;
    }

    _requirements = MealGroceryProjection.calculate(
      _plans.value
          .where((p) => p.sourcePath?.startsWith('$root/mealPlans/') == true),
      _pantryScope() == root ? _pantry.value.values.expand((v) => v) : [],
    );
    final receipts = {for (final item in _stored) item.id: item};
    final items = [
      ..._stored.where((i) => i.sourceMealPaths.isEmpty),
      for (final entry in _requirements.entries)
        entry.value.toItem(receipts[entry.key]),
    ];
    final grouped = <String, List<GroceryItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    value = grouped;
  }

  int _scope = 0;
  int get scopeVersion => _scope;
  Future<void>? _initializing;

  GroceryList? get activeList => _activeList;
  Map<String, List<GroceryItem>> get sections => value;
  bool get isShared => _familyId != null;

  CollectionReference<Map<String, dynamic>> get _groceryListsCol {
    final familyId = _familyId;
    if (familyId != null) {
      return _firestore
          .collection('families')
          .doc(familyId)
          .collection('groceryLists');
    }
    return _firestore.collection('users').doc(_uid).collection('groceryLists');
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
    ++_scope;
    _initializing = null;
    _sub?.cancel();
    _sub = null;
    _parentSub?.cancel();
    _parentSub = null;
    ++_listEpoch;
    _stored = [];
    _requirements = {};
    isLoading = _uid != null;
    _activeList = null;
    error = null;
    final family = _household.value;
    _familyId = family?.memberForUid(_uid) != null ? family?.id : null;
    value = {};
    if (_uid == null) return;
    _listenToActiveList();
  }

  Future<void> _listenToActiveList() =>
      _initializing ??= _initializeActiveList(_scope);

  Future<void> _initializeActiveList(int scope) async {
    if (_uid == null) return;
    final collection = _groceryListsCol;
    final title = isShared ? 'Family Shopping List' : 'Shopping List';
    try {
      if (_canEdit()) {
        if (_initialize != null) {
          await _initialize!(collection, title);
        } else {
          await GroceryStore(_firestore).initialize(collection, title);
        }
      }
      if (scope != _scope) return;
      _parentSub?.cancel();
      final first = await collection
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (scope != _scope) return;
      void attach(QuerySnapshot<Map<String, dynamic>> parents) {
        if (scope != _scope) return;
        final parent = parents.docs.firstOrNull;
        if (parent?.id == _activeList?.id && _sub != null) return;
        final epoch = ++_listEpoch;
        _sub?.cancel();
        _sub = null;
        _stored = [];
        _activeList = parent == null ? null : GroceryList.fromFirestore(parent);
        if (parent == null) isLoading = false;
        error = null;
        _publish();
        if (parent == null) return;
        final items = parent.reference.collection('items');
        _sub = (_watchItems?.call(items) ??
                items
                    .snapshots()
                    .map((s) => s.docs.map(GroceryItem.fromFirestore).toList()))
            .listen((items) {
          if (scope != _scope || epoch != _listEpoch) return;
          isLoading = false;
          error = null;
          _stored = items;
          _publish();
        }, onError: (Object failure) {
          if (scope != _scope || epoch != _listEpoch) return;
          isLoading = false;
          _stored = [];
          _sub = null;
          error = 'Grocery items could not be loaded. Please retry.';
          value = {};
        }, cancelOnError: true);
      }

      attach(first);
      final query = collection.orderBy('createdAt', descending: true).limit(1);
      _parentSub = (_watchParents?.call(query) ?? query.snapshots())
          .listen(attach, onError: (Object failure) {
        if (scope != _scope) return;
        isLoading = false;
        ++_listEpoch;
        _sub?.cancel();
        _stored = [];
        _activeList = null;
        _sub = null;
        error = 'Grocery list could not be loaded. Check your connection.';
        value = {};
      }, cancelOnError: true);
    } catch (_) {
      if (scope != _scope) return;
      isLoading = false;
      error =
          'Failed to initialize grocery list. Check your connection and retry.';
      notifyListeners();
    } finally {
      if (scope == _scope) _initializing = null;
    }
  }

  void _requireScope(int scope) {
    if (_disposed || scope != _scope) {
      throw StateError('Account or household changed.');
    }
  }

  Future<void> cycleStatus(String id) async {
    final scope = _scope;
    if (_activeList == null || _uid == null) {
      throw StateError('Grocery list is not ready.');
    }
    if (!_canEdit()) {
      error = FamilyPermissions.denialMessage('update the grocery list');
      notifyListeners();
      throw StateError(error!);
    }

    GroceryItem? foundItem;
    for (final list in value.values) {
      try {
        foundItem = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }
    if (foundItem == null) return;

    if (_requirements.containsKey(id)) {
      await setPurchased(id, !foundItem.isPurchased);
      return;
    }
    final nextStatus = GroceryStatus
        .values[(foundItem.status.index + 1) % GroceryStatus.values.length];

    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .update({
      'status': nextStatus.name,
      'checked': nextStatus == GroceryStatus.used,
    });
    _requireScope(scope);
  }

  /// Toggle purchased (used) checkbox state.
  Future<void> setPurchased(String id, bool purchased) async {
    if (error != null || isLoading) {
      throw StateError('Wait for shopping requirements to load, then retry.');
    }
    final scope = _scope;
    if (_activeList == null || _uid == null) {
      throw StateError('Grocery list is not ready.');
    }
    if (!_canEdit()) {
      error = FamilyPermissions.denialMessage('update the grocery list');
      notifyListeners();
      throw StateError(error!);
    }
    final requirement = _requirements[id];
    if (requirement != null) {
      final item = requirement.toItem(null).copyWith(
            status: purchased ? GroceryStatus.used : GroceryStatus.needed,
            checked: purchased,
            addedBy: _uid,
          );
      await _groceryListsCol
          .doc(_activeList!.id)
          .collection('items')
          .doc(id)
          .set(item.toFirestore());
      _requireScope(scope);
      return;
    }
    final status = purchased ? GroceryStatus.used : GroceryStatus.needed;
    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .update({
      'status': status.name,
      'checked': purchased,
    });
    _requireScope(scope);
  }

  Future<bool> addItem(String section, GroceryItem item) async {
    final scope = _scope;
    if (_uid == null) {
      error = 'Not signed in; grocery item was not saved.';
      notifyListeners();
      throw StateError(error!);
    }
    if (!_canEdit()) {
      error = FamilyPermissions.denialMessage('add grocery items');
      notifyListeners();
      throw StateError(error!);
    }
    if (_activeList == null) {
      await _listenToActiveList();
    }
    if (scope != _scope) {
      throw StateError('Account or household changed. Retry.');
    }
    if (_activeList == null) {
      error = error ?? 'Grocery list is not ready; item was not saved.';
      notifyListeners();
      throw StateError(error!);
    }
    try {
      final itemToSave = item.copyWith(
        category: section,
        addedBy: item.addedBy ?? _uid,
      );
      final added = await GroceryStore(_firestore)
          .addUnique(_groceryListsCol.doc(_activeList!.id), [itemToSave]);
      if (scope != _scope) throw StateError('Account or household changed.');
      // Duplicate input is an editor outcome, not a feed-loading failure.
      // Keep the existing list visible and let the caller show its feedback.
      error = null;
      if (added == 0) {
        notifyListeners();
        return false;
      }

      // Send household notification
      HouseholdNotificationService.instance.notifyGroceryActivity(
        action: 'added',
        itemName: item.name,
      );
      return true;
    } catch (e) {
      if (scope != _scope) rethrow;
      error = 'Failed to save grocery item. Check your connection and retry.';
      notifyListeners();
      rethrow;
    }
  }

  /// Adds only items not already present (case-insensitive name match).
  /// Returns the number of items actually added.
  Future<int> addMultipleItems(List<GroceryItem> items) async {
    final scope = _scope;
    if (_uid == null) {
      error = 'Not signed in; grocery items were not saved.';
      notifyListeners();
      throw StateError(error!);
    }
    if (!_canEdit()) {
      error = FamilyPermissions.denialMessage('generate a grocery list');
      notifyListeners();
      throw StateError(error!);
    }
    if (_activeList == null) {
      await _listenToActiveList();
    }
    if (scope != _scope) {
      throw StateError('Account or household changed. Retry.');
    }
    if (_activeList == null) {
      error = error ?? 'Grocery list is not ready; items were not saved.';
      notifyListeners();
      throw StateError(error!);
    }

    try {
      final added = await GroceryStore(_firestore).addUnique(
          _groceryListsCol.doc(_activeList!.id),
          items
              .map((item) => item.copyWith(addedBy: item.addedBy ?? _uid))
              .toList());
      _requireScope(scope);
      error = null;
      return added;
    } catch (e) {
      if (scope != _scope) rethrow;
      error = 'Failed to save grocery items. Check your connection and retry.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearUsed() async {
    if (_activeList == null || _uid == null) {
      throw StateError('Grocery list is not ready.');
    }
    if (!_canEdit()) {
      throw StateError('Your role cannot clear groceries.');
    }
    final scope = _scope;
    final itemsCol = _groceryListsCol.doc(_activeList!.id).collection('items');
    final checkedItems = await itemsCol.where('checked', isEqualTo: true).get();
    _requireScope(scope);
    if (checkedItems.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in checkedItems.docs) {
      if ((doc.data()['sourceMealPaths'] as List?)?.isNotEmpty == true) {
        continue;
      }
      batch.delete(doc.reference);
    }
    await batch.commit();
    _requireScope(scope);
  }

  Future<void> updateItem(GroceryItem item) async {
    if (_uid == null || _activeList == null || !_canEdit()) {
      throw StateError('Grocery editing is unavailable.');
    }
    if (item.sourceMealPaths.isNotEmpty) {
      throw StateError('Edit the source meal to change its ingredients.');
    }
    if (item.id == null || item.name.trim().isEmpty) {
      throw StateError('Enter an item name.');
    }
    final scope = _scope;
    await GroceryStore(_firestore)
        .updateManual(_groceryListsCol.doc(_activeList!.id), item);
    _requireScope(scope);
  }

  Future<void> deleteItem(String id) async {
    if (error != null || isLoading) {
      throw StateError('Wait for shopping requirements to load, then retry.');
    }
    if (_requirements.containsKey(id)) {
      throw StateError(
          'Remove or skip the source meal to remove its grocery requirement.');
    }
    final scope = _scope;
    if (_activeList == null || _uid == null) {
      throw StateError('Grocery list is not ready.');
    }
    if (!_canEdit()) {
      error = FamilyPermissions.denialMessage('delete grocery items');
      notifyListeners();
      throw StateError(error!);
    }

    // Get item name for notification
    GroceryItem? foundItem;
    for (final list in value.values) {
      try {
        foundItem = list.firstWhere((i) => i.id == id);
        break;
      } catch (_) {}
    }

    await _groceryListsCol
        .doc(_activeList!.id)
        .collection('items')
        .doc(id)
        .delete();

    // Send only within the session that performed the write.
    _requireScope(scope);
    if (foundItem != null) {
      HouseholdNotificationService.instance.notifyGroceryActivity(
        action: 'removed',
        itemName: foundItem.name,
      );
    }
  }

  int get remainingCount {
    int count = 0;
    for (final list in value.values) {
      count += list.where((item) => item.status == GroceryStatus.needed).length;
    }
    return count;
  }

  List<GroceryItem> get allItems =>
      value.values.expand((list) => list).toList();

  List<String> get allItemNames =>
      allItems.map((i) => i.name).where((n) => n.isNotEmpty).toList();
}
