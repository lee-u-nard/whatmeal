import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../meal/models/meal.dart';
import '../models/saved_meal_plan.dart';

/// Watches both metadata and nested meals; child edits need not touch the parent.
Stream<List<SavedMealPlan>> watchSavedPlans(
  Query<Map<String, dynamic>> query, {
  Stream<QuerySnapshot<Map<String, dynamic>>> Function(
          Query<Map<String, dynamic>>)?
      watchMeals,
}) {
  late StreamController<List<SavedMealPlan>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? parent;
  final children =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final tokens = <String, Object>{};
  final paths = <String, String>{};
  final metadata = <String, Map<String, dynamic>>{};
  final meals = <String, List<GeneratedMeal>>{};
  var stopped = false;

  void emit() {
    if (stopped || metadata.keys.any((id) => !meals.containsKey(id))) return;
    try {
      controller.add([
        for (final entry in metadata.entries)
          SavedMealPlan.fromFirestore(entry.key, entry.value, meals[entry.key]!)
              .copyWith(sourcePath: paths[entry.key]),
      ]);
    } catch (error, stack) {
      controller.addError(error, stack);
    }
  }

  controller = StreamController<List<SavedMealPlan>>(
    onListen: () {
      parent = query.snapshots().listen((snapshot) {
        if (stopped) return;
        for (final doc in snapshot.docs) {
          paths[doc.id] = doc.reference.path;
        }
        final ids = snapshot.docs.map((doc) => doc.id).toSet();
        for (final id in children.keys.toList()) {
          if (!ids.contains(id)) {
            children.remove(id)?.cancel();
            tokens.remove(id);
            meals.remove(id);
          }
        }
        metadata.clear();
        for (final doc in snapshot.docs) {
          metadata[doc.id] = doc.data();
          if (children.containsKey(doc.id)) continue;
          final token = Object();
          tokens[doc.id] = token;
          final mealQuery =
              doc.reference.collection('meals').orderBy('dayIndex');
          children[doc.id] =
              (watchMeals?.call(mealQuery) ?? mealQuery.snapshots()).listen(
                  (snapshot) {
            if (stopped || tokens[doc.id] != token) return;
            try {
              meals[doc.id] = snapshot.docs
                  .map((meal) =>
                      GeneratedMeal.fromCore(Meal.fromFirestore(meal)))
                  .toList();
              emit();
            } catch (error, stack) {
              controller.addError(error, stack);
            }
          }, onError: (Object error, StackTrace stack) {
            if (!stopped && tokens[doc.id] == token) {
              meals.remove(doc.id);
              controller.addError(error, stack);
            }
          });
        }
        emit();
      }, onError: (Object error, StackTrace stack) {
        if (!stopped) controller.addError(error, stack);
      });
    },
    onCancel: () async {
      stopped = true;
      tokens.clear();
      await parent?.cancel();
      await Future.wait(children.values.map((child) => child.cancel()));
      children.clear();
    },
  );
  return controller.stream;
}
