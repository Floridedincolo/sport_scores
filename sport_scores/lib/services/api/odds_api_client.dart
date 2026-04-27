import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/constants.dart';
import '../../models/fixture.dart';
import '../../models/sport.dart';

/// Fallback data source using https://the-odds-api.com (v4).
/// Used only when the primary API-Sports response is empty.
///
/// Free tier: 500 requests / month. `/events` endpoint is free (no quota cost),
/// `/scores` counts against quota but includes live + completed games.
class OddsApiClient {
  static const String _baseUrl = 'https://api.the-odds-api.com/v4';

  final http.Client _http;

  OddsApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  bool get isConfigured => ApiConstants.oddsApiKey.isNotEmpty;

  /// Returns events + live/recent scores for the given sport.
  /// Combines `/events` (upcoming, free) and `/scores` (live+recent, paid)
  /// to maximize coverage while minimizing quota spend.
  Future<List<Fixture>> getScores(SportType sport, {int daysFrom = 3}) async {
    final sportKey = ApiConstants.oddsApiSportKeys[sport];
    if (sportKey == null || !isConfigured) return [];

    try {
      final uri = Uri.parse('$_baseUrl/sports/$sportKey/scores').replace(
        queryParameters: {
          'apiKey': ApiConstants.oddsApiKey,
          'daysFrom': daysFrom.toString(),
          'dateFormat': 'iso',
        },
      );
      debugPrint('OddsApi: GET $uri');
      final response = await _http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('OddsApi: status=${response.statusCode} body=${response.body}');
        return [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((j) => Fixture.fromOddsApiJson(j, sport))
          .toList();
    } catch (e) {
      debugPrint('OddsApi: error - $e');
      return [];
    }
  }

  /// Upcoming events only (no scores). Free endpoint — doesn't count against quota.
  Future<List<Fixture>> getEvents(SportType sport) async {
    final sportKey = ApiConstants.oddsApiSportKeys[sport];
    if (sportKey == null || !isConfigured) return [];

    try {
      final uri = Uri.parse('$_baseUrl/sports/$sportKey/events').replace(
        queryParameters: {
          'apiKey': ApiConstants.oddsApiKey,
          'dateFormat': 'iso',
        },
      );
      debugPrint('OddsApi: GET $uri');
      final response = await _http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((j) => Fixture.fromOddsApiJson(j, sport))
          .toList();
    } catch (e) {
      debugPrint('OddsApi: error - $e');
      return [];
    }
  }
}
