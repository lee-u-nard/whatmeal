

class GroceryItem {
  GroceryItem({
    required this.name,
    required this.quantity,
    this.checked = false,
    this.tag,
  });

  final String name;
  final String quantity;
  bool checked;
  final String? tag; // e.g. "In Pantry"
}