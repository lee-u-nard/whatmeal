import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';

class PantryRepository extends ValueNotifier<Map<String, List<PantryItem>>> {
  PantryRepository() : super({
    'Proteins': [
      const PantryItem(name: 'Chicken Breast', quantity: '1.2 kg', expiresInDays: 12, isExpiringSoon: false),
    ],
    'Vegetables': [
      const PantryItem(name: 'Spinach', quantity: '200 g', expiresInDays: 3, isExpiringSoon: true),
    ],
    'Dairy': [
      const PantryItem(name: 'Greek Yogurt', quantity: '1 Liter', expiresInDays: 12, isExpiringSoon: false),
    ],
  });

  static final instance = PantryRepository();

  void addItem(String category, PantryItem item) {
    final updated = Map<String, List<PantryItem>>.from(value);
    updated[category] = [...?updated[category], item];
    value = updated; // triggers listeners
  }
}