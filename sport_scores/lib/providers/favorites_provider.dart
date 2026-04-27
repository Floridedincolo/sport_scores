import 'package:flutter/foundation.dart';
import '../models/favorite.dart';
import '../models/sport.dart';
import '../services/favorites_service.dart';
import '../services/match_snapshot_service.dart';
import '../services/notification_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _service;
  final MatchSnapshotService _snapshots;

  FavoritesProvider(this._service, this._snapshots);

  List<Favorite> get favorites => _service.getAll();

  List<Favorite> get matchFavorites =>
      favorites.where((f) => f.type == FavoriteType.match).toList();

  List<Favorite> get leagueFavorites =>
      favorites.where((f) => f.type == FavoriteType.league).toList();

  bool isFavorite(SportType sport, int id) => _service.isFavorite(sport, id);

  Future<void> toggle(Favorite favorite) async {
    final wasFavorited =
        _service.isFavorite(favorite.sport, favorite.entityId);
    await _service.toggle(favorite);

    // La de-favorizarea unui meci, curățăm snapshot-ul persistent și orice
    // notificări afișate pentru el, ca să nu mai primim update-uri.
    if (wasFavorited && favorite.type == FavoriteType.match) {
      await _snapshots.remove(favorite.sportIndex, favorite.entityId);
      await NotificationService.cancelAllForMatch(favorite.entityId);
    }

    notifyListeners();
  }
}
