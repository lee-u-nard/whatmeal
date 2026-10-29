import 'dart:async';
import 'saved_plan_stream.dart';
import '../../../core/services/meal_replacement_store.dart';
import '../../../core/services/meal_workflow_store.dart';
import '../../../core/services/unsplash_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_meal_plan.dart';
import '../models/meal_plan.dart';
import '../../meal/models/meal.dart';
import '../../family/data/family_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/user_model.dart';
import '../../family/models/family_space.dart';
import '../../../core/utils/family_permissions.dart';

/// Repository that surfaces saved [SavedMealPlan] objects from Firestore.
///
/// Unlike the previous implementation, this does NOT create its own disconnected
/// [MealPlanRepository] instance.  Instead it listens directly to Firestore,
/// which means saves from anywhere in the app will be reflected here immediately.
class SavedPlansRepository extends ValueNotifier<List<SavedMealPlan>> {
  SavedPlansRepository(
      {required FirebaseFirestore firestore,
      required ValueListenable<UserModel?> account,
      required ValueListenable<FamilySpace?> household,
      required bool Function() canEditShared,
      UnsplashService? images,
      Stream<List<SavedMealPlan>> Function(Query<Map<String, dynamic>>)? watch})
      : _firestore = firestore,
        _account = account,
        _household = household,
        _canEditShared = canEditShared,
        _images = images ?? UnsplashService.instance,
        _watch = watch ?? watchSavedPlans,
        super([]) {
    _account.addListener(_onAuthChange);
    _household.addListener(_onFamilyChange);
    _onAuthChange();
  }

  static final instance = SavedPlansRepository(
      firestore: FirebaseFirestore.instance,
      account: AuthRepository.instance,
      household: FamilyRepository.instance,
      canEditShared: () => FamilyPermissions.canAcceptMeal);
  final FirebaseFirestore _firestore;
  final UnsplashService _images;
  final ValueListenable<UserModel?> _account;
  final ValueListenable<FamilySpace?> _household;
  final bool Function() _canEditShared;
  final Stream<List<SavedMealPlan>> Function(Query<Map<String, dynamic>>)
      _watch;
  bool _disposed = false;
  String? _personalError, _familyError;
  bool _personalLoading = false, _familyLoading = false;
  String? get error => _personalError ?? _familyError;
  bool get isLoading => _personalLoading || _familyLoading;
  void retry() {
    if (!_disposed) _resetSubscriptions(newSession: false);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_scopeVersion;
    ++_feedEpoch;
    _account.removeListener(_onAuthChange);
    _household.removeListener(_onFamilyChange);
    _personalSub?.cancel();
    _familySub?.cancel();
    super.dispose();
  }

  String? _uid;
  String? _familyId;

  StreamSubscription? _personalSub;
  StreamSubscription? _familySub;

  List<SavedMealPlan> _personalPlans = [];
  List<SavedMealPlan> _familyPlans = [];
  int _scopeVersion = 0;
  int _feedEpoch = 0;

  void _onAuthChange() {
    final newUid = _account.value?.id;
    if (_uid != newUid) {
      _uid = newUid;
      _resetSubscriptions();
    }
  }

  void _onFamilyChange() {
    final newFamilyId = _household.value?.id;
    if (_familyId != newFamilyId) {
      _familyId = newFamilyId;
      _resetSubscriptions();
    }
  }

  void _resetSubscriptions({bool newSession = true}) {
    if (_disposed) return;
    final feedEpoch = ++_feedEpoch;
    if (newSession) ++_scopeVersion;
    _personalSub?.cancel();
    _familySub?.cancel();
    _personalSub = null;
    _familySub = null;
    _personalPlans = [];
    _familyPlans = [];
    _personalError = null;
    _familyError = null;
    final uid = _uid;
    final family = _household.value;
    _familyId =
        uid != null && family?.memberForUid(uid) != null ? family!.id : null;
    _personalLoading = uid != null;
    _familyLoading = _familyId != null;
    value = [];
    if (uid == null) return;
    _personalSub = _watch(_firestore
            .collection('users')
            .doc(uid)
            .collection('mealPlans')
            .orderBy('createdAt', descending: true))
        .listen((plans) {
      if (_disposed || feedEpoch != _feedEpoch) return;
      _personalLoading = false;
      _personalError = null;
      _personalPlans = plans;
      _merge();
    }, onError: (Object _) {
      if (_disposed || feedEpoch != _feedEpoch) return;
      _personalLoading = false;
      _personalPlans = [];
      _personalError =
          'Personal saved plans could not be loaded. Please retry.';
      _merge();
    }, cancelOnError: true);
    final familyId = _familyId;
    if (familyId != null) {
      _familySub = _watch(_firestore
              .collection('families')
              .doc(familyId)
              .collection('mealPlans')
              .orderBy('createdAt', descending: true))
          .listen((plans) {
        if (_disposed || feedEpoch != _feedEpoch) return;
        _familyLoading = false;
        _familyError = null;
        _familyPlans = plans;
        _merge();
      }, onError: (Object _) {
        if (_disposed || feedEpoch != _feedEpoch) return;
        _familyLoading = false;
        _familyPlans = [];
        _familyError =
            'Household saved plans could not be loaded. Please retry.';
        _merge();
      }, cancelOnError: true);
    }
  }

  void _merge() {
    final all = [..._personalPlans, ..._familyPlans];
    final unique = <String, SavedMealPlan>{};
    for (final p in all) {
      unique[p.sourcePath ?? p.id] = p;
    }
    value = unique.values.toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
  }

  int get sessionVersion => _scopeVersion;
  String? get workspacePath => _uid == null
      ? null
      : _familyId == null
          ? 'users/$_uid'
          : 'families/$_familyId';

  DocumentReference<Map<String, dynamic>> _planRef(String path) {
    final permitted = path.startsWith('users/$_uid/mealPlans/') ||
        (_familyId != null &&
            path.startsWith('families/$_familyId/mealPlans/'));
    if (_uid == null || !permitted || path.split('/').length != 4) {
      throw StateError('Plan is outside the current workspace.');
    }
    if (path.startsWith('families/') && !_canEditShared()) {
      throw StateError('Your role cannot edit meals.');
    }
    return _firestore.doc(path);
  }

  Future<void> renamePlan(String path, String title) async {
    final scope = _scopeVersion;
    await _planRef(path)
        .update({'title': title, 'updatedAt': FieldValue.serverTimestamp()});
    _requireSession(scope);
  }

  /// Expand only; adding an earlier meal must not shorten an existing plan.
  static Map<String, dynamic> _expandedDates(
      Map<String, dynamic> plan, Iterable<int> mealDays) {
    final originalDays = plan['numberOfDays'] as int? ?? 1;
    var days = originalDays;
    for (final index in mealDays) {
      if (index + 1 > days) days = index + 1;
    }
    if (days == originalDays) return {};
    final start = (plan['startDate'] as Timestamp?)?.toDate();
    return {
      'numberOfDays': days,
      if (start != null)
        'endDate': Timestamp.fromDate(
            DateTime(start.year, start.month, start.day + days - 1)),
    };
  }

  Future<void> editMeal(String path, GeneratedMeal meal) async {
    final scope = _scopeVersion;
    final ref = _planRef(path);
    await _firestore.runTransaction((tx) async {
      final parent = await tx.get(ref);
      if (!parent.exists) throw StateError('Plan was deleted.');
      _requireSession(scope);
      final child = ref.collection('meals').doc(meal.id);
      final current = await tx.get(child);
      _requireSession(scope);
      if (current.data()?['status'] == 'replaced') {
        throw StateError('Meal was replaced. Reload the plan.');
      }
      final extendedDates = _expandedDates(parent.data()!, [meal.dayIndex]);
      if (extendedDates.isNotEmpty) tx.update(ref, extendedDates);
      if (current.exists) {
        final editableFields = _withImage(meal.toCore()).toFirestore()
          ..remove('status')
          ..remove('accepted')
          ..remove('replacedByMealId')
          ..remove('replacedMealId')
          ..remove('isFavorite')
          ..remove('createdAt');
        tx.update(child, editableFields);
      } else {
        tx.set(child, _withImage(meal.toCore()).toFirestore());
      }
    });
    _requireSession(scope);
  }

  Future<void> deleteMeal(String path, String mealId) async {
    final scope = _scopeVersion;
    await _planRef(path).collection('meals').doc(mealId).delete();
    _requireSession(scope);
  }

  /// Save a new plan + meals. Returns the new plan document id.
  Meal _withImage(Meal meal) {
    final cached = _images.cachedPhoto(meal.title);
    // Cache-only: saving never waits on or fails because of a photo service.
    return cached == null ||
            cached.regularUrl.length > 2000 ||
            UnsplashService.validImageUrl(meal.imageUrl ?? '')
        ? meal
        : meal.copyWith(imageUrl: cached.regularUrl);
  }

  Future<String> savePlan(MealPlan plan, List<Meal> meals,
      {bool allowEmptyDraft = false}) async {
    final scope = _scopeVersion;
    final uid = _uid;
    if (_familyId != null && !_canEditShared()) {
      throw StateError("Your role cannot save meals.");
    }
    if ((meals.isEmpty && !(allowEmptyDraft && plan.status == 'draft')) ||
        meals.any((meal) => meal.title.trim().isEmpty)) {
      throw StateError("Complete the meal names before saving.");
    }
    if (uid == null) throw Exception('Not signed in');

    final col = _familyId != null
        ? _firestore
            .collection('families')
            .doc(_familyId)
            .collection('mealPlans')
        : _firestore.collection('users').doc(uid).collection('mealPlans');

    final planRef = col.doc();
    final batch = _firestore.batch();
    final planData = plan.toFirestore();
    planData['createdBy'] = uid;
    planData
        .addAll(_expandedDates(planData, meals.map((meal) => meal.dayIndex)));
    batch.set(planRef, planData);
    for (final meal in meals) {
      // Prefer stable meal ids so status updates / replacements remain consistent.
      final mealRef = meal.id.isNotEmpty
          ? planRef.collection('meals').doc(meal.id)
          : planRef.collection('meals').doc();
      batch.set(mealRef, _withImage(meal).toFirestore());
    }
    if (_familyId != null) {
      batch.set(
          planRef.parent.parent!
              .collection('activity')
              .doc('saved_${planRef.id}'),
          {
            'actorUid': uid,
            'type': 'mealPlanSaved',
            'createdAt': FieldValue.serverTimestamp(),
            'relatedPlanId': planRef.id,
            'targetId': null,
            'includeSelf': true,
          });
    }
    await batch.commit();
    if (scope != _scopeVersion) {
      throw StateError("Account or household changed.");
    }
    return planRef.id;
  }

  /// Contributions derive from meals; never delete unrelated shopping records.
  Future<void> deletePlan(String planId,
      {String? planPath, int? expectedSession}) async {
    _requireSession(expectedSession);
    final scope = _scopeVersion;
    final matches = value
        .where(
            (p) => planPath != null ? p.sourcePath == planPath : p.id == planId)
        .toList();
    if (matches.length != 1 || matches.single.sourcePath == null) {
      throw StateError('Plan not found or ambiguous. Reload.');
    }
    final ref = _planRef(matches.single.sourcePath!);
    final meals = await ref.collection('meals').get();
    _requireSession(scope);
    if (meals.docs.length > 499) {
      throw StateError('This plan exceeds the safe deletion limit.');
    }
    final batch = _firestore.batch();
    for (final meal in meals.docs) {
      batch.delete(meal.reference);
    }
    batch.delete(ref);
    await batch.commit();
    _requireSession(scope);
    // Listeners publish deletion. Historical shared events are retained.
  }

  Future<void> updateMealStatus(String mealId, MealStatus status,
      {String? planPath, int? expectedSession}) async {
    _requireSession(expectedSession);
    final paths = value
        .where((p) => p.meals.any((m) => m.id == mealId))
        .map((p) => p.sourcePath)
        .toList();
    final path = planPath ?? (paths.length == 1 ? paths.single : null);
    if (path == null) throw StateError('Meal not found or ambiguous. Reload.');
    final scope = _scopeVersion;
    final ref = _planRef(path);
    await MealWorkflowStore(_firestore)
        .setStatus(plan: ref, mealId: mealId, status: status, actorUid: _uid!);
    if (scope != _scopeVersion) {
      throw StateError('Account or household changed.');
    }
  }

  void _requireSession(int? expectedSession) {
    if (expectedSession != null && expectedSession != _scopeVersion) {
      throw StateError('Account or household changed. Reopen the meal.');
    }
  }

  /// Persist favorite flag for a meal in a saved plan.
  Future<void> toggleFavorite(String mealId, bool isFavorite,
      {String? planPath, int? expectedSession}) async {
    _requireSession(expectedSession);
    final scope = _scopeVersion;
    final matches = value
        .where((p) =>
            p.meals.any((m) => m.id == mealId) &&
            (planPath == null || p.sourcePath == planPath))
        .toList();
    if (matches.length != 1) throw StateError('Meal not found or ambiguous.');
    await _planRef(matches.single.sourcePath!)
        .collection('meals')
        .doc(mealId)
        .update({'isFavorite': isFavorite});
    _requireSession(scope);
  }

  /// Replace an existing meal with a newly generated meal in a saved plan.
  Future<GeneratedMeal> replaceMeal(
    String oldMealId,
    GeneratedMeal newMeal, {
    MealStatus newMealStatus = MealStatus.pending,
    String? planPath,
    int? expectedSession,
  }) async {
    _requireSession(expectedSession);
    final uid = _uid;
    final scope = _scopeVersion;
    if (uid == null) throw StateError('Not signed in.');
    final matches =
        value.where((p) => p.meals.any((m) => m.id == oldMealId)).toList();
    final path =
        planPath ?? (matches.length == 1 ? matches.single.sourcePath : null);
    if (path == null) {
      throw StateError('Meal not found or ambiguous. Refresh the plan.');
    }
    final result = await MealReplacementStore(_firestore).replace(
      plan: _planRef(path),
      oldMealId: oldMealId,
      replacement: newMeal.toCore(),
      status: newMealStatus,
      actorUid: uid,
    );
    if (_scopeVersion != scope) {
      throw StateError('Account or household changed. Reload the plan.');
    }
    return GeneratedMeal.fromCore(result.successor);
  }
}
