import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal/widgets/meal_status_badge.dart';

void main() {
  testWidgets('meal status remains readable without relying on color',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(
      children: [
        for (final status in MealStatus.values) MealStatusBadge(status: status)
      ],
    ))));
    for (final label in [
      'Pending Decision',
      'Accepted',
      'Completed',
      'Not Completed',
      'Replaced'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
