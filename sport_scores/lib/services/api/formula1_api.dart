import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/fixture.dart';
import '../../models/fixture_event.dart';
import '../../models/league.dart';
import '../../models/sport.dart';
import '../../utils/team_matching.dart';
import 'api_client.dart';

class Formula1Api {
  final ApiClient _client;
  final http.Client _openF1Client = http.Client();

  Formula1Api(this._client);

  Future<List<League>> getLeagues() async {
    // F1 doesn't have leagues in the traditional sense, fetch competitions
    final data = await _client.get(
      SportType.formula1,
      '/competitions',
      cacheTtl: const Duration(hours: 24),
    );
    return data.map((json) {
      final j = json as Map<String, dynamic>;
      final id = j['id'];
      return League(
        id: id is String ? int.tryParse(id) ?? 0 : (id as int? ?? 0),
        name: j['name'] as String? ?? 'Unknown',
        country: null,
        logo: j['logo'] as String?,
        sport: SportType.formula1,
      );
    }).toList();
  }

  static const _maxFreeSeason = 2024;

  Future<List<Fixture>> getRacesByDate(DateTime date) async {
    // Free tier only has access to 2022-2024
    final season = date.year > _maxFreeSeason ? _maxFreeSeason : date.year;
    final data = await _client.get(
      SportType.formula1,
      '/races',
      params: {'season': season.toString()},
      cacheTtl: const Duration(minutes: 10),
    );
    final races = data
        .map((json) => Fixture.fromFormula1Json(json as Map<String, dynamic>))
        .toList();

    // Filter to races within ±7 days of the selected date
    final startDate = date.subtract(const Duration(days: 7));
    final endDate = date.add(const Duration(days: 7));

    return races.where((race) {
      return race.date.isAfter(startDate) && race.date.isBefore(endDate);
    }).toList();
  }

  Future<List<Fixture>> getLiveRaces() async {
    return getRacesByDate(DateTime.now());
  }

  Future<List<Fixture>> getAllRaces(int season) async {
    final safeSeason = season > _maxFreeSeason ? _maxFreeSeason : season;
    final data = await _client.get(
      SportType.formula1,
      '/races',
      params: {'season': safeSeason.toString()},
      cacheTtl: const Duration(minutes: 10),
    );
    return data
        .map((json) => Fixture.fromFormula1Json(json as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<Fixture>> getRacesByCompetition(int competitionId, int season) async {
    final safeSeason = season > _maxFreeSeason ? _maxFreeSeason : season;
    final data = await _client.get(
      SportType.formula1,
      '/races',
      params: {
        'competition': competitionId.toString(),
        'season': safeSeason.toString(),
      },
      cacheTtl: const Duration(minutes: 5),
    );
    return data
        .map((json) => Fixture.fromFormula1Json(json as Map<String, dynamic>))
        .toList();
  }

  Future<Fixture> getRaceById(int raceId) async {
    final data = await _client.get(
      SportType.formula1,
      '/races',
      params: {'id': raceId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    if (data.isEmpty) throw ApiException('Race not found');
    return Fixture.fromFormula1Json(data.first as Map<String, dynamic>);
  }

  // --- OpenF1 integration ---

  /// Map API-Sports session type to OpenF1 session_name.
  static String _mapSessionName(String apiSportsType) {
    final lower = apiSportsType.toLowerCase();
    if (lower.contains('race') && !lower.contains('sprint')) return 'Race';
    if (lower.contains('sprint') && lower.contains('qualifying')) return 'Sprint Qualifying';
    if (lower.contains('sprint')) return 'Sprint';
    if (lower.contains('1st qualifying')) return 'Qualifying';
    if (lower.contains('2nd qualifying')) return 'Qualifying';
    if (lower.contains('3rd qualifying')) return 'Qualifying';
    if (lower.contains('qualifying')) return 'Qualifying';
    if (lower.contains('1st practice')) return 'Practice 1';
    if (lower.contains('2nd practice')) return 'Practice 2';
    if (lower.contains('3rd practice')) return 'Practice 3';
    if (lower.contains('practice')) return 'Practice 1';
    return 'Race';
  }

  /// Look up the OpenF1 session key for this fixture.
  Future<int?> _lookupSessionKey(Fixture fixture) async {
    try {
      final country = fixture.league.country ?? '';
      final sessionType = fixture.awayTeam.name; // e.g. "Race", "1st Qualifying"
      final openF1Session = _mapSessionName(sessionType);
      final year = fixture.date.year;

      debugPrint('F1 lookup: $country / $sessionType -> OpenF1: $openF1Session (year=$year)');

      final response = await _openF1Client.get(
        Uri.parse('https://api.openf1.org/v1/sessions?year=$year&session_name=$openF1Session'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('F1 lookup: OpenF1 returned status ${response.statusCode}');
        return null;
      }

      final sessions = jsonDecode(response.body) as List?;
      if (sessions == null || sessions.isEmpty) {
        debugPrint('F1 lookup: No sessions found');
        return null;
      }

      debugPrint('F1 lookup: Found ${sessions.length} $openF1Session sessions');

      // Match by country name
      for (final s in sessions) {
        if (s is! Map<String, dynamic>) continue;
        final sessionCountry = s['country_name'] as String? ?? '';
        final location = s['location'] as String? ?? '';

        if (TeamMatching.teamsMatch(country, sessionCountry) ||
            TeamMatching.teamsMatch(country, location)) {
          final key = s['session_key'] as int?;
          debugPrint('F1 lookup: Matched $sessionCountry/$location, session_key=$key');
          return key;
        }
      }

      debugPrint('F1 lookup: No country match for "$country"');
      return null;
    } catch (e) {
      debugPrint('F1 lookup: Error - $e');
      return null;
    }
  }

  Future<List<FixtureEvent>> getF1EventsFromFixture(Fixture fixture) async {
    final sessionKey = await _lookupSessionKey(fixture);
    if (sessionKey == null) return [];
    return getF1Events(sessionKey);
  }

  Future<List<FixtureEvent>> getF1Events(int sessionKey) async {
    try {
      debugPrint('F1 events: Fetching for session_key=$sessionKey');

      // Fetch drivers, race control, and pit stops in parallel
      final results = await Future.wait([
        _openF1Client.get(Uri.parse('https://api.openf1.org/v1/drivers?session_key=$sessionKey')).timeout(const Duration(seconds: 10)),
        _openF1Client.get(Uri.parse('https://api.openf1.org/v1/race_control?session_key=$sessionKey')).timeout(const Duration(seconds: 10)),
        _openF1Client.get(Uri.parse('https://api.openf1.org/v1/pit?session_key=$sessionKey')).timeout(const Duration(seconds: 10)),
        _openF1Client.get(Uri.parse('https://api.openf1.org/v1/position?session_key=$sessionKey')).timeout(const Duration(seconds: 10)),
      ]);

      // Parse drivers → number-to-name map
      final driverMap = <int, Map<String, String>>{};
      if (results[0].statusCode == 200) {
        final drivers = jsonDecode(results[0].body) as List? ?? [];
        for (final d in drivers) {
          if (d is Map<String, dynamic>) {
            final num = d['driver_number'] as int?;
            if (num != null) {
              driverMap[num] = {
                'name': d['full_name'] as String? ?? '#$num',
                'team': d['team_name'] as String? ?? '',
              };
            }
          }
        }
      }
      debugPrint('F1 events: ${driverMap.length} drivers loaded');

      final events = <FixtureEvent>[];
      int order = 0;

      // Parse race control — filter to important events
      if (results[1].statusCode == 200) {
        final raceControl = jsonDecode(results[1].body) as List? ?? [];
        for (final rc in raceControl) {
          if (rc is! Map<String, dynamic>) continue;
          final category = rc['category'] as String? ?? '';
          final message = rc['message'] as String? ?? '';
          final flag = rc['flag'] as String?;

          // Only keep important events
          final isImportant = category == 'SafetyCar' ||
              (category == 'Flag' && (flag == 'RED' || flag == 'CHEQUERED')) ||
              message.contains('PENALTY') ||
              message.contains('BLACK AND WHITE') ||
              message.contains('DELETED');

          if (!isImportant) continue;

          events.add(FixtureEvent.fromF1RaceControlJson(rc, order++));
        }
      }
      debugPrint('F1 events: ${events.length} race control events');

      // Parse pit stops
      if (results[2].statusCode == 200) {
        final pits = jsonDecode(results[2].body) as List? ?? [];
        for (final pit in pits) {
          if (pit is! Map<String, dynamic>) continue;
          final driverNum = pit['driver_number'] as int?;
          final driver = driverMap[driverNum];
          events.add(FixtureEvent.fromF1PitJson(pit, driver, order++));
        }
      }
      debugPrint('F1 events: +pit stops = ${events.length} total');

      // Parse final positions (top 10)
      if (results[3].statusCode == 200) {
        final positions = jsonDecode(results[3].body) as List? ?? [];
        // Get the last position entry for each driver (final result)
        final finalPositions = <int, Map<String, dynamic>>{};
        for (final p in positions) {
          if (p is! Map<String, dynamic>) continue;
          final driverNum = p['driver_number'] as int?;
          if (driverNum != null) {
            finalPositions[driverNum] = p;
          }
        }
        // Sort by position and take top 10
        final sorted = finalPositions.entries.toList()
          ..sort((a, b) => (a.value['position'] as int? ?? 99).compareTo(b.value['position'] as int? ?? 99));

        for (final entry in sorted.take(10)) {
          final driver = driverMap[entry.key];
          events.add(FixtureEvent.fromF1PositionJson(entry.value, driver, order++));
        }
      }

      debugPrint('F1 events: Final total = ${events.length} events');

      // Sort by order (race control first, then pits chronologically, then results)
      events.sort((a, b) => (a.elapsed ?? 0).compareTo(b.elapsed ?? 0));
      return events;
    } catch (e) {
      debugPrint('F1 events: Error - $e');
      return [];
    }
  }
}
