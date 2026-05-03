// lib/main.dart
//
// ERREURS CORRIGÉES :
//   1. undefined_method 'ExportScreen'
//      → ExportScreen n'était pas importé.
//        Solution : ajouter l'import de export_screen.dart.
//
//   2. deprecated_member_use 'withOpacity'
//      → withOpacity() est déprécié depuis Flutter 3.x.
//        Solution : remplacé par .withValues(alpha: 0.15).

import 'package:flutter/material.dart';
import 'package:data_monitoring_app/screens/login_screen.dart';
import 'package:data_monitoring_app/screens/dashboard_screen.dart';
import 'package:data_monitoring_app/screens/alerts_screen.dart';
import 'package:data_monitoring_app/screens/device_detail_screen.dart';
import 'package:data_monitoring_app/screens/history_screen.dart';
import 'package:data_monitoring_app/screens/alert_analysis_screen.dart';
import 'package:data_monitoring_app/screens/settings_screen.dart';
import 'package:data_monitoring_app/screens/export_screen.dart'; // ← AJOUTÉ

void main() {
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
          // withValues(alpha:) remplace withOpacity() déprécié
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
        '/export':         (ctx) => const ExportScreen(), // ← const ajouté
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('404: ${settings.name}')),
        ),
      ),
    );
  }
}
