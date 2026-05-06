import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'screens/home/home_screen.dart';
import 'services/live_monitor_service.dart';

/// Frecvența de polling pentru meciurile favorite cât timp app-ul e în foreground.
const Duration _foregroundPollInterval = Duration(minutes: 3);

class SportScoresApp extends StatefulWidget {
  const SportScoresApp({super.key});

  @override
  State<SportScoresApp> createState() => _SportScoresAppState();
}

class _SportScoresAppState extends State<SportScoresApp>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pornire după primul frame ca să avem acces la Provider.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPolling());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopPolling();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _startPolling() {
    if (_pollTimer?.isActive ?? false) return;
    final monitor = context.read<LiveMonitorService>();
    // Rulăm imediat o dată ca să prindem rapid tranzițiile când redeschizi app-ul.
    monitor.checkOnce();
    _pollTimer = Timer.periodic(
      _foregroundPollInterval,
      (_) => monitor.checkOnce(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sport Scores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
