import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// A food photo with optional Unsplash attribution.
class UnsplashPhoto {
  const UnsplashPhoto({
    required this.smallUrl,
    required this.regularUrl,
    required this.photographerName,
    required this.photographerProfileUrl,
    required this.unsplashPageUrl,
    this.showUnsplashAttribution = false,
  });

  final String smallUrl;
  final String regularUrl;
  final String photographerName;
  final String photographerProfileUrl;
  final String unsplashPageUrl;
  final bool showUnsplashAttribution;
}

/// Resolves meal images for cards and detail screens.
///
/// Order: Unsplash (if key set) → TheMealDB → curated Unsplash CDN URLs.
/// Avoids LoremFlickr (unreliable / CORS issues on Flutter web).
class UnsplashService {
  UnsplashService._();
  static final instance = UnsplashService._();

  static const _unsplashBase = 'https://api.unsplash.com';
  static const _mealDbBase = 'https://www.themealdb.com/api/json/v1/1';

  /// Direct `images.unsplash.com` food photos (work on web + mobile).
  static const _foodImagePool = <String>[
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1565958011703-44f9829ba187?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1482049016687-2d3ff1b3ddb6?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1498837164567-7061a14aa0cd?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1555939594-58ed7c6b3b8f?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1529042410759-befb1204bacc?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=800&q=80',
  ];

  final _cache = <String, UnsplashPhoto?>{};

  bool get isConfigured =>
      kUnsplashAccessKey.isNotEmpty &&
      kUnsplashAccessKey != 'YOUR_UNSPLASH_ACCESS_KEY';

  Future<UnsplashPhoto?> fetchMealImage(
    String? query, {
    String? mealTitle,
  }) async {
    final q = _bestQuery(query, mealTitle);
    if (q == null) {
      // Still return a food photo so UI is never blank.
      return _curatedPhoto('meal');
    }

    final key = q.toLowerCase();
    if (_cache.containsKey(key) && _cache[key] != null) return _cache[key];

    if (isConfigured) {
      final unsplash = await _fetchUnsplash(q);
      if (unsplash != null) {
        _cache[key] = unsplash;
        return unsplash;
      }
    }

    final mealDb = await _fetchMealDb(q);
    if (mealDb != null) {
      _cache[key] = mealDb;
      return mealDb;
    }

    final short = q.split(RegExp(r'\s+')).take(2).join(' ');
    if (short.toLowerCase() != key) {
      final mealDbShort = await _fetchMealDb(short);
      if (mealDbShort != null) {
        _cache[key] = mealDbShort;
        return mealDbShort;
      }
    }

    final curated = _curatedPhoto(q);
    _cache[key] = curated;
    return curated;
  }

  String? _bestQuery(String? query, String? mealTitle) {
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) return q;
    final t = mealTitle?.trim() ?? '';
    if (t.isNotEmpty) return t;
    return null;
  }

  /// Synchronous food image URL (curated pool) — for list tiles that can't await.
  static String syncFoodUrl(String seed) {
    final index = seed.hashCode.abs() % _foodImagePool.length;
    return _foodImagePool[index];
  }

  UnsplashPhoto _curatedPhoto(String seed) {
    final url = syncFoodUrl(seed);
    final small =
        url.contains('w=800') ? url.replaceFirst('w=800', 'w=400') : url;
    return UnsplashPhoto(
      smallUrl: small,
      regularUrl: url,
      photographerName: 'Unsplash',
      photographerProfileUrl:
          'https://unsplash.com/?utm_source=whatmeal&utm_medium=referral',
      unsplashPageUrl:
          'https://unsplash.com/?utm_source=whatmeal&utm_medium=referral',
      showUnsplashAttribution: true,
    );
  }

  Future<UnsplashPhoto?> _fetchUnsplash(String query) async {
    try {
      final uri =
          Uri.parse('$_unsplashBase/search/photos').replace(queryParameters: {
        'query': '$query food dish',
        'per_page': '1',
        'orientation': 'landscape',
        'content_filter': 'high',
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Client-ID $kUnsplashAccessKey',
          'Accept-Version': 'v1',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[Unsplash] HTTP ${response.statusCode} for "$query"');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final urls = first['urls'] as Map<String, dynamic>;
      final user = first['user'] as Map<String, dynamic>;
      final links = first['links'] as Map<String, dynamic>;
      final userLinks = user['links'] as Map<String, dynamic>;

      return UnsplashPhoto(
        smallUrl: urls['small'] as String,
        regularUrl: urls['regular'] as String,
        photographerName: user['name'] as String? ?? 'Unsplash',
        photographerProfileUrl:
            '${userLinks['html']}?utm_source=whatmeal&utm_medium=referral',
        unsplashPageUrl:
            '${links['html']}?utm_source=whatmeal&utm_medium=referral',
        showUnsplashAttribution: true,
      );
    } catch (e) {
      debugPrint('[Unsplash] Error "$query": $e');
      return null;
    }
  }

  Future<UnsplashPhoto?> _fetchMealDb(String query) async {
    try {
      final cleaned = query
          .replaceAll(
              RegExp(
                  r'\b(with|and|the|a|an|style|recipe|homemade|easy|quick|vegan|filipino)\b',
                  caseSensitive: false),
              ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isEmpty) return null;

      final uri = Uri.parse('$_mealDbBase/search.php')
          .replace(queryParameters: {'s': cleaned});
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final meals = data['meals'] as List<dynamic>?;
      if (meals == null || meals.isEmpty) return null;

      final first = meals.first as Map<String, dynamic>;
      final thumb = first['strMealThumb'] as String?;
      if (thumb == null || thumb.isEmpty) return null;

      final name = first['strMeal'] as String? ?? 'TheMealDB';
      return UnsplashPhoto(
        smallUrl: thumb,
        regularUrl: thumb,
        photographerName: name,
        photographerProfileUrl: 'https://www.themealdb.com',
        unsplashPageUrl: 'https://www.themealdb.com',
        showUnsplashAttribution: false,
      );
    } catch (e) {
      debugPrint('[MealDB] Error "$query": $e');
      return null;
    }
  }
}
