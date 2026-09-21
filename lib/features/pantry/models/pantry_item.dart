import 'package:cloud_firestore/cloud_firestore.dart';

class PantryItem {
  PantryItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.category,
    required this.expirationDate,
    this.addedBy,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String quantity;
  final String category;
  final DateTime expirationDate;
  final String? addedBy;
  final DateTime? createdAt;

  /// Days remaining until expiration, computed live from [expirationDate].
  int get expiresInDays => expirationDate.difference(DateTime.now()).inDays;

  /// True if the item expires within 5 days. Computed live.
  bool get isExpiringSoon => expiresInDays <= 5;

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