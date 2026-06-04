// lib/services/esp_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';
import 'alert_service.dart';

class EspService {
  EspService._internal();
  static final EspService instance = EspService._internal();

  // ── Streams ───────────────────────────────────────────────────────────────
  final _dataController       = StreamController<EnvironmentData>.broadcast();
  final _errorController      = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<EnvironmentData> get dataStream       => _dataController.stream;
  Stream<String>          get errorStream      => _errorController.stream;
  Stream<bool>            get connectionStream => _connectionController.stream;

  // ── State ─────────────────────────────────────────────────────────────────
  Timer?           _pollingTimer;
  bool             _isConnected = false;
  EnvironmentData? _lastData;

  /// Latest XAI data from the ESP — updated on every successful poll.
  XaiData? _lastXai;

  EnvironmentData? get lastData    => _lastData;
  bool             get isConnected => _isConnected;

  /// The most recent XAI explanation received from the ESP.
  /// Returns XaiData.empty() if no data has been received yet.
  XaiData get lastXai => _lastXai ?? XaiData.empty();

  BuildContext? _activeContext;
  void setContext(BuildContext? ctx) => _activeContext = ctx;

  // ── Polling ───────────────────────────────────────────────────────────────

  void startPolling() {
    fetchOnce();
    _pollingTimer?.cancel();
    _pollingTimer =
        Timer.periodic(ApiConfig.pollingInterval, (_) => fetchOnce());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void restartPolling() {
    stopPolling();
    startPolling();
  }

  // ── Single fetch ──────────────────────────────────────────────────────────

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

        // ── Store latest XAI ─────────────────────────────────────────────
        _lastXai = data.xai;

        _setConnected(true);
        _dataController.add(data);

        await AlertService.instance.evaluate(data, context: _activeContext);

        return data;
      } else {
        _setConnected(false);
        _errorController.add('HTTP ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      _setConnected(false);
      _errorController
          .add('Timeout — ESP not responding at ${ApiConfig.baseUrl}');
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
          .timeout(const Duration(seconds: 3));
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