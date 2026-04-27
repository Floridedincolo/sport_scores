class _CachedEntry {
  final dynamic data;
  final DateTime timestamp;

  _CachedEntry(this.data) : timestamp = DateTime.now();

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }
}

class CacheService {
  final Map<String, _CachedEntry> _cache = {};

  dynamic get(String key, Duration ttl) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired(ttl)) return null;
    return entry.data;
  }

  void put(String key, dynamic data) {
    _cache[key] = _CachedEntry(data);
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void clearAll() {
    _cache.clear();
  }
}
