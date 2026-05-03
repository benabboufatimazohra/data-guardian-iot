// ─────────────────────────────────────────────────────────────────────────────
// lib/models/sensor_reading.dart
//
// Modèle représentant UNE lecture de capteurs enregistrée dans SQLite.
// Correspond à une ligne de la table 'sensor_readings'.
//
// POURQUOI CE FICHIER EST NÉCESSAIRE :
//   Utilisé par DatabaseHelper pour :
//     - getReadingsForExport() → export Excel/PDF
//     - getReadingsLastHours() → affichage graphiques HistoryScreen
//   Utilisé par ExportService pour générer les tableaux Excel et PDF.
//   Utilisé par HistoryScreen pour afficher les événements de fuite.
//
// TABLE sensor_readings (colonnes) :
//   id          INTEGER PRIMARY KEY AUTOINCREMENT
//   esp_id      TEXT    → référence à esp_devices.id
//   temperature REAL    → température en °C
//   humidity    REAL    → humidité en %
//   water_leak  INTEGER → 1 = fuite détectée, 0 = normal
//   water_level INTEGER → valeur ADC brute (0-1023 pour ESP8266)
//   water_pct   REAL    → pourcentage calculé (0.0 - 100.0)
//   recorded_at TEXT    → horodatage ISO8601
//
// NOTE SUR LES TYPES SQLite :
//   SQLite n'a pas de type BOOLEAN — water_leak est stocké comme INTEGER.
//   La conversion (m['water_leak'] as int) == 1 fait INTEGER → bool.
//   REAL en SQLite correspond à double en Dart, mais peut arriver comme
//   int si la valeur est ronde (ex: 24.0 stocké comme 24).
//   C'est pourquoi on utilise (m['temperature'] as num).toDouble()
//   et non simplement m['temperature'] as double.
// ─────────────────────────────────────────────────────────────────────────────

class SensorReading {
  // Identifiant auto-incrémenté par SQLite
  final int id;

  // ID de l'ESP source (ex: 'ESP8266-01')
  final String espId;

  // Température mesurée en degrés Celsius
  final double temperature;

  // Humidité relative en pourcentage (0-100)
  final double humidity;

  // true si une fuite d'eau a été détectée lors de cette lecture
  final bool waterLeak;

  // Valeur brute du capteur analogique (0-1023 sur ESP8266)
  final int waterLevel;

  // Pourcentage calculé depuis waterLevel (0.0 - 100.0)
  final double waterPercent;

  // Horodatage exact de la lecture
  final DateTime recordedAt;

  SensorReading({
    required this.id,
    required this.espId,
    required this.temperature,
    required this.humidity,
    required this.waterLeak,
    required this.waterLevel,
    required this.waterPercent,
    required this.recordedAt,
  });

  // ── Désérialisation depuis SQLite ─────────────────────────────────────────
  //
  // ATTENTION aux types SQLite → Dart :
  //   REAL   → (num).toDouble()  car SQLite peut retourner int ou double
  //   INTEGER→ bool via == 1     car SQLite n'a pas de booléen natif
  //   TEXT   → DateTime.parse()  pour convertir la chaîne ISO8601
  //
  factory SensorReading.fromMap(Map<String, dynamic> m) => SensorReading(
    id:           m['id']            as int,
    espId:        m['esp_id']        as String,
    temperature:  (m['temperature']  as num).toDouble(), // ← num car peut être int
    humidity:     (m['humidity']     as num).toDouble(),
    waterLeak:    (m['water_leak']   as int) == 1,       // ← INTEGER → bool
    waterLevel:   m['water_level']   as int,
    waterPercent: (m['water_pct']    as num).toDouble(), // ← colonne 'water_pct' pas 'water_percent'
    recordedAt:   DateTime.parse(m['recorded_at'] as String),
  );
}
