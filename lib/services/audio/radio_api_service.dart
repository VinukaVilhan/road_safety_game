import 'dart:convert';

import 'package:http/http.dart' as http;

import 'radio_station.dart';

/// Fetches internet radio stations from the public Radio Browser API.
/// Streams are played in-app via [MusicService.playUrl] — no external FM app.
class RadioApiService {
  RadioApiService._();

  static const _baseUrl = 'https://de1.api.radio-browser.info';
  static const _userAgent = 'RoadSafetyGame/1.0 (Flutter; in-app radio)';

  static Future<List<RadioStation>> fetchPopular({int limit = 25}) async {
    return _fetchList('/json/stations/topvote/$limit');
  }

  static Future<List<RadioStation>> search({
    required String query,
    int limit = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return fetchPopular(limit: limit);

    final uri = Uri.parse('$_baseUrl/json/stations/search').replace(
      queryParameters: {
        'name': trimmed,
        'limit': '$limit',
        'order': 'clickcount',
        'reverse': 'true',
      },
    );
    return _getStations(uri);
  }

  static Future<List<RadioStation>> _fetchList(String path) async {
    return _getStations(Uri.parse('$_baseUrl$path'));
  }

  static Future<List<RadioStation>> _getStations(Uri uri) async {
    final response = await http.get(
      uri,
      headers: const {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw RadioApiException(
        'Radio API returned ${response.statusCode}. Check your connection and try again.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const RadioApiException('Unexpected radio API response.');
    }

    final stations = <RadioStation>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final station = RadioStation.fromJson(item);
      if (station.streamUrl.isNotEmpty) {
        stations.add(station);
      }
    }
    stations.sort((a, b) {
      final httpsCmp = (b.usesHttps ? 1 : 0) - (a.usesHttps ? 1 : 0);
      if (httpsCmp != 0) return httpsCmp;
      return a.name.compareTo(b.name);
    });
    return stations;
  }
}

class RadioApiException implements Exception {
  const RadioApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
