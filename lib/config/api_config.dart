// lib/config/api_config.dart
//
// Dynamic API configuration backed by SharedPreferences.
// The ESP8266 IP is no longer hardcoded — it is stored on device
// and updated at runtime without requiring a rebuild.

import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  ApiConfig._();

  // ── SharedPreferences key ────────────────────────────────────────────────
  static const String _kEspBaseUrl = 'esp_base_url';

  /// Fallback used the very first time the app runs (before the user sets an IP).
  static const String defaultBaseUrl = 'http://192.168.1.104';

  /// Polling interval — 2 seconds for near-real-time display.
  static const Duration pollingInterval = Duration(seconds: 2);

  /// HTTP request timeout.
  static const Duration requestTimeout = Duration(seconds: 5);

  // ── In-memory cache (loaded once at startup) ────────────────────────────
  static String _baseUrl = defaultBaseUrl;

  /// The currently active base URL (e.g. "http://192.168.1.104").
  static String get baseUrl  => _baseUrl;
  static String get dataUrl  => '$_baseUrl/data';
  static String get healthUrl => '$_baseUrl/health';

  // ── Persistence helpers ──────────────────────────────────────────────────

  /// Call once in main() before runApp() to hydrate the cache.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kEspBaseUrl) ?? defaultBaseUrl;
  }

  /// Validates and persists a new base URL.
  /// Returns an error string if invalid, or null on success.
  static Future<String?> save(String raw) async {
    final trimmed = raw.trim().replaceAll(RegExp(r'/$'), ''); // strip trailing /

    final validation = _validate(trimmed);
    if (validation != null) return validation;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEspBaseUrl, trimmed);
    _baseUrl = trimmed;
    return null; // success
  }

  /// Returns an error message if the URL looks invalid, else null.
  static String? _validate(String url) {
    if (url.isEmpty) return 'URL cannot be empty.';

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return 'Must start with http:// or https://';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Scheme must be http or https.';
    }
    if (uri.host.isEmpty) {
      return 'No host found. Example: http://192.168.1.10';
    }
    return null;
  }
}
