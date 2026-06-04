// lib/main.dart
//
// CHANGES:
//   1. main() is now async — loads SharedPreferences (ApiConfig.load()) and
//      initialises flutter_local_notifications before runApp().
//   2. Imports ExportScreen (was missing in the original).

import 'package:flutter/material.dart';
import 'package:data_guardian/screens/login_screen.dart';
import 'package:data_guardian/screens/dashboard_screen.dart';
import 'package:data_guardian/screens/alerts_screen.dart';
import 'package:data_guardian/screens/device_detail_screen.dart';
import 'package:data_guardian/screens/history_screen.dart';
import 'package:data_guardian/screens/alert_analysis_screen.dart';
import 'package:data_guardian/screens/settings_screen.dart';
import 'package:data_guardian/screens/export_screen.dart';
import 'package:data_guardian/config/api_config.dart';
import 'package:data_guardian/services/notification_service.dart';

Future<void> main() async {
  // Required before any async work in main()
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved ESP URL from SharedPreferences
  await ApiConfig.load();

  // Initialise notification plugin (requests permissions on Android 13+)
  await NotificationService.instance.init();

  runApp(const DataGuardianApp());
}

class DataGuardianApp extends StatelessWidget {
  const DataGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataGuardian IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101722),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3C83F6),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A2332),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A2332),
          indicatorColor: const Color(0xFF3C83F6).withValues(alpha: 0.15),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101722),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF1F5F9),
          ),
          iconTheme: IconThemeData(color: Color(0xFF94A3B8)),
        ),
        fontFamily: 'Inter',
      ),
      initialRoute: '/login',
      routes: {
        '/login':          (ctx) => const LoginScreen(),
        '/dashboard':      (ctx) => const DashboardScreen(),
        '/alerts':         (ctx) => const AlertsScreen(),
        '/alert-analysis': (ctx) => const AlertAnalysisScreen(),
        '/device-detail':  (ctx) => const DeviceDetailScreen(),
        '/history':        (ctx) => const HistoryScreen(),
        '/settings':       (ctx) => const SettingsScreen(),
        '/export':         (ctx) => const ExportScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('404: ${settings.name}')),
        ),
      ),
    );
  }
}
