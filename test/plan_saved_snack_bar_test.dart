import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/meal_plan/widgets/plan_saved_snack_bar.dart';

void main() {
  testWidgets('saved-plan feedback expires and releases later feedback',
      (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: messenger,
        home: const Scaffold(body: SizedBox())));
    messenger.currentState!
        .showSnackBar(PlanSavedSnackBar(title: 'Local Plan', onView: () {}));
    await tester.pumpAndSettle();
    messenger.currentState!
        .showSnackBar(const SnackBar(content: Text('Favorite saved')));
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Saved "Local Plan"!'), findsNothing);
    expect(find.text('Favorite saved'), findsOneWidget);
  });

  testWidgets('saved-plan View action remains usable', (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    var viewed = false;
    await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: messenger,
        home: const Scaffold(body: SizedBox())));
    messenger.currentState!.showSnackBar(
        PlanSavedSnackBar(title: 'Local Plan', onView: () => viewed = true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(viewed, isTrue);
    expect(find.text('Saved "Local Plan"!'), findsNothing);
  });
}
