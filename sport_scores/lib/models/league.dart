import 'sport.dart';

class League {
  final int id;
  final String name;
  final String? country;
  final String? logo;
  final String? countryFlag;
  final SportType sport;
  final int? currentSeason;

  const League({
    required this.id,
    required this.name,
    this.country,
    this.logo,
    this.countryFlag,
    required this.sport,
    this.currentSeason,
  });

  factory League.fromFootballJson(Map<String, dynamic> json) {
    final league = json['league'] as Map<String, dynamic>? ?? json;
    final country = json['country'] as Map<String, dynamic>?;
    final seasons = json['seasons'] as List?;

    int? currentSeason;
    if (seasons != null && seasons.isNotEmpty) {
      for (final s in seasons) {
        if (s['current'] == true) {
          currentSeason = s['year'] as int?;
          break;
        }
      }
    }

    return League(
      id: league['id'] as int,
      name: league['name'] as String? ?? 'Unknown',
      country: country?['name'] as String?,
      logo: league['logo'] as String?,
      countryFlag: country?['flag'] as String?,
      sport: SportType.football,
      currentSeason: currentSeason,
    );
  }

  factory League.fromBasketballJson(Map<String, dynamic> json) {
    final id = json['id'];

    // Season can be int (2025) or String ("2025-2026")
    int? currentSeason;
    final seasons = json['seasons'] as List?;
    if (seasons != null && seasons.isNotEmpty) {
      final rawSeason = seasons.last['season'];
      if (rawSeason is int) {
        currentSeason = rawSeason;
      } else if (rawSeason is String) {
        currentSeason = int.tryParse(rawSeason.split('-').first);
      }
    }

    return League(
      id: id is String ? int.tryParse(id) ?? 0 : (id as int? ?? 0),
      name: json['name'] as String? ?? 'Unknown',
      country: json['country']?['name'] as String?,
      logo: json['logo'] as String?,
      countryFlag: json['country']?['flag'] as String?,
      sport: SportType.basketball,
      currentSeason: currentSeason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is League && id == other.id && sport == other.sport;

  @override
  int get hashCode => id.hashCode ^ sport.hashCode;
}
