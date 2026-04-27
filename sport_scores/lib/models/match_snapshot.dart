import 'package:hive/hive.dart';

part 'match_snapshot.g.dart';

/// Ultima stare observată pentru un meci favorit.
/// Folosit de [LiveMonitorService] pentru a detecta schimbări (gol, status,
/// incidente noi) la fiecare ciclu de polling.
@HiveType(typeId: 1)
class MatchSnapshot extends HiveObject {
  @HiveField(0)
  final int sportIndex;

  @HiveField(1)
  final int matchId;

  @HiveField(2)
  final int? homeScore;

  @HiveField(3)
  final int? awayScore;

  /// Codul scurt al statusului raportat de API (ex. "NS", "1H", "HT", "FT").
  /// Stocat ca string ca să fim robuști la adăugări în enum-ul FixtureStatus.
  @HiveField(4)
  final String statusCode;

  /// ID-urile evenimentelor deja notificate, ca să nu re-notificăm la
  /// următorul ciclu cartonașele pe care le-am văzut deja.
  @HiveField(5)
  final List<String> notifiedEventIds;

  @HiveField(6)
  final DateTime lastUpdated;

  MatchSnapshot({
    required this.sportIndex,
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    required this.statusCode,
    required this.notifiedEventIds,
    required this.lastUpdated,
  });

  static String keyFor(int sportIndex, int matchId) => '${sportIndex}_$matchId';

  String get compositeKey => keyFor(sportIndex, matchId);

  MatchSnapshot copyWith({
    int? homeScore,
    int? awayScore,
    String? statusCode,
    List<String>? notifiedEventIds,
    DateTime? lastUpdated,
  }) {
    return MatchSnapshot(
      sportIndex: sportIndex,
      matchId: matchId,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      statusCode: statusCode ?? this.statusCode,
      notifiedEventIds: notifiedEventIds ?? this.notifiedEventIds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
