import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'core/config/ai_test_environment.dart';
import 'core/services/ai/adapters/gemini_adapter.dart';
import 'core/services/ai/ai_json_parser.dart';
import 'core/services/ai/ai_models.dart';
import 'core/services/ai/generation_failure.dart';
import 'core/services/ai/model_registry.dart';
import 'core/theme/app_theme.dart';

// Process-scoped, rather than widget-scoped: rebuilding the page cannot reset
// its two-attempt budget. No prompt or call occurs until the user taps.
final _requestBudget = AiTestRequestBudget();

const _syntheticRequest = AiMealPlanRequest(
  familyMemberNames: ['Synthetic adult one', 'Synthetic adult two'],
  memberAges: {'Synthetic adult one': 30, 'Synthetic adult two': 30},
  numberOfDays: 1,
  mealTypes: ['Dinner'],
  pantryItems: ['Rice', 'Carrot'],
  restrictions: ['Peanut'],
  cuisinePreferences: ['Filipino'],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AiTestEnvironment.requireLaunch(
      actualFlavor: appFlavor,
      isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      isDebug: kDebugMode,
      useEmulators: const bool.fromEnvironment('WHATMEAL_EMULATORS'),
    );
    // Only the aitest variant's native configuration is used. This entry point
    // does not import the normal app or its production Firebase options.
    final app = await Firebase.initializeApp();
    AiTestEnvironment.requireIdentity(
      actualProjectId: app.options.projectId,
      actualAppId: app.options.appId,
      actualProjectNumber: app.options.messagingSenderId,
    );
    final appCheck = FirebaseAppCheck.instanceFor(app: app);
    await appCheck.activate(androidProvider: AndroidProvider.debug);
    runApp(_AiTestApp(app: app, appCheck: appCheck));
  } catch (_) {
    runApp(const _AiTestApp(
      startupError:
          'AI test setup was rejected. Check the approved debug build and native Firebase configuration.',
    ));
  }
}

class _AiTestApp extends StatelessWidget {
  const _AiTestApp({this.app, this.appCheck, this.startupError});

  final FirebaseApp? app;
  final FirebaseAppCheck? appCheck;
  final String? startupError;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WhatMeal AI Test',
        theme: AppTheme.lightTheme,
        home: _AiTestPage(
          app: app,
          appCheck: appCheck,
          startupError: startupError,
        ),
      );
}

class _AiTestPage extends StatefulWidget {
  const _AiTestPage({this.app, this.appCheck, this.startupError});

  final FirebaseApp? app;
  final FirebaseAppCheck? appCheck;
  final String? startupError;

  @override
  State<_AiTestPage> createState() => _AiTestPageState();
}

class _AiTestPageState extends State<_AiTestPage> {
  bool _busy = false;
  String? _failure;
  AiMealResponse? _meal;

  Future<void> _generate() async {
    if (_busy || !_requestBudget.canRequest || widget.startupError != null) {
      return;
    }
    final app = widget.app;
    final appCheck = widget.appCheck;
    if (app == null || appCheck == null) return;
    _requestBudget.claim();
    setState(() {
      _busy = true;
      _failure = null;
      _meal = null;
    });
    try {
      // An enforced App Check failure stops here; no bypass or fallback is used.
      // Native debug-token registration is performed separately and privately.
      final token =
          await appCheck.getToken().timeout(const Duration(seconds: 20));
      if (token == null || token.isEmpty) {
        throw const GenerationFailure(GenerationFailureKind.configuration);
      }
      final model =
          FirebaseAI.googleAI(app: app, appCheck: appCheck).generativeModel(
        model: AiModelRegistry.defaultGemini,
        generationConfig: GenerationConfig(
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
      );
      final response = await model.generateContent([
        Content.text(_syntheticRequest.buildPrompt()),
      ]).timeout(const Duration(seconds: 60));
      final text = GeminiAdapter.firebaseText(response);
      final meals = AiJsonParser.parseMealList(text);
      _syntheticRequest.validateMeals(meals);
      if (!mounted) return;
      setState(() => _meal = meals.single);
    } catch (error) {
      // SDK exceptions can echo URLs or tokens. Only fixed classified messages
      // may reach the page; no raw errors, prompts, or tokens are logged.
      final failure = GenerationFailure.from(error);
      if (!mounted) return;
      setState(() => _failure = '${failure.kind.name}: $failure');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = _meal;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatMeal AI Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Separate Firebase Spark test',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const SelectableText('Project: ${AiTestEnvironment.projectId}'),
            const Text('Model: ${AiModelRegistry.defaultGemini}'),
            const SizedBox(height: 16),
            const Text(
                'Synthetic fixture only: two adults, one dinner, rice and carrot in the pantry, peanut restriction. No household account or saved data is used.'),
            const SizedBox(height: 8),
            const Text(
                'This makes a real Gemini request. Nothing is generated automatically. Maximum two attempts per app session; failures also count. Results stay on this screen.'),
            const SizedBox(height: 16),
            Text(
                'Live attempts: ${_requestBudget.attempts}/${AiTestRequestBudget.maximum}'),
            const SizedBox(height: 8),
            if (widget.startupError != null)
              Text(widget.startupError!,
                  key: const ValueKey('ai-startup-error')),
            FilledButton(
              key: const ValueKey('generate-live-test-meal'),
              onPressed: _busy ||
                      !_requestBudget.canRequest ||
                      widget.startupError != null
                  ? null
                  : _generate,
              child: Text(_busy ? 'Generating…' : 'Generate one test dinner'),
            ),
            if (_busy)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )),
            if (_failure != null)
              Semantics(
                liveRegion: true,
                child: Text(_failure!, key: const ValueKey('ai-live-error')),
              ),
            if (!_requestBudget.canRequest && !_busy)
              const Text(
                  'Session limit reached. Relaunch deliberately for another session.'),
            if (meal != null) ...[
              const SizedBox(height: 16),
              const Text('Live response passed structural and fixture checks.',
                  key: ValueKey('ai-live-success')),
              const Text(
                  'This is not a food-safety or nutrition certification. Review the recipe and allergens before using it.'),
              const SizedBox(height: 12),
              SelectableText(meal.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (meal.servings != null) Text('Servings: ${meal.servings}'),
              const SizedBox(height: 8),
              for (final ingredient in meal.ingredients)
                Text('${ingredient.amount} ${ingredient.name}'),
              const SizedBox(height: 8),
              for (var i = 0; i < meal.instructions.length; i++)
                Text('${i + 1}. ${meal.instructions[i]}'),
            ],
          ],
        ),
      ),
    );
  }
}
