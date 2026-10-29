import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/profile/widgets/profile_headings.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('profile headings fit narrow cards at text scale $scale',
        (tester) async {
      var added = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Column(children: [
          SizedBox(
              width: 280,
              child: FamilyProfilesHeading(onAdd: () => added = true)),
          const SizedBox(
              width: 104,
              child: ProfileSettingsIdentity(
                  icon: Icons.groups,
                  badgeText: 'Create/Join',
                  color: Colors.white,
                  iconColor: Colors.green)),
        ]),
      ))));
      expect(tester.takeException(), isNull);
      expect(
          find.text('Family Profiles & Dietary Preferences'), findsOneWidget);
      expect(find.text('Create/Join'), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(added, isTrue);
    });
  }
}
