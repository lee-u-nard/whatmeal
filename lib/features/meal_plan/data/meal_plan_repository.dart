import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';
import '../../meal/models/meal.dart';

/// Repository for meal plans and their nested meals, scoped to a family group.
class MealPlanRepository extends ChangeNotifier {
  MealPlanRepository();

  final _firestore = FirebaseFirestore.instance;
  String? _familyId;
  List<MealPlan> _savedPlans = [];
  MealPlan? _activePlan;

  List<MealPlan> get savedPlans => _savedPlans;
  MealPlan? get activePlan => _activePlan;

  void setFamilyId(String? familyId) {
    if (_familyId == familyId) return;
    _familyId = familyId;
    if (familyId != null) {
      _listenToPlans();
    } else {
      _savedPlans = [];
      _activePlan = null;
      notifyListeners();
    }
  }

  CollectionReference<Map<String, dynamic>> get _plansCol =>
      _firestore.collection('families').doc(_familyId).collection('mealPlans');

  void _listenToPlans() {
    _plansCol.orderBy('createdAt', descending: true).snapshots().listen((snapshot) {
      _savedPlans = snapshot.docs.map((doc) => MealPlan.fromFirestore(doc)).toList();
      _activePlan = _savedPlans.where((p) => p.status == 'active').firstOrNull;
      notifyListeners();
    });
  }

  /// Save a new meal plan with its meals.
  Future<String> savePlan(MealPlan plan, List<Meal> meals) async {
    final planRef = _plansCol.doc();
    final batch = _firestore.batch();

    batch.set(planRef, plan.toFirestore());
    for (final meal in meals) {
      batch.set(planRef.collection('meals').doc(), meal.toFirestore());
    }

    await batch.commit();
    return planRef.id;
  }

  /// Delete a meal plan and its nested meals.
  Future<void> deletePlan(String planId) async {
    if (_familyId == null) return;

    // Delete nested meals first
    final mealsSnapshot = await _plansCol.doc(planId).collection('meals').get();
    final batch = _firestore.batch();
    for (final doc in mealsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_plansCol.doc(planId));
    await batch.commit();
  }

  /// Get all meals for a specific plan.
  Future<List<Meal>> getMealsForPlan(String planId) async {
    if (_familyId == null) return [];
    final snapshot = await _plansCol
        .doc(planId)
        .collection('meals')
        .orderBy('dayIndex')
        .get();
    return snapshot.docs.map((doc) => Meal.fromFirestore(doc)).toList();
  }

  /// Get a single meal by ID within a plan.
  Future<Meal?> getMeal(String planId, String mealId) async {
    if (_familyId == null) return null;
    final doc = await _plansCol.doc(planId).collection('meals').doc(mealId).get();
    if (!doc.exists) return null;
    return Meal.fromFirestore(doc);
  }

  /// Stream a single meal.
  Stream<Meal?> mealStream(String planId, String mealId) {
    return _plansCol.doc(planId).collection('meals').doc(mealId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Meal.fromFirestore(doc);
    });
  }

  /// Toggle a meal's accepted status.
  Future<void> toggleAccepted(String planId, String mealId, bool accepted) async {
    await _plansCol.doc(planId).collection('meals').doc(mealId).update({
      'accepted': accepted,
    });
  }

  /// Toggle a meal's favorite status.
  Future<void> toggleFavorite(String planId, String mealId, bool isFavorite) async {
    await _plansCol.doc(planId).collection('meals').doc(mealId).update({
      'isFavorite': isFavorite,
    });
  }

  /// Update a meal (e.g., after AI replacement).
  Future<void> updateMeal(String planId, String mealId, Meal meal) async {
    await _plansCol.doc(planId).collection('meals').doc(mealId).update(
      meal.toFirestore(),
    );
  }

  /// Count of saved plans.
  int get savedPlanCount => _savedPlans.length;
}
