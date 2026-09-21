import 'package:cloud_firestore/cloud_firestore.dart';

class Ingredient {
  const Ingredient({required this.name, required this.amount});

  final String name;
  final String amount;

  factory Ingredient.fromMap(Map<String, dynamic> data) => Ingredient(
    name: data['name'] ?? '',
    amount: data['amount'] ?? '',
  );

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}

class Meal {
  Meal({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.cuisine,
    this.mealType,
    this.dayIndex = 0,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.badgeText,
    this.ingredients = const [],
    this.accepted = false,
    this.isFavorite = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? cuisine;
  final String? mealType;
  final int dayIndex;
  final String? prepTime;
  final String? cookTime;
  final String? servings;
  final String? calories;
  final String? protein;
  final String? carbs;
  final String? fats;
  final String? badgeText;
  final List<Ingredient> ingredients;
  final bool accepted;
  final bool isFavorite;
  final DateTime? createdAt;

  factory Meal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Meal(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'],
      imageUrl: data['imageUrl'],
      cuisine: data['cuisine'],
      mealType: data['mealType'],
      dayIndex: data['dayIndex'] ?? 0,
      prepTime: data['prepTime'],
      cookTime: data['cookTime'],
      servings: data['servings'],
      calories: data['calories'],
      protein: data['protein'],
      carbs: data['carbs'],
      fats: data['fats'],
      badgeText: data['badgeText'],
      ingredients: (data['ingredients'] as List<dynamic>?)
          ?.map((e) => Ingredient.fromMap(Map<String, dynamic>.from(e)))
          .toList() ?? [],
      accepted: data['accepted'] ?? false,
      isFavorite: data['isFavorite'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'cuisine': cuisine,
    'mealType': mealType,
    'dayIndex': dayIndex,
    'prepTime': prepTime,
    'cookTime': cookTime,
    'servings': servings,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    'badgeText': badgeText,
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'accepted': accepted,
    'isFavorite': isFavorite,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };

  Meal copyWith({bool? accepted, bool? isFavorite}) => Meal(
    id: id,
    title: title,
    subtitle: subtitle,
    imageUrl: imageUrl,
    cuisine: cuisine,
    mealType: mealType,
    dayIndex: dayIndex,
    prepTime: prepTime,
    cookTime: cookTime,
    servings: servings,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fats: fats,
    badgeText: badgeText,
    ingredients: ingredients,
    accepted: accepted ?? this.accepted,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );
}
