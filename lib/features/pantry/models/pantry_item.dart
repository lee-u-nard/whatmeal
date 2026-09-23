import 'package:cloud_firestore/cloud_firestore.dart';

/// Three-state status for a pantry item (FR-08).
enum PantryStatus { available, used, needed }

class PantryItem {
  PantryItem({
    this.id,
    required this.name,
    required this.quantity,
    this.category = 'Other',
    DateTime? expirationDate,
    int? expiresInDays,
    bool? isExpiringSoon,
    this.status = PantryStatus.available,
    this.addedBy,
    this.createdAt,
  }) : expirationDate = expirationDate ?? 
          (expiresInDays != null 
              ? DateTime.now().add(Duration(days: expiresInDays)) 
              : DateTime.now());

  final String? id;
  final String name;
  final String quantity;
  final String category;
  final DateTime expirationDate;
  final String? addedBy;
  final DateTime? createdAt;
  final PantryStatus status;

  /// Days remaining until expiration, computed live from [expirationDate].
  int get expiresInDays => expirationDate.difference(DateTime.now()).inDays;

  /// True if the item expires within 5 days. Computed live.
  bool get isExpiringSoon => expiresInDays <= 5;

  PantryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? category,
    DateTime? expirationDate,
    int? expiresInDays,
    bool? isExpiringSoon,
    PantryStatus? status,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expirationDate: expirationDate ?? this.expirationDate,
      status: status ?? this.status,
      addedBy: addedBy,
      createdAt: createdAt,
    );
  }

  factory PantryItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PantryItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? '',
      category: data['category'] ?? 'Other',
      expirationDate: (data['expirationDate'] as Timestamp).toDate(),
      addedBy: data['addedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: PantryStatus.available, // Deferred (not persisted)
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'quantity': quantity,
    'category': category,
    'expirationDate': Timestamp.fromDate(expirationDate),
    'addedBy': addedBy,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}