// lib/models/models.dart
// Version finale — supporte capteur eau analogique ET numérique

class EnvironmentData {
  final double temperature;
  final double humidity;
  final bool   waterLeakDetected;   // true si niveau élevé ou fuite détectée
  final int    waterLevelRaw;       // valeur ADC brute 0-1023 (analogique)
  final double waterLevelPercent;   // 0.0 – 100.0 %
  final DateTime lastUpdated;
  final String deviceId;
  final String ipAddress;
  final EspAlerts alerts;

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

  /// Parse le JSON de l'ESP8266
  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      ts = DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      ts = DateTime.now();
    }

    return EnvironmentData(
      temperature:       (json['temperature']    as num).toDouble(),
      humidity:          (json['humidity']        as num).toDouble(),
      waterLeakDetected: json['water_leak']       as bool? ?? false,
      waterLevelRaw:     (json['water_level']     as num?)?.toInt()    ?? 0,
      waterLevelPercent: (json['water_percent']   as num?)?.toDouble() ?? 0.0,
      lastUpdated:       ts,
      deviceId:          json['device_id']        as String? ?? 'ESP8266-01',
      ipAddress:         json['ip']               as String? ?? '',
      alerts: json['alerts'] != null
          ? EspAlerts.fromJson(json['alerts'] as Map<String, dynamic>)
          : const EspAlerts(),
    );
  }

  /// Données fictives pour tests avant connexion ESP
  factory EnvironmentData.mock() {
    return EnvironmentData(
      temperature:       24.0,
      humidity:          45.0,
      waterLeakDetected: false,
      waterLevelRaw:     120,
      waterLevelPercent: 11.7,
      lastUpdated:       DateTime.now(),
      deviceId:          'ESP8266-01',
      ipAddress:         '192.168.1.104',
    );
  }

  String get lastUpdatedText {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 10) return 'À l\'instant';
    if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}m';
    return 'Il y a ${diff.inHours}h';
  }
}

class EspAlerts {
  final bool tempCritical;
  final bool tempWarning;
  final bool humidityLow;
  final bool humidityHigh;
  final bool waterHigh;

  const EspAlerts({
    this.tempCritical = false,
    this.tempWarning  = false,
    this.humidityLow  = false,
    this.humidityHigh = false,
    this.waterHigh    = false,
  });

  factory EspAlerts.fromJson(Map<String, dynamic> json) {
    return EspAlerts(
      tempCritical : json['temp_critical']  as bool? ?? false,
      tempWarning  : json['temp_warning']   as bool? ?? false,
      humidityLow  : json['humidity_low']   as bool? ?? false,
      humidityHigh : json['humidity_high']  as bool? ?? false,
      waterHigh    : json['water_high']     as bool? ?? false,
    );
  }

  bool get hasAnyAlert =>
      tempCritical || tempWarning || humidityLow || humidityHigh || waterHigh;
}

// ─── AlertModel ───────────────────────────────────────────────────────────────
class AlertModel {
  final String id;
  final AlertSeverity severity;
  final String title;
  final String deviceId;
  final String location;
  final DateTime timestamp;
  final bool isResolved;

  const AlertModel({
    required this.id,
    required this.severity,
    required this.title,
    required this.deviceId,
    required this.location,
    required this.timestamp,
    this.isResolved = false,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id:         json['id']        as String,
      severity:   AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.info,
      ),
      title:      json['title']     as String,
      deviceId:   json['device_id'] as String,
      location:   json['location']  as String,
      timestamp:  DateTime.parse(json['timestamp'] as String),
      isResolved: json['is_resolved'] as bool? ?? false,
    );
  }

  /// Génère des alertes en temps réel depuis les données de l'ESP
  static List<AlertModel> fromEspData(EnvironmentData data) {
    final alerts = <AlertModel>[];
    final now    = DateTime.now();

    if (data.alerts.tempCritical) {
      alerts.add(AlertModel(
        id: 'live-temp-critical', severity: AlertSeverity.critical,
        title: 'Température critique — ${data.temperature.toStringAsFixed(1)}°C',
        deviceId: data.deviceId, location: 'Rack A-04', timestamp: now,
      ));
    } else if (data.alerts.tempWarning) {
      alerts.add(AlertModel(
        id: 'live-temp-warning', severity: AlertSeverity.warning,
        title: 'Avertissement température — ${data.temperature.toStringAsFixed(1)}°C',
        deviceId: data.deviceId, location: 'Rack A-04', timestamp: now,
      ));
    }

    if (data.waterLeakDetected || data.alerts.waterHigh) {
      alerts.add(AlertModel(
        id: 'live-water', severity: AlertSeverity.critical,
        title: 'Niveau d\'eau élevé — ${data.waterLevelPercent.toStringAsFixed(0)}%',
        deviceId: data.deviceId, location: 'Rack A-04', timestamp: now,
      ));
    }

    if (data.alerts.humidityLow) {
      alerts.add(AlertModel(
        id: 'live-humid-low', severity: AlertSeverity.warning,
        title: 'Humidité basse — ${data.humidity.toStringAsFixed(0)}%',
        deviceId: data.deviceId, location: 'Rack A-04', timestamp: now,
      ));
    }

    return alerts;
  }

  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

enum AlertSeverity { critical, warning, info }

class ActivityLog {
  final String message;
  final String source;
  final DateTime timestamp;
  final ActivityType type;
  const ActivityLog({
    required this.message, required this.source,
    required this.timestamp, required this.type,
  });
}

enum ActivityType { info, auth, config }
