import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite.dart';
import '../models/sport.dart';

/// Persistă lista de favorite într-un `SharedPreferences` (fișier nativ
/// Android / NSUserDefaults iOS). Am ales SharedPreferences în locul Hive
/// fiindcă Hive blochează boxa de fișier pe izolatul care a deschis-o:
/// izolatul de background al `flutter_background_service` nu putea citi
/// favoritele cât timp app-ul era deschis.
class FavoritesService {
  static const _prefsKey = 'favorites_v1';
  late SharedPreferences _prefs;
  final Map<String, Favorite> _cache = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
    _loadFromPrefs();
  }

  /// Re-citește din SharedPreferences. Necesar în izolatul de background
  /// între cicluri, ca să vadă favoritele adăugate/șterse în UI isolate.
  Future<void> reload() async {
    await _prefs.reload();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    _cache.clear();
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final fav = _fromMap(item as Map<String, dynamic>);
        _cache[fav.compositeKey] = fav;
      }
    } catch (_) {
      _cache.clear();
    }
  }

  Future<void> _persist() async {
    final list = _cache.values.map(_toMap).toList();
    await _prefs.setString(_prefsKey, jsonEncode(list));
  }

  List<Favorite> getAll() => _cache.values.toList();

  bool isFavorite(SportType sport, int id) {
    return _cache.values.any(
      (f) => f.sport == sport && f.entityId == id,
    );
  }

  Future<void> add(Favorite favorite) async {
    _cache[favorite.compositeKey] = favorite;
    await _persist();
  }

  Future<void> remove(SportType sport, FavoriteType type, int id) async {
    final key = '${sport.index}_${type.index}_$id';
    _cache.remove(key);
    await _persist();
  }

  Future<void> toggle(Favorite favorite) async {
    if (_cache.containsKey(favorite.compositeKey)) {
      _cache.remove(favorite.compositeKey);
    } else {
      _cache[favorite.compositeKey] = favorite;
    }
    await _persist();
  }

  Map<String, dynamic> _toMap(Favorite f) => {
        'sportIndex': f.sportIndex,
        'typeIndex': f.typeIndex,
        'entityId': f.entityId,
        'displayName': f.displayName,
        'logo': f.logo,
      };

  Favorite _fromMap(Map<String, dynamic> m) => Favorite(
        sportIndex: m['sportIndex'] as int,
        typeIndex: m['typeIndex'] as int,
        entityId: m['entityId'] as int,
        displayName: m['displayName'] as String,
        logo: m['logo'] as String?,
      );
}
