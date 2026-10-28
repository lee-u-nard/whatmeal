import 'package:cloud_firestore/cloud_firestore.dart';

/// Three-state (+ purchased) status for a grocery list item.
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
    this.mealPlanId,
    this.sourceMealPaths = const [],
    String? section,
  })  : checked = checked ?? (status == GroceryStatus.used),
        status = status ??
            (checked == true ? GroceryStatus.used : GroceryStatus.needed),
        category = section ?? category;

  final String? id;
  final String name;
  final String quantity;
  final String category;
  bool checked;
  GroceryStatus status;
  final String? tag;
  final String? addedBy;
  final String? mealPlanId;
  final List<String> sourceMealPaths;

  String get section => category;

  bool get isPurchased => status == GroceryStatus.used || checked;

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    String? category,
    bool? checked,
    GroceryStatus? status,
    String? tag,
    String? section,
    String? mealPlanId,
    String? addedBy,
    List<String>? sourceMealPaths,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? section ?? this.category,
      checked: checked ?? this.checked,
      status: status ?? this.status,
      tag: tag ?? this.tag,
      mealPlanId: mealPlanId ?? this.mealPlanId,
      addedBy: addedBy ?? this.addedBy,
      sourceMealPaths: sourceMealPaths ?? this.sourceMealPaths,
    );
  }

  static GroceryStatus _parseStatus(Map<String, dynamic> data) {
    final raw = data['status'] as String?;
    if (raw != null) {
      switch (raw.toLowerCase()) {
        case 'available':
          return GroceryStatus.available;
        case 'used':
          return GroceryStatus.used;
        case 'needed':
          return GroceryStatus.needed;
      }
    }
    return (data['checked'] == true)
        ? GroceryStatus.used
        : GroceryStatus.needed;
  }

  factory GroceryItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final status = _parseStatus(data);
    return GroceryItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: data['quantity'] ?? '',
      category: data['category'] ?? 'Other',
      checked: status == GroceryStatus.used,
      status: status,
      tag: data['tag'],
      addedBy: data['addedBy'],
      mealPlanId: data['mealPlanId'],
      sourceMealPaths: List<String>.from(data['sourceMealPaths'] ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'quantity': quantity,
        'category': category,
        'checked': status == GroceryStatus.used || checked,
        'status': status.name,
        'tag': tag,
        'addedBy': addedBy,
        if (sourceMealPaths.isNotEmpty) 'sourceMealPaths': sourceMealPaths,
        if (mealPlanId != null) 'mealPlanId': mealPlanId,
      };
}
