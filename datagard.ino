/*
 * datagard.ino — DataGuardian : capteur IoT avec IA explicable (XAI) embarquée
 * Portage MicroPython -> Arduino C++ pour ESP8266
 *
 * Bibliothèques requises (Gestionnaire de bibliothèques de l'IDE Arduino) :
 *   - Cartes ESP8266 (fournit ESP8266WiFi.h et ESP8266WebServer.h)
 *   - "DHT sensor library" par Adafruit
 *   - "Adafruit Unified Sensor" (dépendance de la lib DHT)
 *   - "ArduinoJson" (version 6.x, ex : 6.21.x)
 *
 * Câblage (identique au script d'origine) :
 *   - DHT11 : D4  (GPIO2)
 *   - Fuite d'eau : D5 (GPIO14), entrée numérique
 *
 * Flash : IDE Arduino -> Outils -> Carte : "Generic ESP8266 Module" (ou NodeMCU 1.0)
 *         -> sélectionner le bon port -> Téléverser
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <math.h>

// ── Config ────────────────────────────────────────────────────────────
const char* SSID          = "***REMOVED***";
const char* WIFI_PASSWORD = "***REMOVED***";
const char* DEVICE_ID     = "ESP8266-01";

const float TEMP_WARNING  = 32.0;
const float TEMP_CRITICAL = 38.0;
const float HUM_LOW       = 20.0;
const float HUM_HIGH      = 80.0;

// ── Capteurs ──────────────────────────────────────────────────────────
#define DHTPIN   2      // D4
#define DHTTYPE  DHT11
#define WATERPIN 14     // D5

DHT dht(DHTPIN, DHTTYPE);
ESP8266WebServer server(80);

// ═════════════════════════════════════════════════════════════════════
//  EXPLAINABLE AI — fenêtre glissante de 5 mesures
//  Calcule : tendance, score de risque, explication textuelle
// ═════════════════════════════════════════════════════════════════════

const int WINDOW = 5;   // nombre de mesures gardées en mémoire

float bufT[WINDOW];     // historique températures
float bufH[WINDOW];     // historique humidités
int   bufTLen = 0;
int   bufHLen = 0;

void pushBuf(float* buf, int &len, float val) {
  if (len < WINDOW) {
    buf[len++] = val;
  } else {
    for (int i = 1; i < WINDOW; i++) buf[i - 1] = buf[i];
    buf[WINDOW - 1] = val;
  }
}

// Pente linéaire simple (dernier - premier) / n  →  °C ou % par cycle.
float trendOf(float* buf, int len) {
  if (len < 2) return 0.0;
  return (buf[len - 1] - buf[0]) / len;
}

float meanOf(float* buf, int len) {
  if (len == 0) return 0.0;
  float s = 0;
  for (int i = 0; i < len; i++) s += buf[i];
  return s / len;
}

// Écart à la moyenne en unités d'écart-type (≥2 = anomalie).
float zscoreOf(float val, float* buf, int len) {
  if (len < 2) return 0.0;
  float m = meanOf(buf, len);
  float sq = 0;
  for (int i = 0; i < len; i++) sq += (buf[i] - m) * (buf[i] - m);
  float s = sqrt(sq / len);
  return s > 0 ? (val - m) / s : 0.0;
}

// Normalise val dans [lo, hi] → 0.0–1.0, clampé.
float normVal(float val, float lo, float hi) {
  if (hi == lo) return 0.0;
  float r = (val - lo) / (hi - lo);
  if (r < 0.0) r = 0.0;
  if (r > 1.0) r = 1.0;
  return r;
}

// ── Score de risque (0.0 = ok, 1.0 = critique) ────────────────────────
// Poids : température 40%, humidité 20%, eau 20%, tendance 20%
float riskScore(float t, float h, int w, float trendT, float trendH) {
  float sT  = normVal(t, TEMP_WARNING, TEMP_CRITICAL + 4);      // temp
  float sH1 = normVal(HUM_LOW + 5, h, HUM_LOW);                 // hum basse
  float sH2 = normVal(h, HUM_HIGH - 5, HUM_HIGH + 10);          // hum haute
  float sH  = max(sH1, sH2);
  float sW  = w ? 1.0 : 0.0;                                     // eau
  float sTT = normVal(trendT, 0, 2.0);                          // tendance temp
  float score = 0.40 * sT + 0.20 * sH + 0.20 * sW + 0.20 * sTT;
  if (score > 1.0) score = 1.0;
  return roundf(score * 100.0) / 100.0;
}

struct XAIResult {
  float  score;
  String level;
  String reason;
};

// Prototypes explicites (obligatoires) : l'IDE Arduino génère automatiquement
// des prototypes pour toutes les fonctions et les insère tout en haut du
// fichier, AVANT la définition de la struct ci-dessus, ce qui casse la
// compilation ("XAIResult does not name a type"). En les déclarant ici
// nous-mêmes, l'IDE ne réinsère pas les siens.
XAIResult explainXAI(float t, float h, int w, float trendT, float trendH, float score);
XAIResult computeXAI(float t, float h, int w);

// Formate un float avec 1 décimale (ex : 32.4)
String fmt1(float v) {
  char buf[12];
  dtostrf(v, 0, 1, buf);
  return String(buf);
}

// Formate un float avec 2 décimales (ex : 0.72), pour le score
String fmt2(float v) {
  char buf[12];
  dtostrf(v, 0, 2, buf);
  return String(buf);
}

// ── Génération de l'explication (texte court) ─────────────────────────
XAIResult explainXAI(float t, float h, int w, float trendT, float trendH, float score) {
  String parts = "";
  bool first = true;
  auto addPart = [&](String p) {
    if (!first) parts += ", ";
    parts += p;
    first = false;
  };

  // Température
  if (t > TEMP_CRITICAL) {
    addPart("T=" + fmt1(t) + "C CRITIQUE (+" + fmt1(t - TEMP_CRITICAL) + "C/seuil)");
  } else if (t > TEMP_WARNING) {
    addPart("T=" + fmt1(t) + "C avertissement");
  }
  if (trendT > 0.5) {
    addPart("hausse +" + fmt1(trendT) + "C/cycle");
  } else if (trendT < -0.5) {
    addPart("baisse " + fmt1(trendT) + "C/cycle");
  }

  // Humidité
  if (h < HUM_LOW) {
    addPart("H=" + fmt1(h) + "% trop sec");
  } else if (h > HUM_HIGH) {
    addPart("H=" + fmt1(h) + "% trop humide");
  }

  // Eau
  if (w) {
    addPart("FUITE detectee");
  }

  // Corrélation multi-facteurs
  if (t > TEMP_WARNING && h > 70) {
    addPart("T+H elevees=risque condensation");
  }

  if (first) {
    addPart("parametres normaux");
  }

  XAIResult res;
  res.score  = score;
  res.level  = score >= 0.7 ? "critique" : (score >= 0.4 ? "warning" : "ok");
  res.reason = parts;
  return res;
}

// ── Mise à jour fenêtre + calcul XAI ──────────────────────────────────
XAIResult computeXAI(float t, float h, int w) {
  pushBuf(bufT, bufTLen, t);
  pushBuf(bufH, bufHLen, h);
  float trendT = trendOf(bufT, bufTLen);
  float trendH = trendOf(bufH, bufHLen);
  float score  = riskScore(t, h, w, trendT, trendH);
  return explainXAI(t, h, w, trendT, trendH, score);
}

// ═════════════════════════════════════════════════════════════════════

// ── Lecture capteurs ──────────────────────────────────────────────────
float lastT = 0.0, lastH = 0.0;
int   lastW = 0;

void readSensors(float &t, float &h, int &w) {
  float nt = dht.readTemperature();
  float nh = dht.readHumidity();
  if (!isnan(nt)) lastT = nt;
  if (!isnan(nh)) lastH = nh;
  lastW = digitalRead(WATERPIN);
  t = lastT; h = lastH; w = lastW;
}

// ── WiFi ──────────────────────────────────────────────────────────────
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(SSID, WIFI_PASSWORD);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 40) {
    delay(500);
    tries++;
  }
  Serial.print("WiFi: ");
  Serial.println(WiFi.localIP());
}

// ── Réponses HTTP ────────────────────────────────────────────────────
void handleData() {
  float t, h; int w;
  readSensors(t, h, w);
  XAIResult xai = computeXAI(t, h, w);

  StaticJsonDocument<512> doc;
  doc["temperature"] = t;
  doc["humidity"]    = h;
  doc["water_leak"]  = (bool)w;
  doc["device_id"]   = DEVICE_ID;

  JsonObject alerts = doc.createNestedObject("alerts");
  alerts["temp_critical"] = t > TEMP_CRITICAL;
  alerts["temp_warning"]  = t > TEMP_WARNING;
  alerts["humidity_low"]  = h < HUM_LOW;
  alerts["humidity_high"] = h > HUM_HIGH;
  alerts["water_high"]    = (bool)w;

  JsonObject xaiObj = doc.createNestedObject("xai");
  xaiObj["score"]  = xai.score;
  xaiObj["level"]  = xai.level;
  xaiObj["reason"] = xai.reason;

  String body;
  serializeJson(doc, body);

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", body);
}

void handleXai() {
  float t, h; int w;
  readSensors(t, h, w);
  XAIResult xai = computeXAI(t, h, w);

  StaticJsonDocument<256> doc;
  doc["score"]  = xai.score;
  doc["level"]  = xai.level;
  doc["reason"] = xai.reason;

  String body;
  serializeJson(doc, body);

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", body);
}

void handleHealth() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleRoot() {
  float t, h; int w;
  readSensors(t, h, w);
  XAIResult xai = computeXAI(t, h, w);

  String html = "<h2>DataGuardian XAI</h2>";
  html += "<p>T:" + fmt1(t) + " H:" + fmt1(h) + " Eau:" + (w ? "OUI" : "non") + "</p>";
  html += "<p>Score: <b>" + fmt2(xai.score) + "</b> [" + xai.level + "]</p>";
  html += "<p>" + xai.reason + "</p>";
  html += "<a href='/data'>/data</a> &nbsp; <a href='/xai'>/xai</a>";

  server.send(200, "text/html", html);
}

// ── Main ──────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(WATERPIN, INPUT);
  dht.begin();

  connectWiFi();

  server.on("/",       handleRoot);
  server.on("/data",   handleData);
  server.on("/xai",    handleXai);
  server.on("/health", handleHealth);
  server.begin();

  Serial.println("Serveur pret.");
}

void loop() {
  server.handleClient();
}
