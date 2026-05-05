import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.position,
  });

  final String title;
  final String subtitle;
  final LatLng position;
}

class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return const <PlaceSuggestion>[];
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '6',
    });

    try {
      final response = await _client.get(
        uri,
        headers: const {
          'User-Agent': 'FairBid/1.0 (Flutter production upgrade)',
          'Accept-Language': 'en',
        },
      );
      if (response.statusCode != 200) {
        return const <PlaceSuggestion>[];
      }

      final body = jsonDecode(response.body);
      if (body is! List) {
        return const <PlaceSuggestion>[];
      }

      final suggestions = <PlaceSuggestion>[];
      for (final item in body) {
        if (item is! Map) {
          continue;
        }
        final lat = double.tryParse('${item['lat'] ?? ''}');
        final lng = double.tryParse('${item['lon'] ?? ''}');
        if (lat == null || lng == null) {
          continue;
        }

        final displayName = '${item['display_name'] ?? 'Unknown place'}';
        final parts = displayName
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
        suggestions.add(
          PlaceSuggestion(
            title: parts.isEmpty ? displayName : parts.first,
            subtitle: parts.skip(1).join(', '),
            position: LatLng(lat, lng),
          ),
        );
      }
      return suggestions;
    } catch (error) {
      debugPrint('[PlaceSearchService] Autocomplete failed: $error');
      return const <PlaceSuggestion>[];
    }
  }

  void dispose() {
    _client.close();
  }
}
