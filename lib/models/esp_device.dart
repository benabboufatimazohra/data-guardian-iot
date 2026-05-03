// ─────────────────────────────────────────────────────────────────────────────
// lib/models/esp_device.dart
//
// Modèle représentant un module ESP8266 enregistré dans la base de données.
//
// ERREUR CORRIGÉE :
//   L'ancienne version était incomplète — elle ne contenait que 'id' et 'name'.
//   Cela causait des erreurs dans :
//     - upsertEsp()       → toMap() ne fournissait pas ip_address, location, etc.
//     - EspDevice.fromMap → ip_address, room, is_online, firmware manquaient
//     - SettingsScreen    → affichage ESP row échouait (esp.ipAddress = null)
//
//   Ancienne version (INCOMPLÈTE) :
//     class EspDevice {
//       final String id;
//       final String name;
//       ...
//     }
//
//   Nouvelle version (COMPLÈTE) : tous les champs de la table esp_devices
//
// TABLE esp_devices (colonnes) :
//   id          TEXT PRIMARY KEY   → identifiant manuel ex: 'ESP8266-01'
//   name        TEXT               → nom affiché ex: 'ESP8266 — Rack A'
//   ip_address  TEXT               → adresse IP locale ex: '192.168.1.104'
//   location    TEXT               → emplacement physique ex: 'Rack A-04'
//   room        TEXT               → salle ex: 'Server Room A'
//   is_online   INTEGER (0/1)      → statut connexion (SQLite n'a pas de booléen)
//   firmware    TEXT               → version firmware ex: 'v2.0.4'
//   last_seen   TEXT (ISO8601)     → dernière communication
//   created_at  TEXT (ISO8601)     → date d'enregistrement
// ─────────────────────────────────────────────────────────────────────────────

class EspDevice {
  // Identifiant unique manuel (ex: 'ESP8266-01', 'ESP8266-02')
  // Défini par l'administrateur, pas auto-incrémenté
  final String id;

  // Nom lisible affiché dans l'interface (ex: 'ESP8266 — Rack A')
  final String name;

  // Adresse IP locale sur le réseau (ex: '192.168.1.104')
  final String ipAddress;

  // Emplacement physique précis (ex: 'Rack A-04')
  final String location;

  // Salle ou zone (ex: 'Server Room A')
  final String room;

  // true = ESP connecté et actif, false = hors ligne
  // Stocké comme INTEGER en SQLite : 1 = true, 0 = false
  final bool isOnline;

  // Version du firmware embarqué (ex: 'v2.0.4')
  final String firmware;

  // Horodatage de la dernière donnée reçue (null si jamais connecté)
  final DateTime? lastSeen;

  EspDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.location,
    required this.room,
    required this.isOnline,
    required this.firmware,
    this.lastSeen,
  });

  // ── Désérialisation depuis SQLite ─────────────────────────────────────────
  //
  // Conversion INTEGER → bool pour is_online :
  //   SQLite stocke 1 ou 0, Dart utilise true/false
  //   (m['is_online'] as int) == 1  fait cette conversion
  //
  factory EspDevice.fromMap(Map<String, dynamic> m) => EspDevice(
    id:        m['id']         as String,
    name:      m['name']       as String,
    ipAddress: m['ip_address'] as String,   // ← snake_case SQLite
    location:  m['location']   as String,
    room:      m['room']       as String,
    isOnline:  (m['is_online'] as int) == 1, // ← INTEGER → bool
    firmware:  m['firmware']   as String,
    lastSeen:  m['last_seen'] != null
        ? DateTime.tryParse(m['last_seen'] as String)
        : null,                              // ← null si jamais vu
  );

  // ── Sérialisation vers SQLite ─────────────────────────────────────────────
  //
  // Conversion bool → INTEGER pour is_online :
  //   true  → 1
  //   false → 0
  //
  // Utilisé par upsertEsp() avec ConflictAlgorithm.replace
  // (insert ou mise à jour si l'id existe déjà)
  //
  Map<String, dynamic> toMap() => {
    'id'        : id,
    'name'      : name,
    'ip_address': ipAddress,
    'location'  : location,
    'room'      : room,
    'is_online' : isOnline ? 1 : 0,          // ← bool → INTEGER
    'firmware'  : firmware,
    'last_seen' : lastSeen?.toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  };
}
