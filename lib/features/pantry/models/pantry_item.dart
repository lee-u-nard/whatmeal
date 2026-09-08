


class PantryItem {
  const PantryItem({
    required this.name,
    required this.quantity,
    required this.expiresInDays,
    required this.isExpiringSoon,
  });

  final String name;
  final String quantity;
  final int expiresInDays;
  final bool isExpiringSoon; // drives red vs green
}