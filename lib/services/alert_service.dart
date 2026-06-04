// lib/services/alert_service.dart
//
// ISSUE 1 FIX:
//
// Previous behaviour:
//   - Alerts were created with unique timestamped IDs on every breach.
//   - No code path ever called DatabaseHelper.resolveAlert().
//   - Result: alerts accumulated forever and never resolved.
//
// New behaviour:
//   - Each alert type has a STABLE ID ('live-temp-critical', 'live-water', etc.)
//   - evaluate() is called after every ESP poll.
//   - If a condition is ACTIVE   → upsert an UNRESOLVED alert in SQLite.
//   - If a condition is RESOLVED → call DatabaseHelper.resolveAlert(stableId).
//   - Acknowledging (tapping the dialog button) only records a local flag.
//     It does NOT change is_resolved in SQLite.
//
// Alert lifecycle:
//   sensor abnormal → alert created (is_resolved = 0)
//   user taps Acknowledge → dialog closes, alert stays ACTIVE in DB
//   sensor returns to normal → alert automatically resolved (is_resolved = 1)

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';

// ── Thresholds ────────────────────────────────────────────────────────────────
class AlertThresholds {
  static const double tempCritical = 35.0;
  static const double tempWarning  = 30.0;
  static const double humidityLow  = 20.0;
  static const double humidityHigh = 80.0;
  static const double waterHighPct = 10.0;
}

// ── Stable alert IDs (one per condition type) ─────────────────────────────────
//
// Using fixed IDs is essential for auto-resolution.
// DatabaseHelper.insertAlert uses ConflictAlgorithm.replace, so upserting
// with the same ID either creates or updates the row — never duplicates.
// DatabaseHelper.resolveAlert(id) sets is_resolved=1 for that specific row.
//
class _AlertId {
  static const String tempCritical = 'live-temp-critical';
  static const String tempWarning  = 'live-temp-warning';
  static const String water        = 'live-water';
  static const String humLow       = 'live-hum-low';
  static const String humHigh      = 'live-hum-high';
}

class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  // ── Notification cooldown — prevent OS notification spam ──────────────────
  // Resolution and DB upsert happen on every poll (no cooldown).
  // OS notifications are throttled to once per minute per type.
  final Map<String, DateTime> _notifCooldown = {};
  static const Duration _notifInterval = Duration(minutes: 1);

  bool _notifReady(String key) {
    final last = _notifCooldown[key];
    if (last == null) return true;
    return DateTime.now().difference(last) >= _notifInterval;
  }

  void _markNotifSent(String key) => _notifCooldown[key] = DateTime.now();

  // ── Dialog deduplication — avoid stacking dialogs ──────────────────────────
  final Set<String> _dialogShown = {};

  // ─────────────────────────────────────────────────────────────────────────
  // evaluate()
  //   Called after every successful ESP poll by EspService.
  //   Evaluates ALL conditions on every call. No global cooldown.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> evaluate(EnvironmentData data, {BuildContext? context}) async {
    await _evaluateTemperature(data, context: context);
    await _evaluateWater(data, context: context);
    await _evaluateHumidity(data, context: context);
  }

  // ── Temperature ───────────────────────────────────────────────────────────
  Future<void> _evaluateTemperature(EnvironmentData data,
      {BuildContext? context}) async {
    final temp = data.temperature;

    if (temp >= AlertThresholds.tempCritical) {
      // ── ACTIVE: critical ─────────────────────────────────────────────────
      // Also resolve warning if it was active (critical supersedes warning)
      await _resolveIfActive(_AlertId.tempWarning);

      await _upsertActive(
        id:       _AlertId.tempCritical,
        severity: AlertSeverity.critical,
        title:    'High Temperature Detected: ${temp.toStringAsFixed(1)}°C',
        data:     data,
      );
      if (_notifReady(_AlertId.tempCritical)) {
        _markNotifSent(_AlertId.tempCritical);
        await NotificationService.instance.showTemperatureAlert(temp);
        _maybeShowDialog(
          context:  context,
          key:      _AlertId.tempCritical,
          title:    '🌡️ Critical Temperature',
          message:  'Temperature is ${temp.toStringAsFixed(1)}°C\n'
                    'Threshold: ${AlertThresholds.tempCritical}°C\n\n'
                    'Check the cooling system immediately.',
          severity: AlertSeverity.critical,
        );
      }

    } else if (temp >= AlertThresholds.tempWarning) {
      // ── ACTIVE: warning ──────────────────────────────────────────────────
      // If critical was previously active, resolve it
      await _resolveIfActive(_AlertId.tempCritical);

      await _upsertActive(
        id:       _AlertId.tempWarning,
        severity: AlertSeverity.warning,
        title:    'Temperature Warning: ${temp.toStringAsFixed(1)}°C',
        data:     data,
      );
      if (_notifReady(_AlertId.tempWarning)) {
        _markNotifSent(_AlertId.tempWarning);
        await NotificationService.instance.showAlert(
          id:    NotificationService.idTemperature,
          title: '⚠️ Temperature Warning',
          body:  '${temp.toStringAsFixed(1)}°C — approaching critical level.',
        );
      }

    } else {
      // ── RESOLVED: temperature is normal ──────────────────────────────────
      await _resolveIfActive(_AlertId.tempCritical);
      await _resolveIfActive(_AlertId.tempWarning);
      // Reset dialog dedup so next breach shows dialog again
      _dialogShown.remove(_AlertId.tempCritical);
      _dialogShown.remove(_AlertId.tempWarning);
    }
  }

  // ── Water ─────────────────────────────────────────────────────────────────
  Future<void> _evaluateWater(EnvironmentData data,
      {BuildContext? context}) async {
    final waterTriggered = data.waterLeakDetected ||
        data.waterLevelPercent >= AlertThresholds.waterHighPct;

    if (waterTriggered) {
      // ── ACTIVE ───────────────────────────────────────────────────────────
      await _upsertActive(
        id:       _AlertId.water,
        severity: AlertSeverity.critical,
        title:    'Water Leakage Detected — '
                  '${data.waterLevelPercent.toStringAsFixed(0)}%',
        data:     data,
      );
      if (_notifReady(_AlertId.water)) {
        _markNotifSent(_AlertId.water);
        await NotificationService.instance
            .showWaterLeakAlert(data.waterLevelPercent);
        _maybeShowDialog(
          context:  context,
          key:      _AlertId.water,
          title:    '💧 Water Leakage Detected',
          message:  'Water sensor level: '
                    '${data.waterLevelPercent.toStringAsFixed(0)}%\n'
                    '(ADC raw: ${data.waterLevelRaw})\n\n'
                    'Inspect the area immediately.',
          severity: AlertSeverity.critical,
        );
      }
    } else {
      // ── RESOLVED: no water detected ───────────────────────────────────────
      await _resolveIfActive(_AlertId.water);
      _dialogShown.remove(_AlertId.water);
    }
  }

  // ── Humidity ─────────────────────────────────────────────────────────────
  Future<void> _evaluateHumidity(EnvironmentData data,
      {BuildContext? context}) async {
    final hum = data.humidity;

    if (hum < AlertThresholds.humidityLow) {
      // ── ACTIVE: too dry ───────────────────────────────────────────────────
      await _resolveIfActive(_AlertId.humHigh);
      await _upsertActive(
        id:       _AlertId.humLow,
        severity: AlertSeverity.warning,
        title:    'Low Humidity: ${hum.toStringAsFixed(0)}%',
        data:     data,
      );
      if (_notifReady(_AlertId.humLow)) {
        _markNotifSent(_AlertId.humLow);
        await NotificationService.instance
            .showHumidityAlert(tooLow: true, humidity: hum);
      }

    } else if (hum > AlertThresholds.humidityHigh) {
      // ── ACTIVE: too humid ─────────────────────────────────────────────────
      await _resolveIfActive(_AlertId.humLow);
      await _upsertActive(
        id:       _AlertId.humHigh,
        severity: AlertSeverity.warning,
        title:    'High Humidity: ${hum.toStringAsFixed(0)}%',
        data:     data,
      );
      if (_notifReady(_AlertId.humHigh)) {
        _markNotifSent(_AlertId.humHigh);
        await NotificationService.instance
            .showHumidityAlert(tooLow: false, humidity: hum);
      }

    } else {
      // ── RESOLVED: humidity is normal ──────────────────────────────────────
      await _resolveIfActive(_AlertId.humLow);
      await _resolveIfActive(_AlertId.humHigh);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _upsertActive()
  //   Inserts or replaces the alert row with is_resolved = 0.
  //   Uses ConflictAlgorithm.replace in DatabaseHelper so the same stable
  //   ID never creates duplicate rows.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _upsertActive({
    required String        id,
    required AlertSeverity severity,
    required String        title,
    required EnvironmentData data,
  }) async {
    try {
      await DatabaseHelper.instance.insertAlert(
        AlertModel(
          id:         id,
          severity:   severity,
          title:      title,
          deviceId:   data.deviceId,
          location:   'Rack A-04',
          timestamp:  DateTime.now(),
          isResolved: false,          // explicitly unresolved
        ),
        espId: data.deviceId,
      );
    } catch (e) {
      debugPrint('AlertService: upsert failed for $id — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _resolveIfActive()
  //   Sets is_resolved = 1 in SQLite for the given alert ID.
  //   Safe to call even if the alert does not exist (no-op).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _resolveIfActive(String alertId) async {
    try {
      await DatabaseHelper.instance.resolveAlert(alertId);
    } catch (e) {
      debugPrint('AlertService: resolve failed for $alertId — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _maybeShowDialog()
  //   Shows a dialog at most once per alert type per breach event.
  //   When the condition clears, _dialogShown is cleared so the next
  //   breach will show the dialog again.
  // ─────────────────────────────────────────────────────────────────────────
  void _maybeShowDialog({
    required BuildContext?  context,
    required String         key,
    required String         title,
    required String         message,
    required AlertSeverity  severity,
  }) {
    if (context == null || !context.mounted) return;
    if (_dialogShown.contains(key)) return;
    _dialogShown.add(key);
    _showDialog(
        context: context, title: title, message: message, severity: severity);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _showDialog()
  //   The "Acknowledge" button closes the dialog only.
  //   It does NOT call resolveAlert() — resolution is sensor-driven only.
  // ─────────────────────────────────────────────────────────────────────────
  void _showDialog({
    required BuildContext  context,
    required String        title,
    required String        message,
    required AlertSeverity severity,
  }) {
    final color = severity == AlertSeverity.critical
        ? const Color(0xFFEF4444)
        : const Color(0xFFF97316);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            severity == AlertSeverity.critical
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title,
              style: TextStyle(color: color, fontSize: 16,
                  fontWeight: FontWeight.w700))),
        ]),
        content: Text(message,
            style: const TextStyle(color: Color(0xFF94A3B8),
                fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            // Acknowledge = close dialog only. Does NOT resolve the alert.
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Acknowledge',
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}