import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/pages/register_page.dart';

void main() {
  testWidgets(
      'registration preserves safe errors and permits retry without exposing exceptions',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
        MaterialApp(home: RegisterPage(register: (name, email, password) async {
      attempts++;
      if (attempts == 1) {
        throw 'This email address is already registered. Please sign in instead.';
      }
      throw StateError('secret-internal-detail');
    })));
    final fields = find.byType(TextFormField);
    for (final entry in [
      'Name',
      'test@example.test',
      'Valid-password123!',
      'Valid-password123!'
    ].asMap().entries) {
      await tester.ensureVisible(fields.at(entry.key));
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    final submit = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This email address is already registered. Please sign in instead.'),
        findsOneWidget);
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.textContaining('secret-internal-detail'), findsNothing);
  });
}
