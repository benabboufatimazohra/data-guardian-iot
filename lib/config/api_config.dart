// lib/config/api_config.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// Configuration de la connexion à l'ESP8266
// ─────────────────────────────────────────────────────────────────────────────
//
// ÉTAPES :
//   1. Flashez le code esp8266_server.ino sur votre ESP8266
//   2. Ouvrez le Serial Monitor (115200 baud) → notez l'IP affichée
//   3. Remplacez ESP_IP_ADDRESS ci-dessous par cette IP
//   4. Assurez-vous que le téléphone et l'ESP sont sur le même Wi-Fi
// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  ApiConfig._();

  /// ⚠️  CHANGEZ CETTE VALEUR avec l'IP affichée dans le Serial Monitor
  static const String espIpAddress = '192.168.11.121';
  static const int    espPort      = 80;

  /// Délai entre chaque poll (2 min pour les données en temps réel)
  static const Duration pollingInterval = Duration(minutes: 2); 

  /// Timeout d'une requête HTTP (si l'ESP ne répond pas)
  static const Duration requestTimeout = Duration(minutes: 3);

  // ── URLs construites automatiquement ───────────────────────────────────
  static String get baseUrl  => 'http://$espIpAddress:$espPort';
  static String get dataUrl  => '$baseUrl/data';
  static String get healthUrl => '$baseUrl/health';
}

