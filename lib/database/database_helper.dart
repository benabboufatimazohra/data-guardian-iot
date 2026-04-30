// lib/database/database_helper.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// DatabaseHelper — SQLite local database
// Stores: sensor readings + alerts history
//
// SETUP — add to pubspec.yaml:
//   sqflite: ^2.3.0
//   path: ^1.9.0
//
// Then: flutter pub get
// ─────────────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  // Singleton
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  // ─── Init & schema ────────────────────────────────────────────────────────
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'dataguardian.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table: sensor readings
        await db.execute('''
          CREATE TABLE sensor_readings (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id   TEXT    NOT NULL,
            temperature REAL    NOT NULL,
            humidity    REAL    NOT NULL,
            water_leak  INTEGER NOT NULL DEFAULT 0,
            water_level INTEGER NOT NULL DEFAULT 0,
            water_pct   REAL    NOT NULL DEFAULT 0,
            recorded_at TEXT    NOT NULL
          )
        ''');

        // Table: alerts
        await db.execute('''
          CREATE TABLE alerts (
            id          TEXT    PRIMARY KEY,
            device_id   TEXT    NOT NULL,
            severity    TEXT    NOT NULL,
            title       TEXT    NOT NULL,
            location    TEXT    NOT NULL DEFAULT '',
            is_resolved INTEGER NOT NULL DEFAULT 0,
            created_at  TEXT    NOT NULL
          )
        ''');

        // Index for fast time-range queries
        await db.execute(
          'CREATE INDEX idx_readings_time ON sensor_readings(recorded_at)');
        await db.execute(
          'CREATE INDEX idx_alerts_time   ON alerts(created_at)');
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SENSOR READINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert one reading — called automatically by EspService every 5s
  Future<int> insertReading(EnvironmentData data) async {
    final db = await database;
    return db.insert('sensor_readings', {
      'device_id'  : data.deviceId,
      'temperature': data.temperature,
      'humidity'   : data.humidity,
      'water_leak' : data.waterLeakDetected ? 1 : 0,
      'water_level': data.waterLevelRaw,
      'water_pct'  : data.waterLevelPercent,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get last N readings (most recent first)
  Future<List<SensorReading>> getReadings({int limit = 100}) async {
    final db   = await database;
    final rows = await db.query(
      'sensor_readings',
      orderBy: 'recorded_at DESC',
      limit:   limit,
    );
    return rows.map(SensorReading.fromMap).toList();
  }

  /// Get readings for a specific time range
  Future<List<SensorReading>> getReadingsBetween(
      DateTime from, DateTime to) async {
    final db   = await database;
    final rows = await db.query(
      'sensor_readings',
      where:     'recorded_at BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy:   'recorded_at ASC',
    );
    return rows.map(SensorReading.fromMap).toList();
  }

  /// Get readings for last N hours
  Future<List<SensorReading>> getReadingsLastHours(int hours) async {
    final from = DateTime.now().subtract(Duration(hours: hours));
    final to   = DateTime.now();
    return getReadingsBetween(from, to);
  }

  /// Latest single reading
  Future<SensorReading?> getLatestReading() async {
    final db   = await database;
    final rows = await db.query(
      'sensor_readings',
      orderBy: 'recorded_at DESC',
      limit:   1,
    );
    if (rows.isEmpty) return null;
    return SensorReading.fromMap(rows.first);
  }

  /// Stats: min/max/avg for a time range
  Future<SensorStats> getStats({int hoursBack = 24}) async {
    final db   = await database;
    final from = DateTime.now()
        .subtract(Duration(hours: hoursBack))
        .toIso8601String();

    final result = await db.rawQuery('''
      SELECT
        MIN(temperature) as temp_min,
        MAX(temperature) as temp_max,
        AVG(temperature) as temp_avg,
        MIN(humidity)    as hum_min,
        MAX(humidity)    as hum_max,
        AVG(humidity)    as hum_avg,
        MAX(water_leak)  as had_leak,
        COUNT(*)         as total
      FROM sensor_readings
      WHERE recorded_at >= ?
    ''', [from]);

    if (result.isEmpty || result.first['total'] == 0) return SensorStats.empty();
    return SensorStats.fromMap(result.first);
  }

  /// Delete readings older than N days (keep DB small)
  Future<int> deleteOldReadings(int keepDays) async {
    final db      = await database;
    final cutoff  = DateTime.now()
        .subtract(Duration(days: keepDays))
        .toIso8601String();
    return db.delete('sensor_readings',
        where: 'recorded_at < ?', whereArgs: [cutoff]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert or replace an alert
  Future<void> insertAlert(AlertModel alert) async {
    final db = await database;
    await db.insert(
      'alerts',
      {
        'id'         : alert.id,
        'device_id'  : alert.deviceId,
        'severity'   : alert.severity.name,
        'title'      : alert.title,
        'location'   : alert.location,
        'is_resolved': alert.isResolved ? 1 : 0,
        'created_at' : alert.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all alerts (most recent first)
  Future<List<AlertModel>> getAlerts({int limit = 50}) async {
    final db   = await database;
    final rows = await db.query(
      'alerts',
      orderBy: 'created_at DESC',
      limit:   limit,
    );
    return rows.map(_alertFromMap).toList();
  }

  /// Get only unresolved alerts
  Future<List<AlertModel>> getActiveAlerts() async {
    final db   = await database;
    final rows = await db.query(
      'alerts',
      where:   'is_resolved = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(_alertFromMap).toList();
  }

  /// Mark alert as resolved
  Future<void> resolveAlert(String alertId) async {
    final db = await database;
    await db.update(
      'alerts',
      {'is_resolved': 1},
      where:     'id = ?',
      whereArgs: [alertId],
    );
  }

  /// Count unresolved alerts
  Future<int> getActiveAlertCount() async {
    final db     = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM alerts WHERE is_resolved = 0');
    return (result.first['cnt'] as int?) ?? 0;
  }

  AlertModel _alertFromMap(Map<String, dynamic> m) => AlertModel(
    id:         m['id']          as String,
    deviceId:   m['device_id']   as String,
    severity:   AlertSeverity.values.firstWhere(
        (e) => e.name == m['severity'], orElse: () => AlertSeverity.info),
    title:      m['title']       as String,
    location:   m['location']    as String? ?? '',
    isResolved: (m['is_resolved'] as int) == 1,
    timestamp:  DateTime.parse(m['created_at'] as String),
  );

  // ─── Close ────────────────────────────────────────────────────────────────
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes for query results
// ─────────────────────────────────────────────────────────────────────────────

class SensorReading {
  final int    id;
  final String deviceId;
  final double temperature;
  final double humidity;
  final bool   waterLeak;
  final int    waterLevel;
  final double waterPercent;
  final DateTime recordedAt;

  const SensorReading({
    required this.id,
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    required this.waterLeak,
    required this.waterLevel,
    required this.waterPercent,
    required this.recordedAt,
  });

  factory SensorReading.fromMap(Map<String, dynamic> m) => SensorReading(
    id:           m['id']          as int,
    deviceId:     m['device_id']   as String,
    temperature:  (m['temperature'] as num).toDouble(),
    humidity:     (m['humidity']    as num).toDouble(),
    waterLeak:    (m['water_leak']  as int) == 1,
    waterLevel:   m['water_level']  as int,
    waterPercent: (m['water_pct']   as num).toDouble(),
    recordedAt:   DateTime.parse(m['recorded_at'] as String),
  );
}

class SensorStats {
  final double tempMin, tempMax, tempAvg;
  final double humMin,  humMax,  humAvg;
  final bool   hadLeak;
  final int    totalReadings;

  const SensorStats({
    required this.tempMin, required this.tempMax, required this.tempAvg,
    required this.humMin,  required this.humMax,  required this.humAvg,
    required this.hadLeak, required this.totalReadings,
  });

  factory SensorStats.fromMap(Map<String, dynamic> m) => SensorStats(
    tempMin:       (m['temp_min'] as num).toDouble(),
    tempMax:       (m['temp_max'] as num).toDouble(),
    tempAvg:       (m['temp_avg'] as num).toDouble(),
    humMin:        (m['hum_min']  as num).toDouble(),
    humMax:        (m['hum_max']  as num).toDouble(),
    humAvg:        (m['hum_avg']  as num).toDouble(),
    hadLeak:       (m['had_leak'] as int) == 1,
    totalReadings: m['total']     as int,
  );

  factory SensorStats.empty() => const SensorStats(
    tempMin: 0, tempMax: 0, tempAvg: 0,
    humMin:  0, humMax:  0, humAvg:  0,
    hadLeak: false, totalReadings: 0,
  );
}
