import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whatmeal/app.dart';
import 'package:whatmeal/core/config/runtime_environment.dart';
import 'package:whatmeal/core/services/ai/generation_failure.dart';
import 'package:whatmeal/features/ai_settings/data/ai_provider_repository.dart';
import 'package:whatmeal/features/ai_settings/models/ai_provider.dart';
import 'package:whatmeal/features/ai_settings/pages/ai_settings_page.dart';
import 'package:whatmeal/features/auth/data/auth_repository.dart';
import 'package:whatmeal/features/auth/pages/login_page.dart';
import 'package:whatmeal/main.dart' as app;

/// Real Android widgets + Auth/Firestore emulator SDKs; no live AI calls.
/// Credentials come from an ignored --dart-define-from-file, never this file.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('showcase provider settings persist and isolate demo accounts',
      (tester) async {
    expect(appFlavor, 'showcase', reason: 'Only the separate demo may run.');
    expect(useFirebaseEmulators, isTrue);
    const credentials = {
      'owner': (
        email: String.fromEnvironment('DEMO_OWNER_EMAIL'),
        password: String.fromEnvironment('DEMO_OWNER_PASSWORD'),
      ),
      'member': (
        email: String.fromEnvironment('DEMO_MEMBER_EMAIL'),
        password: String.fromEnvironment('DEMO_MEMBER_PASSWORD'),
      ),
    };
    for (final account in credentials.values) {
      expect(account.email.endsWith('@example.test'), isTrue,
          reason: 'Only disposable local demo accounts are permitted.');
      expect(account.password.isNotEmpty, isTrue,
          reason: 'Supply the private demo defines file.');
    }
    final phases = <String>[];
    binding.reportData = {
      'completedPhases': phases,
      'authMethod': 'real emulator SDK switching; settings via routed UI',
      'liveAiCalled': false,
      'configurationRestored': false,
    };
    void checkpoint(String phase) {
      phases.add(phase);
      debugPrint('Provider settings local checkpoint: $phase');
    }

    Future<void> until(bool Function() ready, String stage) async {
      for (var attempt = 0; attempt < 150; attempt++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (ready()) return;
      }
      fail('Timed out during $stage. No failure was dismissed.');
    }

    Future<void> reveal(Finder finder) async {
      // Lazy settings sections require actual scrolling before they exist.
      for (final direction in [350.0, -350.0]) {
        for (var i = 0;
            i < 16 &&
                finder.evaluate().isEmpty &&
                find.byType(Scrollable).evaluate().isNotEmpty;
            i++) {
          await tester.drag(find.byType(Scrollable).last, Offset(0, direction));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      await until(() => finder.evaluate().isNotEmpty, 'locating a UI control');
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
      expect(finder.first.hitTestable(), findsOneWidget,
          reason: 'The control must be visible and able to receive taps.');
    }

    Future<void> tap(Finder finder) async {
      await reveal(finder);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 250));
    }

    app.main();
    await until(() => find.byType(WhatMealApp).evaluate().isNotEmpty,
        'local application startup');
    expect(Firebase.app().options.projectId == 'demo-whatmeal-showcase', isTrue,
        reason: 'Refuse any other Firebase project.');
    final auth = AuthRepository.instance;
    final repo = AiProviderRepository.instance;
    final originals = <String, ({String uid, Map<String, dynamic>? data})>{};
    DocumentReference<Map<String, dynamic>> configRef() =>
        FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('secrets')
            .doc('llmConfig');

    Future<void> login(String role) async {
      await until(() => !auth.isInitializing, 'profile synchronization');
      await auth.logout();
      await until(() => find.byType(LoginPage).evaluate().isNotEmpty,
          'local signed-out route');
      final account = credentials[role]!;
      try {
        await auth.login(account.email, account.password);
      } catch (_) {
        fail('Disposable demo sign-in failed; private details withheld.');
      }
      await until(
          () =>
              !auth.isInitializing &&
              auth.isAuthenticated &&
              find.text('Home').evaluate().isNotEmpty,
          'local signed-in route');
      await until(() => !repo.isSaving, 'provider settings write queue');
    }

    Future<void> settings() async {
      await tap(find.text('Profile'));
      await tap(find.text('AI Settings'));
      await until(() => find.byType(AiSettingsPage).evaluate().isNotEmpty,
          'routed AI settings');
    }

    Future<void> writesDone() async {
      await until(() => !repo.isSaving, 'provider settings persistence');
      expect(repo.value.status != ApiConnectionStatus.failed, isTrue,
          reason: 'Do not continue after a failed settings write.');
    }

    try {
      // Read the exact prior document under each account's own permissions.
      for (final role in ['owner', 'member']) {
        await login(role);
        final snapshot =
            await configRef().get(const GetOptions(source: Source.server));
        originals[role] = (
          uid: FirebaseAuth.instance.currentUser!.uid,
          data: snapshot.data()
        );
      }
      checkpoint('both disposable account configurations saved in memory');
      await login('owner');
      await settings();
      await tap(find.text(AiProviderType.gemini.displayName));
      await writesDone();
      final alternate = AiProviderType.gemini.availableModels
          .firstWhere((model) => model != AiProviderType.gemini.defaultModel);
      await tap(find.byType(DropdownButtonFormField<String>));
      final choice = find.byWidgetPredicate((widget) =>
          widget is DropdownMenuItem<String> && widget.value == alternate);
      await tap(choice.last);
      await until(() => repo.value.selectedModel == alternate && !repo.isSaving,
          'saving the explicit Gemini model');
      final stored =
          await configRef().get(const GetOptions(source: Source.server));
      expect(stored.data()?['model'] == alternate, isTrue);
      await tap(find.byIcon(Icons.arrow_back));
      await tap(find.text('AI Settings'));
      await until(() => find.byType(AiSettingsPage).evaluate().isNotEmpty,
          'reopening saved provider settings');
      await reveal(find.byType(DropdownButtonFormField<String>));
      expect(
          tester
                  .widget<DropdownButtonFormField<String>>(
                      find.byType(DropdownButtonFormField<String>))
                  .initialValue ==
              alternate,
          isTrue);
      checkpoint(
          'explicit Gemini model persisted and reopened through Android UI');
      await tap(find.text('Test Connection'));
      await until(() => repo.value.status != ApiConnectionStatus.testing,
          'local-only connection feedback');
      expect(repo.value.status, ApiConnectionStatus.providerUnavailable);
      final localOnlyMessage = find.text(
          const GenerationFailure(GenerationFailureKind.localOnly).toString());
      await reveal(localOnlyMessage);
      expect(localOnlyMessage, findsOneWidget);
      checkpoint(
          'Gemini connection action reported local-only policy without live AI');

      // Change accounts while settings was open; the routed page must leave.
      final oldSession = repo.sessionRevision;
      await login('member');
      expect(repo.sessionRevision != oldSession, isTrue);
      expect(find.byType(AiSettingsPage), findsNothing);
      final memberBefore =
          await configRef().get(const GetOptions(source: Source.server));
      expect(mapEquals(memberBefore.data(), originals['member']!.data), isTrue,
          reason: 'Owner edits must not change the member settings document.');
      await settings();
      await tap(find.text(AiProviderType.groq.displayName));
      await writesDone();
      expect(repo.value.apiKey == null, isTrue);
      expect(repo.value.status, ApiConnectionStatus.notConfigured);
      await tap(find.text('Test Connection'));
      await until(() => repo.value.status != ApiConnectionStatus.testing,
          'missing-key provider feedback');
      expect(repo.value.status == ApiConnectionStatus.connected, isFalse);
      expect(repo.value.status, ApiConnectionStatus.providerUnavailable);
      checkpoint(
          'member Groq missing-key configuration never claimed a connection');
      // Empty Save Key opens the real reset confirmation without inventing a key.
      await tap(find.text('Save Key'));
      await until(() => find.text('Remove API Key').evaluate().isNotEmpty,
          'provider removal confirmation');
      await tap(find.text('Remove Key'));
      await until(
          () =>
              repo.value.providerType == AiProviderType.gemini &&
              !repo.isSaving,
          'restoring default Gemini through UI');
      expect(repo.value.apiKey == null, isTrue);
      expect(repo.value.selectedModel == AiProviderType.gemini.defaultModel,
          isTrue);
      checkpoint(
          'confirmed provider removal restored the default Gemini configuration');
      await login('owner');
      await until(() => repo.value.selectedModel == alternate,
          'owner settings after account switch');
      expect(repo.value.providerType, AiProviderType.gemini);
      checkpoint(
          'owner model survived independent member edits and account switching');
    } finally {
      var failures = 0;
      final restorationErrors = <String>[];
      for (final role in ['member', 'owner']) {
        final original = originals[role];
        if (original == null) continue;
        try {
          await login(role);
          expect(
              FirebaseAuth.instance.currentUser?.uid == original.uid, isTrue);
          if (original.data == null) {
            await configRef().delete();
          } else {
            await configRef().set(original.data!);
          }
          final restored =
              await configRef().get(const GetOptions(source: Source.server));
          expect(mapEquals(restored.data(), original.data), isTrue,
              reason: 'Restore the exact prior demo settings document.');
        } catch (error) {
          failures++;
          restorationErrors.add('$role:${error.runtimeType}'
              '${error is FirebaseException ? ':${error.code}' : ''}');
        }
      }
      binding.reportData!['configurationRestored'] = failures == 0;
      binding.reportData!['restorationFailures'] = failures;
      binding.reportData!['restorationErrors'] = restorationErrors;
      if (failures != 0) {
        fail(
            'Demo settings restoration failed. Preserve backend state and inspect the recorded checkpoint.');
      }
      if (originals.containsKey('owner')) {
        await until(() => find.text('Home').evaluate().isNotEmpty,
            'final owner home screen');
        checkpoint(
            'both original demo settings restored exactly; owner signed in');
      }
    }
  });
}
