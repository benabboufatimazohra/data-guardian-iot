# DataGuardian IoT — Complete Project Documentation

## Project Description

DataGuardian IoT is an intelligent environmental monitoring system designed for server rooms and critical infrastructure. It combines an ESP8266 microcontroller with a Flutter Android application to provide real-time monitoring of temperature, humidity, and water levels, with an embedded AI decision engine that explains sensor anomalies in human-readable language.

The system operates entirely over local WiFi — no external server, no cloud, no internet required. All data processing happens either on the ESP8266 or inside the Flutter app with a local SQLite database.

---

## Hardware Required

| Component | Quantity | Purpose |
|---|---|---|
| ESP8266 NodeMCU v1.0 | 1 | Main microcontroller |
| DHT11 sensor | 1 | Temperature + humidity |
| Water level sensor (analog) | 1 | Detect flooding/leaks |
| Jumper wires | ~10 | Connections |
| Breadboard | 1 | Prototyping |
| MicroUSB cable | 1 | Programming + power |

---

## Wiring Diagram

```
ESP8266 NodeMCU         DHT11 Sensor
─────────────           ────────────
3.3V (or 5V)    ──────► VCC (pin 1)
D4   (GPIO2)    ──────► DATA (pin 2)
GND             ──────► GND (pin 4)

ESP8266 NodeMCU         Water Level Sensor
─────────────           ─────────────────
3.3V            ──────► VCC (+)
A0   (ADC)      ──────► Signal (S)
GND             ──────► GND (-)
```

**IMPORTANT NOTE on Water Sensor:**
The ESP8266 ADC (A0) only accepts 0–1.0V, not 3.3V.
Add a voltage divider: two resistors (10kΩ each) between signal and GND.
Without this, you risk damaging the ADC permanently.

---

## Libraries Required

### For MicroPython (on ESP8266)
These are built into MicroPython — no installation needed:
- `dht` — DHT11/DHT22 sensor driver
- `machine` — Hardware control (ADC, Pin, I2C)
- `network` — WiFi connectivity
- `socket` — HTTP server
- `ujson` — JSON encoding (lightweight JSON for embedded systems)
- `utime` / `time` — Timers

### For Flutter (mobile app)
Already in your `pubspec.yaml`:
- `http` — HTTP client to fetch ESP data
- `sqflite` — Local SQLite database
- `pdf` + `excel` — Export reports
- `share_plus` — Share files

---

## Installation Steps

### Step 1: Install MicroPython on ESP8266

```bash
# Install the flashing tool
pip install esptool

# Connect ESP8266 via USB, find your port (COM3 on Windows, /dev/ttyUSB0 on Linux)

# Erase the existing firmware (Arduino)
esptool.py --port COM3 --baud 460800 erase_flash

# Download MicroPython firmware from:
# https://micropython.org/download/esp8266/
# Choose: esp8266-20231227-v1.22.0.bin (or latest stable)

# Flash MicroPython
esptool.py --port COM3 --baud 460800 write_flash --flash_size=detect 0 esp8266-firmware.bin
```

### Step 2: Install Thonny IDE (recommended for beginners)

1. Download from: https://thonny.org
2. Open Thonny
3. Go to: Tools → Options → Interpreter
4. Select: MicroPython (ESP8266)
5. Select your COM port
6. Click OK

### Step 3: Upload the AI code

1. Open `main_micropython.py` in Thonny
2. Change `WIFI_SSID` and `WIFI_PASSWORD` to your values
3. Click the green Run button (▶)
4. Or: File → Save as → MicroPython device → name it `main.py`
   (Naming it `main.py` makes it run automatically on boot)

### Step 4: Verify it works

Open Thonny's serial console. You should see:
```
=== DataGuardian MicroPython AI ===
Initializing sensors...
Connecting to WiFi...
WiFi connected! IP: 192.168.1.XXX
HTTP server started on port 80
System ready. Measuring every 120 seconds.
```

### Step 5: Connect Flutter app

1. Copy the IP address shown in the serial console
2. Open `lib/config/api_config.dart` in your Flutter project
3. Change: `static const String espIpAddress = '192.168.1.XXX';`
4. Make sure your phone is on the same WiFi network
5. Run the Flutter app

---

## How the AI Logic Works

### Overview

The AI model uses a **Weighted Linear Decision Model** — a simplified version of a single-layer neural network. This is the simplest form of machine learning that can run within the ESP8266's 80KB RAM constraint.

### Step-by-step Decision Process

```
STEP 1: Read raw sensor values
        temperature = 35.2°C
        water_adc   = 750

STEP 2: Convert to risk scores (0–100)
        temp_score  = calculate_temp_score(35.2)  → 68.0
        water_score = calculate_water_score(750)  → 75.0

STEP 3: Apply weights (neural network formula)
        final_score = (68.0 × 0.6) + (75.0 × 0.4)
        final_score = 40.8 + 30.0
        final_score = 70.8

STEP 4: Map score to alert level
        70.8 >= 70 → EMERGENCY

STEP 5: Generate human explanation
        "Temperature 35.2°C exceeds safe limit AND water level 73%
         is dangerously high. Combined danger score: 70.8"

STEP 6: Generate recommendation
        "EMERGENCY SHUTDOWN RECOMMENDED..."
```

### Alert Levels

| Score Range | Level | Meaning |
|---|---|---|
| 0 – 14 | NORMAL | All safe |
| 15 – 39 | WARNING | Attention needed |
| 40 – 69 | CRITICAL | Immediate action |
| 70 – 100 | EMERGENCY | Shutdown recommended |

### Why Weighted Scoring?

Using weights allows the system to prioritize different sensors:
- Temperature gets **60% weight** because thermal damage to hardware is faster
- Water gets **40% weight** because minor water is less immediately destructive

If you wanted humidity to matter more, you would adjust:
```python
WEIGHT_TEMPERATURE = 0.4
WEIGHT_WATER       = 0.3
WEIGHT_HUMIDITY    = 0.3
```

---

## How to Run the Code

### Normal operation (after main.py uploaded)
1. Power the ESP8266
2. Wait ~10 seconds for WiFi connection
3. Open browser: `http://192.168.1.XXX/data`
4. You should see JSON with temperature, water, AND ai fields
5. The Flutter app polls this endpoint every 2 minutes

### Testing without Flutter
Open Chrome on your phone (connected to same WiFi):
```
http://192.168.1.XXX/data
```
You will see the complete JSON including AI explanation.

### Monitoring via Serial
Keep Thonny open → Shell tab → Watch measurements print every 2 minutes.

---

## Data Flow Diagram

```
DHT11 Sensor ──┐
               ├──► ESP8266 reads raw values
Water Sensor ──┘         │
                         ▼
               calculate_temp_score()
               calculate_water_score()
                         │
                         ▼
               ai_decision() — combines scores
                         │
                         ▼
               JSON response built
                         │
              ┌──────────▼──────────┐
              │   HTTP GET /data    │
              └──────────▲──────────┘
                         │  WiFi
                         │
              ┌──────────▼──────────┐
              │  Flutter EspService │
              │  fetchOnce()        │
              └──────────┬──────────┘
                         │
              ┌──────────▼──────────┐
              │  EnvironmentData    │
              │  .fromJson()        │
              └──────────┬──────────┘
                         │
              ┌──────────▼──────────┐
              │  DashboardScreen    │
              │  AlertsScreen       │
              │  AI Explanation UI  │
              └─────────────────────┘
```

---

## Limitations of AI on ESP8266

| Limitation | Explanation |
|---|---|
| No learning | The weights are fixed. The system cannot improve from experience. |
| No memory | Each decision is independent. It cannot detect slow trends over days. |
| Simple model only | Neural networks with hidden layers require too much RAM (80KB limit). |
| No real-time clock | Timestamps use uptime, not real date/time (no RTC chip). |
| Single-threaded | HTTP server and sensor reading share the same CPU thread. |
| WiFi drops | If WiFi disconnects, data is lost until reconnection. |

---

## Comparison: Rule-based vs AI Model

| Feature | Simple if/else | Our Weighted Model |
|---|---|---|
| Can handle gradual changes | No | Yes (scores are continuous) |
| Explains decisions | No | Yes (XAI explanations) |
| Multiple sensor fusion | Difficult | Built-in (weighted sum) |
| Adjustable priorities | No | Yes (change weights) |
| RAM usage | ~1KB | ~3KB |
| Complexity | Very simple | Moderate |

---

## Future Improvements

### Short-term (possible on ESP8266)
- Add RTC module (DS3231) for real timestamps
- Store last 10 readings in flash memory (not RAM) for trend detection
- Add LED indicators: Green=normal, Yellow=warning, Red=critical
- Add buzzer for audio emergency alert

### Medium-term (requires ESP32)
- ESP32 has 520KB RAM — can run small decision tree models
- Store 1000+ readings in SPIFFS filesystem
- Implement moving average to detect slow temperature rise
- Run TensorFlow Lite Micro with a tiny trained model

### Long-term (requires edge server)
- Train a proper LSTM model on historical data
- Predict failures 30 minutes in advance
- Anomaly detection for unusual patterns

---

## File Structure

```
DataGuardian IoT/
├── micropython/
│   └── main.py              ← This file (AI + HTTP server)
├── flutter_app/
│   └── lib/
│       ├── config/
│       │   └── api_config.dart      ← ESP IP address
│       ├── services/
│       │   ├── esp_service.dart     ← Polls ESP every 2 min
│       │   └── export_service.dart  ← Excel/PDF export
│       ├── models/
│       │   └── models.dart          ← Data structures
│       ├── screens/
│       │   ├── dashboard_screen.dart
│       │   ├── alerts_screen.dart
│       │   └── history_screen.dart
│       └── database/
│           └── database_helper.dart ← SQLite (alerts only)
└── README.md
```

---

## Academic Summary (for your project report)

This project demonstrates the implementation of a lightweight embedded intelligence system on resource-constrained hardware. The AI component utilizes a weighted linear scoring model, mathematically equivalent to a single-layer perceptron without bias, operating within the 80KB RAM constraint of the ESP8266 microcontroller.

The system architecture follows the IoT reference model: perception layer (sensors), network layer (WiFi/HTTP), and application layer (Flutter/SQLite). The AI decision engine implements explainable artificial intelligence (XAI) principles by providing human-readable justifications for each alert, addressing the transparency requirements of critical infrastructure monitoring systems.

The choice of MicroPython over C++ (Arduino) reduces development complexity while maintaining acceptable performance for the 120-second polling interval, demonstrating that high-level language abstractions are viable for embedded AI applications when computational requirements are carefully managed.
