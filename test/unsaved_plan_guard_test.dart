import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatmeal/features/meal_plan/widgets/unsaved_plan_guard.dart';

void main() {
  Future<GoRouter> openEditor(WidgetTester tester,
      {required ValueNotifier<bool> unsaved,
      required VoidCallback save}) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Planner')),
      GoRoute(
        path: '/editor',
        builder: (_, __) => ValueListenableBuilder<bool>(
          valueListenable: unsaved,
          builder: (context, dirty, _) => UnsavedPlanGuard(
            hasUnsavedPlan: dirty,
            onSave: save,
            child: Scaffold(
              appBar: AppBar(
                  leading: BackButton(
                      onPressed: () => Navigator.of(context).maybePop())),
              body: const TextField(
                  decoration: InputDecoration(labelText: 'Meal name')),
            ),
          ),
        ),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/editor');
    await tester.pumpAndSettle();
    addTearDown(router.dispose);
    addTearDown(unsaved.dispose);
    return router;
  }

  for (final systemBack in [false, true]) {
    testWidgets(
        'unsaved plan survives ${systemBack ? 'system' : 'toolbar'} back',
        (tester) async {
      var saves = 0;
      await openEditor(tester,
          unsaved: ValueNotifier(true), save: () => saves++);
      await tester.enterText(find.byType(TextField), 'My edited dinner');
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byType(BackButton));
      }
      await tester.pumpAndSettle();
      expect(find.text('Save this meal plan?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('My edited dinner'), findsOneWidget);
      expect(saves, 0);
    });
  }

  testWidgets('discard requires explicit choice and returns to planner',
      (tester) async {
    await openEditor(tester, unsaved: ValueNotifier(true), save: () {});
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Planner'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('save request keeps draft until save succeeds', (tester) async {
    var saves = 0;
    final unsaved = ValueNotifier(true);
    await openEditor(tester, unsaved: unsaved, save: () => saves++);
    await tester.enterText(find.byType(TextField), 'Retain on failed save');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Plan'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Retain on failed save'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Save this meal plan?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    unsaved.value = false;
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Planner'), findsOneWidget);
  });

  testWidgets('stale account draft cannot be saved from an open exit dialog',
      (tester) async {
    var saves = 0;
    final unsaved = ValueNotifier(true);
    await openEditor(tester, unsaved: unsaved, save: () => saves++);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    unsaved.value = false;
    await tester.pump();
    await tester.tap(find.text('Save Plan'));
    await tester.pumpAndSettle();
    expect(saves, 0);
  });
}
