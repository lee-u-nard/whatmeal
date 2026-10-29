import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whatmeal/core/services/unsplash_service.dart';
import 'package:whatmeal/features/auth/models/user_model.dart';
import 'package:whatmeal/features/family/models/family_space.dart';
import 'package:whatmeal/features/meal/models/meal.dart';
import 'package:whatmeal/features/meal/widgets/meal_network_image.dart';
import 'package:whatmeal/features/meal_plan/data/saved_plans_repository.dart';
import 'package:whatmeal/features/meal_plan/models/meal_plan.dart';

final fixtures = (jsonDecode(
        File('test/fixtures/meal_image_public_metadata.json')
            .readAsStringSync()) as List)
    .cast<Map<String, dynamic>>();

http.Response commons(Map<String, dynamic> fixture, {String? url}) =>
    http.Response(
        jsonEncode({
          'query': {
            'pages': {
              '1': {
                'title': fixture['Title'],
                'imageinfo': [
                  {
                    'mime': 'image/jpeg',
                    'thumburl': url ?? fixture['Url'],
                    'descriptionurl': fixture['Source'],
                    'extmetadata': {
                      'Artist': {'value': fixture['Artist']},
                      'LicenseShortName': {'value': fixture['License']},
                    }
                  }
                ]
              }
            }
          }
        }),
        200);

UnsplashService serviceFor(Map<String, dynamic> fixture) => UnsplashService(
    accessKey: '',
    client: MockClient((request) async =>
        request.url.host == 'commons.wikimedia.org'
            ? commons(fixture)
            : http.Response('{"meals":null}', 200)));

void main() {
  for (final fixture in fixtures) {
    test(
        'resolves ${fixture['Dish']} using its matched public source and credits',
        () async {
      final image = await serviceFor(fixture)
          .fetchMealImage('generic food', mealTitle: fixture['Dish'] as String);
      expect(image?.regularUrl, fixture['Url']);
      expect(image?.sourceName, 'Wikimedia Commons');
      expect(image?.license, fixture['License']);
      expect(image?.photographerName, isNotEmpty);
    });
  }

  test('dish matching preserves protein, dietary and noodle distinctions', () {
    expect(
        UnsplashService.dishMatches(
            'Sinigang na baboy', 'File:Pork sinigang.JPG'),
        isTrue);
    expect(
        UnsplashService.dishMatches('Adobong manok', 'File:Chicken adobo.jpg'),
        isTrue);
    for (final pair in [
      ['Chicken adobo', 'File:Chicken and pork adobo.jpg'],
      ['Vegetable fried rice', 'File:Chicken Fried Rice.jpg'],
      ['Pancit canton', 'File:Pancit palabok.jpg'],
      ['Pancit canton', 'File:Stacks of Pancit Canton.jpg'],
      ['Pancit canton', 'File:Instant Pancit Canton packet.jpg'],
    ]) {
      expect(UnsplashService.dishMatches(pair[0], pair[1]), isFalse);
    }
    expect(fixtures.map((f) => f['Url']).toSet(), hasLength(4));
  });

  test(
      'simultaneous widgets share searches; misses expire and explicit retry recovers',
      () async {
    var calls = 0;
    var current = DateTime(2026, 10, 25);
    var healthy = false;
    final gate = Completer<void>();
    final fixture = fixtures.first;
    final service = UnsplashService(
        accessKey: '',
        now: () => current,
        client: MockClient((request) async {
          calls++;
          await gate.future;
          return healthy && request.url.host == 'commons.wikimedia.org'
              ? commons(fixture)
              : http.Response('{"meals":null}', 200);
        }));
    final first = service.fetchMealImage('Chicken adobo');
    final second = service.fetchMealImage('CHICKEN ADOBO');
    gate.complete();
    expect(await first, isNull);
    expect(await second, isNull);
    expect(calls, 2);
    expect(await service.fetchMealImage('Chicken adobo'), isNull);
    expect(calls, 2);
    healthy = true;
    expect(await service.fetchMealImage('Chicken adobo', refresh: true),
        isNotNull);
    expect(calls, 4);
    current = current.add(const Duration(hours: 7));
    expect(await service.fetchMealImage('Chicken adobo'), isNotNull);
    expect(calls, 6);
  });

  test(
      'known broken reference is rejected instead of being returned from cache',
      () async {
    final service = serviceFor(fixtures.first);
    final first = (await service.fetchMealImage('Chicken adobo'))!;
    service.rejectImage('Chicken adobo', first.smallUrl);
    expect(
        await service.fetchMealImage('Chicken adobo', refresh: true), isNull);
  });

  test(
      'resolved reference survives saving and reopening without another search',
      () async {
    final images = serviceFor(fixtures.first);
    final photo = (await images.fetchMealImage('Chicken adobo'))!;
    final db = FakeFirebaseFirestore();
    final account = ValueNotifier<UserModel?>(
        UserModel(id: 'local', name: 'Local', email: 'local@example.test'));
    final household = ValueNotifier<FamilySpace?>(null);
    final repo = SavedPlansRepository(
        firestore: db,
        account: account,
        household: household,
        canEditShared: () => true,
        images: images);
    final id = await repo.savePlan(
        MealPlan(id: '', title: 'Plan', numberOfDays: 1),
        [Meal(id: 'meal', title: 'Chicken adobo')]);
    final snapshot = await db.doc('users/local/mealPlans/$id/meals/meal').get();
    final reopened = Meal.fromFirestore(snapshot);
    expect(reopened.imageUrl, photo.regularUrl);
    expect(images.cachedPhoto(reopened.title)?.regularUrl, reopened.imageUrl);
    final coldImage = await serviceFor(fixtures.first)
        .fetchMealImage(null, mealTitle: reopened.title);
    expect(coldImage?.regularUrl, reopened.imageUrl);
    final existingId = await repo.savePlan(
        MealPlan(id: '', title: 'Existing reference', numberOfDays: 1), [
      Meal(
          id: 'existing',
          title: 'Chicken adobo',
          imageUrl: 'https://example.invalid/existing.jpg')
    ]);
    final retained =
        (await db.doc('users/local/mealPlans/$existingId/meals/existing').get())
            .data()!;
    expect(retained['imageUrl'], 'https://example.invalid/existing.jpg');
    repo.dispose();
    account.dispose();
    household.dispose();
  });

  testWidgets('matched image decodes and a rebuild reuses the same reference',
      (tester) async {
    final service = serviceFor(fixtures.first);
    // Existing local asset tests decoding only; live dish photos were checked separately.
    final bytes = File('assets/images/whatmeal_logo.png').readAsBytesSync();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(() => precacheImage(MemoryImage(bytes), context));
    final urls = <String>[];
    Widget view() => MaterialApp(
        home: Scaffold(
            body: MealNetworkImage(
                url: '',
                mealTitle: 'Chicken adobo',
                service: service,
                width: 160,
                height: 120,
                imageProvider: (url) {
                  urls.add(url);
                  return MemoryImage(bytes);
                })));
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byTooltip('Retry dish image'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(urls.toSet(), {fixtures.first['Url']});
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid bytes recover once and cannot loop during rebuilds',
      (tester) async {
    final service = serviceFor(fixtures.first);
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MealNetworkImage(
                url: 'https://expired.example.invalid/image.jpg',
                mealTitle: 'Chicken adobo',
                service: service,
                width: 160,
                height: 120,
                imageProvider: (_) {
                  loads++;
                  return MemoryImage(Uint8List.fromList([0, 1, 2]));
                }))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retry dish image'), findsOneWidget);
    expect(loads, lessThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stalled image has a deadline and leaves the card usable',
      (tester) async {
    final gate = Completer<http.Response>();
    final service = UnsplashService(
        useCommons: false,
        accessKey: '',
        client: MockClient((_) => gate.future));
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      MealNetworkImage(
          url: '',
          mealTitle: 'Chicken adobo',
          service: service,
          width: 100,
          height: 80,
          loadTimeout: const Duration(milliseconds: 50)),
      TextButton(
          onPressed: () => pressed = true, child: const Text('View meal')),
    ]))));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byTooltip('Retry dish image'), findsOneWidget);
    await tester.tap(find.text('View meal'));
    expect(pressed, isTrue);
    gate.complete(http.Response('{"meals":null}', 200));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retry dish image'), findsOneWidget);
  });
}
