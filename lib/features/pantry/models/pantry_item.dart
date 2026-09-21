/// Three-state status for a pantry item (FR-08).
enum PantryStatus { available, used, needed }

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expiresInDays,
    required this.isExpiringSoon,
    this.status = PantryStatus.available,
  });

  final String id;
  final String name;
  final String quantity;
  final int expiresInDays;
  final bool isExpiringSoon;
  final PantryStatus status;

  PantryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    int? expiresInDays,
    bool? isExpiringSoon,
    PantryStatus? status,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      expiresInDays: expiresInDays ?? this.expiresInDays,
      isExpiringSoon: isExpiringSoon ?? this.isExpiringSoon,
      status: status ?? this.status,
    );
  }
}