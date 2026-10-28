import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/services/unsplash_service.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal/widgets/meal_network_image.dart';
import 'package:whatmeal/features/meal_plan/models/saved_meal_plan.dart';
import 'package:whatmeal/features/meal_plan/pages/generated_meal_plan_page.dart';

Map<String, String> meal(String name, String id) => {
      'strMeal': name,
      'strMealThumb': 'https://www.themealdb.com/images/media/meals/$id.jpg',
    };

void main() {
  test('actual dish title overrides an unrelated generated search query',
      () async {
    final service = UnsplashService(
        useCommons: false,
        accessKey: '',
        client: MockClient((request) async {
          expect(request.url.queryParameters['s'], 'Chicken Adobo');
          return http.Response(
              jsonEncode({
                'meals': [meal('Chicken Adobo', 'adobo')]
              }),
              200);
        }));
    final image =
        await service.fetchMealImage('pizza', mealTitle: 'Chicken Adobo');
    expect(image?.smallUrl, endsWith('/adobo.jpg'));
  });

  test('search selects exact dish instead of the first unrelated result',
      () async {
    final service = UnsplashService(
        useCommons: false,
        accessKey: '',
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'meals': [
                meal('Beef Adobo', 'beef'),
                meal('Chicken Adobo', 'chicken')
              ]
            }),
            200)));
    expect((await service.fetchMealImage('Chicken Adobo'))?.smallUrl,
        endsWith('/chicken.jpg'));
  });

  test(
      'vegan qualifiers are preserved and unrelated results never become fallback',
      () async {
    var requests = 0;
    final service = UnsplashService(
        useCommons: false,
        accessKey: '',
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['s'], 'Vegan chicken curry');
          return http.Response(
              jsonEncode({
                'meals': [meal('Chicken Curry', 'chicken')]
              }),
              200);
        }));
    expect(await service.fetchMealImage('Vegan chicken curry'), isNull);
    expect(requests, 1); // No lossy shortened retry or random image pool.
    expect(UnsplashService.syncFoodUrl('Vegan chicken curry'), isEmpty);
  });

  test('unknown dish has no invented fallback and can recover after a failure',
      () async {
    var attempts = 0;
    final service = UnsplashService(
        useCommons: false,
        accessKey: '',
        client: MockClient((_) async {
          if (++attempts == 1) return http.Response('unavailable', 503);
          return http.Response(
              jsonEncode({
                'meals': [meal('Rice bowl', 'rice')]
              }),
              200);
        }));
    expect(await service.fetchMealImage('Rice bowl'), isNull);
    expect((await service.fetchMealImage('Rice bowl', refresh: true))?.smallUrl,
        endsWith('/rice.jpg'));
    expect(attempts, 2);
    expect((await service.fetchMealImage('rice BOWL'))?.smallUrl,
        endsWith('/rice.jpg'));
    expect(attempts, 2); // Successful exact dish results are cached.
  });

  test('empty dish performs no request and arbitrary image hosts are rejected',
      () async {
    var requests = 0;
    final service = UnsplashService(
        useCommons: false,
        accessKey: '',
        client: MockClient((_) async {
          requests++;
          return http.Response(
              jsonEncode({
                'meals': [
                  {
                    'strMeal': 'Rice',
                    'strMealThumb': 'https://unrelated.example/photo.jpg'
                  }
                ]
              }),
              200);
        }));
    expect(await service.fetchMealImage(null), isNull);
    expect(requests, 0);
    expect(await service.fetchMealImage('Rice'), isNull);
  });

  test('Unsplash metadata must explicitly match the actual dish', () async {
    final service = UnsplashService(
        useCommons: false,
        accessKey: 'test-only',
        client: MockClient((request) async {
          expect(request.url.host, 'api.unsplash.com');
          return http.Response(
              jsonEncode({
                'results': [
                  {'alt_description': 'A plate of pizza'},
                  {
                    'alt_description': 'A bowl of chicken adobo on a table',
                    'urls': {
                      'small': 'https://images.unsplash.com/adobo-small',
                      'regular': 'https://images.unsplash.com/adobo'
                    },
                    'user': {
                      'name': 'Photographer',
                      'links': {'html': 'https://unsplash.com/@p'}
                    },
                    'links': {'html': 'https://unsplash.com/photos/adobo'}
                  }
                ]
              }),
              200);
        }));
    final image = await service.fetchMealImage('Chicken Adobo');
    expect(image?.smallUrl, 'https://images.unsplash.com/adobo-small');
    expect(image?.showUnsplashAttribution, isTrue);
  });

  test('legacy hash-selected URLs are recognized without modifying saved data',
      () {
    expect(
        UnsplashService.isUnmatchedLegacyUrl(
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400'),
        isTrue);
    expect(
        UnsplashService.isUnmatchedLegacyUrl(
            'https://www.themealdb.com/images/media/meals/adobo.jpg'),
        isFalse);
  });

  testWidgets(
      'empty image uses an explicit placeholder and clears a previous image',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
        home: MealNetworkImage(
            url: 'https://example.invalid/old-photo.jpg', height: 80)));
    await tester.pumpWidget(
        const MaterialApp(home: MealNetworkImage(url: '', height: 80)));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('Dish image unavailable'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('reused meal card refreshes its image for the replacement dish',
      (tester) async {
    Widget card(String title, String image) => MaterialApp(
            home: Scaffold(
          body: SingleChildScrollView(
              child: GeneratedMealCard(
            meal: GeneratedMeal.fromCore(
                Meal(id: 'same-id', title: title, imageUrl: image)),
            dayIndex: 0,
            onOpen: () {},
            onReplace: () {},
            onAccept: () {},
          )),
        ));
    await tester.pumpWidget(card('Rice', 'https://example.invalid/rice.jpg'));
    await tester.pumpWidget(card('Soup', 'https://example.invalid/soup.jpg'));
    expect(tester.widget<MealNetworkImage>(find.byType(MealNetworkImage)).url,
        'https://example.invalid/soup.jpg');
  });
}
