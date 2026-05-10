// lib/services/esp_service.dart
//
// CHANGED: No longer saves every sensor reading to SQLite.
//          Only saves CRITICAL alerts to save storage space.
//          Regular polling still works and streams data to the UI.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';
import '../database/database_helper.dart';

class EspService {
  EspService._internal();
  static final EspService instance = EspService._internal();

  final _dataController       = StreamController<EnvironmentData>.broadcast();
  final _errorController      = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<EnvironmentData> get dataStream       => _dataController.stream;
  Stream<String>          get errorStream      => _errorController.stream;
  Stream<bool>            get connectionStream => _connectionController.stream;

  Timer? _pollingTimer;
  bool   _isConnected = false;
  EnvironmentData? _lastData;

  EnvironmentData? get lastData    => _lastData;
  bool             get isConnected => _isConnected;

  void startPolling() {
    fetchOnce();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(ApiConfig.pollingInterval, (_) => fetchOnce());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<EnvironmentData?> fetchOnce() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.dataUrl))
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        if (json.containsKey('error')) {
          _setConnected(false);
          _errorController.add('Sensor error: ${json['error']}');
          return null;
        }

        final data = EnvironmentData.fromJson(json);
        _lastData = data;
        _setConnected(true);

        // ── Send to UI via stream ────────────────────────────────────────
        _dataController.add(data);

        // ── Save ONLY critical alerts to SQLite (saves storage space) ────
        // We do NOT save sensor readings anymore.
        // We only save alerts that are critical severity.
        final liveAlerts = AlertModel.fromEspData(data);
        for (final alert in liveAlerts) {
          if (alert.severity == AlertSeverity.critical) {
            await DatabaseHelper.instance.insertAlert(alert, espId: data.deviceId);
          }
          // Warning and info alerts are shown in UI but NOT stored
        }
        // ─────────────────────────────────────────────────────────────────

        return data;
      } else {
        _setConnected(false);
        _errorController.add('HTTP ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      _setConnected(false);
      _errorController
          .add('Timeout — ESP not responding (${ApiConfig.espIpAddress})');
      return null;
    } catch (e) {
      _setConnected(false);
      _errorController.add('Network error: $e');
      return null;
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.healthUrl))
          .timeout(const Duration(seconds: 2));
      final ok = response.statusCode == 200;
      _setConnected(ok);
      return ok;
    } catch (_) {
      _setConnected(false);
      return false;
    }
  }

  void _setConnected(bool value) {
    if (_isConnected != value) {
      _isConnected = value;
      _connectionController.add(value);
    }
  }
}

