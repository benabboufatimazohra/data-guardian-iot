#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <DHT.h>

// ── WiFi credentials ──────────────────────────────────────────────
const char* ssid     = "***REMOVED***";
const char* password = "***REMOVED***";

// ── Pins ──────────────────────────────────────────────────────────
#define DHTPIN    2     // D4 on NodeMCU
#define DHTTYPE   DHT11
#define WATER_PIN 14    // D5 on NodeMCU

DHT dht(DHTPIN, DHTTYPE);
ESP8266WebServer server(80);

// ── Safe temperature thresholds  ──────────────────────
const float TEMP_MIN      = 18.0;
const float TEMP_MAX_SAFE = 27.0;
const float TEMP_WARNING  = 32.0;
const float TEMP_CRITICAL = 38.0;

// ── Measurement every 2 minutes  ──────────────────────
unsigned long lastMeasurement = 0;
const long MEASURE_INTERVAL   = 120000; // 2 minutes in ms

// ── Last sensor values ────────────────────────────────────────────
float lastTemp     = 0;
float lastHumidity = 0;
int   lastWater    = 0;

void handleData() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  int   w = digitalRead(WATER_PIN);

  if (isnan(t) || isnan(h)) {
    server.send(500, "application/json", "{\"error\":\"DHT read failed\"}");
    return;
  }

  lastTemp = t; lastHumidity = h; lastWater = w;

  bool tempWarning  = t > TEMP_WARNING;
  bool tempCritical = t > TEMP_CRITICAL;
  bool humLow       = h < 20.0;
  bool humHigh      = h > 80.0;
  bool waterHigh    = w == 1;

  String json = "{";
  json += "\"temperature\":"  + String(t, 1) + ",";
  json += "\"humidity\":"     + String(h, 1) + ",";
  json += "\"water_leak\":"   + String(w == 1 ? "true" : "false") + ",";
  json += "\"water_level\":"  + String(w) + ",";
  json += "\"water_percent\":" + String(w * 100.0, 1) + ",";
  json += "\"timestamp\":\""  + getTimestamp() + "\",";
  json += "\"device_id\":\"ESP8266-01\",";
  json += "\"ip\":\""         + WiFi.localIP().toString() + "\",";
  json += "\"alerts\":{";
  json += "\"temp_critical\":"  + String(tempCritical ? "true" : "false") + ",";
  json += "\"temp_warning\":"   + String(tempWarning  ? "true" : "false") + ",";
  json += "\"humidity_low\":"   + String(humLow       ? "true" : "false") + ",";
  json += "\"humidity_high\":"  + String(humHigh      ? "true" : "false") + ",";
  json += "\"water_high\":"     + String(waterHigh    ? "true" : "false");
  json += "}}";

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);

  Serial.printf("📡 /data → T=%.1f°C H=%.1f%% W=%d\n", t, h, w);
}

void handleHealth() {
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleRoot() {
  String html = "<h2>DataGuardian ESP8266</h2>";
  html += "<p>Temperature: " + String(lastTemp, 1) + " C</p>";
  html += "<p>Humidity: "    + String(lastHumidity, 1) + " %</p>";
  html += "<p>Water: "       + String(lastWater) + "</p>";
  html += "<p><a href='/data'>JSON Data</a></p>";
  server.send(200, "text/html", html);
}

String getTimestamp() {
  unsigned long ms = millis();
  unsigned long s  = ms / 1000;
  int hh = (s / 3600) % 24;
  int mm = (s / 60)   % 60;
  int ss = s % 60;
  char buf[25];
  sprintf(buf, "2026-05-09T%02d:%02d:%02d", hh, mm, ss);
  return String(buf);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  dht.begin();
  pinMode(WATER_PIN, INPUT);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\n✅ WiFi connected!");
  Serial.println("════════════════════════════════");
  Serial.println("🌐 Open in Chrome:");
  Serial.print  ("   http://");
  Serial.println(WiFi.localIP());
  Serial.println("════════════════════════════════");
  Serial.println("Endpoints:");
  Serial.println("  /       → HTML status page");
  Serial.println("  /data   → JSON sensor data");
  Serial.println("  /health → Health check");

  server.on("/",       handleRoot);
  server.on("/data",   handleData);
  server.on("/health", handleHealth);
  server.begin();
}

void loop() {
  server.handleClient();

  // Log to Serial every 2 minutes (Question 3)
  if (millis() - lastMeasurement >= MEASURE_INTERVAL) {
    lastMeasurement = millis();
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    int   w = digitalRead(WATER_PIN);
    Serial.printf("⏱ [2min] T=%.1f°C H=%.1f%% W=%d\n", t, h, w);
  }
}
