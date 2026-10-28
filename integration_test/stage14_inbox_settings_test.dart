import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:whatmeal/core/models/app_notification.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/notification_service.dart';
import 'package:whatmeal/core/services/household_activity_store.dart';
import 'package:whatmeal/features/notifications/pages/notifications_page.dart';
import 'package:whatmeal/features/ai_settings/data/ai_provider_repository.dart';
import 'package:whatmeal/features/ai_settings/pages/ai_settings_page.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('local Android inbox and settings recovery', (tester) async {
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

    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty);
    await until(() => !AuthRepository.instance.isInitializing);
    expect(Firebase.app().options.projectId, 'demo-whatmeal-audit');
    await AuthRepository.instance.logout();
    await tester.pumpAndSettle();
    final ownerEmail = await register('InboxOwner');
    final ownerUid = FirebaseAuth.instance.currentUser!.uid;
    await tap(find.text('Profile'));
    await tap(find.text('Sign Out'));
    await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    final otherEmail = await register('InboxOther');
    final otherUid = FirebaseAuth.instance.currentUser!.uid;
    await tap(find.text('Profile'));
    await tap(find.text('Sign Out'));
    await tap(find.widgetWithText(ElevatedButton, 'Log Out'));
    await enter('Email Address', ownerEmail);
    await enter('Password', 'Local-fixture-123!');
    await tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await until(() => AuthRepository.instance.value?.id == ownerUid);
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final denials = <String>[];
    Stream<T> capture<T>(Stream<T> source) => source.handleError((Object e) {
          if (e is FirebaseException) denials.add(e.code);
          throw e;
        });

    await tap(find.text('Profile'));
    await tap(find.text('Family Sharing'));
    await tap(find.text('Create Space'));
    await enter('Family Space Name', 'Local Inbox Household');
    await tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Create Space')));
    await until(() => FamilyRepository.instance.value != null);
    final familyId = FamilyRepository.instance.value!.id;
    checkpoint(
        'household created through ordinary UI for authorized shared activity');
    await db
        .doc('users/$ownerUid/notifications/local-event')
        .set(AppNotification(
          id: 'local-event',
          title: 'Local inbox event',
          body: 'Local fixture',
          type: AppNotificationType.general,
          createdAt: DateTime.now(),
          navigationRoute: '/pantry',
        ).toFirestore());
    await HouseholdActivityStore(db).publish(
        familyId: familyId,
        actorUid: ownerUid,
        type: AppNotificationType.general,
        operationId: 'stage14-event');
    var denyPersonal = true;
    var denyShared = false;
    final inbox = NotificationService(
      firestore: db,
      userIds: auth.authStateChanges().map((u) => u?.uid),
      household: FamilyRepository.instance,
      watchPersonal: (uid) => capture(db
          .collection(
              'users/${denyPersonal ? 'stage14-outsider' : uid}/notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()),
      watchShared: (uid, id, joinedAt) => capture(HouseholdActivityStore(db)
          .watch(
              uid: uid,
              familyId: denyShared ? 'stage14-outsider' : id,
              joinedAt: joinedAt)),
    );
    await until(() => inbox.error != null);
    await tester
        .pumpWidget(MaterialApp(home: NotificationsPage(service: inbox)));
    await tap(find.text('Retry'));
    await until(() => inbox.error != null);
    denyPersonal = false;
    final originalSession = inbox.sessionVersion;
    await tap(find.text('Retry'));
    await until(() =>
        inbox.error == null &&
        !inbox.isLoading &&
        inbox.notifications.any((n) => n.id == 'local-event'));
    expect(inbox.sessionVersion, originalSession);
    expect(find.text('Local inbox event'), findsOneWidget);
    checkpoint(
        'personal notification SDK denial recovered through visible Retry without changing session');
    denyShared = true;
    inbox.retry();
    await until(
        () => inbox.error == 'Household notifications could not be loaded.');
    expect(inbox.notifications.any((n) => n.id == 'local-event'), true);
    denyShared = false;
    await tap(find.text('Retry'));
    await until(() =>
        inbox.error == null &&
        !inbox.isLoading &&
        inbox.notifications
            .any((n) => n.id == 'household:$familyId:stage14-event'));
    await tap(find.text('Mark all read'));
    await until(() => inbox.unreadCount == 0);
    expect(
        (await db
                .doc('users/$ownerUid/notifications/local-event')
                .get(const GetOptions(source: Source.server)))
            .data()?['read'],
        true);
    expect(
        (await db
                .doc(
                    'users/$ownerUid/notificationReceipts/household:$familyId:stage14-event')
                .get(const GetOptions(source: Source.server)))
            .data()?['read'],
        true);
    checkpoint(
        'shared SDK denial recovered and UI mark-all persisted personal read and own shared receipt');
    final staleSession = inbox.sessionVersion;
    inbox.pendingNavigation.value = {'route': '/pantry'};
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: otherEmail, password: 'Local-fixture-123!');
    await until(() =>
        AuthRepository.instance.value?.id == otherUid && !inbox.isLoading);
    expect(inbox.value, isEmpty);
    expect(inbox.pendingNavigation.value, isNull);
    await expectLater(
        inbox.markRead('local-event', expectedSession: staleSession),
        throwsStateError);
    expect(
        (await db
                .collection('users/$otherUid/notificationReceipts')
                .get(const GetOptions(source: Source.server)))
            .docs,
        isEmpty);
    checkpoint(
        'native account switch clears previous inbox and queued routing; stale read rejected');
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: ownerEmail, password: 'Local-fixture-123!');
    await until(() =>
        AuthRepository.instance.value?.id == ownerUid &&
        !inbox.isLoading &&
        inbox.notifications.any((n) => n.id == 'local-event'));
    await expectLater(
        inbox.markAllRead(expectedSession: staleSession), throwsStateError);
    expect(inbox.unreadCount, 0);
    checkpoint(
        'native A B A restores correct persisted read state while rejecting old session');
    var denySettings = true;
    final settings = AiProviderRepository(
      userIds: auth.authStateChanges().map((u) => u?.uid),
      watchConfig: (uid) => capture(db
              .doc(
                  'users/${denySettings ? 'stage14-outsider' : uid}/secrets/llmConfig')
              .snapshots())
          .map((s) => s.exists
              ? LlmConfig.fromMap(s.data()!)
              : LlmConfig.defaultConfig),
      readConfig: (uid) async {
        final doc = await db.doc('users/$uid/secrets/llmConfig').get();
        return doc.exists
            ? LlmConfig.fromMap(doc.data()!)
            : LlmConfig.defaultConfig;
      },
      saveConfig: (uid, config) =>
          db.doc('users/$uid/secrets/llmConfig').set(config.toMap()),
    );
    await until(() => settings.value.status == ApiConnectionStatus.failed);
    await tester
        .pumpWidget(MaterialApp(home: AiSettingsPage(repository: settings)));
    denySettings = false;
    await tap(find.text('Retry Settings'));
    await until(() => settings.value.status == ApiConnectionStatus.configured);
    expect(settings.value.providerType, AiProviderType.gemini);
    expect(settings.value.apiKey, isNull);
    checkpoint(
        'provider settings SDK denial recovered through visible Retry Settings without live AI call');
    settings.updateModel('local-metadata-only');
    await until(() => !settings.isSaving);
    expect(
        (await db
                .doc('users/$ownerUid/secrets/llmConfig')
                .get(const GetOptions(source: Source.server)))
            .data()?['model'],
        'local-metadata-only');
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: otherEmail, password: 'Local-fixture-123!');
    await until(() =>
        AuthRepository.instance.value?.id == otherUid &&
        settings.value.selectedModel != 'local-metadata-only');
    expect(settings.value.apiKey, isNull);
    expect(
        (await db
                .doc('users/$otherUid/secrets/llmConfig')
                .get(const GetOptions(source: Source.server)))
            .exists,
        false);
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
        email: ownerEmail, password: 'Local-fixture-123!');
    await until(() =>
        AuthRepository.instance.value?.id == ownerUid &&
        settings.value.selectedModel == 'local-metadata-only');
    checkpoint(
        'metadata-only settings persisted and remained isolated through native A B A');
    expect(denials.where((c) => c == 'permission-denied').length,
        greaterThanOrEqualTo(4));
    binding.reportData!['sdkPermissionDeniedObservations'] =
        denials.where((c) => c == 'permission-denied').length;
    await tester
        .pumpWidget(MaterialApp(home: NotificationsPage(service: inbox)));
    await until(() => !inbox.isLoading);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('notification-recovered');
    await tester.pumpWidget(const SizedBox());
    inbox.dispose();
    settings.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
