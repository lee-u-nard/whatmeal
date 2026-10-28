import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/family/widgets/member_identity.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('member name and role wrap at narrow width, scale $scale',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const Center(
            child: SizedBox(
                width: 190,
                child: MemberIdentity(
                    name: 'A household member with a long name',
                    role: 'Household Admin',
                    roleBackground: Colors.white,
                    roleColor: Colors.green))),
      ))));
      expect(tester.takeException(), isNull);
      expect(find.text('A household member with a long name'), findsOneWidget);
      expect(find.text('Household Admin'), findsOneWidget);
    });
  }
}
