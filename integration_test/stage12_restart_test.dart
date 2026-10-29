import 'package:whatmeal/features/grocery/data/grocery_repository.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/profile/models/family_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatmeal/features/profile/data/family_member_repository.dart';
import 'package:whatmeal/features/pantry/data/pantry_repository.dart';
import 'package:whatmeal/features/pantry/models/pantry_item.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/main.dart' as app;
import 'package:whatmeal/app.dart';
import 'package:whatmeal/features/auth/data/auth_repository.dart';
import 'package:whatmeal/features/auth/pages/login_page.dart';
import 'package:whatmeal/features/family/data/family_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
      'local Android persistent restart terminal listener and rapid account acceptance',
      (tester) async {
    // Flutter documents that injected editing updates can race a real IME.
    // Use deterministic test typing; this does not verify native-keyboard UX.
    // Clipboard, permissions, Android UI and Firebase SDKs remain real.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    expect(appFlavor, 'local', reason: 'Refuse any production-flavor launch');
    app.main();
    final phases = <String>[];
    binding.reportData = {'completedPhases': phases};
    void checkpoint(String phase) {
      phases.add(phase);
      debugPrint('Local UI checkpoint: $phase');
    }

    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (ready()) return;
      }
      fail('Timed out waiting for local app state');
    }

    Future<void> tap(Finder finder) async {
      // Lazy ListViews dispose controls outside the viewport. Search using
      // ordinary scrolling before waiting for an asynchronous control to appear.
      final visibleScrolls = find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .hitTestable();
      if (finder.evaluate().isEmpty && visibleScrolls.evaluate().isNotEmpty) {
        final scrollable = visibleScrolls.last;
        for (var i = 0; i < 6 && finder.evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, 400));
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
      }
      await until(() => finder.evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      // Native IME inset updates can arrive after Flutter's first settled frame.
      // Re-scroll after those updates; keep missed taps fatal rather than tapping
      // an off-screen button or dismissing unrelated Android UI.
      for (var attempt = 0;
          attempt < 20 && finder.first.hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 200));
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
      }
      if (finder.first.hitTestable().evaluate().isEmpty) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await binding.takeScreenshot('blocked-control');
      }
      expect(finder.first.hitTestable(), findsOneWidget,
          reason: 'The UI control must be visible and able to receive taps');
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    Future<void> enter(String label, String text) async {
      // Focus and settle the native keyboard before replacing a prefilled value.
      await tap(field(label));
      await tester.enterText(field(label), text);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(label)).controller?.text == text,
          isTrue,
          reason: 'Entered field must retain input; never print its value');
    }

    Future<String> register(String label) async {
      await until(() => find.byType(LoginPage).evaluate().isNotEmpty);
      await tap(find.text('Create Account'));
      final email =
          '${label.toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}@example.test';
      await enter('Full Name', label);
      await enter('Email Address', email);
      await enter('Password', 'Local-fixture-123!');
      await enter('Confirm Password', 'Local-fixture-123!');
      await tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await until(
          () => find.text('Verify Your Email Address').evaluate().isNotEmpty);
      expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
      // Obtain only the local emulator's generated email action; never bypass verification.
      const host = String.fromEnvironment('WHATMEAL_EMULATOR_HOST',
          defaultValue: '127.0.0.1');
      expect(['127.0.0.1', '10.0.2.2'], contains(host));
      final client = HttpClient();
      try {
        Map<String, dynamic>? code;
        // Auth routing can show verification before sendEmailVerification has
        // completed. Wait for the real demo action instead of assuming it exists.
        for (var attempt = 0; attempt < 100 && code == null; attempt++) {
          final request = await client.getUrl(Uri.parse(
              'http://$host:9099/emulator/v1/projects/demo-whatmeal-audit/oobCodes'));
          final response = await request.close();
          expect(response.statusCode, 200);
          final codes = (jsonDecode(await utf8.decoder.bind(response).join())
              as Map)['oobCodes'] as List;
          final matching = codes.where(
              (c) => c['email'] == email && c['requestType'] == 'VERIFY_EMAIL');
          if (matching.isNotEmpty) {
            code = matching.last as Map<String, dynamic>;
          }
          if (code == null) {
            await tester.pump(const Duration(milliseconds: 200));
          }
        }
        expect(code != null, isTrue,
            reason: 'Demo verification action must arrive within the deadline');
        await FirebaseAuth.instance.applyActionCode(code!['oobCode'] as String);
      } finally {
        client.close();
      }
      await tap(find.text("I've Verified My Email"));
      await until(() => find.text('Home').evaluate().isNotEmpty);
      checkpoint('$label registered and verified');
      return email;
    }

    Future<void> relay(String action) async {
      final client = HttpClient();
      try {
        final req =
            await client.postUrl(Uri.parse('http://10.0.2.2:8182/$action'));
        final res = await req.close();
        expect(res.statusCode, 200);
        await res.drain<void>();
      } finally {
        client.close(force: true);
      }
    }

    final prefs = await _FixturePreferences.load();
    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty);
    await until(() => !AuthRepository.instance.isInitializing);
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    final db = FirebaseFirestore.instance;
    if (prefs.getBool('stage12_ready') != true) {
      await AuthRepository.instance.logout();
      await tester.pumpAndSettle();
      final ownerEmail = await register('RestartOwner');
      final ownerUid = FirebaseAuth.instance.currentUser!.uid;
      await tap(find.text('Profile'));
      await tap(find.text('Family Sharing'));
      await tap(find.text('Create Space'));
      await enter('Family Space Name', 'Local Restart Household');
      await tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.text('Create Space')));
      await until(() => FamilyRepository.instance.value != null);
      final familyId = FamilyRepository.instance.value!.id;
      await tap(find.byIcon(Icons.arrow_back));
      await tap(find.widgetWithText(TextButton, 'Add'));
      await enter('First Name', 'Restart Child');
      await enter('Age', '8');
      await tap(find.widgetWithText(ElevatedButton, 'Add Family Member'));
      await until(() => FamilyMemberRepository.instance.members
          .any((m) => m.name == 'Restart Child'));
      await tap(find.text('Pantry'));
      await tap(find.text('Add Ingredient'));
      await enter('Ingredient Name', 'Restart Rice');
      await enter('Quantity (e.g. 1.2 kg, 4 units)', '2 kg');
      await tap(find.text('Select expiration date'));
      await tap(find.widgetWithText(TextButton, 'OK'));
      await tap(find.widgetWithText(FilledButton, 'Add to Pantry'));
      await until(() =>
          PantryRepository.instance.availableNames.contains('Restart Rice'));
      await tap(find.text('Grocery'));
      await until(() => !GroceryRepository.instance.isLoading);
      expect(GroceryRepository.instance.error, isNull);
      await tap(find.byTooltip('Add grocery item'));
      await enter('Item Name', 'Restart Milk');
      await enter('Quantity', '2 cups');
      await tap(find.widgetWithText(ElevatedButton, 'Add to List'));
      await until(() => GroceryRepository.instance.allItems
          .any((i) => i.name == 'Restart Milk'));
      await db.waitForPendingWrites();
      checkpoint(
          'owner household pantry and dietary profile created through UI');
      Future<void> logout() async {
        await tap(find.text('Profile'));
        await tap(find.text('Sign Out'));
        await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
        await until(() => find.byType(LoginPage).evaluate().isNotEmpty);
      }

      await logout();
      final otherEmail = await register('RestartOther');
      final otherUid = FirebaseAuth.instance.currentUser!.uid;
      await logout();
      await enter('Email Address', ownerEmail);
      await enter('Password', 'Local-fixture-123!');
      await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await until(() => FamilyRepository.instance.value?.id == familyId);
      await tap(find.text('Pantry'));
      await until(() => find.text('Restart Rice').evaluate().isNotEmpty);
      await tap(find.text('Profile'));
      await tester.scrollUntilVisible(find.text('Restart Child'), 200,
          scrollable: find
              .byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down)
              .hitTestable()
              .last);
      await until(() => find.text('Restart Child').evaluate().isNotEmpty);
      await db
          .doc('families/$familyId')
          .get(const GetOptions(source: Source.server));
      await prefs.setString('stage12_owner', ownerEmail);
      await prefs.setString('stage12_other', otherEmail);
      await prefs.setString('stage12_owner_uid', ownerUid);
      await prefs.setString('stage12_other_uid', otherUid);
      await prefs.setString('stage12_family', familyId);
      await prefs.setBool('stage12_ready', true);
      checkpoint(
          'both demo accounts created; owner data and native session ready for process restart');
      binding.reportData!['mode'] = 'prepare';
      return;
    }
    binding.reportData!['mode'] = 'offline-restart';
    final uid = prefs.getString('stage12_owner_uid')!;
    final familyId = prefs.getString('stage12_family')!;
    expect(FirebaseAuth.instance.currentUser?.uid == uid, isTrue,
        reason: 'Native Auth session must survive process death');
    await until(() => FamilyRepository.instance.value?.id == familyId);
    await tap(find.text('Pantry'));
    await until(() => find.text('Restart Rice').evaluate().isNotEmpty);
    expect(PantryRepository.instance.scopePath, 'families/$familyId');
    await tap(find.text('Profile'));
    await tester.scrollUntilVisible(find.text('Restart Child'), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .hitTestable()
            .last);
    await until(() => find.text('Restart Child').evaluate().isNotEmpty);
    final cached = await db
        .doc('families/$familyId')
        .get(const GetOptions(source: Source.cache));
    expect(cached.metadata.isFromCache, isTrue);
    await tap(find.text('Grocery'));
    await until(() => find.text('Restart Milk').evaluate().isNotEmpty);
    expect(GroceryRepository.instance.error, isNull);
    checkpoint(
        'Firestore offline process restart restored Auth household pantry grocery and profile cache through UI');
    await relay('online');
    var connected = false;
    for (var i = 0; i < 45 && !connected; i++) {
      try {
        await db
            .doc('families/$familyId')
            .get(const GetOptions(source: Source.server));
        connected = true;
      } on FirebaseException catch (e) {
        expect(e.code, 'unavailable');
        await tester.pump(const Duration(seconds: 1));
      }
    }
    expect(connected, isTrue);
    checkpoint(
        'authorized server read confirmed reconnect after offline restart');
    // Request a forbidden demo path for a real terminal SDK error. A new
    // subscription then uses the authorized household path; rules stay intact.
    final household =
        ValueNotifier<FamilySpace?>(FamilyRepository.instance.value);
    final denialCodes = <String>[];
    var pantryWatches = 0;
    var profileWatches = 0;
    Stream<List<T>> watch<T>(
            String path,
            T Function(DocumentSnapshot<Map<String, dynamic>>) decode,
            bool denied) =>
        db
            .collection(denied
                ? 'users/stage12-forbidden-outsider/${path.split('/').last}'
                : path)
            .snapshots()
            .handleError((Object e) {
          if (e is FirebaseException) denialCodes.add(e.code);
          throw e;
        }).map((s) => s.docs.map(decode).toList());
    final pantry = PantryRepository(
        firestore: db,
        authIds: Stream.value(uid),
        household: household,
        watch: (p) => watch(p, PantryItem.fromFirestore, pantryWatches++ == 0));
    final profiles = FamilyMemberRepository(
        firestore: db,
        authIds: Stream.value(uid),
        household: household,
        watch: (p) =>
            watch(p, FamilyMember.fromFirestore, profileWatches++ == 0));
    await until(() => pantry.error != null && profiles.error != null);
    expect(denialCodes, ['permission-denied', 'permission-denied']);
    expect(pantry.value, isEmpty);
    expect(profiles.value, isEmpty);
    pantry.retry();
    profiles.retry();
    await until(() =>
        pantry.availableNames.contains('Restart Rice') &&
        profiles.members.any((m) => m.name == 'Restart Child'));
    expect(pantry.error, isNull);
    expect(profiles.error, isNull);
    expect(pantryWatches, 2);
    expect(profileWatches, 2);
    pantry.dispose();
    profiles.dispose();
    household.dispose();
    checkpoint(
        'actual SDK terminal permission denials cleared feeds; explicit resubscription restored authorized data');
    final auth = FirebaseAuth.instance;
    for (var cycle = 0; cycle < 3; cycle++) {
      await auth.signOut();
      await until(() => AuthRepository.instance.value == null);
      expect(PantryRepository.instance.value, isEmpty);
      expect(FamilyMemberRepository.instance.value, isEmpty);
      await auth.signInWithEmailAndPassword(
          email: prefs.getString('stage12_other')!,
          password: 'Local-fixture-123!');
      await until(() =>
          AuthRepository.instance.value?.id ==
          prefs.getString('stage12_other_uid'));
      expect(PantryRepository.instance.availableNames,
          isNot(contains('Restart Rice')));
      expect(
          FamilyMemberRepository.instance.members
              .where((m) => m.name == 'Restart Child'),
          isEmpty);
      expect(FamilyRepository.instance.value, isNull);
      await auth.signOut();
      await auth.signInWithEmailAndPassword(
          email: prefs.getString('stage12_owner')!,
          password: 'Local-fixture-123!');
      await until(() =>
          FamilyRepository.instance.value?.id == familyId &&
          PantryRepository.instance.availableNames.contains('Restart Rice'));
      await until(() => FamilyMemberRepository.instance.members
          .any((m) => m.name == 'Restart Child'));
    }
    await tap(find.text('Profile'));
    await tester.scrollUntilVisible(find.text('Restart Child'), 200,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .hitTestable()
            .last);
    await until(() => find.text('Restart Child').evaluate().isNotEmpty);
    checkpoint(
        'three rapid native SDK A logout B logout A cycles isolated data and recovered owner UI');
    await prefs.remove('stage12_ready');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

// Only disposable local fixture identifiers, never credentials or action tokens.
class _FixturePreferences {
  _FixturePreferences(this.file, this.values);
  final File file;
  final Map<String, dynamic> values;
  static Future<_FixturePreferences> load() async {
    final file = File(
        '/data/user/0/com.example.whatmeal.local/files/stage12_fixture.json');
    return _FixturePreferences(
        file,
        await file.exists()
            ? Map<String, dynamic>.from(
                jsonDecode(await file.readAsString()) as Map)
            : {});
  }

  bool? getBool(String key) => values[key] as bool?;
  String? getString(String key) => values[key] as String?;
  Future<void> setString(String key, String value) async {
    values[key] = value;
    await file.writeAsString(jsonEncode(values), flush: true);
  }

  Future<void> setBool(String key, bool value) async {
    values[key] = value;
    await file.writeAsString(jsonEncode(values), flush: true);
  }

  Future<void> remove(String key) async {
    values.remove(key);
    await file.writeAsString(jsonEncode(values), flush: true);
  }
}
