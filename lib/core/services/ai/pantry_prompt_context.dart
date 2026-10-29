import '../../../features/pantry/models/pantry_item.dart';

/// Preserve recorded stock amounts for generation without guessing units,
/// combining lots, or treating used/needed/expired ingredients as available.
List<String> pantryPromptContext(Iterable<PantryItem> items,
    {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (final item in items)
      if ((item.status == PantryStatus.available ||
              item.status == PantryStatus.runningLow) &&
          !item.expirationDate.isBefore(today) &&
          item.name.trim().isNotEmpty)
        if (item.quantity.trim().isEmpty)
          item.name.trim()
        else
          '${item.quantity.trim()} ${item.name.trim()}',
  ];
}
