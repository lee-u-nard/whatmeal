import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/grocery/widgets/grocery_toolbar.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('grocery count and actions fit narrow screen at scale $scale',
        (tester) async {
      var shared = false;
      var cleared = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
            child: SizedBox(
                width: 280,
                child: GroceryToolbar(
                    remainingCount: 2,
                    onShare: () => shared = true,
                    onClearUsed: () => cleared = true))),
      ))));
      expect(tester.takeException(), isNull);
      expect(find.text('2 remaining items'), findsOneWidget);
      await tester.tap(find.text('Share List'));
      await tester.tap(find.text('Clear Used'));
      expect(shared && cleared, isTrue);
    });
  }
}
