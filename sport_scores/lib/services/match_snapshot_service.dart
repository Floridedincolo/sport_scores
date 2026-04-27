import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_snapshot.dart';

/// Persistă ultima stare cunoscută a fiecărui meci favorit, astfel încât
/// [LiveMonitorService] să poată compara cu noile date de la API și detecta
/// schimbări între cicluri (inclusiv între rulări ale aplicației).
///
/// Folosim SharedPreferences (cheie per snapshot) în locul Hive pentru că
/// izolatul de background trebuie să poată citi/scrie aceiași snapshot-uri
/// ca UI-ul, iar Hive blochează fișierul per-izolat.
class MatchSnapshotService {
  static const _prefix = 'match_snapshot_';
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
  }

  /// Re-citește din SharedPreferences. Chemată în izolatul background înainte
  /// de fiecare ciclu ca să vadă scrierile făcute de UI isolate (și invers).
  Future<void> reload() async {
    await _prefs.reload();
  }

  String _keyFor(int sportIndex, int matchId) =>
      '$_prefix${sportIndex}_$matchId';

  MatchSnapshot? get(int sportIndex, int matchId) {
    final raw = _prefs.getString(_keyFor(sportIndex, matchId));
    if (raw == null) return null;
    try {
      return _fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MatchSnapshot snapshot) async {
    await _prefs.setString(
      _keyFor(snapshot.sportIndex, snapshot.matchId),
      jsonEncode(_toMap(snapshot)),
    );
  }

  Future<void> remove(int sportIndex, int matchId) async {
    await _prefs.remove(_keyFor(sportIndex, matchId));
  }

  List<MatchSnapshot> getAll() {
    final out = <MatchSnapshot>[];
    for (final k in _prefs.getKeys()) {
      if (!k.startsWith(_prefix)) continue;
      final raw = _prefs.getString(k);
      if (raw == null) continue;
      try {
        out.add(_fromMap(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Map<String, dynamic> _toMap(MatchSnapshot s) => {
        'sportIndex': s.sportIndex,
        'matchId': s.matchId,
        'homeScore': s.homeScore,
        'awayScore': s.awayScore,
        'statusCode': s.statusCode,
        'notifiedEventIds': s.notifiedEventIds,
        'lastUpdated': s.lastUpdated.toIso8601String(),
      };

  MatchSnapshot _fromMap(Map<String, dynamic> m) => MatchSnapshot(
        sportIndex: m['sportIndex'] as int,
        matchId: m['matchId'] as int,
        homeScore: m['homeScore'] as int?,
        awayScore: m['awayScore'] as int?,
        statusCode: m['statusCode'] as String,
        notifiedEventIds: (m['notifiedEventIds'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        lastUpdated: DateTime.parse(m['lastUpdated'] as String),
      );
}
