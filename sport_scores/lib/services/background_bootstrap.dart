import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/sport_api_factory.dart';
import 'cache_service.dart';
import 'favorites_service.dart';
import 'live_monitor_service.dart';
import 'match_snapshot_service.dart';
import 'notification_service.dart';
import '../utils/api_rate_limiter.dart';

const String _bgNotificationChannelId = 'sport_scores_bg';
const int _bgNotificationId = 7771;

/// Configurează și pornește serviciul background care rulează `checkOnce` la 2 min.
/// Pe Android rulează ca foreground service (notificare persistentă).
/// Pe iOS `onBackground` este chemat oportun de sistem (nu la intervale precise).
Future<void> configureAndStartBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: _bgNotificationChannelId,
      initialNotificationTitle: 'Sport Scores',
      initialNotificationContent: 'Urmărim meciurile tale favorite',
      foregroundServiceNotificationId: _bgNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false, // iOS nu permite polling fiabil la 2 min în background
      onForeground: _onStart,
      onBackground: _onIosBackground,
    ),
  );
  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  // iOS cheamă callback-ul oportun; rulăm o singură iterație și returnăm.
  DartPluginRegistrant.ensureInitialized();
  await _runSingleCheck();
  return true;
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  // Inițializează bindings în izolatul background pentru plugin-uri.
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Pornim un ciclu imediat, apoi unul la fiecare 2 minute.
  await _runSingleCheck();
  Timer.periodic(const Duration(minutes: 2), (_) async {
    await _runSingleCheck();
  });

  service.on('stopService').listen((_) {
    service.stopSelf();
  });
}

/// Rulează o iterație completă în izolatul background.
/// Re-inițializează serviciile minime de care avem nevoie (nu avem acces la
/// Providers din izolatul principal).
Future<void> _runSingleCheck() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rateLimiter = ApiRateLimiter(prefs);
    final cache = CacheService();
    final apiClient = ApiClient(rateLimiter: rateLimiter, cache: cache);
    final apiFactory = SportApiFactory(apiClient);
    final favorites = FavoritesService();
    await favorites.init();
    final snapshots = MatchSnapshotService();
    await snapshots.init();

    await NotificationService.init();

    final monitor = LiveMonitorService.fromApiFactory(
      favorites: favorites,
      snapshots: snapshots,
      apiFactory: apiFactory,
    );
    await monitor.checkOnce();
  } catch (e, st) {
    // În izolatul background nu avem UI; log simplu.
    debugPrint('[BackgroundBootstrap] checkOnce error: $e\n$st');
  }
}
