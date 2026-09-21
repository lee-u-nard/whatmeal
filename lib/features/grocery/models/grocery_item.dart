import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryItem {
  GroceryItem({
    this.id,
    required this.name,
    required this.quantity,
    this.category = 'Other',
    this.checked = false,
    this.tag,
    this.addedBy,
  });

  final String? id;
  final String name;
  final String quantity;
  final String category;
  bool checked;
  final String? tag;
  final String? addedBy;

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
    'checked': checked,
    'tag': tag,
    'addedBy': addedBy,
  };
}