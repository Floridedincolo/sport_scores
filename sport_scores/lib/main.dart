import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/favorites_provider.dart';
import 'providers/fixture_detail_provider.dart';
import 'providers/fixtures_provider.dart';
import 'providers/sport_provider.dart';
import 'services/api/api_client.dart';
import 'services/api/sport_api_factory.dart';
import 'services/background_bootstrap.dart';
import 'services/cache_service.dart';
import 'services/favorites_service.dart';
import 'services/live_monitor_service.dart';
import 'services/match_snapshot_service.dart';
import 'services/notification_service.dart';
import 'utils/api_rate_limiter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress 404 errors from missing team/league logos (already handled visually
  // via errorWidget / errorBuilder but still leak through FlutterError).
  FlutterError.onError = (details) {
    final exceptionStr = details.exception.toString();
    if (exceptionStr.contains('HttpException') &&
        exceptionStr.contains('statusCode: 404') &&
        exceptionStr.contains('media.api-sports.io')) {
      return;
    }
    FlutterError.presentError(details);
  };

  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final rateLimiter = ApiRateLimiter(prefs);
  final cacheService = CacheService();
  final apiClient = ApiClient(rateLimiter: rateLimiter, cache: cacheService);
  final apiFactory = SportApiFactory(apiClient);
  final favoritesService = FavoritesService();
  await favoritesService.init();
  final snapshotService = MatchSnapshotService();
  await snapshotService.init();

  // Initialize notifications
  await NotificationService.init();
  await NotificationService.requestPermissions();

  // Live monitor pentru meciurile favorite — rulează pe un Timer.periodic
  // pornit din SportScoresApp (foreground). Background-ul e configurat separat.
  final liveMonitor = LiveMonitorService.fromApiFactory(
    favorites: favoritesService,
    snapshots: snapshotService,
    apiFactory: apiFactory,
  );

  // Pornim și serviciul background (Android foreground service; pe iOS
  // sistemul decide când rulează — limitare a platformei).
  await configureAndStartBackgroundService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiRateLimiter>.value(value: rateLimiter),
        Provider<CacheService>.value(value: cacheService),
        Provider<SportApiFactory>.value(value: apiFactory),
        Provider<MatchSnapshotService>.value(value: snapshotService),
        Provider<LiveMonitorService>.value(value: liveMonitor),
        ChangeNotifierProvider(create: (_) => SportProvider()),
        ChangeNotifierProvider(create: (_) => FixturesProvider(apiFactory)),
        ChangeNotifierProvider(
            create: (_) => FixtureDetailProvider(apiFactory)),
        ChangeNotifierProvider(
            create: (_) =>
                FavoritesProvider(favoritesService, snapshotService)),
      ],
      child: const SportScoresApp(),
    ),
  );
}
