import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/widgets/labeled_action_row.dart';
import 'package:whatmeal/features/meal_plan/widgets/meal_participant_tile.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';
import 'package:whatmeal/features/profile/pages/profile_page.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('profile card keeps long name and actions visible at $scale',
        (tester) async {
      var edited = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
            child: SizedBox(
                width: 280,
                child: FamilyMemberCard(
                    member: const FamilyMember(
                        name: 'Local Participant',
                        age: 30,
                        preferences: [],
                        restrictions: []),
                    onEdit: () => edited = true,
                    onDelete: () {}))),
      ))));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Member actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Profile'));
      expect(edited, isTrue);
    });

    testWidgets('pantry explanation wraps beside usable switch at $scale',
        (tester) async {
      var changed = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
            child: SizedBox(
                width: 250,
                child: LabeledActionRow(
                    label: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prioritize Pantry',
                              style: TextStyle(fontSize: 14)),
                          Text('Use ingredients already available first',
                              style: TextStyle(fontSize: 11)),
                        ]),
                    action: Switch(
                        value: false, onChanged: (_) => changed = true)))),
      ))));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Switch));
      expect(changed, isTrue);
    });

    testWidgets('participant selection paints above card background at $scale',
        (tester) async {
      bool? selected;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Center(
            child: Container(
                width: 280,
                color: Colors.white,
                child: MealParticipantTile(
                    name: 'Local Participant',
                    restrictions: const ['No Peanuts'],
                    selected: false,
                    onChanged: (value) => selected = value))),
      ))));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Local Participant'));
      expect(selected, isTrue);
    });
  }
}
