import 'package:flutter/foundation.dart';
import '../models/grocery_item.dart';

class GroceryRepository extends ValueNotifier<Map<String, List<GroceryItem>>> {
  GroceryRepository._()
      : super({
          'PRODUCE AISLE': [
            GroceryItem(id: 'g1', name: 'Asparagus bundle', quantity: '1 unit', section: 'PRODUCE AISLE'),
            GroceryItem(id: 'g2', name: 'Lemons', quantity: '3 units', section: 'PRODUCE AISLE'),
            GroceryItem(
              id: 'g3',
              name: 'Avocados',
              quantity: '2 units',
              status: GroceryStatus.used,
              tag: 'In Pantry',
              section: 'PRODUCE AISLE',
            ),
          ],
          'MEAT & SEAFOOD': [
            GroceryItem(id: 'g4', name: 'Fresh Atlantic Salmon', quantity: '500g', section: 'MEAT & SEAFOOD'),
            GroceryItem(
              id: 'g5',
              name: 'Chicken Breast',
              quantity: '1.2 kg',
              status: GroceryStatus.available,
              section: 'MEAT & SEAFOOD',
            ),
          ],
          'PANTRY STAPLES': [
            GroceryItem(id: 'g6', name: 'Organic Honey', quantity: '1 jar', section: 'PANTRY STAPLES'),
            GroceryItem(id: 'g7', name: 'Almond Flour', quantity: '400g', section: 'PANTRY STAPLES'),
          ],
        });

  static final instance = GroceryRepository._();

  /// Cycles the item's status: needed → available → used → needed (FR-08).
  void cycleStatus(String id) {
    final updated = Map<String, List<GroceryItem>>.from(value);
    for (final entry in updated.entries) {
      for (final item in entry.value) {
        if (item.id == id) {
          item.status = GroceryStatus.values[
              (item.status.index + 1) % GroceryStatus.values.length];
          break;
        }
      }
    }
    value = Map.from(updated);
  }

  void addItem(String section, GroceryItem item) {
    final updated = Map<String, List<GroceryItem>>.from(value);
    final list = updated[section] ?? [];
    updated[section] = [...list, item];
    value = updated;
  }

  void addMultipleItems(List<GroceryItem> items) {
    final updated = Map<String, List<GroceryItem>>.from(value);
    for (final item in items) {
      final section = item.section.toUpperCase();
      final list = updated[section] ?? [];
      list.add(item);
      updated[section] = list;
    }
    value = updated;
  }

  /// Removes all items with status == used.
  void clearUsed() {
    final updated = <String, List<GroceryItem>>{};
    for (final entry in value.entries) {
      final remaining =
          entry.value.where((i) => i.status != GroceryStatus.used).toList();
      if (remaining.isNotEmpty) {
        updated[entry.key] = remaining;
      }
    }
    value = updated;
  }

  void deleteItem(String id) {
    final updated = <String, List<GroceryItem>>{};
    for (final entry in value.entries) {
      final remaining = entry.value.where((i) => i.id != id).toList();
      if (remaining.isNotEmpty) {
        updated[entry.key] = remaining;
      }
    }
    value = updated;
  }
}
