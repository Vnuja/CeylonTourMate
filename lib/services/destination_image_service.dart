// lib/services/destination_image_service.dart
//
// Resolves a relevant photo for a destination from Wikipedia (keyless REST
// API) when the app doesn't have a curated local asset for it. Keeps a small
// in-memory cache so the same destination isn't looked up twice.
//
// Example: "Galle Face Green" → the Wikipedia page's lead image, instead of a
// wrong local asset or a generic Sri Lanka stock photo.

import 'dart:convert';
import 'package:http/http.dart' as http;

class DestinationImageService {
  DestinationImageService._();
  static final DestinationImageService instance = DestinationImageService._();

  static const String _wikiSummary =
      'https://en.wikipedia.org/api/rest_v1/page/summary/';

  // Generic Sri Lanka fallback when even Wikipedia has nothing.
  static const String genericFallback =
      'https://images.unsplash.com/photo-1566296314736-6eaac1ca0cb9?w=800';

  final Map<String, String> _cache = {};

  /// A relevant image URL for [destination]. Tries a couple of cleaned
  /// Wikipedia titles, then falls back to the generic Sri Lanka photo. Never
  /// throws.
  Future<String> imageUrlFor(String destination) async {
    final key = destination.trim().toLowerCase();
    final cached = _cache[key];
    if (cached != null) return cached;

    for (final title in _candidateTitles(destination)) {
      final url = await _wikiThumb(title);
      if (url != null) {
        _cache[key] = url;
        return url;
      }
    }
    _cache[key] = genericFallback;
    return genericFallback;
  }

  /// Cleaned title variants to try, most specific first.
  List<String> _candidateTitles(String destination) {
    final cleaned = destination
        .replaceAll(RegExp(r'\s*\(.*?\)'), '') // "(Colombo)" / "(Sri Pada)"
        .split('&')
        .first
        .split(',')
        .first
        .trim();
    return <String>{
      cleaned,
      '$cleaned Sri Lanka',
    }.where((t) => t.isNotEmpty).toList();
  }

  Future<String?> _wikiThumb(String title) async {
    try {
      final uri = Uri.parse(
          '$_wikiSummary${Uri.encodeComponent(title.replaceAll(' ', '_'))}');
      final resp = await http.get(uri, headers: {
        'User-Agent': 'CeylonTourMate/1.0 (travel app; contact: app)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final src = (data['thumbnail'] as Map<String, dynamic>?)?['source'];
        final original =
            (data['originalimage'] as Map<String, dynamic>?)?['source'];
        final url = (original is String && original.isNotEmpty)
            ? original
            : (src is String && src.isNotEmpty ? src : null);
        return url;
      }
    } catch (_) {
      // ignore — caller falls back
    }
    return null;
  }
}
