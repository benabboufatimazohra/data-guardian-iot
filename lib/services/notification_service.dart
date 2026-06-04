// lib/services/notification_service.dart
//
// Wraps flutter_local_notifications.
// Call NotificationService.instance.init() once in main().
// Then call .showAlert(...) whenever a threshold is breached.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Notification channel IDs ─────────────────────────────────────────────
  static const String _channelId   = 'dataguardian_alerts';
  static const String _channelName = 'DataGuardian Alerts';
  static const String _channelDesc = 'Critical sensor alerts from your ESP8266';

  // ── Notification IDs (stable so repeated alerts update, not stack) ───────
  static const int idTemperature = 1001;
  static const int idWaterLeak   = 1002;
  static const int idHumidity    = 1003;

  // ─────────────────────────────────────────────────────────────────────────
  // init() — call once in main() before runApp()
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);

    // Android 8+ requires a notification channel.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
          ),
        );

    // Request permissions on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // showAlert() — display an OS-level notification
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> showAlert({
    required int    id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  // Convenience wrappers ─────────────────────────────────────────────────────

  Future<void> showTemperatureAlert(double temp) => showAlert(
    id:    idTemperature,
    title: '🌡️ High Temperature Detected',
    body:  'Temperature is ${temp.toStringAsFixed(1)}°C — exceeds safe limit.',
  );

  Future<void> showWaterLeakAlert(double pct) => showAlert(
    id:    idWaterLeak,
    title: '💧 Water Leakage Detected',
    body:  'Water level at ${pct.toStringAsFixed(0)}% — check the sensor immediately.',
  );

  Future<void> showHumidityAlert({required bool tooLow, required double humidity}) =>
      showAlert(
        id:    idHumidity,
        title: tooLow ? '🌵 Low Humidity Warning' : '💦 High Humidity Warning',
        body:  'Humidity is ${humidity.toStringAsFixed(0)}% — '
               '${tooLow ? 'below safe minimum.' : 'above safe maximum.'}',
      );
}
