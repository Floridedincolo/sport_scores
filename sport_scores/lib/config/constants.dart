import '../models/sport.dart';

class ApiConstants {
  static const String apiKey = '5bfb3ad4c897a9f443abbd07d691fdec';
  static const String authHeader = 'x-apisports-key';
  static const int dailyRequestLimit = 100;

  static const Map<SportType, String> baseUrls = {
    SportType.football: 'https://v3.football.api-sports.io',
    SportType.basketball: 'https://v1.basketball.api-sports.io',
    SportType.hockey: 'https://v1.hockey.api-sports.io',
    SportType.baseball: 'https://v1.baseball.api-sports.io',
    SportType.formula1: 'https://v1.formula-1.api-sports.io',
    SportType.handball: 'https://v1.handball.api-sports.io',
    // Tennis uses SportsAPIPro only (no API-Sports endpoint)
  };

  // The Odds API (https://the-odds-api.com) — fallback source used when
  // primary API-Sports returns no events. Free tier: 500 req/month.
  // Register at https://the-odds-api.com and paste your key below.
  static const String oddsApiKey = 'c8e219c8971b77d5094ce7b4e570c86e';

  /// Primary league sport keys for The Odds API. Extend as needed.
  static const Map<SportType, String> oddsApiSportKeys = {
    SportType.basketball: 'basketball_nba',
    SportType.baseball: 'baseball_mlb',
    SportType.hockey: 'icehockey_nhl',
    // Football/soccer has many leagues in the Odds API (soccer_epl,
    // soccer_spain_la_liga, ...) — football_api.dart already works, so no
    // fallback is wired for it here. Handball and F1 are not supported
    // by The Odds API.
  };
}
