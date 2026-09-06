import 'package:flutter/material.dart';

class MealDetailPage extends StatelessWidget {
  const MealDetailPage({super.key, required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meal $mealId')),
      body: Center(child: Text('Details for meal $mealId')),
    );
  }
}
