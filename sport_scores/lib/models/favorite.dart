import 'package:hive/hive.dart';
import 'sport.dart';

part 'favorite.g.dart';

@HiveType(typeId: 0)
class Favorite extends HiveObject {
  @HiveField(0)
  final int sportIndex;

  @HiveField(1)
  final int typeIndex;

  @HiveField(2)
  final int entityId;

  @HiveField(3)
  final String displayName;

  @HiveField(4)
  final String? logo;

  Favorite({
    required this.sportIndex,
    required this.typeIndex,
    required this.entityId,
    required this.displayName,
    this.logo,
  });

  SportType get sport => SportType.values[sportIndex];
  FavoriteType get type => FavoriteType.values[typeIndex];

  String get compositeKey => '${sportIndex}_${typeIndex}_$entityId';

  factory Favorite.match({
    required SportType sport,
    required int matchId,
    required String displayName,
  }) {
    return Favorite(
      sportIndex: sport.index,
      typeIndex: FavoriteType.match.index,
      entityId: matchId,
      displayName: displayName,
    );
  }

  factory Favorite.league({
    required SportType sport,
    required int leagueId,
    required String displayName,
    String? logo,
  }) {
    return Favorite(
      sportIndex: sport.index,
      typeIndex: FavoriteType.league.index,
      entityId: leagueId,
      displayName: displayName,
      logo: logo,
    );
  }
}

enum FavoriteType { match, league }
