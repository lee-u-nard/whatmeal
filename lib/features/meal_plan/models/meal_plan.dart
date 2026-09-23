import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlan {
  MealPlan({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.numberOfDays = 5,
    this.mealTypes = const [],
    this.cuisinePreferences = const [],
    this.prioritizePantry = true,
    this.selectedMemberIds = const [],
    this.estimatedCost,
    this.groceryListId,
    this.status = 'active',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final int numberOfDays;
  final List<String> mealTypes;
  final List<String> cuisinePreferences;
  final bool prioritizePantry;
  final List<String> selectedMemberIds;
  final String? estimatedCost;
  final String? groceryListId;
  final String status; // "active" | "saved" | "archived"
  final String? createdBy;
  final DateTime? createdAt;

  /// Formatted date range string for display (e.g. "Oct 1 - Oct 7")
  String get dateRange {
    if (startDate == null || endDate == null) return '';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[startDate!.month - 1]} ${startDate!.day} - ${months[endDate!.month - 1]} ${endDate!.day}';
  }

  factory MealPlan.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MealPlan(
      id: doc.id,
      title: data['title'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      numberOfDays: data['numberOfDays'] ?? 5,
      mealTypes: List<String>.from(data['mealTypes'] ?? []),
      cuisinePreferences: List<String>.from(data['cuisinePreferences'] ?? []),
      prioritizePantry: data['prioritizePantry'] ?? true,
      selectedMemberIds: List<String>.from(data['selectedMemberIds'] ?? []),
      estimatedCost: data['estimatedCost'],
      groceryListId: data['groceryListId'],
      status: data['status'] ?? 'active',
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'numberOfDays': numberOfDays,
    'mealTypes': mealTypes,
    'cuisinePreferences': cuisinePreferences,
    'prioritizePantry': prioritizePantry,
    'selectedMemberIds': selectedMemberIds,
    'estimatedCost': estimatedCost,
    'groceryListId': groceryListId,
    'status': status,
    'createdBy': createdBy,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };
}
