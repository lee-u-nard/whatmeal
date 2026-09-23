import 'package:cloud_firestore/cloud_firestore.dart';

/// Three-state status for a grocery list item (FR-08).
enum GroceryStatus { needed, available, used }

class GroceryItem {
  GroceryItem({
    this.id,
    required this.name,
    required this.quantity,
    String category = 'Other',
    bool? checked,
    GroceryStatus? status,
    this.tag,
    this.addedBy,
    String? section,
  }) : checked = checked ?? (status == GroceryStatus.used),
       status = status ?? (checked == true ? GroceryStatus.used : GroceryStatus.needed),
       category = section ?? category;

  final String? id;
  final String name;
  final String quantity;
  final String category;
  bool checked; // Used for backend
  GroceryStatus status; // Used for frontend
  final String? tag;
  final String? addedBy;
  
  String get section => category;

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? category,
    bool? checked,
    GroceryStatus? status,
    String? tag,
    String? section,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? section ?? this.category,
      checked: checked ?? this.checked,
      status: status ?? this.status,
      tag: tag ?? this.tag,
      addedBy: addedBy,
    );
  }

  factory GroceryItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroceryItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? '',
      category: data['category'] ?? 'Other',
      checked: data['checked'] ?? false,
      tag: data['tag'],
      addedBy: data['addedBy'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'quantity': quantity,
    'category': category,
    'checked': status == GroceryStatus.used || checked,
    'tag': tag,
    'addedBy': addedBy,
  };
}