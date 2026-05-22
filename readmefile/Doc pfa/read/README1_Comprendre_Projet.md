# README 1 — Comprendre l'Ensemble du Projet DataGuardian IoT

> **Document de référence technique** — BENABBOU Fatima Zohra — PFA ENSAO GSEIR 2025-2026  
> Ce document t'explique **tout** le projet de manière claire, pour que tu puisses le défendre avec confiance.

---

## Table des matières

1. [Vue d'ensemble du projet](#1-vue-densemble)
2. [Architecture globale](#2-architecture-globale)
3. [Structure des dossiers](#3-structure-des-dossiers)
4. [Explication de chaque fichier](#4-explication-de-chaque-fichier)
5. [Flux de données complet](#5-flux-de-données-complet)
6. [Base de données SQLite](#6-base-de-données-sqlite)
7. [Communication HTTP avec l'ESP8266](#7-communication-http-avec-lesp8266)
8. [Gestion des alertes](#8-gestion-des-alertes)
9. [Packages et dépendances](#9-packages-et-dépendances)
10. [Démarrage du projet](#10-démarrage-du-projet)
11. [Conseils de débogage](#11-conseils-de-débogage)
12. [Questions fréquentes à la soutenance](#12-questions-fréquentes)

---

## 1. Vue d'ensemble

### Qu'est-ce que DataGuardian IoT ?

DataGuardian IoT est une application mobile de **surveillance environnementale en temps réel** pour salles serveurs ou tout environnement critique. Le système surveille :

- La **température** (via capteur DHT11/DHT22)
- L'**humidité** (via le même capteur DHT)
- Le **niveau d'eau** (via capteur analogique, valeur ADC 0-1023)
- La **détection de fuite** (via capteur numérique)

### Pourquoi ce projet est-il important ?

Dans une salle serveur, une surtempérature ou une fuite d'eau peut détruire des équipements coûteux en quelques minutes. Ce système permet une surveillance continue, des alertes automatiques, et un historique des incidents — le tout **sans dépendance à un cloud externe**.

### Ce que le projet N'utilise PAS (important pour la soutenance)

- ❌ Pas de Flask / serveur Python externe
- ❌ Pas de Firebase
- ❌ Pas de PostgreSQL
- ❌ Pas de cloud backend
- ✅ Architecture directe : ESP8266 ↔ Flutter ↔ SQLite local

---

## 2. Architecture globale

```
┌──────────────────────────────────────────────────────────┐
│                    COUCHE MATÉRIELLE                      │
│  [DHT11/22]──┐                                           │
│  [Capteur H2O]──► [ESP8266 NodeMCU] ◄──► [WiFi Router]  │
│  [Capteur fuite]──┘      ▲                               │
│                          │ HTTP GET /data                 │
└──────────────────────────┼───────────────────────────────┘
                           │
┌──────────────────────────┼───────────────────────────────┐
│                    COUCHE RÉSEAU LOCAL                     │
│              WiFi 192.168.x.x (réseau local)              │
└──────────────────────────┼───────────────────────────────┘
                           │
┌──────────────────────────┼───────────────────────────────┐
│                  APPLICATION FLUTTER                       │
│                                                           │
│  ┌─────────────┐   ┌──────────────┐  ┌────────────────┐  │
│  │ EspService  │   │ DatabaseHelper│  │ AuthService    │  │
│  │ (HTTP poll) │   │ (SQLite CRUD) │  │ (Login/Logout) │  │
│  └──────┬──────┘   └──────┬───────┘  └────────────────┘  │
│         │                 │                               │
│  ┌──────▼─────────────────▼───────────────────────────┐  │
│  │               COUCHE MODÈLES                        │  │
│  │  EnvironmentData │ AlertModel │ AppUser │ EspDevice  │  │
│  └────────────────────────────────────────────────────┘  │
│         │                                                 │
│  ┌──────▼──────────────────────────────────────────────┐ │
│  │                  ÉCRANS (UI)                         │ │
│  │  Login │ Dashboard │ Alerts │ History │ Settings     │ │
│  └─────────────────────────────────────────────────────┘ │
│         │                                                 │
│  ┌──────▼──────────────────────────────────────────────┐ │
│  │              BASE DE DONNÉES LOCALE                  │ │
│  │         SQLite — dataguardian_v2.db                  │ │
│  │  users │ esp_devices │ sensor_readings │ alerts       │ │
│  └─────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

**Flux simplifié :**
1. L'ESP8266 lit les capteurs en continu
2. Flutter envoie un `GET http://<IP_ESP>/data` toutes les 2 minutes
3. L'ESP répond avec un JSON contenant toutes les mesures
4. Flutter analyse les données, met à jour l'UI via des Streams
5. Si une alerte critique est détectée → sauvegarde en SQLite
6. L'historique et les exports sont générés depuis la base locale

---

## 3. Structure des dossiers

```
lib/
├── main.dart                    # Point d'entrée de l'app + routes
├── config/
│   └── api_config.dart          # IP de l'ESP, intervalles, timeouts
├── models/
│   ├── models.dart              # Fichier central — réexporte tout + modèles temps réel
│   ├── app_user.dart            # Modèle utilisateur (admin/responsable)
│   ├── esp_device.dart          # Modèle d'un module ESP enregistré
│   ├── sensor_reading.dart      # Une ligne de la table sensor_readings
│   └── sensor_stats.dart        # Statistiques agrégées MIN/MAX/AVG
├── database/
│   └── database_helper.dart     # Singleton SQLite — toutes les opérations CRUD
├── services/
│   ├── auth_service.dart        # Gestion de la session utilisateur
│   ├── esp_service.dart         # Polling HTTP + Streams de données
│   └── export_service.dart      # Génération Excel + PDF
├── screens/
│   ├── login_screen.dart        # Écran de connexion
│   ├── dashboard_screen.dart    # Tableau de bord temps réel
│   ├── alerts_screen.dart       # Liste des alertes
│   ├── alert_analysis_screen.dart # Analyse XAI d'une alerte
│   ├── device_detail_screen.dart  # Détail d'un ESP
│   ├── history_screen.dart      # Historique des alertes
│   ├── settings_screen.dart     # Administration (utilisateurs, ESP)
│   └── export_screen.dart       # Export Excel/PDF
├── widgets/
│   └── widgets.dart             # Widgets réutilisables (cartes, navigation, etc.)
└── theme/
    └── app_colors.dart          # Constantes de couleurs + styles de texte

test/
└── widget_test.dart             # Test de démarrage de l'application

.gitlab-ci.yml                   # Pipeline CI/CD (analyse + build APK)
pubspec.yaml                     # Dépendances et métadonnées du projet
```

---

## 4. Explication de chaque fichier

### `main.dart` — Point d'entrée

C'est le premier fichier exécuté. Il définit :
- Le thème visuel global (couleurs sombres, Material 3)
- La **table de routage** de l'application (quelles URLs vont vers quels écrans)
- La route initiale : `/login`

```dart
routes: {
  '/login':          LoginScreen,
  '/dashboard':      DashboardScreen,
  '/alerts':         AlertsScreen,
  '/alert-analysis': AlertAnalysisScreen,
  '/device-detail':  DeviceDetailScreen,
  '/history':        HistoryScreen,
  '/settings':       SettingsScreen,
  '/export':         ExportScreen,
}
```

**Pourquoi `pushReplacementNamed` dans la navigation ?**  
Pour éviter d'empiler les écrans en mémoire. Si l'utilisateur navigue Dashboard → Alerts → Dashboard, sans `Replacement`, il aurait 3 écrans en mémoire. Avec `Replacement`, chaque navigation remplace l'écran actuel.

---

### `config/api_config.dart` — Configuration de l'ESP

```dart
static const String espIpAddress = '192.168.11.111';  // À changer selon ton réseau
static const Duration pollingInterval = Duration(minutes: 2);
static const Duration requestTimeout  = Duration(minutes: 3);
```

**Pourquoi 2 minutes de polling ?**  
L'ESP8266 a des limitations mémoire et de CPU. Un polling trop fréquent (ex: toutes les secondes) peut surcharger le module et provoquer des redémarrages (watchdog timer). 2 minutes est un bon compromis pour la surveillance environnementale.

---

### `models/models.dart` — Hub central des modèles

Ce fichier a deux rôles :
1. **Réexporter** les modèles séparés (AppUser, EspDevice, SensorReading, SensorStats) → un seul import suffit partout
2. **Contenir** les modèles temps réel : `EnvironmentData`, `EspAlerts`, `AlertModel`, `AlertSeverity`

**Pourquoi regrouper EnvironmentData et AlertModel ici ?**  
Ces deux classes sont fortement couplées : `AlertModel.fromEspData()` prend un `EnvironmentData` en paramètre. Les séparer aurait créé des imports circulaires.

---

### `models/app_user.dart` — Utilisateur

Deux rôles possibles :
- **`admin`** : voit tous les ESP, peut gérer les utilisateurs et les appareils
- **`responsable`** : assigné à un seul ESP, voit uniquement ses données

**Erreur corrigée importante :**  
SQLite stocke les colonnes en `snake_case` (`full_name`, `assigned_esp_id`), mais l'ancienne version du code utilisait `camelCase` dans `fromMap()`. Cela provoquait des valeurs `null` silencieuses à la lecture.

```dart
// ❌ ANCIEN (faux) :
fullName: map['fullName'],          // null ! la colonne s'appelle 'full_name'

// ✅ CORRIGÉ :
fullName: m['full_name'],           // correct
```

---

### `models/esp_device.dart` — Module ESP

Représente un ESP8266 enregistré dans la base. Champs importants :
- `id` : identifiant manuel (`'ESP8266-01'`) — pas auto-incrémenté
- `ipAddress` : adresse IP locale pour les requêtes HTTP
- `isOnline` : `bool` en Dart, stocké comme `INTEGER` (0/1) en SQLite
- `lastSeen` : horodatage de la dernière communication reçue

---

### `models/sensor_reading.dart` — Lecture de capteur

Une ligne de la table `sensor_readings`. Attention aux types SQLite :
- `REAL` peut arriver comme `int` si la valeur est ronde → toujours utiliser `(m['temperature'] as num).toDouble()`
- `water_leak` est un `INTEGER` → conversion `== 1` pour obtenir un `bool`

---

### `models/sensor_stats.dart` — Statistiques agrégées

Pas une table SQLite — c'est le résultat d'un `rawQuery()` avec `MIN()`, `MAX()`, `AVG()`, `COUNT()`. Utilisé dans l'écran d'historique et les exports.

---

### `database/database_helper.dart` — Le cœur de la persistance

C'est le fichier le plus important après `esp_service`. Il utilise le **pattern Singleton** :

```dart
DatabaseHelper._();
static final DatabaseHelper instance = DatabaseHelper._();
```

**Pourquoi Singleton ?**  
Pour qu'il n'existe qu'une seule connexion à la base de données dans toute l'application. Plusieurs connexions simultanées à SQLite peuvent causer des erreurs de verrouillage.

**Tables créées au démarrage (`_onCreate`) :**
- `users` : administrateurs et responsables
- `esp_devices` : modules ESP enregistrés
- `sensor_readings` : historique des mesures
- `alerts` : historique des alertes

**Données initiales (`_seedData`) :**  
Un compte admin (`admin@dataguardian.com` / `Admin@1234`) et un ESP de démo sont insérés automatiquement à la première installation.

**Hachage des mots de passe :**  
Les mots de passe ne sont jamais stockés en clair. SHA-256 est appliqué avant insertion :
```dart
String _hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();
```

---

### `services/esp_service.dart` — Le service de polling

C'est le "moteur" de l'application. Il :
1. Lance un timer qui appelle `fetchOnce()` toutes les 2 minutes
2. Envoie une requête `GET http://<IP>/data` à l'ESP
3. Parse le JSON reçu en `EnvironmentData`
4. Diffuse les données via des **Streams** (3 streams : données, erreurs, connexion)
5. Sauvegarde en SQLite **uniquement les alertes critiques** (pas toutes les lectures)

**Pourquoi des Streams ?**  
Les streams permettent à plusieurs widgets de "s'abonner" aux données et d'être mis à jour automatiquement, sans que chaque widget ait besoin de faire sa propre requête.

**Pourquoi ne pas sauvegarder toutes les lectures ?**  
L'espace de stockage d'un téléphone est limité. Si l'app sonde toutes les 2 minutes et sauvegarde chaque lecture, ça représente 720 lignes par jour. Sur 30 jours : 21 600 lignes, juste pour un ESP. En ne sauvegardant que les alertes critiques, on économise l'espace et on garde ce qui compte.

---

### `services/auth_service.dart` — Session utilisateur

Service simple qui maintient l'utilisateur connecté en mémoire (`_currentUser`). Pas de token JWT — la session est gérée in-memory.

**Limite connue :** Si l'app est fermée et relancée, l'utilisateur doit se reconnecter. Pour une vraie app de production, on utiliserait `shared_preferences` pour persister la session.

---

### `services/export_service.dart` — Génération de fichiers

Génère des fichiers Excel (`.xlsx`) et PDF à partir des alertes stockées en SQLite.

- **Excel** : utilise le package `excel ^2.1.0`. Attention : l'API est différente entre `excel v2` et `excel v4`. Ce projet est compatible v2.
- **PDF** : utilise `pdf ^3.11.0` avec le package `pw` (pdf widgets).
- **Partage** : utilise `share_plus ^10.0.0` pour ouvrir le sélecteur de partage natif.

---

### `screens/dashboard_screen.dart` — Tableau de bord

L'écran principal. Points importants :

**Gestion des Streams :**
```dart
_dataSub = EspService.instance.dataStream.listen((data) {
  if (mounted) setState(() { _envData = data; _isLoading = false; });
});
```
`mounted` est vérifié avant chaque `setState()` pour éviter les erreurs si le widget a été détruit entre temps.

**Nettoyage dans `dispose()` :**
```dart
_dataSub?.cancel();
_errorSub?.cancel();
_connSub?.cancel();
```
Toujours annuler les abonnements aux streams dans `dispose()`, sinon des fuites mémoire se produisent.

**Jauge verticale d'eau (`_WaterTubePainter`) :**  
Dessinée avec `CustomPaint` qui utilise le Canvas Flutter directement — pas de bibliothèque externe nécessaire.

---

### `screens/alerts_screen.dart` — Alertes

Filtrage par onglets (Tout / Critique / Avertissement / Résolu). Le filtre est géré localement avec `_selectedTab` et un getter `_filteredAlerts`.

**Point de débogage :** Les alertes sont pour l'instant statiques (`_allAlerts` hardcodé). Dans une vraie version, `initState()` chargerait les alertes depuis `DatabaseHelper`.

---

### `screens/history_screen.dart` — Historique

Charge les alertes depuis SQLite pour les périodes 24H / 7J / 30J. Contient des `debugPrint()` pour diagnostiquer les problèmes de chargement.

**Correction importante (`_isLoading` bug) :**  
L'ancien code ne remettait pas `_isLoading = false` en cas d'erreur. La version corrigée utilise un `try/catch` avec `finally` pour s'assurer que le loader disparaît toujours.

---

### `screens/settings_screen.dart` — Administration

Gère les utilisateurs et les ESP. Points techniques :

**Correction `DropdownButton` :**  
L'ancien code utilisait `value: e` (un `EspDevice`) mais le type attendu était `String`. La correction : `value: e.id` (juste l'identifiant string).

**Pourquoi vérifier `user.id != currentUser?.id` avant de permettre la suppression ?**  
Pour éviter qu'un administrateur se supprime lui-même et perde l'accès à l'application.

---

### `widgets/widgets.dart` — Widgets réutilisables

Contient :
- `AppBottomNavBar` : barre de navigation inférieure avec 4 onglets
- `SensorGaugeCard` : carte avec jauge circulaire (température, humidité)
- `WaterLeakCard` : carte de détection de fuite
- `ActivityListItem` : ligne de la liste d'activité
- `AlertCard` : carte d'alerte avec boutons "Explain" et "Dismiss"

**Correction `AppBottomNavBar` :**  
L'ancien code ne gérait que les indices 0 et 2. La version corrigée gère les 4 indices avec `pushReplacementNamed`.

---

### `theme/app_colors.dart` — Palette de couleurs

Équivalent des variables CSS `:root`. Définit une palette cohérente utilisée dans toute l'application. À utiliser toujours à la place de `Color(0xFF...)` en dur dans les widgets.

---

## 5. Flux de données complet

### Scénario : L'ESP détecte une surtempérature

```
1. [ESP8266] — Capteur DHT lit 38°C
   → Calcule : 38 > 35 (seuil critique) → flag temp_critical = true
   → Encode en JSON :
   {
     "temperature": 38.2,
     "humidity": 42.0,
     "water_leak": false,
     "water_level": 50,
     "water_percent": 4.9,
     "timestamp": "2026-05-22T14:30:00",
     "device_id": "ESP8266-01",
     "alerts": { "temp_critical": true, "temp_warning": false, ... }
   }

2. [Timer Flutter] — Toutes les 2 minutes, EspService.fetchOnce() s'exécute
   → GET http://192.168.11.111:80/data
   → Timeout : 3 minutes

3. [EspService] — Reçoit la réponse HTTP 200
   → Parse JSON → EnvironmentData.fromJson(json)
   → _dataController.add(data)   ← diffuse via Stream

4. [DashboardScreen] — Écoute le Stream
   → setState() → rebuild de l'UI
   → La jauge de température passe au rouge
   → La carte de statut affiche "ALERTE"

5. [EspService] — Analyse les alertes
   → AlertModel.fromEspData(data) génère une liste d'alertes
   → Seules les alertes severity == critical sont sauvegardées
   → DatabaseHelper.insertAlert(alert) avec ConflictAlgorithm.replace

6. [HistoryScreen / ExportService] — Peut maintenant lire l'alerte
   → getAlertsForExport(espId, from, to) retourne la liste
   → Export Excel ou PDF possible
```

---

## 6. Base de données SQLite

### Schéma complet

```sql
CREATE TABLE users (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name       TEXT    NOT NULL,
  email           TEXT    NOT NULL UNIQUE,
  password_hash   TEXT    NOT NULL,     -- SHA-256, jamais en clair
  role            TEXT    NOT NULL DEFAULT 'responsable',  -- 'admin' | 'responsable'
  assigned_esp_id TEXT,                 -- null pour admin
  created_at      TEXT    NOT NULL      -- ISO8601
);

CREATE TABLE esp_devices (
  id          TEXT    PRIMARY KEY,      -- manuel ex: 'ESP8266-01'
  name        TEXT    NOT NULL,
  ip_address  TEXT    NOT NULL,
  location    TEXT    NOT NULL DEFAULT '',
  room        TEXT    NOT NULL DEFAULT '',
  is_online   INTEGER NOT NULL DEFAULT 0,  -- 0=false, 1=true
  firmware    TEXT    NOT NULL DEFAULT 'v2.0.4',
  last_seen   TEXT,
  created_at  TEXT    NOT NULL
);

CREATE TABLE sensor_readings (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  esp_id      TEXT    NOT NULL,
  temperature REAL    NOT NULL,
  humidity    REAL    NOT NULL,
  water_leak  INTEGER NOT NULL DEFAULT 0,  -- 0=false, 1=true
  water_level INTEGER NOT NULL DEFAULT 0,  -- ADC 0-1023
  water_pct   REAL    NOT NULL DEFAULT 0,
  recorded_at TEXT    NOT NULL,
  FOREIGN KEY (esp_id) REFERENCES esp_devices(id)
);

CREATE TABLE alerts (
  id          TEXT    PRIMARY KEY,   -- ex: 'live-temp-critical'
  esp_id      TEXT    NOT NULL,
  device_id   TEXT    NOT NULL,
  severity    TEXT    NOT NULL,      -- 'critical' | 'warning' | 'info'
  title       TEXT    NOT NULL,
  location    TEXT    NOT NULL DEFAULT '',
  is_resolved INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT    NOT NULL,
  FOREIGN KEY (esp_id) REFERENCES esp_devices(id)
);
```

### Index créés pour la performance

```sql
CREATE INDEX idx_readings_esp_time ON sensor_readings(esp_id, recorded_at);
CREATE INDEX idx_alerts_esp_time   ON alerts(esp_id, created_at);
CREATE INDEX idx_readings_time     ON sensor_readings(recorded_at);
```

Ces index accélèrent les requêtes filtrées par ESP et par plage de dates — les deux opérations les plus fréquentes dans l'app.

---

## 7. Communication HTTP avec l'ESP8266

### Format JSON attendu de l'ESP

```json
{
  "temperature": 24.5,
  "humidity": 48.2,
  "water_leak": false,
  "water_level": 120,
  "water_percent": 11.7,
  "timestamp": "2026-05-22T12:34:56",
  "device_id": "ESP8266-01",
  "ip": "192.168.1.104",
  "alerts": {
    "temp_critical": false,
    "temp_warning": false,
    "humidity_low": false,
    "humidity_high": false,
    "water_high": false
  }
}
```

### Endpoints ESP8266

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/data` | GET | Retourne le JSON de mesures complet |
| `/health` | GET | Ping rapide pour vérifier la connectivité |

### Gestion des erreurs côté Flutter

| Erreur | Cause probable | Comportement Flutter |
|--------|---------------|----------------------|
| `TimeoutException` | ESP éteint ou WiFi coupé | Affiche bannière rouge "OFFLINE" |
| HTTP 500 | Erreur firmware ESP | Affiche le code d'erreur |
| JSON invalide | Timestamp non standard | Fallback `DateTime.now()` |
| `SocketException` | Pas de réseau | Bannière d'erreur |

---

## 8. Gestion des alertes

### Seuils configurés côté ESP (firmware)

| Paramètre | Seuil avertissement | Seuil critique |
|-----------|--------------------|-|
| Température | > 35°C | > 40°C |
| Humidité basse | < 30% | < 20% |
| Humidité haute | > 75% | > 85% |
| Niveau d'eau | > 50% | > 70% |

### Cycle de vie d'une alerte

```
Détection ESP → flag dans JSON → EnvironmentData.fromJson()
    → AlertModel.fromEspData()
        → severity == critical ?
            OUI → DatabaseHelper.insertAlert() (ConflictAlgorithm.replace)
            NON → Affichage UI uniquement, non persistée
        → AlertsScreen affiche les alertes actives
        → Utilisateur clique "Dismiss" → resolveAlert()
```

### Pourquoi `ConflictAlgorithm.replace` pour les alertes ?

Les alertes live ont des IDs fixes (`'live-temp-critical'`, `'live-water'`, etc.). Si la même alerte est détectée à chaque polling, l'insert remplace l'entrée existante plutôt que de créer des doublons.

---

## 9. Packages et dépendances

| Package | Version | Utilisation |
|---------|---------|-------------|
| `http` | ^1.6.0 | Requêtes HTTP vers l'ESP |
| `crypto` | ^3.1.0 | Hachage SHA-256 des mots de passe |
| `sqflite` | ^2.4.0 | Base de données SQLite locale |
| `path` | ^1.8.4 | Construction des chemins de fichiers |
| `excel` | ^2.1.0 | Génération de fichiers Excel |
| `pdf` | ^3.11.0 | Génération de fichiers PDF |
| `path_provider` | ^3.0.0 | Accès aux dossiers du téléphone |
| `share_plus` | ^10.0.0 | Partage de fichiers natif |
| `cupertino_icons` | ^1.0.9 | Icônes iOS |

---

## 10. Démarrage du projet

### Prérequis

```bash
# Vérifier l'installation Flutter
flutter doctor

# Mettre à jour les dépendances
flutter pub get

# Vérifier les erreurs de code
flutter analyze
```

### Configuration avant lancement

1. Ouvrir `lib/config/api_config.dart`
2. Remplacer l'IP par celle de ton ESP8266 :
   ```dart
   static const String espIpAddress = '192.168.X.X';  // ton IP
   ```
3. S'assurer que le téléphone et l'ESP sont sur le même réseau WiFi
4. Flasher le firmware `esp8266_server.ino` sur l'ESP
5. Lancer l'app :
   ```bash
   flutter run
   ```

### Compte admin par défaut

- Email : `admin@dataguardian.com`
- Mot de passe : `Admin@1234`

---

## 11. Conseils de débogage

### L'app reste en "OFFLINE"

1. Vérifier que l'ESP est alimenté et que la LED WiFi clignote
2. Ouvrir le Serial Monitor Arduino (115200 baud) → noter l'IP affichée
3. Vérifier que `api_config.dart` contient la bonne IP
4. Tester depuis un navigateur : `http://192.168.X.X/health`
5. S'assurer que le téléphone et l'ESP sont sur le même WiFi (pas 4G !)

### Écran blanc au démarrage

```bash
flutter clean
flutter pub get
flutter run
```

### Erreurs SQLite

- Vérifier que les noms de colonnes dans `fromMap()` correspondent exactement au schéma dans `_onCreate()`
- Si la base est corrompue, désinstaller l'app et la réinstaller

### `withOpacity() deprecated`

Déjà corrigé dans le code. Utiliser toujours `.withValues(alpha: 0.X)`.

### Conflits de packages

```bash
flutter pub outdated     # voir les packages à mettre à jour
dart fix --apply         # corriger les problèmes auto-détectés
```

---

## 12. Questions fréquentes à la soutenance

**Q : Pourquoi pas Firebase ?**  
R : Firebase nécessite une connexion Internet permanente, implique des coûts au-delà du quota gratuit, et crée une dépendance à un service tiers. Notre solution fonctionne entièrement en réseau local sans connexion Internet.

**Q : Pourquoi SQLite et pas une autre base ?**  
R : SQLite est intégré nativement à Flutter via `sqflite`. Elle est légère, ne nécessite pas de serveur, fonctionne hors ligne, et est parfaitement adaptée au volume de données d'une application mobile mono-utilisateur.

**Q : Pourquoi HTTP et pas MQTT ?**  
R : HTTP est plus simple à implémenter sur ESP8266, plus facile à déboguer (testable avec un navigateur), et suffisant pour une fréquence de polling de 2 minutes. MQTT serait pertinent si on avait besoin d'un push temps réel sub-seconde.

**Q : Comment fonctionne le polling ?**  
R : Un `Timer.periodic()` déclenche `fetchOnce()` toutes les 2 minutes. Ce n'est pas du push — c'est du pull. L'ESP ne contacte jamais Flutter ; c'est toujours Flutter qui interroge l'ESP.

**Q : Que se passe-t-il si le WiFi est coupé ?**  
R : Une `TimeoutException` est capturée, le badge passe en "OFFLINE", une bannière rouge s'affiche. Le timer continue à essayer et lorsque le WiFi revient, l'app se reconnecte automatiquement.
