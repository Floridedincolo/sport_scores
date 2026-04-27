import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    // Pe Android 8+ canalele trebuie create explicit înainte de prima
    // notificare. Canalul `sport_scores_bg` este folosit de foreground
    // service-ul din background_bootstrap.dart pentru notificarea
    // persistentă; dacă nu există, startForeground crashează cu
    // "Bad notification for startForeground".
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'sport_scores_bg',
          'Sport Scores Background',
          description: 'Serviciu în fundal pentru meciurile favorite',
          importance: Importance.low,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          'match_updates',
          'Match Updates',
          description: 'Live match score updates',
          importance: Importance.high,
        ),
      );
    }
  }

  static Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> showMatchUpdate({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'match_updates',
        'Match Updates',
        channelDescription: 'Live match score updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  // ----- Helperi specifici pentru LiveMonitorService -----
  // Folosim offset-uri diferite pentru notification id astfel încât
  // evenimente diferite pe același meci să nu se suprascrie.
  static const int _idOffsetGoal = 1;
  static const int _idOffsetKickoff = 2;
  static const int _idOffsetStatus = 3;
  static const int _idOffsetIncident = 4;

  static int _notifId(int matchId, int offset) => matchId * 10 + offset;

  static Future<void> showGoal({
    required int matchId,
    required String homeTeam,
    required String awayTeam,
    required int homeScore,
    required int awayScore,
    required bool scoredByHome,
  }) async {
    final scorer = scoredByHome ? homeTeam : awayTeam;
    await showMatchUpdate(
      id: _notifId(matchId, _idOffsetGoal),
      title: 'GOL — $scorer',
      body: '$homeTeam $homeScore - $awayScore $awayTeam',
    );
  }

  static Future<void> showKickoff({
    required int matchId,
    required String displayName,
  }) async {
    await showMatchUpdate(
      id: _notifId(matchId, _idOffsetKickoff),
      title: 'A început meciul',
      body: displayName,
    );
  }

  static Future<void> showStatusChange({
    required int matchId,
    required String displayName,
    required String statusLabel,
  }) async {
    await showMatchUpdate(
      id: _notifId(matchId, _idOffsetStatus),
      title: statusLabel,
      body: displayName,
    );
  }

  static Future<void> showIncident({
    required int matchId,
    required String displayName,
    required String description,
  }) async {
    // Fiecare incident primește un id unic (timp + matchId) ca să putem
    // afișa mai multe cartonașe pe același meci.
    final uniqueId = _notifId(matchId, _idOffsetIncident) +
        DateTime.now().millisecondsSinceEpoch % 1000;
    await showMatchUpdate(
      id: uniqueId,
      title: description,
      body: displayName,
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Curăță toate notificările asociate unui meci (gol, kickoff, status).
  static Future<void> cancelAllForMatch(int matchId) async {
    await _plugin.cancel(_notifId(matchId, _idOffsetGoal));
    await _plugin.cancel(_notifId(matchId, _idOffsetKickoff));
    await _plugin.cancel(_notifId(matchId, _idOffsetStatus));
  }
}
