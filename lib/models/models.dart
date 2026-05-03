// ─────────────────────────────────────────────────────────────────────────────
// lib/models/models.dart
//
// Fichier central des modèles — deux rôles :
//   1. Réexporter les modèles séparés (AppUser, EspDevice, SensorReading, SensorStats)
//      via les directives 'export' pour que les autres fichiers n'aient besoin que de :
//        import '../models/models.dart';
//
//   2. Contenir les modèles liés aux données temps-réel de l'ESP :
//        EnvironmentData  → données reçues en JSON depuis l'ESP via HTTP
//        EspAlerts        → flags d'alertes intégrés dans la réponse ESP
//        AlertModel       → alerte persistée en base de données
//        AlertSeverity    → enum critical / warning / info
//        ActivityLog      → log d'activité (non persisté, affiché en UI)
//        ActivityType     → enum info / auth / config
//
// POURQUOI TOUT DANS models.dart ET PAS DES FICHIERS SÉPARÉS ?
//   EnvironmentData, EspAlerts et AlertModel sont fortement couplés
//   (AlertModel.fromEspData prend un EnvironmentData en paramètre).
//   Les garder ensemble évite les imports circulaires.
// ─────────────────────────────────────────────────────────────────────────────

// ── Réexports des modèles SQLite ──────────────────────────────────────────────
// Tout fichier qui importe 'models.dart' a accès à toutes ces classes
// sans avoir à les importer individuellement.
export 'app_user.dart';       // AppUser — utilisateurs admin/responsable
export 'esp_device.dart';     // EspDevice — modules ESP enregistrés
export 'sensor_reading.dart'; // SensorReading — une ligne de sensor_readings
export 'sensor_stats.dart';   // SensorStats — stats agrégées MIN/MAX/AVG

// =============================================================================
// ENVIRONMENT DATA — données temps-réel reçues de l'ESP via HTTP
// =============================================================================
//
// L'ESP répond à GET http://<ip>/data avec un JSON de la forme :
// {
//   "temperature": 24.5,
//   "humidity": 48.2,
//   "water_leak": false,
//   "water_level": 120,
//   "water_percent": 11.7,
//   "timestamp": "2026-05-01T12:34:56",
//   "device_id": "ESP8266-01",
//   "ip": "192.168.1.104",
//   "alerts": { "temp_critical": false, "temp_warning": false, ... }
// }
//
class EnvironmentData {
  final double   temperature;       // Température en °C
  final double   humidity;          // Humidité relative en %
  final bool     waterLeakDetected; // true si niveau élevé ou fuite capteur digital
  final int      waterLevelRaw;     // Valeur ADC brute (0-1023 pour ESP8266)
  final double   waterLevelPercent; // Pourcentage calculé (0.0 - 100.0)
  final DateTime lastUpdated;       // Horodatage de la lecture
  final String   deviceId;          // ID de l'ESP source
  final String   ipAddress;         // IP de l'ESP (pour debug/affichage)
  final EspAlerts alerts;           // Flags d'alertes calculés côté ESP

  const EnvironmentData({
    required this.temperature,
    required this.humidity,
    required this.waterLeakDetected,
    required this.lastUpdated,
    this.waterLevelRaw     = 0,
    this.waterLevelPercent = 0.0,
    this.deviceId          = 'ESP8266-01',
    this.ipAddress         = '',
    this.alerts            = const EspAlerts(),
  });

  // ── Parsing JSON depuis l'ESP ─────────────────────────────────────────────
  //
  // Gère les cas d'erreur de parsing du timestamp avec try/catch
  // (l'ESP peut envoyer un format non-standard si l'horloge n'est pas syncée).
  //
  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      ts = DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      // Fallback : heure locale si le timestamp ESP est invalide
      ts = DateTime.now();
    }

    return EnvironmentData(
      temperature:       (json['temperature']  as num).toDouble(),
      humidity:          (json['humidity']      as num).toDouble(),
      waterLeakDetected: json['water_leak']     as bool? ?? false,
      waterLevelRaw:     (json['water_level']   as num?)?.toInt()    ?? 0,
      waterLevelPercent: (json['water_percent'] as num?)?.toDouble() ?? 0.0,
      lastUpdated:       ts,
      deviceId:          json['device_id']      as String? ?? 'ESP8266-01',
      ipAddress:         json['ip']             as String? ?? '',
      alerts: json['alerts'] != null
          ? EspAlerts.fromJson(json['alerts'] as Map<String, dynamic>)
          : const EspAlerts(), // Pas de section alerts → tous les flags à false
    );
  }

  // ── Données fictives pour tests hors ESP ─────────────────────────────────
  //
  // Utilisé dans DashboardScreen pendant le développement ou
  // quand l'ESP n'est pas disponible sur le réseau.
  //
  factory EnvironmentData.mock() => EnvironmentData(
    temperature:       24.0,
    humidity:          45.0,
    waterLeakDetected: false,
    waterLevelRaw:     120,
    waterLevelPercent: 11.7,
    lastUpdated:       DateTime.now(),
    deviceId:          'ESP8266-01',
    ipAddress:         '192.168.1.104',
  );

  // ── Texte relatif pour affichage UI ──────────────────────────────────────
  //
  // Retourne une chaîne lisible depuis la dernière mise à jour.
  // Exemple : 'À l'instant', 'Il y a 30s', 'Il y a 5m', 'Il y a 2h'
  //
  String get lastUpdatedText {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 10) return 'À l\'instant';
    if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}m';
    return 'Il y a ${diff.inHours}h';
  }
}

// =============================================================================
// ESP ALERTS — flags d'alertes calculés par l'ESP et envoyés dans le JSON
// =============================================================================
//
// L'ESP calcule ces seuils en local (firmware) et les inclut dans sa réponse.
// Avantage : pas besoin de recalculer les seuils côté Flutter.
//
class EspAlerts {
  final bool tempCritical; // Température > seuil critique (ex: > 40°C)
  final bool tempWarning;  // Température > seuil avertissement (ex: > 35°C)
  final bool humidityLow;  // Humidité trop basse (ex: < 20%)
  final bool humidityHigh; // Humidité trop haute (ex: > 80%)
  final bool waterHigh;    // Niveau d'eau > seuil (ex: > 70%)

  const EspAlerts({
    this.tempCritical = false,
    this.tempWarning  = false,
    this.humidityLow  = false,
    this.humidityHigh = false,
    this.waterHigh    = false,
  });

  factory EspAlerts.fromJson(Map<String, dynamic> json) => EspAlerts(
    tempCritical : json['temp_critical']  as bool? ?? false,
    tempWarning  : json['temp_warning']   as bool? ?? false,
    humidityLow  : json['humidity_low']   as bool? ?? false,
    humidityHigh : json['humidity_high']  as bool? ?? false,
    waterHigh    : json['water_high']     as bool? ?? false,
  );

  /// true si au moins un flag d'alerte est actif
  bool get hasAnyAlert =>
      tempCritical || tempWarning || humidityLow || humidityHigh || waterHigh;
}

// =============================================================================
// ALERT MODEL — alerte persistée dans la table SQLite 'alerts'
// =============================================================================
//
// Une AlertModel peut venir de deux sources :
//   1. L'ESP via HTTP   → AlertModel.fromJson()
//   2. Données temps-réel → AlertModel.fromEspData() (génère des alertes live)
//
// Elle est ensuite sauvegardée via DatabaseHelper.insertAlert()
// et peut être marquée comme résolue via DatabaseHelper.resolveAlert().
//
class AlertModel {
  final String        id;         // Identifiant unique (UUID ou 'live-temp-critical')
  final AlertSeverity severity;   // Niveau : critical / warning / info
  final String        title;      // Message descriptif de l'alerte
  final String        deviceId;   // ID de l'ESP source
  final String        location;   // Emplacement physique (ex: 'Rack A-04')
  final DateTime      timestamp;  // Horodatage de l'alerte
  final bool          isResolved; // false = active, true = traitée

  const AlertModel({
    required this.id,
    required this.severity,
    required this.title,
    required this.deviceId,
    required this.location,
    required this.timestamp,
    this.isResolved = false,
  });

  // ── Parsing depuis JSON ESP ───────────────────────────────────────────────
  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
    id:         json['id']          as String,
    severity:   AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.info), // Fallback si valeur inconnue
    title:      json['title']       as String,
    deviceId:   json['device_id']   as String,
    location:   json['location']    as String,
    timestamp:  DateTime.parse(json['timestamp'] as String),
    isResolved: json['is_resolved'] as bool? ?? false,
  );

  // ── Génération d'alertes depuis les données temps-réel ───────────────────
  //
  // Appelé dans EspService.fetchOnce() après chaque lecture réussie.
  // Compare les flags EspAlerts et crée les AlertModel correspondantes.
  // Ces alertes sont ensuite sauvegardées en base via insertAlert().
  //
  // Les IDs ('live-temp-critical', etc.) sont fixes → ConflictAlgorithm.replace
  // dans insertAlert() met à jour l'alerte existante plutôt que d'en créer
  // une nouvelle à chaque polling.
  //
  static List<AlertModel> fromEspData(EnvironmentData data) {
    final alerts = <AlertModel>[];
    final now    = DateTime.now();

    // Alerte température — critique prioritaire sur avertissement
    if (data.alerts.tempCritical) {
      alerts.add(AlertModel(
        id: 'live-temp-critical',
        severity: AlertSeverity.critical,
        title: 'Température critique — ${data.temperature.toStringAsFixed(1)}°C',
        deviceId: data.deviceId,
        location: 'Rack A-04',
        timestamp: now,
      ));
    } else if (data.alerts.tempWarning) {
      alerts.add(AlertModel(
        id: 'live-temp-warning',
        severity: AlertSeverity.warning,
        title: 'Avertissement température — ${data.temperature.toStringAsFixed(1)}°C',
        deviceId: data.deviceId,
        location: 'Rack A-04',
        timestamp: now,
      ));
    }

    // Alerte eau — waterLeakDetected (capteur digital) OU waterHigh (capteur analogique)
    if (data.waterLeakDetected || data.alerts.waterHigh) {
      alerts.add(AlertModel(
        id: 'live-water',
        severity: AlertSeverity.critical,
        title: 'Niveau d\'eau élevé — ${data.waterLevelPercent.toStringAsFixed(0)}%',
        deviceId: data.deviceId,
        location: 'Rack A-04',
        timestamp: now,
      ));
    }

    // Alerte humidité basse
    if (data.alerts.humidityLow) {
      alerts.add(AlertModel(
        id: 'live-humid-low',
        severity: AlertSeverity.warning,
        title: 'Humidité basse — ${data.humidity.toStringAsFixed(0)}%',
        deviceId: data.deviceId,
        location: 'Rack A-04',
        timestamp: now,
      ));
    }

    return alerts; // Liste vide si tout est normal
  }

  // ── Temps relatif pour affichage UI ──────────────────────────────────────
  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

// Niveaux de sévérité des alertes (ordre décroissant de gravité)
enum AlertSeverity { critical, warning, info }

// =============================================================================
// ACTIVITY LOG — log d'activité affiché dans l'interface (non persisté)
// =============================================================================
class ActivityLog {
  final String       message;   // Description de l'événement
  final String       source;    // Source (ex: 'ESP8266-01', 'AuthService')
  final DateTime     timestamp; // Horodatage
  final ActivityType type;      // Catégorie de l'événement

  const ActivityLog({
    required this.message,
    required this.source,
    required this.timestamp,
    required this.type,
  });
}

// Catégories de logs
enum ActivityType {
  info,   // Information générale
  auth,   // Connexion / déconnexion
  config, // Modification de configuration
}
