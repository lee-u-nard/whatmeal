import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';

class PantryRepository extends ValueNotifier<Map<String, List<PantryItem>>> {
  PantryRepository._() : super({}) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (_uid != null) {
        _listenToItems();
      } else {
        _sub?.cancel();
        _sub = null;
        value = {};
      }
    });
  }
  static final instance = PantryRepository._();

  final _firestore = FirebaseFirestore.instance;
  String? _uid;
  StreamSubscription? _sub;
  String? error;

  Map<String, List<PantryItem>> get items => value;

  CollectionReference<Map<String, dynamic>> get _pantryCol =>
      _firestore.collection('users').doc(_uid).collection('pantryItems');

  void _listenToItems() {
    _sub?.cancel();
    if (_uid == null) return;
    _sub = _pantryCol.orderBy('createdAt', descending: true).snapshots().listen(
      (snapshot) {
        error = null;
        final grouped = <String, List<PantryItem>>{};
        final oldItems = <String, PantryItem>{};
        for (final list in value.values) {
          for (final item in list) {
            if (item.id != null) oldItems[item.id!] = item;
          }
        }
        
        for (final doc in snapshot.docs) {
          final item = PantryItem.fromFirestore(doc);
          final old = oldItems[item.id];
          final mergedItem = old != null ? item.copyWith(status: old.status) : item;
          grouped.putIfAbsent(mergedItem.category, () => []).add(mergedItem);
        }
        value = grouped;
      },
      onError: (e) {
        error = 'Failed to load pantry: $e';
        notifyListeners();
      },
    );
  }

  void addItem(String category, PantryItem item) async {
    if (_uid == null) return;
    final itemToSave = item.copyWith(category: category);
    await _pantryCol.add(itemToSave.toFirestore());
  }

  void updateItem(String category, PantryItem updatedItem) async {
    if (_uid == null || updatedItem.id == null || updatedItem.id!.isEmpty) return;
    await _pantryCol.doc(updatedItem.id).update(updatedItem.toFirestore());
  }

  void setItemStatus(String id, PantryStatus status) {
    final updated = Map<String, List<PantryItem>>.from(value);
    for (final entry in updated.entries) {
      final idx = entry.value.indexWhere((item) => item.id == id);
      if (idx != -1) {
        entry.value[idx] = entry.value[idx].copyWith(status: status);
        value = updated;
        return;
      }
    }
  }

  void deleteItem(String id) async {
    if (_uid == null) return;
    await _pantryCol.doc(id).delete();
  }

  int get expiringCount {
    int count = 0;
    for (final list in value.values) {
      count += list.where((item) => item.isExpiringSoon).length;
    }
    return count;
  }
}