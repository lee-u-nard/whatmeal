import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/saved_meal_plan.dart';
import '../models/meal_plan.dart';
import '../../meal/models/meal.dart';
import '../../family/data/family_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/app_notification.dart';

/// Repository that surfaces saved [SavedMealPlan] objects from Firestore.
///
/// Unlike the previous implementation, this does NOT create its own disconnected
/// [MealPlanRepository] instance.  Instead it listens directly to Firestore,
/// which means saves from anywhere in the app will be reflected here immediately.
class SavedPlansRepository extends ValueNotifier<List<SavedMealPlan>> {
  SavedPlansRepository._() : super([]) {
    AuthRepository.instance.addListener(_onAuthChange);
    FamilyRepository.instance.addListener(_onFamilyChange);
    _onAuthChange();
  }

  static final instance = SavedPlansRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  String? _familyId;

  StreamSubscription? _personalSub;
  StreamSubscription? _familySub;

  List<SavedMealPlan> _personalPlans = [];
  List<SavedMealPlan> _familyPlans = [];

  void _onAuthChange() {
    final newUid = AuthRepository.instance.value?.id;
    if (_uid != newUid) {
      _uid = newUid;
      _resetSubscriptions();
    }
  }

  void _onFamilyChange() {
    final newFamilyId = FamilyRepository.instance.value?.id;
    if (_familyId != newFamilyId) {
      _familyId = newFamilyId;
      _resetSubscriptions();
    }
  }

  void _resetSubscriptions() {
    _personalSub?.cancel();
    _familySub?.cancel();
    _personalPlans = [];
    _familyPlans = [];
    value = [];

    final uid = _uid;
    if (uid == null) return;

    // Listen to personal plans
    _personalSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('mealPlans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) async {
        _personalPlans = await _loadPlans(snapshot);
        _merge();
      },
      onError: (e) => debugPrint('[SavedPlansRepo] Personal listen error: $e'),
    );

    // Listen to family plans (if in a family)
    final familyId = _familyId;
    if (familyId != null) {
      _familySub = _firestore
          .collection('families')
          .doc(familyId)
          .collection('mealPlans')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) async {
          _familyPlans = await _loadPlans(snapshot);
          _merge();
        },
        onError: (e) => debugPrint('[SavedPlansRepo] Family listen error: $e'),
      );
    }
  }

  Future<List<SavedMealPlan>> _loadPlans(
      QuerySnapshot<Map<String, dynamic>> snapshot) async {
    final plans = <SavedMealPlan>[];
    for (final doc in snapshot.docs) {
      try {
        final mealsSnap =
            await doc.reference.collection('meals').orderBy('dayIndex').get();
        final meals = mealsSnap.docs
            .map((m) => GeneratedMeal.fromCore(Meal.fromFirestore(m)))
            .toList();
        plans.add(SavedMealPlan.fromFirestore(doc.id, doc.data(), meals));
      } catch (e) {
        debugPrint('[SavedPlansRepo] Error loading plan ${doc.id}: $e');
      }
    }
    return plans;
  }

  void _merge() {
    final all = [..._personalPlans, ..._familyPlans];
    final unique = <String, SavedMealPlan>{};
    for (final p in all) {
      unique[p.id] = p;
    }
    value = unique.values.toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
  }

  /// Save a new plan + meals. Returns the new plan document id.
  Future<String> savePlan(MealPlan plan, List<Meal> meals) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final col = _familyId != null
        ? _firestore
            .collection('families')
            .doc(_familyId)
            .collection('mealPlans')
        : _firestore.collection('users').doc(uid).collection('mealPlans');

    final planRef = col.doc();
    final batch = _firestore.batch();
    batch.set(planRef, plan.toFirestore());
    for (final meal in meals) {
      // Prefer stable meal ids so status updates / replacements remain consistent.
      final mealRef = meal.id.isNotEmpty
          ? planRef.collection('meals').doc(meal.id)
          : planRef.collection('meals').doc();
      batch.set(mealRef, meal.toFirestore());
    }
    await batch.commit();
    return planRef.id;
  }

  /// Deletes a saved plan, its nested meals, and related grocery/notification records
  /// so home recommendations and other saved data are not left dangling.
  Future<void> deletePlan(String planId) async {
    final uid = _uid;
    if (uid == null) return;

    final matching = value.where((p) => p.id == planId);
    final planTitle = matching.isEmpty ? null : matching.first.title;

    DocumentReference<Map<String, dynamic>>? ref;

    if (_familyPlans.any((p) => p.id == planId) && _familyId != null) {
      ref = _firestore
          .collection('families')
          .doc(_familyId)
          .collection('mealPlans')
          .doc(planId);
    } else {
      ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('mealPlans')
          .doc(planId);
    }

    // 1. Delete nested meals + plan document.
    final mealsSnap = await ref.collection('meals').get();
    final batch = _firestore.batch();
    for (final doc in mealsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(ref);
    await batch.commit();

    // 2. Remove grocery lists linked to this plan (and their items).
    await _deleteLinkedGroceryLists(uid, planId);

    // 3. Remove notifications that reference this saved plan.
    await _deleteRelatedNotifications(uid,
        planId: planId, planTitle: planTitle);

    // 4. Optimistically drop from local cache so recommendations update immediately.
    _personalPlans = _personalPlans.where((p) => p.id != planId).toList();
    _familyPlans = _familyPlans.where((p) => p.id != planId).toList();
    _merge();
  }

  Future<void> _deleteLinkedGroceryLists(String uid, String planId) async {
    try {
      final listsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('groceryLists')
          .where('mealPlanId', isEqualTo: planId)
          .get();

      for (final listDoc in listsSnap.docs) {
        final itemsSnap = await listDoc.reference.collection('items').get();
        final batch = _firestore.batch();
        for (final item in itemsSnap.docs) {
          batch.delete(item.reference);
        }
        batch.delete(listDoc.reference);
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[SavedPlansRepo] Grocery cascade delete error: $e');
    }
  }

  Future<void> _deleteRelatedNotifications(
    String uid, {
    required String planId,
    String? planTitle,
  }) async {
    try {
      final notifCol =
          _firestore.collection('users').doc(uid).collection('notifications');

      final byPlanId =
          await notifCol.where('relatedPlanId', isEqualTo: planId).get();

      final refsToDelete = <DocumentReference<Map<String, dynamic>>>{};
      for (final doc in byPlanId.docs) {
        refsToDelete.add(doc.reference);
      }

      // Fallback for older notifications that only mention the plan title.
      if (planTitle != null && planTitle.isNotEmpty) {
        final recent = await notifCol
            .orderBy('createdAt', descending: true)
            .limit(40)
            .get();
        for (final doc in recent.docs) {
          if (refsToDelete.any((r) => r.id == doc.id)) continue;
          final data = doc.data();
          final type = data['type'] as String? ?? '';
          final body = data['body'] as String? ?? '';
          final title = data['title'] as String? ?? '';
          final isMealPlanNotif =
              type == 'mealPlanSaved' || type == 'mealPlanGenerated';
          if (isMealPlanNotif &&
              (body.contains(planTitle) || title.contains(planTitle))) {
            refsToDelete.add(doc.reference);
          }
        }
      }

      if (refsToDelete.isEmpty) return;

      final batch = _firestore.batch();
      for (final ref in refsToDelete) {
        batch.delete(ref);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[SavedPlansRepo] Notification cascade delete error: $e');
    }
  }

  /// Update the status of a meal across saved plans.
  Future<void> updateMealStatus(String mealId, MealStatus status) async {
    for (final plan in value) {
      final mealIndex = plan.meals.indexWhere((m) => m.id == mealId);
      if (mealIndex != -1) {
        final targetMeal = plan.meals[mealIndex];
        DocumentReference<Map<String, dynamic>>? ref;
        final isFamily =
            _familyPlans.any((p) => p.id == plan.id) && _familyId != null;
        if (isFamily) {
          ref = _firestore
              .collection('families')
              .doc(_familyId)
              .collection('mealPlans')
              .doc(plan.id);
        } else if (_uid != null) {
          ref = _firestore
              .collection('users')
              .doc(_uid)
              .collection('mealPlans')
              .doc(plan.id);
        }

        if (ref != null) {
          final batch = _firestore.batch();
          batch.update(ref.collection('meals').doc(mealId), {
            'status': status.name,
            'accepted': status == MealStatus.accepted,
          });
          batch.set(
              ref,
              {
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
          await batch.commit();
        }

        final updatedMeals = List<GeneratedMeal>.from(plan.meals);
        updatedMeals[mealIndex] =
            updatedMeals[mealIndex].copyWith(status: status);
        final updatedPlan = plan.copyWith(meals: updatedMeals);
        final plans = List<SavedMealPlan>.from(value);
        final planIdx = plans.indexWhere((p) => p.id == plan.id);
        if (planIdx != -1) {
          plans[planIdx] = updatedPlan;
          value = plans;
        }

        // Notify household members of the status change
        if (isFamily) {
          final userName = AuthRepository.instance.value?.name ?? 'A member';
          String title = 'Meal Update';
          String body =
              '$userName updated ${targetMeal.title} to ${status.name}.';
          if (status == MealStatus.accepted) {
            title = 'Meal Accepted 🍽️';
            body =
                '$userName accepted "${targetMeal.title}" for ${targetMeal.type}.';
          } else if (status == MealStatus.completed) {
            title = 'Meal Completed ✅';
            body = '$userName marked "${targetMeal.title}" as completed!';
          } else if (status == MealStatus.notCompleted) {
            title = 'Meal Skipped ⏭️';
            body = '$userName marked "${targetMeal.title}" as not completed.';
          }
          NotificationService.instance.notifyHouseholdMembers(
            title: title,
            body: body,
            type: AppNotificationType.general,
            relatedPlanId: plan.id,
            includeSelf: false,
          );
        }
        break;
      }
    }
  }

  /// Persist favorite flag for a meal in a saved plan.
  Future<void> toggleFavorite(String mealId, bool isFavorite) async {
    for (final plan in value) {
      final mealIndex = plan.meals.indexWhere((m) => m.id == mealId);
      if (mealIndex == -1) continue;

      DocumentReference<Map<String, dynamic>>? ref;
      final isFamily =
          _familyPlans.any((p) => p.id == plan.id) && _familyId != null;
      if (isFamily) {
        ref = _firestore
            .collection('families')
            .doc(_familyId)
            .collection('mealPlans')
            .doc(plan.id);
      } else if (_uid != null) {
        ref = _firestore
            .collection('users')
            .doc(_uid)
            .collection('mealPlans')
            .doc(plan.id);
      }

      if (ref != null) {
        final batch = _firestore.batch();
        batch.update(
            ref.collection('meals').doc(mealId), {'isFavorite': isFavorite});
        batch.set(ref, {'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await batch.commit();
      }

      final updatedMeals = List<GeneratedMeal>.from(plan.meals);
      updatedMeals[mealIndex] =
          updatedMeals[mealIndex].copyWith(isFavorite: isFavorite);
      final plans = List<SavedMealPlan>.from(value);
      final planIdx = plans.indexWhere((p) => p.id == plan.id);
      if (planIdx != -1) {
        plans[planIdx] = plan.copyWith(meals: updatedMeals);
        value = plans;
      }
      break;
    }
  }

  /// Replace an existing meal with a newly generated meal in a saved plan.
  Future<void> replaceMeal(
    String oldMealId,
    GeneratedMeal newMeal, {
    MealStatus newMealStatus = MealStatus.pending,
  }) async {
    for (final plan in value) {
      final oldIndex = plan.meals.indexWhere((m) => m.id == oldMealId);
      if (oldIndex != -1) {
        final oldMeal = plan.meals[oldIndex];
        DocumentReference<Map<String, dynamic>>? ref;
        final isFamily =
            _familyPlans.any((p) => p.id == plan.id) && _familyId != null;
        if (isFamily) {
          ref = _firestore
              .collection('families')
              .doc(_familyId)
              .collection('mealPlans')
              .doc(plan.id);
        } else if (_uid != null) {
          ref = _firestore
              .collection('users')
              .doc(_uid)
              .collection('mealPlans')
              .doc(plan.id);
        }

        final prepared = newMeal.copyWith(
          status: newMealStatus,
          replacedMealId: oldMealId,
        );

        if (ref != null) {
          final batch = _firestore.batch();
          final oldDocRef = ref.collection('meals').doc(oldMealId);
          batch.update(oldDocRef, {
            'status': MealStatus.replaced.name,
            'accepted': false,
            'replacedByMealId': prepared.id,
          });

          final newDocRef = prepared.id.isNotEmpty
              ? ref.collection('meals').doc(prepared.id)
              : ref.collection('meals').doc();
          batch.set(newDocRef, prepared.toCore().toFirestore());
          batch.set(ref, {'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
          await batch.commit();
        }

        final updatedMeals = List<GeneratedMeal>.from(plan.meals);
        updatedMeals[oldIndex] = updatedMeals[oldIndex].copyWith(
          status: MealStatus.replaced,
          replacedByMealId: prepared.id,
        );
        updatedMeals.add(prepared);

        final updatedPlan = plan.copyWith(meals: updatedMeals);
        final plans = List<SavedMealPlan>.from(value);
        final planIdx = plans.indexWhere((p) => p.id == plan.id);
        if (planIdx != -1) {
          plans[planIdx] = updatedPlan;
          value = plans;
        }

        if (isFamily) {
          final userName = AuthRepository.instance.value?.name ?? 'A member';
          NotificationService.instance.notifyHouseholdMembers(
            title: 'Meal Replaced 🔄',
            body:
                '$userName replaced "${oldMeal.title}" with "${prepared.title}".',
            type: AppNotificationType.general,
            relatedPlanId: plan.id,
            includeSelf: false,
          );
        }
        break;
      }
    }
  }
}
