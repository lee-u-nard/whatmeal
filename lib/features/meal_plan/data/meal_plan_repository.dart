import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';
import '../../meal/models/meal.dart';
import '../../auth/data/auth_repository.dart';
import '../../family/data/family_repository.dart';

/// Repository for meal plans and their nested meals, scoped to a family group.
class MealPlanRepository extends ChangeNotifier {
  MealPlanRepository() {
    AuthRepository.instance.addListener(_onAuthChange);
    FamilyRepository.instance.addListener(_onFamilyChange);
    _onAuthChange();
  }

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  String? _familyId;
  
  StreamSubscription? _personalSub;
  StreamSubscription? _familySub;

  List<MealPlan> _personalPlans = [];
  List<MealPlan> _familyPlans = [];
  List<MealPlan> _savedPlans = [];
  MealPlan? _activePlan;

  List<MealPlan> get savedPlans => _savedPlans;
  MealPlan? get activePlan => _activePlan;

  void _onAuthChange() {
    final newUid = AuthRepository.instance.value?.id;
    if (_uid != newUid) {
      _uid = newUid;
      _listenToPlans();
    }
  }

  void _onFamilyChange() {
    final newFamilyId = FamilyRepository.instance.value?.id;
    if (_familyId != newFamilyId) {
      _familyId = newFamilyId;
      _listenToPlans();
    }
  }

  CollectionReference<Map<String, dynamic>>? get _personalPlansCol =>
      _uid != null ? _firestore.collection('users').doc(_uid).collection('mealPlans') : null;

  CollectionReference<Map<String, dynamic>>? get _familyPlansCol =>
      _familyId != null ? _firestore.collection('families').doc(_familyId).collection('mealPlans') : null;

  void _listenToPlans() {
    _personalSub?.cancel();
    _familySub?.cancel();

    if (_personalPlansCol != null) {
      _personalSub = _personalPlansCol!.orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
        _personalPlans = snapshot.docs.map((doc) => MealPlan.fromFirestore(doc)).toList();
        _mergePlans();
      });
    } else {
      _personalPlans = [];
      _mergePlans();
    }

    if (_familyPlansCol != null) {
      _familySub = _familyPlansCol!.orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
        _familyPlans = snapshot.docs.map((doc) => MealPlan.fromFirestore(doc)).toList();
        _mergePlans();
      });
    } else {
      _familyPlans = [];
      _mergePlans();
    }
  }

  void _mergePlans() {
    final all = [..._personalPlans, ..._familyPlans];
    // Deduplicate by ID just in case
    final unique = <String, MealPlan>{};
    for (final p in all) {
      unique[p.id] = p;
    }
    _savedPlans = unique.values.toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    
    _activePlan = _savedPlans.where((p) => p.status == 'active').firstOrNull;
    notifyListeners();
  }

  CollectionReference<Map<String, dynamic>> get _currentPlansCol {
    if (_uid == null) {
      throw Exception('Not signed in');
    }
    if (_familyId != null) return _familyPlansCol!;
    return _personalPlansCol!;
  }

  CollectionReference<Map<String, dynamic>> _getColForPlan(String planId) {
    if (_familyPlans.any((p) => p.id == planId) && _familyPlansCol != null) {
      return _familyPlansCol!;
    }
    if (_personalPlansCol != null) {
      return _personalPlansCol!;
    }
    throw Exception('Plan not found or user not logged in');
  }

  /// Save a new meal plan with its meals.
  Future<String> savePlan(MealPlan plan, List<Meal> meals) async {
    try {
      final col = _currentPlansCol;
      final planRef = col.doc();
      final batch = _firestore.batch();

      batch.set(planRef, plan.toFirestore());
      for (final meal in meals) {
        batch.set(planRef.collection('meals').doc(), meal.toFirestore());
      }

      await batch.commit();
      // TEMPORARY: remove after persistence is confirmed on device.
      debugPrint(
        '[SAVE-DEBUG] meal plan save success path=${col.path} id=${planRef.id} meals=${meals.length}',
      );
      return planRef.id;
    } catch (e) {
      debugPrint('[SAVE-DEBUG] meal plan save FAILED uid=$_uid familyId=$_familyId error=$e');
      rethrow;
    }
  }

  /// Delete a meal plan and its nested meals.
  Future<void> deletePlan(String planId) async {
    final col = _getColForPlan(planId);
    
    // Delete nested meals first
    final mealsSnapshot = await col.doc(planId).collection('meals').get();
    final batch = _firestore.batch();
    for (final doc in mealsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(col.doc(planId));
    await batch.commit();
  }

  /// Get all meals for a specific plan.
  Future<List<Meal>> getMealsForPlan(String planId) async {
    final col = _getColForPlan(planId);
    final snapshot = await col
        .doc(planId)
        .collection('meals')
        .orderBy('dayIndex')
        .get();
    return snapshot.docs.map((doc) => Meal.fromFirestore(doc)).toList();
  }

  /// Get a single meal by ID within a plan.
  Future<Meal?> getMeal(String planId, String mealId) async {
    final col = _getColForPlan(planId);
    final doc = await col.doc(planId).collection('meals').doc(mealId).get();
    if (!doc.exists) return null;
    return Meal.fromFirestore(doc);
  }

  /// Stream a single meal.
  Stream<Meal?> mealStream(String planId, String mealId) {
    final col = _getColForPlan(planId);
    return col.doc(planId).collection('meals').doc(mealId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Meal.fromFirestore(doc);
    });
  }

  /// Toggle a meal's accepted status.
  Future<void> toggleAccepted(String planId, String mealId, bool accepted) async {
    final col = _getColForPlan(planId);
    await col.doc(planId).collection('meals').doc(mealId).update({
      'accepted': accepted,
    });
  }

  /// Toggle a meal's favorite status.
  Future<void> toggleFavorite(String planId, String mealId, bool isFavorite) async {
    final col = _getColForPlan(planId);
    await col.doc(planId).collection('meals').doc(mealId).update({
      'isFavorite': isFavorite,
    });
  }

  /// Update a meal (e.g., after AI replacement).
  Future<void> updateMeal(String planId, String mealId, Meal meal) async {
    final col = _getColForPlan(planId);
    await col.doc(planId).collection('meals').doc(mealId).update(
      meal.toFirestore(),
    );
  }

  /// Count of saved plans.
  int get savedPlanCount => _savedPlans.length;
  
  @override
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthChange);
    FamilyRepository.instance.removeListener(_onFamilyChange);
    _personalSub?.cancel();
    _familySub?.cancel();
    super.dispose();
  }
}
