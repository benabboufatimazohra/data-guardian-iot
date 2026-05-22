// lib/services/esp_service.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// EspService — Gère toute la communication avec l'ESP8266
// ─────────────────────────────────────────────────────────────────────────────
//
// Ce service centralise :
//   - La récupération des données capteurs (polling)
//   - La gestion des erreurs réseau
//   - Le stream de données en temps réel pour le dashboard
//
// USAGE dans un StatefulWidget :
//   @override
//   void initState() {
//     super.initState();
//     // S'abonner au stream de données
//     _subscription = EspService.instance.dataStream.listen((data) {
//       setState(() => _envData = data);
//     });
//     EspService.instance.startPolling();
//   }
//
//   @override
//   void dispose() {
//     _subscription.cancel();
//     EspService.instance.stopPolling();
//     super.dispose();
//   }
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';

class EspService {
  // Singleton — une seule instance partagée dans toute l'app
  EspService._internal();
  static final EspService instance = EspService._internal();

  // StreamController broadcast : plusieurs widgets peuvent écouter le même stream
  final _dataController = StreamController<EnvironmentData>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  /// Stream de données — abonnez-vous dans vos widgets pour recevoir les mises à jour
  Stream<EnvironmentData> get dataStream => _dataController.stream;

  /// Stream d'erreurs (message d'erreur réseau, timeout, etc.)
  Stream<String> get errorStream => _errorController.stream;

  /// Stream d'état de connexion — true = ESP connecté, false = déconnecté
  Stream<bool> get connectionStream => _connectionController.stream;

  Timer? _pollingTimer;
  bool _isConnected = false;
  EnvironmentData? _lastData;

  EnvironmentData? get lastData => _lastData;
  bool get isConnected => _isConnected;

  // ─── Démarrer le polling périodique ──────────────────────────────────────
  void startPolling() {
    // Première lecture immédiate
    fetchOnce();

    // Puis toutes les N secondes selon ApiConfig
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(ApiConfig.pollingInterval, (_) {
      fetchOnce();
    });
  }

  // ─── Arrêter le polling ───────────────────────────────────────────────────
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ─── Une seule lecture ────────────────────────────────────────────────────
  Future<EnvironmentData?> fetchOnce() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.dataUrl))
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // Vérifier si le JSON contient une erreur de capteur
        if (json.containsKey('error')) {
          _setConnected(false);
          _errorController.add('Erreur capteur : ${json['error']}');
          return null;
        }

        final data = EnvironmentData.fromJson(json);
        _lastData = data;
        _setConnected(true);
        _dataController.add(data);
        return data;
      } else {
        _setConnected(false);
        _errorController.add('Erreur HTTP ${response.statusCode}');
        return null;
      }
    } on TimeoutException {
      _setConnected(false);
      _errorController.add('Timeout — ESP ne répond pas (${ApiConfig.espIpAddress})');
      return null;
    } catch (e) {
      _setConnected(false);
      _errorController.add('Erreur réseau : $e');
      return null;
    }
  }

  // ─── Vérifier si l'ESP est en ligne ──────────────────────────────────────
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

  void dispose() {
    stopPolling();
    _dataController.close();
    _errorController.close();
    _connectionController.close();
  }
}
