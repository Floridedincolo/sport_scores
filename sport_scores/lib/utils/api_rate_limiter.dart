import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiRateLimiter {
  static const _countKey = 'api_request_count';
  static const _dateKey = 'api_request_date';

  final SharedPreferences _prefs;

  ApiRateLimiter(this._prefs);

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  int get todayCount {
    final savedDate = _prefs.getString(_dateKey);
    if (savedDate != _today) return 0;
    return _prefs.getInt(_countKey) ?? 0;
  }

  int get remaining => ApiConstants.dailyRequestLimit - todayCount;

  bool get canMakeRequest => todayCount < ApiConstants.dailyRequestLimit;

  Future<void> recordRequest() async {
    final today = _today;
    final savedDate = _prefs.getString(_dateKey);

    if (savedDate != today) {
      await _prefs.setString(_dateKey, today);
      await _prefs.setInt(_countKey, 1);
    } else {
      await _prefs.setInt(_countKey, todayCount + 1);
    }
  }
}
