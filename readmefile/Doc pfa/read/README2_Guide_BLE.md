# README 2 — Guide d'Intégration BLE pour DataGuardian IoT

> **Guide technique complet** — Du débutant à l'intermédiaire  
> Comprendre le BLE, son intérêt pour ce projet, et comment le mettre en œuvre.

---

## Table des matières

1. [Qu'est-ce que le BLE ?](#1-quest-ce-que-le-ble)
2. [BLE vs WiFi — Comparaison technique](#2-ble-vs-wifi--comparaison-technique)
3. [Le BLE est-il utile pour ce projet ?](#3-le-ble-est-il-utile-pour-ce-projet)
4. [Limitations de l'ESP8266 avec le BLE](#4-limitations-de-lesp8266-avec-le-ble)
5. [ESP32 — La meilleure alternative](#5-esp32--la-meilleure-alternative)
6. [Architecture possible avec BLE](#6-architecture-possible-avec-ble)
7. [Packages Flutter pour le BLE](#7-packages-flutter-pour-le-ble)
8. [Implémentation pas à pas](#8-implémentation-pas-à-pas)
9. [Exemples de code concrets](#9-exemples-de-code-concrets)
10. [Avantages et inconvénients du BLE](#10-avantages-et-inconvénients-du-ble)
11. [Stratégie de migration future](#11-stratégie-de-migration-future)

---

## 1. Qu'est-ce que le BLE ?

### Définition

**BLE** (Bluetooth Low Energy) est une version basse consommation du Bluetooth, standardisée dans la spécification Bluetooth 4.0 (2010). Contrairement au Bluetooth classique (utilisé pour les écouteurs, etc.), le BLE est conçu pour envoyer de **petites quantités de données** avec une **consommation énergétique minimale**.

### Comment ça marche ?

Le BLE utilise un modèle **client-serveur** basé sur des concepts spécifiques :

```
┌─────────────────────────────────────────────────────────┐
│                ARCHITECTURE BLE                          │
│                                                          │
│   PÉRIPHÉRIQUE (ex: ESP32)      CENTRAL (ex: Téléphone) │
│   ┌──────────────────┐          ┌──────────────────┐    │
│   │    GATT Server   │◄────────►│    GATT Client   │    │
│   │                  │          │                  │    │
│   │  Service IoT     │          │  Flutter App     │    │
│   │  UUID: 180A...   │          │                  │    │
│   │                  │          │                  │    │
│   │  Characteristic  │─────────►│  Lecture valeur  │    │
│   │  Température     │          │                  │    │
│   │  UUID: 2A6E...   │          │                  │    │
│   │                  │          │                  │    │
│   │  Characteristic  │─────────►│  Notification    │    │
│   │  Alerte          │  NOTIFY  │  automatique     │    │
│   └──────────────────┘          └──────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Terminologie essentielle à connaître

| Terme | Explication simple |
|-------|-------------------|
| **GATT** | Generic Attribute Profile — protocole de communication BLE |
| **Service** | Groupe logique de fonctionnalités (ex: "Capteurs environnementaux") |
| **Characteristic** | Une donnée spécifique (ex: valeur de température) |
| **UUID** | Identifiant unique d'un service ou d'une caracteristic |
| **Notify** | Le périphérique envoie automatiquement des mises à jour sans qu'on lui demande |
| **Read** | Le central lit la valeur une seule fois |
| **Write** | Le central envoie une commande au périphérique |
| **Advertisement** | Signal de diffusion envoyé par le BLE pour se faire découvrir |
| **Scan** | Le téléphone cherche des appareils BLE à proximité |
| **MTU** | Maximum Transmission Unit — taille max d'un paquet (23 à 512 octets) |

---

## 2. BLE vs WiFi — Comparaison technique

| Critère | WiFi (HTTP) — actuel | BLE |
|---------|---------------------|-----|
| **Portée** | 30–100m (intérieur) | 10–30m (intérieur) |
| **Débit max** | 54–600 Mbps | 0.27–2 Mbps |
| **Consommation** | 150–300mA | 0.01–15mA |
| **Latence** | 1–50ms | 3–6ms |
| **Configuration** | IP, SSID, mot de passe | Scan + appairage |
| **Besoin d'un routeur** | ✅ Oui | ❌ Non |
| **Protocole** | TCP/IP HTTP | GATT/ATT |
| **Sécurité** | WPA2/TLS | Pairing + chiffrement |
| **Facilité d'impl.** | ⭐⭐⭐⭐ Simple | ⭐⭐ Complexe |
| **Adapté IoT capteurs** | ⭐⭐⭐ Bien | ⭐⭐⭐⭐⭐ Excellent |

### Quand WiFi est meilleur que BLE

- Quand un routeur est déjà disponible dans l'environnement
- Quand les données sont volumineuses (images, gros JSON)
- Quand la distance dépasse 30 mètres
- Quand on veut une intégration avec Internet facile

### Quand BLE est meilleur que WiFi

- Quand l'appareil fonctionne sur batterie et la durée est critique
- Quand il n'y a pas de routeur WiFi disponible
- Quand la communication directe téléphone-capteur est préférée
- Quand on veut éviter les problèmes d'IP dynamique et de configuration réseau

---

## 3. Le BLE est-il utile pour ce projet ?

### Analyse du cas DataGuardian IoT

**Architecture actuelle :**  
ESP8266 → WiFi → HTTP GET → Flutter

**Avec BLE (si migration vers ESP32) :**  
ESP32 → BLE GATT → Flutter directement

### Avantages concrets pour ce projet

1. **Pas besoin de routeur** : L'ESP32 et le téléphone communiquent directement. Utile si la salle serveur n'a pas de réseau WiFi accessible au téléphone.

2. **Connexion plus fiable** : Pas de problème de DHCP, d'IP qui change, de réseau qui se coupe. Le BLE s'appaire une fois et retrouve l'appareil automatiquement.

3. **Notifications push réelles** : Avec BLE Notify, l'ESP32 pousse les alertes vers Flutter dès qu'elles se produisent, sans attendre le prochain poll de 2 minutes.

4. **Consommation réduite** : Si l'ESP est alimenté sur batterie, BLE consomme 10x moins que WiFi.

### Inconvénients pour ce projet

1. **Portée limitée** : Si le téléphone est dans une autre pièce, la connexion est perdue.
2. **Un seul client à la fois** : BLE standard ne supporte qu'une connexion simultanée.
3. **MTU limité** : Envoyer un grand JSON nécessite de le découper en morceaux.
4. **Complexité accrue** : Le code BLE est plus complexe que du HTTP simple.

### Conclusion pour la soutenance

> "La solution actuelle basée sur WiFi/HTTP est adaptée à l'environnement visé (salle serveur connectée). Le BLE représente une amélioration pertinente pour de futurs déploiements où l'alimentation sur batterie ou l'absence de routeur est une contrainte. Une migration vers ESP32 + BLE est envisagée comme perspective d'amélioration."

---

## 4. Limitations de l'ESP8266 avec le BLE

**L'ESP8266 n'a PAS de Bluetooth.** C'est une limitation matérielle fondamentale.

L'ESP8266 (NodeMCU, Wemos D1) ne contient que :
- ✅ WiFi 802.11 b/g/n (2.4GHz)
- ❌ Pas de Bluetooth
- ❌ Pas de BLE

Il est physiquement **impossible** d'ajouter le BLE à un ESP8266 sans composant externe.

**Solutions de contournement :**
- Ajouter un module HC-08 ou HM-10 (Bluetooth série) — mais très limité et peu fiable
- Utiliser un ESP32 — la vraie solution (voir section suivante)

---

## 5. ESP32 — La meilleure alternative

### Pourquoi ESP32 ?

L'ESP32 est le successeur naturel de l'ESP8266. Il intègre **nativement** :
- WiFi 802.11 b/g/n
- **Bluetooth 4.2 + BLE**
- Processeur double cœur (240 MHz vs 80 MHz)
- Plus de mémoire RAM (520KB vs 80KB)
- Plus de GPIO (34 vs 17 utilisables)
- ADC plus précis (12 bits vs 10 bits)

### Comparaison ESP8266 vs ESP32

| Critère | ESP8266 | ESP32 |
|---------|---------|-------|
| CPU | 80 MHz, 1 cœur | 240 MHz, 2 cœurs |
| RAM | 80 KB | 520 KB |
| WiFi | ✅ | ✅ |
| Bluetooth | ❌ | ✅ BLE + Classic |
| ADC | 10 bits (1 canal) | 12 bits (18 canaux) |
| Prix indicatif | ~3€ | ~5-8€ |
| Librairie Arduino | ✅ | ✅ |
| Compatibilité code | — | Faible modification |

### Migration du code Arduino

La migration du firmware ESP8266 vers ESP32 est relativement simple :
- Les librairies WiFi et HTTP sont identiques
- DHT11/22 fonctionne pareil
- On ajoute simplement le code BLE en plus

---

## 6. Architecture possible avec BLE

### Architecture hybride WiFi + BLE (recommandée)

```
┌─────────────────────────────────────────────────────────────┐
│                    ESP32                                      │
│                                                              │
│  ┌──────────────┐    ┌──────────────────────────────────┐   │
│  │   Capteurs   │    │           BLE Server             │   │
│  │  DHT22       │    │  Service: IoT Monitoring         │   │
│  │  Niveau eau  │───►│  Charact: Temperature (Notify)   │   │
│  │  Fuite       │    │  Charact: Humidity (Notify)      │   │
│  └──────────────┘    │  Charact: WaterLevel (Notify)    │   │
│                      │  Charact: AlertFlag (Notify)     │   │
│                      └──────────────┬───────────────────┘   │
└─────────────────────────────────────┼─────────────────────┘
                                      │ BLE GATT
                                      │ Notifications push
                                      ▼
                          ┌──────────────────────┐
                          │   Flutter App        │
                          │   (flutter_blue_plus)│
                          │                      │
                          │  Scan → Connect      │
                          │  Subscribe Notify    │
                          │  Receive Data        │
                          │  → SQLite → UI       │
                          └──────────────────────┘
```

### Services et Characteristics suggérés

```
Service Principal (UUID: 12345678-1234-5678-1234-56789abcdef0)
│
├── Characteristic Temperature
│   UUID: 12345678-1234-5678-1234-56789abcdef1
│   Propriétés: READ + NOTIFY
│   Format: float (4 octets) ou string "24.5"
│
├── Characteristic Humidity
│   UUID: 12345678-1234-5678-1234-56789abcdef2
│   Propriétés: READ + NOTIFY
│   Format: float (4 octets)
│
├── Characteristic WaterLevel
│   UUID: 12345678-1234-5678-1234-56789abcdef3
│   Propriétés: READ + NOTIFY
│   Format: uint16 (valeur ADC 0-1023)
│
└── Characteristic AlertStatus
    UUID: 12345678-1234-5678-1234-56789abcdef4
    Propriétés: READ + NOTIFY
    Format: byte (bits flags pour chaque type d'alerte)
```

---

## 7. Packages Flutter pour le BLE

### Option 1 : `flutter_blue_plus` (recommandé)

```yaml
dependencies:
  flutter_blue_plus: ^1.35.5
```

**Pourquoi ce package ?**
- Activement maintenu
- Support Android + iOS
- API moderne avec Streams
- Bonne gestion des erreurs
- Compatible avec les dernières versions de Flutter

### Option 2 : `flutter_reactive_ble`

```yaml
dependencies:
  flutter_reactive_ble: ^5.3.2
```

**Avantages :** API réactive, plus robuste sur certains appareils Android.  
**Inconvénients :** API légèrement plus complexe.

### Permissions requises

**Android (`android/app/src/main/AndroidManifest.xml`) :**
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**iOS (`ios/Runner/Info.plist`) :**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Utilisé pour la communication avec les capteurs IoT</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Connexion aux modules ESP32</string>
```

---

## 8. Implémentation pas à pas

### Étape 1 — Modifier le firmware ESP32

```cpp
// esp32_ble_server.ino
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <DHT.h>

// UUIDs du service et des caractéristiques
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_TEMP_UUID      "12345678-1234-5678-1234-56789abcdef1"
#define CHAR_HUMID_UUID     "12345678-1234-5678-1234-56789abcdef2"
#define CHAR_WATER_UUID     "12345678-1234-5678-1234-56789abcdef3"
#define CHAR_ALERT_UUID     "12345678-1234-5678-1234-56789abcdef4"

BLECharacteristic *pTempChar, *pHumidChar, *pWaterChar, *pAlertChar;
DHT dht(4, DHT22);  // Pin 4, capteur DHT22

bool deviceConnected = false;

// Callback de connexion/déconnexion
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    pServer->startAdvertising();  // Relance l'advertisement
  }
};

void setup() {
  Serial.begin(115200);
  dht.begin();
  
  // Initialise le BLE
  BLEDevice::init("DataGuardian-ESP32");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  // Crée le service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Crée les caractéristiques avec NOTIFY + READ
  pTempChar = pService->createCharacteristic(
    CHAR_TEMP_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pTempChar->addDescriptor(new BLE2902());  // Requis pour Notify
  
  pHumidChar = pService->createCharacteristic(
    CHAR_HUMID_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pHumidChar->addDescriptor(new BLE2902());
  
  pAlertChar = pService->createCharacteristic(
    CHAR_ALERT_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pAlertChar->addDescriptor(new BLE2902());
  
  // Démarre le service et l'advertisement
  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("BLE démarré — en attente de connexion...");
}

void loop() {
  if (deviceConnected) {
    float temp  = dht.readTemperature();
    float humid = dht.readHumidity();
    
    if (!isnan(temp) && !isnan(humid)) {
      // Convertit les floats en string pour BLE
      String tempStr = String(temp, 1);   // "24.5"
      String humStr  = String(humid, 0);  // "48"
      
      pTempChar->setValue(tempStr.c_str());
      pTempChar->notify();  // Envoie automatiquement au Flutter
      
      pHumidChar->setValue(humStr.c_str());
      pHumidChar->notify();
      
      // Calcule les alertes
      uint8_t alertByte = 0;
      if (temp > 40) alertByte |= 0x01;   // bit 0 = temp critique
      if (temp > 35) alertByte |= 0x02;   // bit 1 = temp warning
      if (humid < 30) alertByte |= 0x04;  // bit 2 = humidité basse
      
      pAlertChar->setValue(&alertByte, 1);
      pAlertChar->notify();
      
      Serial.printf("T:%.1f H:%.0f Alert:0x%02X\n", temp, humid, alertByte);
    }
  }
  delay(30000);  // Envoie toutes les 30 secondes
}
```

### Étape 2 — Créer le BleService Flutter

```dart
// lib/services/ble_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/models.dart';

class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  // UUIDs — doivent correspondre au firmware ESP32
  static const String _serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String _tempUuid    = '12345678-1234-5678-1234-56789abcdef1';
  static const String _humidUuid   = '12345678-1234-5678-1234-56789abcdef2';
  static const String _alertUuid   = '12345678-1234-5678-1234-56789abcdef4';

  BluetoothDevice? _device;
  StreamSubscription? _tempSub, _humidSub, _alertSub;
  
  double _temperature = 0;
  double _humidity    = 0;
  bool   _isConnected = false;
  
  final _dataController = StreamController<EnvironmentData>.broadcast();
  Stream<EnvironmentData> get dataStream => _dataController.stream;

  // Scanne et trouve l'ESP32
  Future<BluetoothDevice?> scanForEsp32() async {
    BluetoothDevice? found;
    
    // Démarre le scan pendant 5 secondes
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    
    await for (final result in FlutterBluePlus.scanResults) {
      for (final r in result) {
        // Cherche le dispositif par nom
        if (r.device.platformName == 'DataGuardian-ESP32') {
          found = r.device;
          await FlutterBluePlus.stopScan();
          break;
        }
      }
      if (found != null) break;
    }
    
    return found;
  }

  // Se connecte et souscrit aux notifications
  Future<bool> connectAndSubscribe(BluetoothDevice device) async {
    try {
      await device.connect();
      _device = device;
      _isConnected = true;
      
      // Découvre les services
      final services = await device.discoverServices();
      
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final char in service.characteristics) {
            final uuid = char.uuid.toString().toLowerCase();
            
            if (uuid == _tempUuid) {
              // Active les notifications
              await char.setNotifyValue(true);
              _tempSub = char.onValueReceived.listen((value) {
                _temperature = double.tryParse(utf8.decode(value)) ?? 0;
                _pushData();
              });
            }
            
            if (uuid == _humidUuid) {
              await char.setNotifyValue(true);
              _humidSub = char.onValueReceived.listen((value) {
                _humidity = double.tryParse(utf8.decode(value)) ?? 0;
                _pushData();
              });
            }
            
            if (uuid == _alertUuid) {
              await char.setNotifyValue(true);
              _alertSub = char.onValueReceived.listen((value) {
                if (value.isNotEmpty) {
                  final byte = value[0];
                  final alerts = EspAlerts(
                    tempCritical: (byte & 0x01) != 0,
                    tempWarning:  (byte & 0x02) != 0,
                    humidityLow:  (byte & 0x04) != 0,
                  );
                  _pushData(overrideAlerts: alerts);
                }
              });
            }
          }
        }
      }
      return true;
    } catch (e) {
      print('Erreur BLE connexion: $e');
      return false;
    }
  }

  // Envoie les données au Stream (même interface que EspService)
  void _pushData({EspAlerts? overrideAlerts}) {
    final data = EnvironmentData(
      temperature:       _temperature,
      humidity:          _humidity,
      waterLeakDetected: false,
      lastUpdated:       DateTime.now(),
      deviceId:          'ESP32-BLE-01',
      alerts: overrideAlerts ?? const EspAlerts(),
    );
    _dataController.add(data);
  }

  Future<void> disconnect() async {
    await _tempSub?.cancel();
    await _humidSub?.cancel();
    await _alertSub?.cancel();
    await _device?.disconnect();
    _isConnected = false;
  }
}
```

### Étape 3 — Utiliser BleService dans le Dashboard

Le `DashboardScreen` peut rester quasiment identique, car `BleService` expose le même `dataStream` que `EspService`. Il suffit de changer :

```dart
// Avant (WiFi) :
_dataSub = EspService.instance.dataStream.listen(...)

// Après (BLE) :
_dataSub = BleService.instance.dataStream.listen(...)
```

---

## 9. Exemples de code concrets

### Lire une valeur BLE manuellement (sans notification)

```dart
// Lire la température une seule fois
Future<double> readTemperatureOnce(BluetoothCharacteristic char) async {
  final value = await char.read();
  return double.tryParse(utf8.decode(value)) ?? 0.0;
}
```

### Écrire une commande vers l'ESP32 (ex: changer le seuil)

```dart
// Envoyer un nouveau seuil d'alerte (35°C)
Future<void> setTemperatureThreshold(
    BluetoothCharacteristic configChar, double threshold) async {
  final data = utf8.encode(threshold.toStringAsFixed(1));
  await configChar.write(data);
}
```

### Gérer les déconnexions BLE

```dart
device.connectionState.listen((state) {
  if (state == BluetoothConnectionState.disconnected) {
    // Tenter une reconnexion automatique
    Future.delayed(const Duration(seconds: 3), () => connectAndSubscribe(device));
  }
});
```

---

## 10. Avantages et inconvénients du BLE

### ✅ Avantages pour DataGuardian IoT

- **Notifications push réelles** : L'ESP32 pousse une alerte dès qu'elle se produit, sans attendre 2 minutes
- **Pas de routeur requis** : Communication directe smartphone ↔ capteur
- **Très basse consommation** : Idéal si alimenté sur batterie
- **Connexion directe** : Pas de problème d'IP dynamique
- **Sécurité** : Le BLE peut chiffrer les communications nativement

### ❌ Inconvénients

- **Portée limitée** : ~10-30m, problématique si la salle est loin
- **Un seul client** : Un seul téléphone peut se connecter à la fois
- **Complexité du code** : Beaucoup plus complexe que HTTP
- **MTU limité** : JSON complexe doit être découpé
- **Incompatibilité ESP8266** : Nécessite de migrer vers ESP32
- **Débogage difficile** : Moins d'outils que HTTP (pas de navigateur pour tester)

---

## 11. Stratégie de migration future

### Phase 1 — Actuel (Version 1.0)
```
ESP8266 → WiFi HTTP → Flutter (polling 2 min)
Avantage : Simple, fonctionnel, déployé
```

### Phase 2 — Hybride (Version 2.0 recommandée)
```
ESP32 → WiFi HTTP (existant) + BLE Notify (nouveau)
- WiFi pour les données complètes (JSON)
- BLE pour les alertes critiques (push immédiat)
```

### Phase 3 — BLE Natif (Version 3.0)
```
ESP32 → BLE uniquement
- Tous les capteurs via GATT
- Pas de dépendance WiFi
- Idéal pour déploiements sans infrastructure
```

### Estimation d'effort pour la migration

| Tâche | Effort |
|-------|--------|
| Remplacement ESP8266 → ESP32 | Faible (même brochage) |
| Réécriture firmware Arduino | ~2-3 jours |
| Ajout BleService Flutter | ~3-5 jours |
| Tests et débogage | ~2-3 jours |
| **Total** | **~7-11 jours** |

### Recommandation pour la soutenance

Présenter le BLE comme une **amélioration future planifiée** avec ces arguments :
1. "La solution actuelle WiFi/HTTP est stable et couvre tous les besoins fonctionnels"
2. "Le BLE permettrait des notifications push instantanées et une indépendance vis-à-vis du réseau WiFi"
3. "La migration vers ESP32 + BLE est techniquement réalisable et représente une évolution naturelle du projet"
