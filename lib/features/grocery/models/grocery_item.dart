/// Three-state status for a grocery list item (FR-08).
enum GroceryStatus { needed, available, used }

class GroceryItem {
  GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.status = GroceryStatus.needed,
    this.tag,
    this.section = 'PANTRY STAPLES',
  });

  final String id;
  final String name;
  final String quantity;
  GroceryStatus status; // mutable — cycled in-place by repository
  final String? tag; // e.g. "In Pantry"
  final String section;

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    GroceryStatus? status,
    String? tag,
    String? section,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      tag: tag ?? this.tag,
      section: section ?? this.section,
    );
  }
}