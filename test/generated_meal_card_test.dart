import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/generated_meal_plan_page.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('accepted meal actions fit narrow card at text scale $scale',
        (tester) async {
      var edited = false;
      var completed = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
            child: Center(
                child: SizedBox(
                    width: 280,
                    child: GeneratedMealCard(
                      meal: const GeneratedMeal(
                          id: 'local',
                          title: 'Local Rice Meal',
                          type: 'Breakfast',
                          prepTime: '',
                          calories: '',
                          badgeText: 'Custom',
                          imageUrl: 'https://example.test/meal.png',
                          ingredients: [],
                          macros: {},
                          status: MealStatus.accepted),
                      dayIndex: 0,
                      onOpen: () {},
                      onReplace: () {},
                      onAccept: () {},
                      onEdit: () => edited = true,
                      onDelete: () {},
                      onComplete: () => completed = true,
                      onNotCompleted: () {},
                    )))),
      ))));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Edit Dish'));
      await tester.tap(find.byTooltip('Edit Dish'));
      expect(edited, isTrue);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
