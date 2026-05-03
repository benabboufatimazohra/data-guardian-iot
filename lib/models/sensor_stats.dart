// ─────────────────────────────────────────────────────────────────────────────
// lib/models/sensor_stats.dart
//
// Modèle représentant les statistiques agrégées calculées par une requête SQL.
// N'est PAS une table SQLite — c'est le résultat d'un rawQuery() avec
// des fonctions d'agrégation (MIN, MAX, AVG, COUNT).
//
// POURQUOI CE FICHIER EST NÉCESSAIRE :
//   Retourné par DatabaseHelper.getStats() qui exécute :
//     SELECT MIN(temperature), MAX(temperature), AVG(temperature),
//            MIN(humidity),    MAX(humidity),    AVG(humidity),
//            MAX(water_leak),  COUNT(*)
//     FROM sensor_readings WHERE esp_id = ? AND recorded_at >= ?
//
//   Utilisé par :
//     - HistoryScreen    → affichage des cartes min/max/avg
//     - ExportService    → section Summary dans Excel et PDF
//
// MÉTHODES FACTORY :
//   fromMap()  → construit depuis le résultat SQL (rawQuery retourne une List<Map>)
//   empty()    → retourne des zéros quand il n'y a pas de données
//               (évite les null checks partout dans l'UI)
//
// NOTE SUR had_leak :
//   MAX(water_leak) retourne 1 si AU MOINS UNE fuite a été détectée
//   dans la période, 0 si aucune. C'est une astuce SQL pour "OR sur toutes les lignes".
// ─────────────────────────────────────────────────────────────────────────────

class SensorStats {
  // ── Statistiques de température (°C) ─────────────────────────────────────
  final double tempMin; // Température minimale enregistrée
  final double tempMax; // Température maximale enregistrée
  final double tempAvg; // Température moyenne

  // ── Statistiques d'humidité (%) ───────────────────────────────────────────
  final double humMin;  // Humidité minimale enregistrée
  final double humMax;  // Humidité maximale enregistrée
  final double humAvg;  // Humidité moyenne

  // true si au moins une fuite a été détectée dans la période analysée
  // Calculé avec MAX(water_leak) en SQL → 1 si au moins une ligne a water_leak=1
  final bool hadLeak;

  // Nombre total de lectures dans la période (COUNT(*))
  final int totalReadings;

  SensorStats({
    required this.tempMin,
    required this.tempMax,
    required this.tempAvg,
    required this.humMin,
    required this.humMax,
    required this.humAvg,
    required this.hadLeak,
    required this.totalReadings,
  });

  // ── Désérialisation depuis rawQuery() ────────────────────────────────────
  //
  // Les alias SQL (AS temp_min, AS temp_max, etc.) deviennent les clés de la Map.
  // Requête source dans DatabaseHelper.getStats() :
  //   MIN(temperature) as temp_min
  //   MAX(temperature) as temp_max
  //   AVG(temperature) as temp_avg
  //   MIN(humidity)    as hum_min
  //   MAX(humidity)    as hum_max
  //   AVG(humidity)    as hum_avg
  //   MAX(water_leak)  as had_leak
  //   COUNT(*)         as total
  //
  factory SensorStats.fromMap(Map<String, dynamic> m) => SensorStats(
    tempMin:       (m['temp_min'] as num).toDouble(), // ← alias SQL
    tempMax:       (m['temp_max'] as num).toDouble(),
    tempAvg:       (m['temp_avg'] as num).toDouble(),
    humMin:        (m['hum_min']  as num).toDouble(),
    humMax:        (m['hum_max']  as num).toDouble(),
    humAvg:        (m['hum_avg']  as num).toDouble(),
    hadLeak:       (m['had_leak'] as int) == 1,       // ← MAX() retourne int
    totalReadings: m['total']     as int,
  );

  // ── Valeur par défaut quand il n'y a pas de données ───────────────────────
  //
  // Appelé dans DatabaseHelper.getStats() si :
  //   result.isEmpty || result.first['total'] == 0
  //
  // Évite de retourner null et force les écrans à gérer le cas "pas de données"
  // proprement (affichage de 0 plutôt que crash NullPointerException).
  //
  factory SensorStats.empty() => SensorStats(
    tempMin: 0, tempMax: 0, tempAvg: 0,
    humMin:  0, humMax:  0, humAvg:  0,
    hadLeak: false, totalReadings: 0,
  );
}
