import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/profile/widgets/edit_profile_sheet.dart';
import 'package:whatmeal/features/auth/pages/forgot_password_page.dart';

Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label);

Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await tester.pump();
  if (find.text('Change password?').evaluate().isNotEmpty) {
    await tester.tap(find.text('Change Password'));
    await tester.pump();
  }
}

void main() {
  testWidgets('password change preserves literal whitespace', (tester) async {
    String? current, replacement;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EditProfileSheet(
      initialName: 'Local',
      initialEmail: 'local@example.test',
      onUpdateName: (_) async {},
      onUpdatePassword: (a, b) async {
        current = a;
        replacement = b;
      },
      isSessionCurrent: () => true,
    ))));
    await fill(tester, 'Current Password', ' old value ');
    await fill(tester, 'New Password', ' new value ');
    await fill(tester, 'Confirm New Password', ' new value ');
    await save(tester);
    expect(current == ' old value ', isTrue, reason: 'Never trim passwords');
    expect(replacement == ' new value ', isTrue);
  });

  testWidgets('missing current password prevents any profile write',
      (tester) async {
    var names = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EditProfileSheet(
      initialName: 'Local',
      onUpdateName: (_) async {
        names++;
      },
      onUpdatePassword: (_, __) async {},
      isSessionCurrent: () => true,
    ))));
    await fill(tester, 'Display Name', 'Changed');
    await fill(tester, 'New Password', 'new-value');
    await fill(tester, 'Confirm New Password', 'new-value');
    await save(tester);
    expect(names, 0);
    expect(find.text('Current password is required'), findsOneWidget);
  });

  testWidgets('failed reauthentication retains draft without changing name',
      (tester) async {
    var names = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EditProfileSheet(
      initialName: 'Local',
      onUpdateName: (_) async {
        names++;
      },
      onUpdatePassword: (_, __) async {
        throw StateError('PRIVATE_DETAIL');
      },
      isSessionCurrent: () => true,
    ))));
    await fill(tester, 'Display Name', 'Changed');
    await fill(tester, 'Current Password', 'wrong-value');
    await fill(tester, 'New Password', 'new-value');
    await fill(tester, 'Confirm New Password', 'new-value');
    await save(tester);
    expect(names, 0);
    expect(find.textContaining('PRIVATE_DETAIL'), findsNothing);
    expect(tester.widget<TextField>(field('Display Name')).controller!.text,
        'Changed');
  });

  testWidgets('stale account editor cannot dispatch mutations', (tester) async {
    var writes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EditProfileSheet(
      initialName: 'Local',
      onUpdateName: (_) async {
        writes++;
      },
      onUpdatePassword: (_, __) async {
        writes++;
      },
      isSessionCurrent: () => false,
    ))));
    await fill(tester, 'Display Name', 'Changed');
    await save(tester);
    expect(writes, 0);
  });

  testWidgets('recovery form scrolls above keyboard at narrow enlarged size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: ForgotPasswordPage(onSendReset: (_) async {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Send Recovery Link'));
    expect(find.text('Send Recovery Link').hitTestable(), findsOneWidget);
  });
  testWidgets(
      'completed password change is not repeated when name save retries',
      (tester) async {
    var passwords = 0, names = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EditProfileSheet(
                initialName: 'Local',
                onUpdateName: (_) async {
                  names++;
                  if (names == 1) throw StateError('PRIVATE_DETAIL');
                },
                onUpdatePassword: (_, __) async {
                  passwords++;
                },
                isSessionCurrent: () => true))));
    await fill(tester, 'Display Name', 'Changed');
    await fill(tester, 'Current Password', 'old-value');
    await fill(tester, 'New Password', 'new-value');
    await fill(tester, 'Confirm New Password', 'new-value');
    await save(tester);
    expect(find.textContaining('Password changed.'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(field('New Password'))
            .controller!
            .text
            .isEmpty,
        isTrue);
    await save(tester);
    expect(passwords, 1);
    expect(names, 2);
  });

  testWidgets('password change cancellation dispatches no account writes',
      (tester) async {
    var writes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EditProfileSheet(
                initialName: 'Local',
                onUpdateName: (_) async {
                  writes++;
                },
                onUpdatePassword: (_, __) async {
                  writes++;
                },
                isSessionCurrent: () => true))));
    await fill(tester, 'Current Password', 'old-value');
    await fill(tester, 'New Password', 'new-value');
    await fill(tester, 'Confirm New Password', 'new-value');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
  });

  testWidgets('reset error is sanitized and retains email for successful retry',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordPage(onSendReset: (_) async {
      calls++;
      if (calls == 1) throw 'PRIVATE_DETAIL';
    })));
    await fill(tester, 'Email Address', 'local@example.test');
    await tester.ensureVisible(find.text('Send Recovery Link'));
    await tester.tap(find.text('Send Recovery Link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE_DETAIL'), findsNothing);
    expect(
        find.text('Could not send reset email. Please retry.'), findsOneWidget);
    expect(tester.widget<TextField>(field('Email Address')).controller!.text,
        'local@example.test');
    await tester.tap(find.text('Send Recovery Link'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Reset Link Sent!'), findsOneWidget);
  });
}
