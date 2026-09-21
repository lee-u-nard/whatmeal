import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';

class PantryRepository extends ValueNotifier<Map<String, List<PantryItem>>> {
  PantryRepository._()
      : super({
          'Proteins': [
            const PantryItem(
              id: 'p1',
              name: 'Chicken Breast',
              quantity: '1.2 kg',
              expiresInDays: 12,
              isExpiringSoon: false,
              status: PantryStatus.available,
            ),
            const PantryItem(
              id: 'p2',
              name: 'Fresh Atlantic Salmon',
              quantity: '500 g',
              expiresInDays: 2,
              isExpiringSoon: true,
              status: PantryStatus.available,
            ),
          ],
          'Vegetables': [
            const PantryItem(
              id: 'p3',
              name: 'Spinach',
              quantity: '200 g',
              expiresInDays: 3,
              isExpiringSoon: true,
              status: PantryStatus.available,
            ),
            const PantryItem(
              id: 'p4',
              name: 'Avocados',
              quantity: '4 units',
              expiresInDays: 1,
              isExpiringSoon: true,
              status: PantryStatus.used,
            ),
          ],
          'Dairy': [
            const PantryItem(
              id: 'p5',
              name: 'Greek Yogurt',
              quantity: '1 Liter',
              expiresInDays: 12,
              isExpiringSoon: false,
              status: PantryStatus.available,
            ),
          ],
        });

  static final instance = PantryRepository._();

  void addItem(String category, PantryItem item) {
    final updated = Map<String, List<PantryItem>>.from(value);
    updated[category] = [...?updated[category], item];
    value = updated;
  }

  void updateItem(String category, PantryItem updatedItem) {
    final updated = Map<String, List<PantryItem>>.from(value);
    if (updated.containsKey(category)) {
      updated[category] = updated[category]!
          .map((item) => item.id == updatedItem.id ? updatedItem : item)
          .toList();
      value = updated;
    }
  }

  /// Updates only the [status] of the item with [id] (FR-08).
  void setItemStatus(String id, PantryStatus status) {
    for (final entry in value.entries) {
      final idx = entry.value.indexWhere((item) => item.id == id);
      if (idx != -1) {
        updateItem(entry.key, entry.value[idx].copyWith(status: status));
        return;
      }
    }
  }

  void deleteItem(String id) {
    final updated = <String, List<PantryItem>>{};
    for (final entry in value.entries) {
      final filtered = entry.value.where((item) => item.id != id).toList();
      if (filtered.isNotEmpty) {
        updated[entry.key] = filtered;
      }
    }
    value = updated;
  }
}