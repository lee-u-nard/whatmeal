import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryList {
  GroceryList({
    required this.id,
    this.title,
    this.mealPlanId,
    this.createdAt,
  });

  final String id;
  final String? title;
  final String? mealPlanId;
  final DateTime? createdAt;

  factory GroceryList.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroceryList(
      id: doc.id,
      title: data['title'],
      mealPlanId: data['mealPlanId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'mealPlanId': mealPlanId,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}
