// lib/database/database_helper.dart
//
// CORRECTION PRINCIPALE :
//   Les classes AppUser, EspDevice, SensorReading, SensorStats qui étaient
//   définies en bas de ce fichier ont été SUPPRIMÉES.
//   Elles vivent maintenant dans leurs propres fichiers dans lib/models/.
//   Les garder ici causait l'erreur "ambiguous_import" dans tous les écrans.
//
//   Les imports '../models/app_user.dart' et '../models/esp_device.dart'
//   ont aussi été supprimés — un seul import '../models/models.dart' suffit.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  // ─── Initialisation ───────────────────────────────────────────────────────
  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'dataguardian_v2.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Table users ──────────────────────────────────────────────────────────
    // role : 'admin' | 'responsable'
    // assigned_esp_id : null pour admin (voit tout), sinon l'id de l'ESP assigné
    await db.execute('''
      CREATE TABLE users (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name       TEXT    NOT NULL,
        email           TEXT    NOT NULL UNIQUE,
        password_hash   TEXT    NOT NULL,
        role            TEXT    NOT NULL DEFAULT 'responsable',
        assigned_esp_id TEXT,
        created_at      TEXT    NOT NULL
      )
    ''');

    // ── Table esp_devices ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE esp_devices (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        ip_address  TEXT    NOT NULL,
        location    TEXT    NOT NULL DEFAULT '',
        room        TEXT    NOT NULL DEFAULT '',
        is_online   INTEGER NOT NULL DEFAULT 0,
        firmware    TEXT    NOT NULL DEFAULT 'v2.0.4',
        last_seen   TEXT,
        created_at  TEXT    NOT NULL
      )
    ''');

    // ── Table sensor_readings ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE sensor_readings (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        esp_id      TEXT    NOT NULL,
        temperature REAL    NOT NULL,
        humidity    REAL    NOT NULL,
        water_leak  INTEGER NOT NULL DEFAULT 0,
        water_level INTEGER NOT NULL DEFAULT 0,
        water_pct   REAL    NOT NULL DEFAULT 0,
        recorded_at TEXT    NOT NULL,
        FOREIGN KEY (esp_id) REFERENCES esp_devices(id)
      )
    ''');

    // ── Table alerts ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE alerts (
        id          TEXT    PRIMARY KEY,
        esp_id      TEXT    NOT NULL,
        device_id   TEXT    NOT NULL,
        severity    TEXT    NOT NULL,
        title       TEXT    NOT NULL,
        location    TEXT    NOT NULL DEFAULT '',
        is_resolved INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL,
        FOREIGN KEY (esp_id) REFERENCES esp_devices(id)
      )
    ''');

    // Index pour accélérer les requêtes temporelles
    await db.execute('CREATE INDEX idx_readings_esp_time ON sensor_readings(esp_id, recorded_at)');
    await db.execute('CREATE INDEX idx_alerts_esp_time   ON alerts(esp_id, created_at)');
    await db.execute('CREATE INDEX idx_readings_time     ON sensor_readings(recorded_at)');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Administrateur par défaut
    await db.insert('users', {
      'full_name'       : 'System Administrator',
      'email'           : 'admin@dataguardian.com',
      'password_hash'   : _hashPassword('Admin@1234'),
      'role'            : 'admin',
      'assigned_esp_id' : null,
      'created_at'      : now,
    });

    // ESP de démonstration
    await db.insert('esp_devices', {
      'id'         : 'ESP8266-01',
      'name'       : 'ESP8266 — Rack A',
      'ip_address' : '192.168.1.104',
      'location'   : 'Rack A-04',
      'room'       : 'Server Room A',
      'is_online'  : 1,
      'firmware'   : 'v2.0.4',
      'last_seen'  : now,
      'created_at' : now,
    });

    // Responsable assigné à l'ESP de démo
    await db.insert('users', {
      'full_name'       : 'Mohammed Alami',
      'email'           : 'alami@dataguardian.com',
      'password_hash'   : _hashPassword('Resp@1234'),
      'role'            : 'responsable',
      'assigned_esp_id' : 'ESP8266-01',
      'created_at'      : now,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Connexion : vérifie email + hash SHA-256 du mot de passe
  Future<AppUser?> login(String email, String password) async {
    final db   = await database;
    final hash = _hashPassword(password);
    final rows = await db.query('users',
        where:     'email = ? AND password_hash = ?',
        whereArgs: [email.trim().toLowerCase(), hash]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// Crée un utilisateur — hache le mot de passe avant insertion
  Future<int> createUser(AppUser user, String password) async {
    final db = await database;
    return db.insert('users', {
      'full_name'       : user.fullName,
      'email'           : user.email.toLowerCase(),
      'password_hash'   : _hashPassword(password),
      'role'            : user.role,
      'assigned_esp_id' : user.assignedEspId,
      'created_at'      : DateTime.now().toIso8601String(),
    });
  }

  /// Retourne tous les utilisateurs triés : admins en premier, puis par nom
  Future<List<AppUser>> getAllUsers() async {
    final db   = await database;
    final rows = await db.query('users', orderBy: 'role DESC, full_name ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  /// Met à jour nom, email, rôle et ESP assigné (pas le mot de passe)
  Future<void> updateUser(AppUser user) async {
    final db = await database;
    await db.update('users',
      {
        'full_name'       : user.fullName,
        'email'           : user.email,
        'role'            : user.role,
        'assigned_esp_id' : user.assignedEspId,
      },
      where: 'id = ?', whereArgs: [user.id]);
  }

  /// Supprime un utilisateur par son id
  Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  /// Change le mot de passe — rehache avant mise à jour
  Future<void> changePassword(int userId, String newPassword) async {
    final db = await database;
    await db.update('users',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = ?', whereArgs: [userId]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESP DEVICES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert ou remplace si l'id existe déjà (ConflictAlgorithm.replace)
  Future<void> upsertEsp(EspDevice esp) async {
    final db = await database;
    await db.insert('esp_devices', esp.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Tous les ESP triés par nom
  Future<List<EspDevice>> getAllEsps() async {
    final db   = await database;
    final rows = await db.query('esp_devices', orderBy: 'name ASC');
    return rows.map(EspDevice.fromMap).toList();
  }

  /// Admin → tous les ESP / Responsable → seulement son ESP assigné
  Future<List<EspDevice>> getEspsForUser(AppUser user) async {
    if (user.isAdmin) return getAllEsps();
    final db   = await database;
    final rows = await db.query('esp_devices',
        where: 'id = ?', whereArgs: [user.assignedEspId]);
    return rows.map(EspDevice.fromMap).toList();
  }

  /// Met à jour le statut en ligne et l'horodatage last_seen
  Future<void> setEspOnline(String espId, bool isOnline) async {
    final db = await database;
    await db.update('esp_devices',
      {
        'is_online' : isOnline ? 1 : 0,
        'last_seen' : DateTime.now().toIso8601String(),
      },
      where: 'id = ?', whereArgs: [espId]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SENSOR READINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sauvegarde une lecture et marque l'ESP comme online
  Future<int> insertReading(EnvironmentData data) async {
    final db = await database;
    await setEspOnline(data.deviceId, true);
    return db.insert('sensor_readings', {
      'esp_id'     : data.deviceId,
      'temperature': data.temperature,
      'humidity'   : data.humidity,
      'water_leak' : data.waterLeakDetected ? 1 : 0,
      'water_level': data.waterLevelRaw,
      'water_pct'  : data.waterLevelPercent,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  /// Lectures pour export — filtre par ESP + plage temporelle
  Future<List<SensorReading>> getReadingsForExport({
    required String   espId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db   = await database;
    final rows = await db.query(
      'sensor_readings',
      where:     'esp_id = ? AND recorded_at BETWEEN ? AND ?',
      whereArgs: [espId, from.toIso8601String(), to.toIso8601String()],
      orderBy:   'recorded_at ASC',
    );
    return rows.map(SensorReading.fromMap).toList();
  }

  /// Raccourci : lectures des N dernières heures pour un ESP
  Future<List<SensorReading>> getReadingsLastHours(String espId, int hours) async {
    final from = DateTime.now().subtract(Duration(hours: hours));
    return getReadingsForExport(espId: espId, from: from, to: DateTime.now());
  }

  /// Stats agrégées MIN/MAX/AVG pour un ESP sur une période
  Future<SensorStats> getStats({
    required String espId,
    int hoursBack = 24,
  }) async {
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
      WHERE esp_id = ? AND recorded_at >= ?
    ''', [espId, from]);

    if (result.isEmpty || result.first['total'] == 0) {
      return SensorStats.empty();
    }
    return SensorStats.fromMap(result.first);
  }

  /// Purge les lectures plus anciennes que keepDays jours
  Future<int> deleteOldReadings(int keepDays) async {
    final db     = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .toIso8601String();
    return db.delete('sensor_readings',
        where: 'recorded_at < ?', whereArgs: [cutoff]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert ou remplace une alerte (les alertes live ont des ids fixes)
  Future<void> insertAlert(AlertModel alert, {String espId = ''}) async {
    final db = await database;
    await db.insert('alerts', {
      'id'         : alert.id,
      'esp_id'     : espId.isEmpty ? alert.deviceId : espId,
      'device_id'  : alert.deviceId,
      'severity'   : alert.severity.name,
      'title'      : alert.title,
      'location'   : alert.location,
      'is_resolved': alert.isResolved ? 1 : 0,
      'created_at' : alert.timestamp.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Alertes pour export — filtre par ESP + plage temporelle
  Future<List<AlertModel>> getAlertsForExport({
    required String   espId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db   = await database;
    final rows = await db.query('alerts',
        where:     'esp_id = ? AND created_at BETWEEN ? AND ?',
        whereArgs: [espId, from.toIso8601String(), to.toIso8601String()],
        orderBy:   'created_at ASC');
    return rows.map(_alertFromMap).toList();
  }

  /// Alertes non résolues pour un ESP
  Future<List<AlertModel>> getActiveAlerts(String espId) async {
    final db   = await database;
    final rows = await db.query('alerts',
        where:     'esp_id = ? AND is_resolved = 0',
        whereArgs: [espId],
        orderBy:   'created_at DESC');
    return rows.map(_alertFromMap).toList();
  }

  /// Marque une alerte comme résolue
  Future<void> resolveAlert(String alertId) async {
    final db = await database;
    await db.update('alerts', {'is_resolved': 1},
        where: 'id = ?', whereArgs: [alertId]);
  }

  /// Convertit une ligne SQL en AlertModel
  AlertModel _alertFromMap(Map<String, dynamic> m) => AlertModel(
    id:         m['id']        as String,
    deviceId:   m['device_id'] as String,
    severity:   AlertSeverity.values.firstWhere(
        (e) => e.name == m['severity'],
        orElse: () => AlertSeverity.info),
    title:      m['title']     as String,
    location:   m['location']  as String? ?? '',
    isResolved: (m['is_resolved'] as int) == 1,
    timestamp:  DateTime.parse(m['created_at'] as String),
  );

  // ─── Utilitaires ─────────────────────────────────────────────────────────

  /// Hash SHA-256 du mot de passe — jamais stocké en clair
  String _hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<void> close() async => (await database).close();
}
