import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/standing_row.dart';

/// Free fallback for league standings using ESPN's public site API.
/// No auth, no season-tier restrictions — covers current season for major
/// soccer / NBA / NHL / MLB leagues.
class EspnStandingsClient {
  final http.Client _client = http.Client();

  /// Map API-Sports football league IDs → ESPN soccer slugs.
  static const Map<int, String> _footballSlugs = {
    39: 'eng.1', // Premier League
    40: 'eng.2', // Championship
    140: 'esp.1', // La Liga
    141: 'esp.2',
    78: 'ger.1', // Bundesliga
    79: 'ger.2',
    135: 'ita.1', // Serie A
    136: 'ita.2',
    61: 'fra.1', // Ligue 1
    62: 'fra.2',
    88: 'ned.1', // Eredivisie
    94: 'por.1', // Primeira Liga
    144: 'bel.1',
    203: 'tur.1',
    283: 'rou.1', // Superliga României
    2: 'uefa.champions',
    3: 'uefa.europa',
    848: 'uefa.europa.conf',
    253: 'usa.1', // MLS
    71: 'bra.1', // Brasileirão
    128: 'arg.1', // Liga Profesional
  };

  static String? footballSlug(int leagueId) => _footballSlugs[leagueId];

  Future<List<StandingRow>> getFootballStandings(int leagueId) async {
    final slug = _footballSlugs[leagueId];
    if (slug == null) return [];
    return _fetch('soccer/$slug');
  }

  Future<List<StandingRow>> getNbaStandings() => _fetch('basketball/nba');
  Future<List<StandingRow>> getNhlStandings() => _fetch('hockey/nhl');
  Future<List<StandingRow>> getMlbStandings() => _fetch('baseball/mlb');

  Future<List<StandingRow>> _fetch(String path) async {
    try {
      final url =
          'https://site.api.espn.com/apis/v2/sports/$path/standings?level=3';
      final res =
          await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('ESPN standings: HTTP ${res.statusCode} for $path');
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return _parse(body);
    } catch (e) {
      debugPrint('ESPN standings error: $e');
      return [];
    }
  }

  List<StandingRow> _parse(Map<String, dynamic> body) {
    final rows = <StandingRow>[];

    void parseEntries(List entries, String? group) {
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;
        final team = entry['team'] as Map<String, dynamic>? ?? {};
        final stats = entry['stats'] as List? ?? [];
        int? statInt(String name) {
          for (final s in stats) {
            if (s is Map<String, dynamic> && s['name'] == name) {
              final v = s['value'];
              if (v is num) return v.toInt();
              if (v is String) return int.tryParse(v);
            }
          }
          return null;
        }

        final logos = team['logos'] as List?;
        String? logo;
        if (logos != null && logos.isNotEmpty) {
          final first = logos[0];
          if (first is Map<String, dynamic>) logo = first['href'] as String?;
        }

        rows.add(StandingRow(
          rank: statInt('rank') ?? rows.length + 1,
          teamId: int.tryParse(team['id']?.toString() ?? '') ?? 0,
          teamName: team['displayName'] as String? ??
              team['name'] as String? ??
              '?',
          teamLogo: logo,
          played: statInt('gamesPlayed') ?? 0,
          win: statInt('wins'),
          draw: statInt('ties'),
          lose: statInt('losses'),
          goalsFor: statInt('pointsFor'),
          goalsAgainst: statInt('pointsAgainst'),
          points: statInt('points'),
          group: group,
        ));
      }
    }

    void visit(dynamic node) {
      if (node is Map<String, dynamic>) {
        final standings = node['standings'];
        if (standings is Map<String, dynamic>) {
          final entries = standings['entries'];
          if (entries is List) {
            parseEntries(entries, node['name'] as String?);
          }
        }
        final children = node['children'];
        if (children is List) {
          for (final c in children) {
            visit(c);
          }
        }
      }
    }

    visit(body);
    return rows;
  }
}
