import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';
import 'package:whatmeal/features/family/pages/family_space_page.dart';
import 'package:whatmeal/features/grocery/widgets/grocery_item_editor.dart';
import 'package:whatmeal/features/pantry/widgets/add_pantry_item_sheet.dart';
import 'package:whatmeal/features/profile/widgets/add_edit_family_member_sheet.dart';
import 'package:whatmeal/features/profile/widgets/edit_profile_sheet.dart';

void configureView(WidgetTester tester, double keyboard) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
  tester.view.padding =
      FakeViewPadding(top: 24, bottom: keyboard == 0 ? 48 : 0);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Widget application(Widget home) => MaterialApp(
    builder: (context, child) => MediaQuery(
        data:
            MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.6)),
        child: child!),
    home: home);

Future<void> checkButton(
    WidgetTester tester, Finder button, double keyboard) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(button.hitTestable(), findsOneWidget);
  final bounds = tester.getRect(button);
  expect(
      bounds.bottom, lessThanOrEqualTo(640 - (keyboard == 0 ? 48 : keyboard)),
      reason: 'Entire button must avoid the system navigation bar or keyboard');
}

void main() {
  for (final keyboard in [0.0, 240.0]) {
    for (final kind in ['pantry', 'grocery', 'profile', 'dietary']) {
      testWidgets('$kind editor avoids system bars with keyboard $keyboard',
          (tester) async {
        configureView(tester, keyboard);
        final sheet = switch (kind) {
          'pantry' => const AddPantryItemSheet(),
          'grocery' => GroceryItemEditor(onSave: (_) async {}),
          'profile' => EditProfileSheet(
              initialName: 'Local account',
              initialEmail: 'local@example.test',
              isSessionCurrent: () => true,
              onUpdateName: (_) async {},
              onUpdatePassword: (_, __) async {}),
          _ => const AddEditFamilyMemberSheet(),
        };
        await tester.pumpWidget(application(Scaffold(
            body: Builder(
          builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => sheet),
              child: const Text('Open editor')),
        ))));
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        final label = switch (kind) {
          'pantry' => 'Add to Pantry',
          'grocery' => 'Add to List',
          'profile' => 'Save Changes',
          _ => 'Add Family Member',
        };
        final button = find.ancestor(
            of: find.text(label),
            matching: find
                .byWidgetPredicate((widget) => widget is ButtonStyleButton));
        await checkButton(tester, button, keyboard);
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final create in [true, false]) {
      testWidgets(
          'household ${create ? 'create' : 'join'} avoids bars with keyboard $keyboard',
          (tester) async {
        configureView(tester, 0);
        final account = ValueNotifier<UserModel?>(null);
        final repo = FamilyRepository(
            firestore: FakeFirebaseFirestore(),
            authIds: const Stream.empty(),
            account: account);
        addTearDown(() {
          repo.dispose();
          account.dispose();
        });
        await tester.pumpWidget(application(FamilySpacePage(repository: repo)));
        await tester.pumpAndSettle();
        final opener = find.text(create ? 'Create Space' : 'Join with Key');
        await tester.ensureVisible(opener);
        await tester.pumpAndSettle();
        await tester.tap(opener);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        tester.view.padding =
            FakeViewPadding(top: 24, bottom: keyboard == 0 ? 48 : 0);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        final label = create ? 'Create Space' : 'Join Family Space';
        final button = find.widgetWithText(ElevatedButton, label).last;
        await checkButton(tester, button, keyboard);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
