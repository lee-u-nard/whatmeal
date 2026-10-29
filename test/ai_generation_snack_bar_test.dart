import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatmeal/core/models/llm_config.dart';
import 'package:whatmeal/core/services/llm_service.dart';
import 'package:whatmeal/core/theme/app_theme.dart';
import 'package:whatmeal/core/widgets/ai_generation_snack_bar.dart';

void main() {
  Future<GlobalKey<ScaffoldMessengerState>> host(WidgetTester tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messenger,
      home: const Scaffold(body: SizedBox()),
    ));
    return messenger;
  }

  testWidgets('normal result identifies actual provider and exact model ID',
      (tester) async {
    final messenger = await host(tester);
    final result = AiResult<List<String>>(
      data: const ['synthetic meal'],
      providerUsed: LlmProvider.groq,
      modelUsed: 'openai/gpt-oss-20b',
    );
    messenger.currentState!.showSnackBar(AiGenerationSnackBar(result: result));
    await tester.pumpAndSettle();
    expect(
        find.text('Generated with Groq (openai/gpt-oss-20b).'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        AppColors.primary);
    expect(find.textContaining('selected AI provider failed'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'replacement fallback preserves success and discloses actual identity',
      (tester) async {
    final messenger = await host(tester);
    // Saved selection has changed or failed; it is not evidence of fulfillment.
    final selected =
        LlmConfig(provider: LlmProvider.groq, model: 'openai/gpt-oss-120b');
    final result = AiResult<String>(
      data: 'synthetic replacement',
      usedFallback: true,
      providerUsed: LlmProvider.gemini,
      modelUsed: 'gemini-exact-requested-alias',
    );
    const success =
        'Rice replaced with "Vegetable bowl". Status is now Pending.';
    messenger.currentState!.showSnackBar(
        AiGenerationSnackBar(result: result, successMessage: success));
    await tester.pumpAndSettle();
    expect(find.textContaining(success), findsOneWidget);
    expect(find.textContaining(result.fallbackNotice!), findsOneWidget);
    expect(find.textContaining('Gemini (gemini-exact-requested-alias)'),
        findsOneWidget);
    expect(find.textContaining(selected.model!), findsNothing);
    expect(find.textContaining('Generated with Groq'), findsNothing);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        AppColors.warning);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing provider metadata does not invent the saved provider',
      (tester) async {
    final messenger = await host(tester);
    final result =
        AiResult<String>(data: 'synthetic', modelUsed: 'exact-model-id');
    messenger.currentState!.showSnackBar(AiGenerationSnackBar(
        result: result,
        successMessage: 'Meal replaced with "Soup". Status is now Pending.'));
    await tester.pumpAndSettle();
    expect(find.textContaining('an unidentified AI provider (exact-model-id)'),
        findsOneWidget);
    expect(find.textContaining('Gemini'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'generation disclosure expires and allows later operation feedback',
      (tester) async {
    final messenger = await host(tester);
    final result = AiResult<String>(
        data: 'synthetic',
        providerUsed: LlmProvider.openai,
        modelUsed: 'exact-model-id');
    messenger.currentState!.showSnackBar(AiGenerationSnackBar(result: result));
    await tester.pumpAndSettle();
    messenger.currentState!
        .showSnackBar(const SnackBar(content: Text('Favorite saved')));
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.textContaining('Generated with'), findsNothing);
    expect(find.text('Favorite saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
