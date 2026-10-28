import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:whatmeal/core/services/unsplash_service.dart';

// Explicit opt-in: ordinary tests must never contact external services.
void main() {
  test(
      'live public photo resolver and Flutter decoder handle four distinct dishes',
      () async {
    final service = UnsplashService(accessKey: '');
    final urls = <String>{};
    final client = http.Client();
    try {
      for (final dish in [
        'Chicken adobo',
        'Sinigang na baboy',
        'Pancit canton',
        'Vegetable fried rice'
      ]) {
        final photo = await service.fetchMealImage(null, mealTitle: dish);
        expect(photo, isNotNull, reason: 'No matched public image for $dish');
        final response =
            await client.get(Uri.parse(photo!.regularUrl), headers: {
          'User-Agent': 'WhatMeal/1.0 (bounded public image verification)',
        }).timeout(const Duration(seconds: 8));
        expect(response.statusCode, 200,
            reason: 'Image download failed for $dish');
        expect(response.headers['content-type'], startsWith('image/'));
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
        expect(urls.add(photo.regularUrl), isTrue,
            reason: 'Unrelated dishes reused one photo');
        debugPrint(
            'Public image PASS: $dish; ${photo.sourceName}; HTTP 200; Flutter decoded');
      }
    } finally {
      client.close();
    }
  },
      skip: !const bool.fromEnvironment('WHATMEAL_PUBLIC_IMAGE_PROBE'),
      timeout: const Timeout(Duration(seconds: 90)));
}
