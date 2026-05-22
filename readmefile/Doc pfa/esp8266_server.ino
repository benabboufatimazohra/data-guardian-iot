/*
 * ─────────────────────────────────────────────────────────────────────────────
 * DataGuardian IoT — ESP8266 Firmware
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Ce code transforme l'ESP8266 en serveur HTTP qui expose deux endpoints :
 *   GET /data   → retourne JSON avec température, humidité, fuite d'eau
 *   GET /health → retourne { "status": "ok" } pour vérifier la connexion
 *
 * L'application Flutter poll /data toutes les 5 secondes pour afficher
 * les données en temps réel.
 *
 * CÂBLAGE :
 *   DHT22 (ou DHT11)
 *     VCC  → 3.3V
 *     GND  → GND
 *     DATA → D4 (GPIO2) — avec résistance pull-up 10kΩ entre DATA et 3.3V
 *
 *   Capteur de fuite d'eau (module avec sortie numérique)
 *     VCC  → 3.3V
 *     GND  → GND
 *     DO   → D5 (GPIO14)  — LOW = fuite détectée, HIGH = sec
 *
 * BIBLIOTHÈQUES REQUISES (Arduino Library Manager) :
 *   - ESP8266WiFi        (incluse avec esp8266 board package)
 *   - ESP8266WebServer   (incluse avec esp8266 board package)
 *   - DHT sensor library by Adafruit
 *   - Adafruit Unified Sensor by Adafruit
 *
 * CONFIGURATION BOARD (Arduino IDE) :
 *   Board: NodeMCU 1.0 (ESP-12E Module)
 *   Flash size: 4MB
 *   Upload speed: 115200
 * ─────────────────────────────────────────────────────────────────────────────
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <DHT.h>
#include <ArduinoJson.h>   // Version 6.x — à installer depuis Library Manager

// ─── CONFIGURATION — MODIFIEZ CES VALEURS ────────────────────────────────────
const char* WIFI_SSID     = "VotreSSID";        // Nom de votre réseau Wi-Fi
const char* WIFI_PASSWORD = "VotreMotDePasse";  // Mot de passe Wi-Fi

// Pins
#define DHT_PIN         2    // D4 sur NodeMCU = GPIO2
#define DHT_TYPE        DHT22  // Changez en DHT11 si vous utilisez DHT11
#define WATER_LEAK_PIN  14   // D5 sur NodeMCU = GPIO14

// Seuils d'alerte (doivent correspondre à ceux configurés dans l'app Flutter)
const float TEMP_CRITICAL_THRESHOLD  = 35.0;
const float TEMP_WARNING_THRESHOLD   = 30.0;
const float HUMID_LOW_THRESHOLD      = 20.0;
const float HUMID_HIGH_THRESHOLD     = 80.0;
// ─────────────────────────────────────────────────────────────────────────────

ESP8266WebServer server(80);  // Serveur HTTP sur le port 80
DHT dht(DHT_PIN, DHT_TYPE);

// Variables globales pour stocker la dernière lecture
float lastTemperature = 0;
float lastHumidity    = 0;
bool  lastWaterLeak   = false;
unsigned long lastReadTime = 0;
const unsigned long READ_INTERVAL = 2000; // Lire le capteur toutes les 2s

// ─── CORS Headers ─────────────────────────────────────────────────────────────
// Nécessaire pour que Flutter (et les navigateurs) puissent accéder à l'API
void setCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  server.sendHeader("Cache-Control", "no-cache");
}

// ─── Endpoint: GET /data ──────────────────────────────────────────────────────
/*
 * Retourne toutes les données capteurs au format JSON.
 *
 * Exemple de réponse :
 * {
 *   "temperature": 24.5,
 *   "humidity": 48.2,
 *   "water_leak": false,
 *   "timestamp": "2026-04-27T14:32:45",
 *   "device_id": "ESP8266-01",
 *   "ip": "192.168.1.104",
 *   "alerts": {
 *     "temp_critical": false,
 *     "temp_warning": false,
 *     "humidity_low": false,
 *     "humidity_high": false
 *   }
 * }
 */
void handleGetData() {
  setCORSHeaders();

  // Construire le JSON avec ArduinoJson
  StaticJsonDocument<512> doc;

  // Données capteurs
  if (isnan(lastTemperature) || isnan(lastHumidity)) {
    // Capteur non disponible — envoyer une erreur lisible
    doc["error"]   = "Sensor read failed";
    doc["sensor"]  = "DHT";
    server.send(503, "application/json", doc.as<String>());
    return;
  }

  doc["temperature"] = round(lastTemperature * 10) / 10.0;  // 1 décimale
  doc["humidity"]    = round(lastHumidity * 10) / 10.0;
  doc["water_leak"]  = lastWaterLeak;
  doc["device_id"]   = "ESP8266-01";
  doc["ip"]          = WiFi.localIP().toString();

  // Timestamp au format ISO 8601 simplifié
  // Note : l'ESP n'a pas de RTC intégré. Pour un vrai timestamp,
  // utilisez NTPClient (voir commentaire en bas du fichier).
  doc["timestamp"]   = "2026-04-27T00:00:00";  // Remplacez avec NTP si besoin

  // Évaluation des alertes côté ESP
  JsonObject alerts = doc.createNestedObject("alerts");
  alerts["temp_critical"]  = (lastTemperature > TEMP_CRITICAL_THRESHOLD);
  alerts["temp_warning"]   = (lastTemperature > TEMP_WARNING_THRESHOLD && lastTemperature <= TEMP_CRITICAL_THRESHOLD);
  alerts["humidity_low"]   = (lastHumidity < HUMID_LOW_THRESHOLD);
  alerts["humidity_high"]  = (lastHumidity > HUMID_HIGH_THRESHOLD);

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);

  Serial.println("[/data] → " + response);
}

// ─── Endpoint: GET /health ────────────────────────────────────────────────────
void handleHealth() {
  setCORSHeaders();
  server.send(200, "application/json", "{\"status\":\"ok\",\"device\":\"ESP8266-01\"}");
}

// ─── Endpoint: OPTIONS (CORS preflight) ──────────────────────────────────────
void handleOptions() {
  setCORSHeaders();
  server.send(204);
}

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n=== DataGuardian ESP8266 ===");

  // Initialiser les pins
  dht.begin();
  pinMode(WATER_LEAK_PIN, INPUT_PULLUP);  // Pullup interne activé

  // ── Connexion Wi-Fi ─────────────────────────────────────────────────────
  Serial.print("Connexion à ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  WiFi.setAutoReconnect(true);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\n✓ Wi-Fi connecté !");
  Serial.print("  IP locale : ");
  Serial.println(WiFi.localIP());
  Serial.println("  Entrez cette IP dans l'app Flutter → lib/config/api_config.dart");

  // ── Routes HTTP ─────────────────────────────────────────────────────────
  server.on("/data",    HTTP_GET,     handleGetData);
  server.on("/health",  HTTP_GET,     handleHealth);
  server.on("/data",    HTTP_OPTIONS, handleOptions);
  server.on("/health",  HTTP_OPTIONS, handleOptions);

  // Route 404 par défaut
  server.onNotFound([]() {
    server.send(404, "application/json", "{\"error\":\"Not found\"}");
  });

  server.begin();
  Serial.println("✓ Serveur HTTP démarré sur le port 80");
  Serial.println("  Testez dans un navigateur : http://" + WiFi.localIP().toString() + "/data");
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  server.handleClient();  // Traiter les requêtes HTTP entrantes

  // Lire les capteurs périodiquement (non-bloquant avec millis())
  unsigned long now = millis();
  if (now - lastReadTime >= READ_INTERVAL) {
    lastReadTime = now;

    // Lecture DHT (peut retourner NaN si capteur absent ou câblage incorrect)
    float t = dht.readTemperature();
    float h = dht.readHumidity();

    if (!isnan(t) && !isnan(h)) {
      lastTemperature = t;
      lastHumidity    = h;
    } else {
      Serial.println("[WARN] Échec lecture DHT — vérifiez le câblage (pin D4)");
    }

    // Lecture capteur eau : LOW = eau détectée (selon la plupart des modules)
    lastWaterLeak = (digitalRead(WATER_LEAK_PIN) == LOW);

    // Debug Serial
    Serial.printf("[Capteurs] Temp: %.1f°C | Humid: %.1f%% | Eau: %s\n",
      lastTemperature, lastHumidity, lastWaterLeak ? "FUITE!" : "OK");
  }
}

/*
 * ─────────────────────────────────────────────────────────────────────────────
 * OPTIONNEL : Horodatage réel avec NTP
 * ─────────────────────────────────────────────────────────────────────────────
 * Ajoutez ces bibliothèques : NTPClient, Time
 *
 * #include <NTPClient.h>
 * #include <WiFiUDP.h>
 * WiFiUDP ntpUDP;
 * NTPClient timeClient(ntpUDP, "pool.ntp.org", 3600); // +1h pour Maroc (UTC+1)
 *
 * Dans setup() après WiFi.begin :
 *   timeClient.begin();
 *
 * Dans handleGetData(), remplacez le timestamp hardcodé par :
 *   timeClient.update();
 *   doc["timestamp"] = timeClient.getFormattedDate();
 * ─────────────────────────────────────────────────────────────────────────────
 */
