import '../../models/sport.dart';
import 'api_client.dart';
import 'football_api.dart';
import 'basketball_api.dart';
import 'hockey_api.dart';
import 'baseball_api.dart';
import 'formula1_api.dart';
import 'handball_api.dart';
import 'espn_standings_client.dart';
import 'odds_api_client.dart';
import 'sportsapipro_client.dart';

class SportApiFactory {
  final ApiClient _client;
  final Map<SportType, dynamic> _cache = {};
  final SportsApiProClient sportsApiPro = SportsApiProClient();
  final OddsApiClient oddsApi = OddsApiClient();
  final EspnStandingsClient espnStandings = EspnStandingsClient();

  SportApiFactory(this._client);

  FootballApi get football {
    return _cache.putIfAbsent(
        SportType.football, () => FootballApi(_client)) as FootballApi;
  }

  BasketballApi get basketball {
    return _cache.putIfAbsent(
        SportType.basketball,
        () => BasketballApi(_client, oddsApi: oddsApi)) as BasketballApi;
  }

  HockeyApi get hockey {
    return _cache.putIfAbsent(
        SportType.hockey,
        () => HockeyApi(_client, oddsApi: oddsApi)) as HockeyApi;
  }

  BaseballApi get baseball {
    return _cache.putIfAbsent(
        SportType.baseball,
        () => BaseballApi(_client, oddsApi: oddsApi)) as BaseballApi;
  }

  Formula1Api get formula1 {
    return _cache.putIfAbsent(
        SportType.formula1, () => Formula1Api(_client)) as Formula1Api;
  }

  HandballApi get handball {
    return _cache.putIfAbsent(
        SportType.handball, () => HandballApi(_client)) as HandballApi;
  }
}
