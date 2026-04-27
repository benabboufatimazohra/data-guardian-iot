import 'package:flutter/material.dart';
import 'package:data_monitoring_app/screens/login_screen.dart';
import 'package:data_monitoring_app/screens/dashboard_screen.dart';
import 'package:data_monitoring_app/screens/alerts_screen.dart';
import 'package:data_monitoring_app/screens/device_detail_screen.dart';
import 'package:data_monitoring_app/screens/history_screen.dart';
import 'package:data_monitoring_app/screens/alert_analysis_screen.dart';
import 'package:data_monitoring_app/screens/settings_screen.dart';

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
          indicatorColor: const Color(0xFF3C83F6).withOpacity(0.15),
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
      // ── Starting screen ──────────────────────────────────────────────────
      initialRoute: '/login',
      // ── All app routes ───────────────────────────────────────────────────
      // Like a URL map: any screen can navigate to any other by name.
      //   Navigator.pushNamed(context, '/dashboard')  → go to dashboard
      //   Navigator.pushReplacementNamed(ctx, '/login') → replace current
      //   Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false)
      //      → logout: clear entire back stack and go to login
      routes: {
        '/login':          (ctx) => const LoginScreen(),
        '/dashboard':      (ctx) => const DashboardScreen(),
        '/alerts':         (ctx) => const AlertsScreen(),
        '/alert-analysis': (ctx) => const AlertAnalysisScreen(),
        '/device-detail':  (ctx) => const DeviceDetailScreen(),
        '/history':        (ctx) => const HistoryScreen(),
        '/settings':       (ctx) => const SettingsScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('404: ${settings.name}')),
        ),
      ),
    );
  }
}