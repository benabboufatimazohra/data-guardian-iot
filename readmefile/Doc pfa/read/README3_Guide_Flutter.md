# README 3 — Guide Flutter Complet — Du Débutant à la Soutenance

> **Guide de préparation à la soutenance** — BENABBOU Fatima Zohra  
> Comprendre Flutter en profondeur pour défendre le projet avec confiance.

---

## Table des matières

1. [Flutter — Fondamentaux](#1-flutter--fondamentaux)
2. [StatelessWidget vs StatefulWidget](#2-statelesswidget-vs-statefulwidget)
3. [Gestion d'état — Provider et alternatives](#3-gestion-détat--provider-et-alternatives)
4. [Structure d'un projet Flutter](#4-structure-dun-projet-flutter)
5. [Programmation asynchrone](#5-programmation-asynchrone)
6. [HTTP et réseau](#6-http-et-réseau)
7. [SQLite — Base de données locale](#7-sqlite--base-de-données-locale)
8. [Commandes Flutter essentielles](#8-commandes-flutter-essentielles)
9. [Débogage et développement](#9-débogage-et-développement)
10. [Bonnes pratiques](#10-bonnes-pratiques)
11. [Questions de soutenance et réponses](#11-questions-de-soutenance-et-réponses)

---

## 1. Flutter — Fondamentaux

### Qu'est-ce que Flutter ?

Flutter est un **framework open-source de Google** permettant de créer des applications mobiles, web et desktop à partir d'un **seul code source**. Il utilise le langage **Dart**.

**En résumé :**
- Un seul code → Android + iOS (+ Web + Desktop)
- Interface graphique rendue par son propre moteur (Skia/Impeller)
- Haute performance (compilé en code natif)
- Design Material 3 et Cupertino intégrés

### Flutter vs développement natif

| Critère | Flutter | Android (Kotlin) | iOS (Swift) |
|---------|---------|-----------------|-------------|
| Langages | Dart | Kotlin/Java | Swift/ObjC |
| Cibles | Android + iOS + Web | Android seulement | iOS seulement |
| Performance | ⭐⭐⭐⭐ Très bonne | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐⭐⭐ Native |
| Courbe d'apprentissage | ⭐⭐⭐ Modérée | ⭐⭐ Longue | ⭐⭐ Longue |
| Communauté | ⭐⭐⭐⭐⭐ Grande | ⭐⭐⭐⭐⭐ Grande | ⭐⭐⭐⭐ Bonne |
| Hot Reload | ✅ | ⚠️ Limité | ⚠️ Limité |
| Packages IoT | ✅ Nombreux | ✅ | ✅ |

### Architecture Flutter

```
┌──────────────────────────────────────────┐
│              TON CODE DART                │
│  (Widgets, Services, Models, etc.)        │
├──────────────────────────────────────────┤
│           FRAMEWORK FLUTTER               │
│  (Material, Cupertino, Animations, etc.) │
├──────────────────────────────────────────┤
│              MOTEUR FLUTTER               │
│  (Skia/Impeller — rendu graphique)        │
├──────────────────────────────────────────┤
│          EMBEDDER PLATEFORME              │
│     Android (JNI)  |  iOS (ObjC)         │
└──────────────────────────────────────────┘
```

### Le langage Dart — Bases essentielles

```dart
// Variables
String nom = "DataGuardian";   // Type explicite
var version = 2.0;             // Type inféré par Dart
final url = 'http://esp/data'; // Immutable à l'exécution
const pi = 3.14159;            // Immutable à la compilation

// Null safety (très important en Flutter 3.x)
String? email = null;          // Peut être null (le ? l'indique)
String nom = "Fatima";         // Ne peut PAS être null

// Opérateur null-aware
String affichage = email ?? "Non défini";    // Si null → "Non défini"
email?.toLowerCase();                         // Si null → null (pas d'erreur)
email!.toLowerCase();                         // Force non-null (crash si null!)

// Fonctions
double celsius(double kelvin) => kelvin - 273.15;  // Arrow function
Future<String> fetchData() async { ... }           // Async function

// Classes
class Capteur {
  final String id;
  double temperature;
  
  Capteur({required this.id, this.temperature = 0});
  
  bool get isChaud => temperature > 35;  // Getter
}
```

### Le concept de Widget Tree

**Tout en Flutter est un Widget.** Chaque élément visuel — bouton, texte, couleur de fond, marge — est un widget.

```
MaterialApp
└── Scaffold
    ├── AppBar
    │   └── Text("Dashboard")
    └── body: Column
        ├── Container (carte)
        │   └── Text("24.5°C")
        └── Container (carte)
            └── Text("48%")
```

L'**arbre de widgets** est reconstruit partiellement à chaque `setState()`. Flutter compare l'ancien arbre avec le nouveau (reconciliation) et ne redessine que ce qui a changé — c'est pourquoi c'est rapide.

### BuildContext

`BuildContext` est un objet qui représente **l'emplacement d'un widget dans l'arbre**. Il est passé automatiquement à `build()`.

Utilisations courantes :
```dart
// Navigation
Navigator.pushNamed(context, '/dashboard');

// Afficher un SnackBar
ScaffoldMessenger.of(context).showSnackBar(SnackBar(...));

// Lire un thème
Theme.of(context).colorScheme.primary

// Provider
Provider.of<MonProvider>(context)
```

---

## 2. StatelessWidget vs StatefulWidget

### StatelessWidget — Widget sans état

Un `StatelessWidget` ne change **jamais** après sa création. Sa méthode `build()` est appelée une fois et produit une UI statique.

```dart
class MonBouton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  
  const MonBouton({required this.label, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
```

**Utiliser StatelessWidget quand :**
- L'UI ne change pas (titre, icône, texte fixe)
- Toutes les données viennent des paramètres du constructeur
- Exemple dans le projet : `AppColors`, `SensorGaugeCard` (les données lui sont passées)

### StatefulWidget — Widget avec état

Un `StatefulWidget` peut se **reconstruire** quand ses données internes changent, grâce à `setState()`.

```dart
class CompteurWidget extends StatefulWidget {
  const CompteurWidget({super.key});
  
  @override
  State<CompteurWidget> createState() => _CompteurWidgetState();
}

class _CompteurWidgetState extends State<CompteurWidget> {
  int _count = 0;  // ← ÉTAT local
  
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$_count'),
      ElevatedButton(
        onPressed: () => setState(() => _count++),  // ← rebuild
        child: const Text('+1'),
      ),
    ]);
  }
}
```

**Utiliser StatefulWidget quand :**
- L'UI doit réagir à des actions utilisateur
- Des données changent dans le temps (polling, animation)
- Des timers ou des streams sont utilisés
- Exemple dans le projet : `DashboardScreen`, `AlertsScreen`, `LoginScreen`

### Cycle de vie d'un StatefulWidget

```
createState()       → Crée l'objet State
    ↓
initState()         → Appelé une seule fois au démarrage
    ↓               (démarrer timers, streams, initialiser données)
build()             → Construit l'UI
    ↓               (appelé à chaque setState() ou reconstruction parent)
setState()          → Marque le widget comme "dirty" → rebuild
    ↓
dispose()           → Appelé quand le widget est détruit
                    (annuler timers, streams, controllers!)
```

**Exemple dans DashboardScreen :**
```dart
@override
void initState() {
  super.initState();
  // ← Ici on démarre le polling et les écoutes de streams
  _dataSub = EspService.instance.dataStream.listen(...);
  EspService.instance.startPolling();
}

@override
void dispose() {
  // ← Ici on nettoie tout pour éviter les fuites mémoire
  _dataSub?.cancel();
  _errorSub?.cancel();
  _connSub?.cancel();
  super.dispose();
}
```

---

## 3. Gestion d'état — Provider et alternatives

### Qu'est-ce que la gestion d'état ?

L'"état" d'une app, c'est **l'ensemble des données qui peuvent changer** et qui influencent l'affichage. La gestion d'état consiste à organiser comment ces données circulent entre les widgets.

**Le problème :**
```
AppRoot
├── Dashboard (a besoin des données ESP)
│   ├── TemperatureCard (a besoin de la température)
│   └── HumidityCard (a besoin de l'humidité)
└── AlertsScreen (a besoin des alertes)
```

Si on passe les données par les constructeurs (`prop drilling`), ça devient vite ingérable avec des arbres profonds.

### Solution 1 : setState() local (utilisé dans ce projet)

```dart
// Simple, utilisé pour l'état LOCAL d'un seul écran
setState(() {
  _envData = data;
  _isLoading = false;
});
```

**Avantage :** Simple, pas de package supplémentaire  
**Limite :** Difficile à partager entre plusieurs écrans

### Solution 2 : Streams (utilisé dans ce projet pour les données ESP)

```dart
// EspService expose des Streams — les widgets s'abonnent
Stream<EnvironmentData> get dataStream => _dataController.stream;

// Dans DashboardScreen :
_dataSub = EspService.instance.dataStream.listen((data) {
  setState(() => _envData = data);
});
```

**Avantage :** Parfait pour les données qui arrivent en continu  
**Limite :** Nécessite de gérer les abonnements manuellement

### Solution 3 : Provider (package recommandé pour les grandes apps)

```yaml
dependencies:
  provider: ^6.1.2
```

```dart
// 1. Créer un ChangeNotifier
class EspDataProvider extends ChangeNotifier {
  EnvironmentData? _data;
  EnvironmentData? get data => _data;
  
  void updateData(EnvironmentData newData) {
    _data = newData;
    notifyListeners();  // ← Notifie tous les consumers
  }
}

// 2. Exposer le provider dans l'arbre de widgets
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => EspDataProvider(),
      child: const DataGuardianApp(),
    ),
  );
}

// 3. Consommer dans n'importe quel widget
class TemperatureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = context.watch<EspDataProvider>().data;
    return Text('${data?.temperature ?? '--'}°C');
  }
}

// Ou lire sans écouter :
final data = context.read<EspDataProvider>().data;
```

### Pourquoi ce projet utilise setState + Streams plutôt que Provider ?

Ce projet est de taille modérée avec des écrans relativement indépendants. `setState()` et les Streams suffisent. Provider serait plus pertinent si :
- L'app grandissait avec 10+ écrans partageant les mêmes données
- On avait besoin de partager l'état utilisateur (AuthService) plus facilement
- On voulait éviter la propagation de callbacks

### Alternatives à Provider

| Solution | Complexité | Adapté pour |
|----------|-----------|-------------|
| `setState` | ⭐ Très simple | État local d'un widget |
| `Streams` | ⭐⭐ Simple | Données en continu |
| `Provider` | ⭐⭐⭐ Modérée | Apps moyennes à grandes |
| `Riverpod` | ⭐⭐⭐ Modérée | Comme Provider mais plus safe |
| `Bloc/Cubit` | ⭐⭐⭐⭐ Avancée | Apps d'entreprise |
| `GetX` | ⭐⭐ Simple | Rapide à implémenter |

---

## 4. Structure d'un projet Flutter

### Organisation recommandée

```
lib/
├── main.dart                    # Point d'entrée unique
│
├── config/                      # Configuration globale
│   └── api_config.dart          # URLs, timeouts, constantes
│
├── models/                      # Structures de données
│   ├── models.dart              # Hub central des modèles
│   ├── app_user.dart            # Données utilisateur
│   ├── esp_device.dart          # Données ESP
│   ├── sensor_reading.dart      # Lecture capteur
│   └── sensor_stats.dart        # Statistiques
│
├── database/                    # Persistance locale
│   └── database_helper.dart     # Toutes les opérations SQLite
│
├── services/                    # Logique métier / communication
│   ├── auth_service.dart        # Authentification
│   ├── esp_service.dart         # Communication HTTP ESP
│   └── export_service.dart      # Génération de fichiers
│
├── screens/                     # Écrans de l'application
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   └── ...
│
├── widgets/                     # Composants réutilisables
│   └── widgets.dart             # Tous les widgets partagés
│
└── theme/                       # Design system
    └── app_colors.dart          # Couleurs, typographie, spacing

assets/                          # Images, fonts, fichiers statiques
test/                            # Tests unitaires et widgets
pubspec.yaml                     # Manifeste du projet
```

### Principe de Séparation des Responsabilités

| Couche | Rôle | Exemples |
|--------|------|---------|
| `models/` | Représenter les données | `AppUser`, `EnvironmentData` |
| `services/` | Communiquer avec l'extérieur | HTTP, SQLite, Auth |
| `screens/` | Afficher et interagir | Dashboard, Login |
| `widgets/` | Composants visuels réutilisables | `AlertCard`, `SensorGaugeCard` |
| `theme/` | Style visuel cohérent | Couleurs, tailles |

---

## 5. Programmation asynchrone

### Pourquoi l'asynchronisme est essentiel en Flutter ?

Flutter tourne sur le **thread principal** (UI thread). Si on bloque ce thread (ex: attendre une réponse HTTP pendant 2 secondes), l'interface gèle et devient inutilisable.

La solution : les opérations longues (réseau, BDD, fichiers) sont **asynchrones** — elles s'exécutent en arrière-plan sans bloquer l'UI.

### Future — Une valeur qui sera disponible plus tard

```dart
// Une Future représente une opération qui prendra du temps
Future<String> fetchTemperature() async {
  await Future.delayed(const Duration(seconds: 2));  // Simule une attente
  return "24.5°C";
}

// Utilisation avec async/await
Future<void> afficherTemperature() async {
  print("Chargement...");
  final temp = await fetchTemperature();  // ← attend que la Future se complète
  print("Température : $temp");
}

// Utilisation avec then()
fetchTemperature().then((temp) {
  print("Température : $temp");
}).catchError((e) {
  print("Erreur : $e");
});
```

### async/await dans le projet

```dart
// Dans EspService.fetchOnce() :
Future<EnvironmentData?> fetchOnce() async {
  try {
    // await suspend l'exécution jusqu'à la réponse HTTP
    final response = await http
        .get(Uri.parse(ApiConfig.dataUrl))
        .timeout(ApiConfig.requestTimeout);
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return EnvironmentData.fromJson(json);
    }
    return null;
  } on TimeoutException {
    // Si l'ESP ne répond pas dans le délai
    _errorController.add('Timeout — ESP non disponible');
    return null;
  } catch (e) {
    _errorController.add('Erreur réseau: $e');
    return null;
  }
}
```

### FutureBuilder — Construire l'UI quand la Future est prête

```dart
FutureBuilder<List<AlertModel>>(
  future: DatabaseHelper.instance.getAlertsForExport(...),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();  // Chargement
    }
    if (snapshot.hasError) {
      return Text('Erreur: ${snapshot.error}');
    }
    final alerts = snapshot.data ?? [];
    return ListView.builder(
      itemCount: alerts.length,
      itemBuilder: (_, i) => AlertCard(alert: alerts[i]),
    );
  },
)
```

### Stream — Flux de données continues

```dart
// Un Stream émet plusieurs valeurs dans le temps
// Exemple : nouvelles données ESP toutes les 2 minutes

// Créer un Stream (dans EspService)
final _controller = StreamController<EnvironmentData>.broadcast();
Stream<EnvironmentData> get dataStream => _controller.stream;

// Émettre une valeur
_controller.add(newData);

// S'abonner dans un widget
@override
void initState() {
  super.initState();
  _sub = EspService.instance.dataStream.listen((data) {
    setState(() => _envData = data);
  });
}

@override
void dispose() {
  _sub.cancel();  // TOUJOURS annuler les abonnements !
  super.dispose();
}
```

### StreamBuilder — Construire l'UI sur un Stream

```dart
StreamBuilder<EnvironmentData>(
  stream: EspService.instance.dataStream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const Text('En attente...');
    
    final data = snapshot.data!;
    return Text('${data.temperature}°C');
  },
)
```

---

## 6. HTTP et réseau

### Requête HTTP GET avec le package `http`

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>?> getEspData(String ipAddress) async {
  try {
    final url = Uri.parse('http://$ipAddress/data');
    
    final response = await http.get(url).timeout(
      const Duration(seconds: 5),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      print('Erreur HTTP: ${response.statusCode}');
      return null;
    }
  } on TimeoutException {
    print('Timeout — pas de réponse');
    return null;
  } on SocketException catch (e) {
    print('Pas de réseau: $e');
    return null;
  } catch (e) {
    print('Erreur inattendue: $e');
    return null;
  }
}
```

### Sérialisation JSON

```dart
// JSON → Objet Dart (désérialisation)
final jsonString = '{"temperature": 24.5, "humidity": 48}';
final map = jsonDecode(jsonString);           // → Map<String, dynamic>
final temp = map['temperature'] as double;   // → 24.5

// Objet Dart → JSON (sérialisation)
final data = {'temperature': 24.5, 'device': 'ESP8266-01'};
final jsonStr = jsonEncode(data);            // → String JSON
```

### Gestion des timeouts

```dart
// Dans ApiConfig :
static const Duration requestTimeout = Duration(minutes: 3);

// Dans EspService :
final response = await http
    .get(Uri.parse(ApiConfig.dataUrl))
    .timeout(ApiConfig.requestTimeout);
```

**Pourquoi un timeout de 3 minutes ?**  
C'est délibérément long pour laisser le temps à l'ESP8266 de répondre même si le réseau WiFi est lent ou instable. Un timeout trop court provoquerait des faux négatifs.

### Dio vs http

| Critère | `http` (utilisé) | `Dio` |
|---------|-----------------|-------|
| Simplicité | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Intercepteurs | ❌ | ✅ |
| Retry automatique | ❌ | ✅ avec plugin |
| Cancel request | ⚠️ Limité | ✅ |
| Multipart upload | ⚠️ Manuel | ✅ Simple |
| Adapté pour ce projet | ✅ Oui | ✅ Oui |

`http` est suffisant pour ce projet. `Dio` serait préférable pour une app avec beaucoup d'endpoints et une gestion d'erreurs centralisée.

---

## 7. SQLite — Base de données locale

### Pourquoi SQLite ?

SQLite est une base de données **embarquée** — elle vit dans un fichier sur l'appareil, sans serveur. C'est la solution idéale pour les applications mobiles qui ont besoin de persistance locale.

### Opérations CRUD de base avec sqflite

```dart
// INITIALISATION
final db = await openDatabase(
  join(await getDatabasesPath(), 'app.db'),
  version: 1,
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE capteurs (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        nom   TEXT NOT NULL,
        valeur REAL NOT NULL,
        horodatage TEXT NOT NULL
      )
    ''');
  },
);

// CREATE (Insert)
await db.insert('capteurs', {
  'nom': 'température',
  'valeur': 24.5,
  'horodatage': DateTime.now().toIso8601String(),
});

// READ (Select)
final List<Map<String, dynamic>> rows = await db.query(
  'capteurs',
  where: 'valeur > ?',
  whereArgs: [30.0],
  orderBy: 'horodatage DESC',
  limit: 10,
);
final lectures = rows.map(LectureCapteur.fromMap).toList();

// UPDATE
await db.update(
  'capteurs',
  {'valeur': 25.0},
  where: 'id = ?',
  whereArgs: [1],
);

// DELETE
await db.delete(
  'capteurs',
  where: 'horodatage < ?',
  whereArgs: [DateTime.now().subtract(Duration(days: 30)).toIso8601String()],
);

// RAW QUERY (pour les agrégations)
final result = await db.rawQuery('''
  SELECT MIN(valeur) as min, MAX(valeur) as max, AVG(valeur) as avg
  FROM capteurs
  WHERE horodatage >= ?
''', [DateTime.now().subtract(Duration(hours: 24)).toIso8601String()]);
```

### Pattern Singleton pour DatabaseHelper

```dart
// Pourquoi Singleton ?
// SQLite ne supporte qu'une seule connexion active sûre.
// Le Singleton garantit qu'on n'ouvre la base qu'une seule fois.

class DatabaseHelper {
  DatabaseHelper._();  // Constructeur privé
  static final DatabaseHelper instance = DatabaseHelper._();  // Instance unique
  
  static Database? _db;
  
  Future<Database> get database async {
    _db ??= await _initDb();  // Ouvre seulement si pas déjà ouvert
    return _db!;
  }
}
```

### Avantages de la base locale pour ce projet

1. **Fonctionne hors ligne** : Les alertes sont sauvegardées même sans Internet
2. **Pas de coût** : Pas d'abonnement Firebase ou autre
3. **Confidentialité** : Les données restent sur l'appareil
4. **Performance** : Accès instantané sans latence réseau
5. **Simplicité** : Pas de backend à maintenir

---

## 8. Commandes Flutter essentielles

### `flutter doctor`

```bash
flutter doctor
```

**Ce que ça fait :** Vérifie que tout l'environnement de développement Flutter est correctement installé (Android SDK, Xcode, émulateurs, etc.)

**Quand l'utiliser :** En premier lieu si quelque chose ne fonctionne pas. La commande indique clairement ce qui manque avec des suggestions de correction.

**Exemple de sortie :**
```
✓ Flutter (Channel stable, 3.x.x)
✓ Android toolchain
✗ Xcode - iOS development (Xcode not installed)
✓ Android Studio
✓ Connected device (1 available)
```

---

### `flutter pub get`

```bash
flutter pub get
```

**Ce que ça fait :** Télécharge toutes les dépendances listées dans `pubspec.yaml`. Équivalent de `npm install` ou `pip install -r requirements.txt`.

**Quand l'utiliser :**
- Après avoir cloné un projet
- Après avoir ajouté un nouveau package à `pubspec.yaml`
- Si tu vois l'erreur "Target of URI doesn't exist"

---

### `flutter analyze`

```bash
flutter analyze
```

**Ce que ça fait :** Analyse statique du code — détecte les erreurs, avertissements, et violations des règles de style sans exécuter l'app.

**Pourquoi c'est important :** Le pipeline CI/CD du projet l'exécute automatiquement à chaque commit. Si `flutter analyze` échoue, le build est bloqué.

**Corrections automatiques :**
```bash
dart fix --apply  # Corrige automatiquement les problèmes simples
```

---

### `flutter clean`

```bash
flutter clean
```

**Ce que ça fait :** Supprime tous les fichiers compilés et le cache (dossiers `build/`, `.dart_tool/`).

**Quand l'utiliser :**
- Quand l'app a un comportement bizarre inexpliqué
- Après un changement de version Flutter
- Après avoir résolu des conflits de packages
- Toujours suivre de `flutter pub get`

---

### `flutter run`

```bash
flutter run                          # Lance sur l'appareil/émulateur disponible
flutter run -d <device_id>          # Lance sur un appareil spécifique
flutter run --release               # Lance en mode release (plus rapide)
flutter run --profile               # Mode profiling (performance)
```

**Ce que ça fait :** Compile et lance l'application sur l'appareil connecté ou l'émulateur.

**Raccourcis pendant l'exécution :**
- `r` : Hot Reload (recharge l'UI instantanément)
- `R` : Hot Restart (redémarre l'app)
- `q` : Quitter
- `p` : Afficher le widget tree
- `v` : Ouvrir Flutter DevTools

---

### `flutter build apk`

```bash
flutter build apk --release          # APK optimisé pour la production
flutter build apk --debug            # APK de débogage
flutter build apk --split-per-abi   # APK séparés par architecture (plus petit)
```

**Ce que ça fait :** Compile l'application en fichier APK installable sur Android.

**Le fichier généré :** `build/app/outputs/flutter-apk/app-release.apk`

**Utilisé dans le pipeline CI/CD du projet** pour générer l'APK automatiquement à chaque push sur `main`.

---

### `flutter devices`

```bash
flutter devices
```

**Ce que ça fait :** Liste tous les appareils disponibles (physiques et émulateurs).

**Exemple :**
```
2 connected devices:

Android SDK built for x86 64 (mobile) • emulator-5554 • android-x64
SM-A52s (mobile)                      • R3CN90XXXXX   • android-arm64
```

---

### `flutter upgrade`

```bash
flutter upgrade          # Met à jour Flutter vers la dernière version stable
flutter upgrade --force  # Force la mise à jour
```

**Quand l'utiliser :** Rarement pendant un projet actif — une mise à jour peut casser des packages. Le faire plutôt entre les versions du projet.

---

### `flutter test`

```bash
flutter test                         # Lance tous les tests
flutter test test/widget_test.dart   # Lance un fichier de test spécifique
flutter test --coverage              # Avec rapport de couverture
```

**Ce que ça fait :** Exécute les tests unitaires et widget tests dans le dossier `test/`.

**Dans ce projet :** `test/widget_test.dart` vérifie que l'app démarre sans planter.

---

## 9. Débogage et développement

### Hot Reload vs Hot Restart

| | Hot Reload (`r`) | Hot Restart (`R`) |
|--|-----------------|------------------|
| Vitesse | ~200ms | ~2-3s |
| Reset de l'état | ❌ Non | ✅ Oui |
| Utile pour | Changements UI | Changements logiques |
| Preserve les données | ✅ | ❌ |

### Logs et debugging

```dart
// Print simple
print("Données reçues: $data");

// Print de debug (n'apparaît pas en release)
debugPrint("DEBUG: Temperature = ${data.temperature}");

// Assert (crash en debug si la condition est fausse)
assert(temperature >= 0, "La température ne peut pas être négative");
```

### Flutter DevTools

Accessible via `flutter run` puis `v`, ou à `http://127.0.0.1:9100`.

Fonctionnalités utiles :
- **Widget Inspector** : Visualise l'arbre de widgets
- **Performance** : Détecte les janks (images à 60fps)
- **Memory** : Détecte les fuites mémoire
- **Logging** : Voir tous les prints en temps réel

### Erreurs courantes et solutions

**`setState() called after dispose()`**
```dart
// Cause : le widget est détruit mais un callback essaie encore d'appeler setState
// Solution : vérifier mounted avant setState
if (mounted) setState(() { ... });
```

**`RenderFlex overflowed`**
```dart
// Cause : un widget dépasse sa zone d'affichage
// Solution : envelopper dans Expanded, Flexible, ou SingleChildScrollView
```

**`type 'Null' is not a subtype of type 'String'`**
```dart
// Cause : null safety — une valeur peut être null
// Solution : utiliser ?? pour fournir une valeur par défaut
final nom = user.nom ?? "Inconnu";
```

**`MissingPluginException`**
```dart
// Cause : un plugin natif n'est pas initialisé
// Solution : flutter clean && flutter pub get && redémarrer l'émulateur
```

---

## 10. Bonnes pratiques

### Nommage

```dart
// Classes : PascalCase
class DatabaseHelper {}
class EspService {}

// Variables et méthodes : camelCase
String fullName;
Future<void> fetchOnce() {}

// Constantes : camelCase avec const
const double maxTemperature = 40.0;

// Fichiers : snake_case
database_helper.dart
esp_service.dart
```

### Widgets réutilisables

```dart
// ❌ NE PAS faire : dupliquer le même design partout
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: Color(0xFF1A2332), ...),
  child: Text(...)
)

// ✅ FAIRE : créer un widget réutilisable
class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, ...),
      child: child,
    );
  }
}
```

### Gestion des couleurs

```dart
// ❌ NE PAS faire : couleurs en dur
Container(color: const Color(0xFF3C83F6))

// ✅ FAIRE : utiliser les constantes
Container(color: AppColors.primary)
```

### const et final

```dart
// Utiliser const quand possible — améliore les performances
const Text("Température");       // ✅ reconstruit jamais
const EdgeInsets.all(16);        // ✅ 

// final pour les valeurs calculées une seule fois
final theme = Theme.of(context);
final date = DateTime.now();
```

---

## 11. Questions de soutenance et réponses

### Questions générales sur Flutter

**Q : Pourquoi avez-vous choisi Flutter ?**  
R : Flutter permet de développer une seule fois pour Android et iOS. Pour un projet PFA avec des ressources limitées, c'est idéal — un seul codebase à maintenir, des performances proches du natif, et une communauté très active avec des packages IoT disponibles.

**Q : Quelle est la différence entre StatelessWidget et StatefulWidget ?**  
R : Un StatelessWidget est immuable — son UI ne change jamais après construction. Un StatefulWidget possède un objet State associé dont les données peuvent changer. Quand on appelle `setState()`, Flutter reconstruit uniquement ce widget et ses enfants. J'utilise StatefulWidget pour le Dashboard (données qui changent toutes les 2 minutes) et StatelessWidget pour les composants visuels fixes comme les cartes.

**Q : Comment fonctionne la navigation dans Flutter ?**  
R : Flutter utilise un système de routes. Dans `main.dart`, je définis une table de routes (URL → écran). Pour naviguer, j'utilise `Navigator.pushReplacementNamed(context, '/dashboard')`. Le `Replacement` remplace l'écran actuel pour éviter d'empiler des écrans en mémoire.

---

### Questions sur l'architecture du projet

**Q : Pourquoi utiliser le pattern Singleton pour DatabaseHelper ?**  
R : SQLite ne supporte qu'une connexion active fiable. Le Singleton garantit qu'une seule instance de la connexion existe dans toute l'application, évitant les erreurs de verrouillage de base de données.

**Q : Pourquoi ne pas sauvegarder toutes les lectures en base ?**  
R : L'app interroge l'ESP toutes les 2 minutes — ça ferait 720 lignes par jour, 21 600 par mois. Nous sauvegardons uniquement les alertes critiques, ce qui réduit l'espace de 99% tout en conservant ce qui est important.

**Q : Comment gérez-vous les erreurs réseau ?**  
R : EspService encapsule chaque requête HTTP dans un `try/catch` avec gestion spécifique de `TimeoutException` et `SocketException`. En cas d'erreur, le stream `errorStream` diffuse un message d'erreur, la barre de navigation affiche "OFFLINE" et l'interface affiche une bannière rouge. L'app continue à fonctionner avec les dernières données reçues.

---

### Questions sur les choix technologiques

**Q : Pourquoi SQLite et pas Firebase ?**  
R : Firebase nécessite une connexion Internet permanente et devient payant au-delà du quota gratuit. SQLite fonctionne hors ligne, est gratuit, et suffit largement pour le volume de données d'un monitoring local. C'est aussi plus adapté à la confidentialité des données d'une salle serveur.

**Q : Pourquoi HTTP et pas MQTT pour la communication avec l'ESP ?**  
R : HTTP est plus simple à déboguer (testable avec un navigateur), plus facile à implémenter, et adapté à notre fréquence de polling de 2 minutes. MQTT serait pertinent pour des mises à jour sub-seconde ou pour gérer des dizaines d'ESP. C'est mentionné comme amélioration future.

**Q : Qu'est-ce qu'un Stream en Dart et pourquoi l'utilisez-vous ?**  
R : Un Stream est un flux de données asynchrone qui émet des valeurs au fil du temps. Je l'utilise dans EspService car les données arrivent périodiquement. Les écrans s'abonnent au stream et sont automatiquement mis à jour à chaque nouvelle lecture, sans couplage fort entre EspService et les widgets.

**Q : Comment sécurisez-vous les mots de passe ?**  
R : Les mots de passe ne sont jamais stockés en clair. Dans DatabaseHelper, la méthode `_hashPassword()` applique SHA-256 via le package `crypto` avant toute insertion. La vérification compare le hash du mot de passe saisi avec le hash stocké.

**Q : Qu'est-ce que le pipeline CI/CD GitLab dans votre projet ?**  
R : Le fichier `.gitlab-ci.yml` définit deux étapes automatiques à chaque push sur `main` : d'abord `flutter analyze` qui vérifie la qualité du code, puis `flutter build apk --release` qui génère l'APK. Si l'analyse échoue, le build est bloqué. L'APK est archivé 7 jours. Cela garantit que chaque version du code est compilable et sans erreurs.

**Q : Pourquoi avez-vous utilisé Wokwi avant de construire le vrai prototype ?**  
R : Wokwi permet de simuler l'ESP8266, les capteurs DHT et les capteurs d'eau sans matériel physique. J'ai d'abord validé le firmware Arduino, la logique de lecture des capteurs et la structure JSON dans le simulateur. Cela a permis de détecter et corriger des bugs (comme la gestion du timestamp invalide) avant de toucher au vrai matériel, réduisant le risque de griller des composants.

---

### Questions spécifiques sur le code

**Q : Pourquoi `withValues(alpha:)` au lieu de `withOpacity()` ?**  
R : `withOpacity()` est déprécié depuis Flutter 3.x car il n'est pas compatible avec la nouvelle gestion des espaces colorimétriques. `withValues(alpha:)` est la méthode correcte et moderne.

**Q : Qu'est-ce que `mounted` et pourquoi le vérifiez-vous ?**  
R : `mounted` est une propriété d'un State qui est `true` tant que le widget est dans l'arbre de widgets. Si une opération asynchrone se termine après que l'utilisateur a quitté l'écran, appeler `setState()` sur un widget détruit provoquerait une erreur. Vérifier `if (mounted)` avant `setState()` évite cet crash.

**Q : Expliquez `ConflictAlgorithm.replace` dans `insertAlert`.**  
R : Les alertes live ont des IDs fixes (`'live-temp-critical'`). Si l'ESP envoie la même alerte à chaque polling (température toujours critique), sans `replace`, on accumulerait des doublons. `ConflictAlgorithm.replace` met à jour l'entrée existante si l'ID existe déjà, évitant la duplication.
