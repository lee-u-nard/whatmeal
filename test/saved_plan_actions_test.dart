import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/meal_plan/widgets/saved_plan_actions.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('saved plan actions fit narrow card at scale $scale',
        (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
            child: SizedBox(
                width: 246,
                child: SavedPlanActions(
                    onDelete: () => actions.add('delete'),
                    onReuse: () => actions.add('reuse'),
                    onLoad: () => actions.add('load')))),
      ))));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Delete'));
      await tester.tap(find.text('Reuse'));
      await tester.tap(find.text('Load Plan'));
      expect(actions, ['delete', 'reuse', 'load']);
    });
  }
}
