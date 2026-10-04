import 'package:cloud_firestore/cloud_firestore.dart';

/// Ingredient availability status for pantry items.
enum PantryStatus { available, runningLow, used, needed }

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

  int get expiresInDays => expirationDate.difference(DateTime.now()).inDays;

  bool get isExpiringSoon => expiresInDays <= 5;

  String get statusLabel {
    switch (status) {
      case PantryStatus.available:
        return 'Available';
      case PantryStatus.runningLow:
        return 'Running Low';
      case PantryStatus.used:
        return 'Used';
      case PantryStatus.needed:
        return 'Needed';
    }
  }

  PantryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? category,
    DateTime? expirationDate,
    int? expiresInDays,
    bool? isExpiringSoon,
    PantryStatus? status,
    String? addedBy,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expirationDate: expirationDate ?? this.expirationDate,
      status: status ?? this.status,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt,
    );
  }

  static PantryStatus _parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'runninglow':
      case 'running_low':
      case 'low':
        return PantryStatus.runningLow;
      case 'used':
        return PantryStatus.used;
      case 'needed':
        return PantryStatus.needed;
      default:
        return PantryStatus.available;
    }
  }

  factory PantryItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PantryItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? '',
      category: data['category'] ?? 'Other',
      expirationDate:
          (data['expirationDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedBy: data['addedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: _parseStatus(data['status'] as String?),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'quantity': quantity,
        'category': category,
        'expirationDate': Timestamp.fromDate(expirationDate),
        'status': status.name,
        'addedBy': addedBy,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };
}
