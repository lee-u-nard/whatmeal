import 'dart:convert';
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
    this.sourceName = 'Unsplash',
    this.license = '',
  });

  final String smallUrl;
  final String regularUrl;
  final String photographerName;
  final String photographerProfileUrl;
  final String unsplashPageUrl;
  final bool showUnsplashAttribution;
  final String sourceName;
  final String license;
}

/// Resolves meal images for cards and detail screens.
///
/// Only dish-matched photos; failed searches never become random food images.
class UnsplashService {
  UnsplashService(
      {http.Client? client,
      String? accessKey,
      this.useCommons = true,
      DateTime Function()? now})
      : _client = client ?? http.Client(),
        _accessKey = accessKey ?? kUnsplashAccessKey,
        _now = now ?? DateTime.now;
  static final instance = UnsplashService();
  final http.Client _client;
  final String _accessKey;
  final bool useCommons;
  final DateTime Function() _now;

  static const _unsplashBase = 'https://api.unsplash.com';
  static const _mealDbBase = 'https://www.themealdb.com/api/json/v1/1';

  // Old releases selected one of these photos by hash, without dish matching.
  // Avoid continuing to display those cached/persisted arbitrary assignments.
  static const _legacyPhotoIds = {
    '1546069901-ba9599a7e63c',
    '1565299624946-b28f40a0ae38',
    '1567620905732-2d1ec7ab7445',
    '1540189549336-e6e99c3679fe',
    '1565958011703-44f9829ba187',
    '1482049016687-2d3ff1b3ddb6',
    '1512621776951-a57141f2eefd',
    '1476224203421-9ac39bcb3327',
    '1504674900247-0877df9cc836',
    '1414235077428-338989a2e8c0',
    '1498837164567-7061a14aa0cd',
    '1467003909585-2f8a72700288',
    '1555939594-58ed7c6b3b8f',
    '1529042410759-befb1204bacc',
    '1455619452474-d2be8b1e70cd',
    '1603133872878-684f208fb84b',
  };

  final _cache = <String, UnsplashPhoto>{};
  final _expires = <String, DateTime>{};
  final _pending = <String, Future<UnsplashPhoto?>>{};
  final _misses = <String, DateTime>{};
  final _failedUrls = <String, DateTime>{};

  static bool validImageUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        !isUnmatchedLegacyUrl(url);
  }

  UnsplashPhoto? cachedPhoto(String title) {
    final key = _normalize(title);
    return _expires[key]?.isAfter(_now()) == true ? _cache[key] : null;
  }

  void rejectImage(String title, String url) {
    _failedUrls[url] = _now().add(const Duration(minutes: 5));
    final key = _normalize(title);
    _cache.remove(key);
    _expires.remove(key);
    _misses.remove(key);
  }

  bool _usable(String url) =>
      validImageUrl(url) && _failedUrls[url]?.isAfter(_now()) != true;

  bool get isConfigured =>
      _accessKey.isNotEmpty && _accessKey != 'YOUR_UNSPLASH_ACCESS_KEY';

  static bool isUnmatchedLegacyUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host == 'images.unsplash.com' &&
        _legacyPhotoIds.any((id) => uri!.path == '/photo-$id');
  }

  Future<UnsplashPhoto?> fetchMealImage(String? query,
      {String? mealTitle, bool refresh = false}) {
    // The generated search phrase must never override the actual dish identity.
    final title = mealTitle?.trim() ?? '';
    final dish = title.isNotEmpty ? title : query?.trim() ?? '';
    final key = _normalize(dish);
    if (key.isEmpty) return Future.value(null);
    if (!refresh && cachedPhoto(dish) != null) return Future.value(_cache[key]);
    if (!refresh && _misses[key]?.isAfter(_now()) == true) {
      return Future.value(null);
    }
    return _pending.putIfAbsent(key, () => _resolve(dish, key));
  }

  Future<UnsplashPhoto?> _resolve(String dish, String key) async {
    try {
      final results = await Future.wait([
        if (isConfigured) _fetchUnsplash(dish),
        _fetchMealDb(dish),
        if (useCommons) _fetchCommons(dish),
      ]);
      final photo = results.whereType<UnsplashPhoto>().firstOrNull;
      if (photo != null) {
        if (_cache.length >= 64) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = photo;
        _expires[key] = _now().add(const Duration(hours: 6));
        _misses.remove(key);
      } else {
        _misses[key] = _now().add(const Duration(seconds: 30));
      }
      return photo;
    } finally {
      _pending.remove(key);
    }
  }

  /// A synchronous seed cannot establish which dish a photo depicts.
  static String syncFoodUrl(String seed) => '';

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\bsinigang na baboy\b'), 'pork sinigang')
      .replaceAll(RegExp(r'\badobong manok\b'), 'chicken adobo')
      .replaceAll(RegExp(r'\bveg\b'), 'vegetable')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static bool _matchingDescription(String dish, Object? description) =>
      description is String &&
      ' ${_normalize(description)} '.contains(' ${_normalize(dish)} ');

  static bool _imageUrl(String value, String host) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        (uri.host == host || uri.host == 'www.$host');
  }

  Future<UnsplashPhoto?> _fetchUnsplash(String query) async {
    try {
      final uri =
          Uri.parse('$_unsplashBase/search/photos').replace(queryParameters: {
        'query': '$query food dish',
        'per_page': '10',
        'orientation': 'landscape',
        'content_filter': 'high',
      });

      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Client-ID $_accessKey',
          'Accept-Version': 'v1',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final matching = results.whereType<Map<String, dynamic>>().where((item) =>
          _matchingDescription(query, item['alt_description']) ||
          _matchingDescription(query, item['description']));
      if (matching.isEmpty) return null;
      final first = matching.first;
      final urls = first['urls'] as Map<String, dynamic>;
      final small = urls['small'] as String;
      final regular = urls['regular'] as String;
      if (!_usable(small) ||
          !_usable(regular) ||
          !_imageUrl(small, 'images.unsplash.com') ||
          !_imageUrl(regular, 'images.unsplash.com') ||
          isUnmatchedLegacyUrl(regular)) {
        return null;
      }
      final user = first['user'] as Map<String, dynamic>;
      final links = first['links'] as Map<String, dynamic>;
      final userLinks = user['links'] as Map<String, dynamic>;

      return UnsplashPhoto(
        smallUrl: small,
        regularUrl: regular,
        photographerName: user['name'] as String? ?? 'Unsplash',
        photographerProfileUrl:
            '${userLinks['html']}?utm_source=whatmeal&utm_medium=referral',
        unsplashPageUrl:
            '${links['html']}?utm_source=whatmeal&utm_medium=referral',
        showUnsplashAttribution: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<UnsplashPhoto?> _fetchMealDb(String query) async {
    try {
      final uri = Uri.parse('$_mealDbBase/search.php')
          .replace(queryParameters: {'s': query.trim()});
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final meals = data['meals'] as List<dynamic>?;
      if (meals == null || meals.isEmpty) return null;

      final matching = meals.whereType<Map<String, dynamic>>().where((item) =>
          item['strMeal'] is String &&
          _normalize(item['strMeal'] as String) == _normalize(query));
      if (matching.isEmpty) return null;
      final first = matching.first;
      final thumb = first['strMealThumb'] as String?;
      if (thumb == null ||
          !_usable(thumb) ||
          !_imageUrl(thumb, 'themealdb.com')) {
        return null;
      }

      final name = first['strMeal'] as String? ?? 'TheMealDB';
      return UnsplashPhoto(
        smallUrl: thumb,
        regularUrl: thumb,
        photographerName: name,
        photographerProfileUrl: 'https://www.themealdb.com',
        unsplashPageUrl: 'https://www.themealdb.com',
        showUnsplashAttribution: false,
        sourceName: 'TheMealDB',
      );
    } catch (_) {
      return null;
    }
  }

  static bool dishMatches(String dish, String description) {
    final wanted =
        _normalize(dish).split(' ').where((word) => word.isNotEmpty).toSet();
    final actual = _normalize(description
            .replaceFirst(RegExp(r'^File:', caseSensitive: false), '')
            .replaceFirst(
                RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false), ''))
        .split(' ')
        .toSet();
    if (wanted.isEmpty || !wanted.every(actual.contains)) return false;
    const notDish = {
      'packaging',
      'packet',
      'packets',
      'stacks',
      'logo',
      'menu',
      'uncooked'
    };
    if (actual.intersection(notDish).isNotEmpty) return false;
    if (!wanted.contains('instant') && actual.contains('instant')) return false;
    const proteins = {
      'chicken',
      'pork',
      'beef',
      'shrimp',
      'prawn',
      'prawns',
      'fish',
      'spam'
    };
    final specified = wanted.intersection(proteins);
    final vegetarian =
        wanted.intersection({'vegan', 'vegetarian', 'vegetable'}).isNotEmpty;
    if ((specified.isNotEmpty || vegetarian) &&
        actual.intersection(proteins).difference(specified).isNotEmpty) {
      return false;
    }
    return true;
  }

  Future<UnsplashPhoto?> _fetchCommons(String dish) async {
    try {
      final response = await _client.get(
          Uri.https('commons.wikimedia.org', '/w/api.php', {
            'action': 'query',
            'generator': 'search',
            'gsrsearch': 'intitle:"${_normalize(dish)}" filetype:bitmap',
            'gsrnamespace': '6',
            'gsrlimit': '8',
            'prop': 'imageinfo',
            'iiprop': 'url|extmetadata|mime',
            'iiurlwidth': '800',
            'format': 'json',
            'origin': '*',
          }),
          headers: {
            'User-Agent': 'WhatMeal/1.0 (meal photo lookup)'
          }).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final pages = (jsonDecode(response.body)['query']?['pages'] as Map?)
              ?.values
              .whereType<Map>()
              .where((page) =>
                  page['title'] is String &&
                  dishMatches(dish, page['title'] as String))
              .toList() ??
          [];
      pages.sort((a, b) => (a['title'] as String)
          .length
          .compareTo((b['title'] as String).length));
      for (final page in pages) {
        final info = (page['imageinfo'] as List?)?.whereType<Map>().firstOrNull;
        if (info == null ||
            !{'image/jpeg', 'image/png', 'image/webp'}.contains(info['mime'])) {
          continue;
        }
        final url = info['thumburl'] ?? info['url'];
        final source = info['descriptionurl'];
        if (url is! String ||
            !_usable(url) ||
            !{'upload.wikimedia.org', 'thumb.wikimedia.org'}
                .contains(Uri.parse(url).host) ||
            source is! String ||
            !_imageUrl(source, 'commons.wikimedia.org')) {
          continue;
        }
        final metadata = info['extmetadata'] as Map? ?? {};
        final license = metadata['LicenseShortName']?['value'];
        final artist = metadata['Artist']?['value'];
        if (license is! String ||
            artist is! String ||
            !RegExp(r'^(CC BY|CC0|Public domain)').hasMatch(license)) {
          continue;
        }
        return UnsplashPhoto(
            smallUrl: url,
            regularUrl: url,
            photographerName: artist.replaceAll(RegExp('<[^>]*>'), '').trim(),
            photographerProfileUrl: source,
            unsplashPageUrl: source,
            sourceName: 'Wikimedia Commons',
            license: license);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
