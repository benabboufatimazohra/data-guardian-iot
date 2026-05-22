# =============================================================================
# DataGuardian IoT — MicroPython AI Model for ESP8266
# File: main.py
#
# WHAT IS THIS?
#   This is a simple rule-based AI system running directly on the ESP8266.
#   It reads temperature and water level sensors, then makes intelligent
#   decisions about what is happening and why.
#
# WHY "AI" AND NOT JUST IF/ELSE?
#   Real AI on ESP8266 is limited to simple models because:
#     - Only 80KB RAM available
#     - No floating point GPU
#     - Cannot run TensorFlow or PyTorch
#   Our "AI" uses a weighted scoring system — this is a real technique
#   called a "Linear Decision Model" or "Weighted Rule Engine".
#   It is mathematically similar to a simplified neural network with
#   one layer and predefined weights.
#
# HOW THE AI MAKES DECISIONS:
#   Each sensor reading gets a "risk score" from 0 to 100.
#   Multiple risk scores are combined with weights to give a final score.
#   The final score determines the alert level.
#   This is exactly how the first layer of a neural network works.
#
# HARDWARE NEEDED:
#   - ESP8266 (NodeMCU or Wemos D1 Mini)
#   - DHT11 temperature/humidity sensor → pin D4 (GPIO2)
#   - Water sensor (analog or digital) → pin A0 (ADC)
#   - MicroUSB cable for programming
#
# HOW TO FLASH MICROPYTHON:
#   1. Download MicroPython firmware: https://micropython.org/download/esp8266/
#   2. Install esptool: pip install esptool
#   3. Erase flash: esptool.py --port COM3 erase_flash
#   4. Flash firmware: esptool.py --port COM3 write_flash 0x0 firmware.bin
#   5. Upload this file using Thonny IDE or ampy
# =============================================================================

import machine
import time
import network
import ujson
import dht
from machine import ADC, Pin

# =============================================================================
# CONFIGURATION — Change these values for your setup
# =============================================================================

WIFI_SSID     = "..."
WIFI_PASSWORD = "..."

# Safe temperature range (your project requirement: 18°C to 27°C)
TEMP_MIN_SAFE     = 18.0   # Below this = too cold
TEMP_MAX_SAFE     = 27.0   # Above this = warning
TEMP_WARNING      = 32.0   # Above this = serious warning
TEMP_CRITICAL     = 38.0   # Above this = critical emergency

# Water level thresholds (ADC value 0-1023 on ESP8266)
WATER_LOW         = 200    # Safe: very little water
WATER_WARNING     = 500    # Warning: water rising
WATER_HIGH        = 700    # Critical: dangerous water level
WATER_EMERGENCY   = 900    # Emergency: flooding

# How often to measure (in seconds)
MEASURE_INTERVAL  = 120    # 2 minutes

# =============================================================================
# AI WEIGHT SYSTEM — The "brain" of our model
# =============================================================================
#
# HOW WEIGHTS WORK:
#   Each sensor contributes to the final danger score.
#   Higher weight = that sensor matters more for the decision.
#
#   Think of it like a doctor checking symptoms:
#     - Fever (temperature) is the most important symptom → weight 0.6
#     - Water level is also important → weight 0.4
#
#   If temperature is critical (score=100) and water is fine (score=0):
#     final_score = (100 × 0.6) + (0 × 0.4) = 60
#   This means: danger score is 60/100 → WARNING level
#
WEIGHT_TEMPERATURE = 0.6   # 60% importance
WEIGHT_WATER       = 0.4   # 40% importance

# =============================================================================
# SENSOR SETUP
# =============================================================================

dht_sensor = dht.DHT11(Pin(2))   # DHT11 on GPIO2 (D4 on NodeMCU)
adc        = ADC(0)               # Analog pin A0 for water sensor

# =============================================================================
# FUNCTION: Calculate temperature risk score (0 to 100)
# =============================================================================
#
# HOW THIS WORKS:
#   We convert a raw temperature reading into a normalized score.
#   0   = perfectly safe
#   25  = slightly warm
#   50  = warning level
#   75  = serious warning
#   100 = critical emergency
#
# This is called "feature normalization" in machine learning.
# We map the raw sensor value to a 0-100 scale.
#
def calculate_temp_score(temp):
    if temp < TEMP_MIN_SAFE:
        # Too cold — some risk but lower than heat
        cold_ratio = (TEMP_MIN_SAFE - temp) / TEMP_MIN_SAFE
        return min(cold_ratio * 40, 40)   # Max 40 for cold
    
    elif temp <= TEMP_MAX_SAFE:
        # Perfect safe zone → score 0
        return 0
    
    elif temp <= TEMP_WARNING:
        # Warming up — linear increase from 0 to 50
        ratio = (temp - TEMP_MAX_SAFE) / (TEMP_WARNING - TEMP_MAX_SAFE)
        return ratio * 50   # 0 to 50
    
    elif temp <= TEMP_CRITICAL:
        # Serious warning — score 50 to 85
        ratio = (temp - TEMP_WARNING) / (TEMP_CRITICAL - TEMP_WARNING)
        return 50 + (ratio * 35)   # 50 to 85
    
    else:
        # Critical — score 85 to 100
        ratio = min((temp - TEMP_CRITICAL) / 10.0, 1.0)
        return 85 + (ratio * 15)   # 85 to 100


# =============================================================================
# FUNCTION: Calculate water risk score (0 to 100)
# =============================================================================
def calculate_water_score(water_adc):
    if water_adc <= WATER_LOW:
        return 0   # No water — safe
    
    elif water_adc <= WATER_WARNING:
        ratio = (water_adc - WATER_LOW) / (WATER_WARNING - WATER_LOW)
        return ratio * 30   # 0 to 30
    
    elif water_adc <= WATER_HIGH:
        ratio = (water_adc - WATER_WARNING) / (WATER_HIGH - WATER_WARNING)
        return 30 + (ratio * 40)   # 30 to 70
    
    elif water_adc <= WATER_EMERGENCY:
        ratio = (water_adc - WATER_HIGH) / (WATER_EMERGENCY - WATER_HIGH)
        return 70 + (ratio * 20)   # 70 to 90
    
    else:
        return 100   # Complete emergency


# =============================================================================
# FUNCTION: The AI Decision Engine
# =============================================================================
#
# HOW THIS WORKS (this is the actual "AI"):
#   1. Get individual scores from each sensor
#   2. Combine them using weighted average (like a mini neural network)
#   3. Map the final score to a human-readable decision
#
# MATHEMATICAL FORMULA:
#   final_score = (temp_score × W_temp) + (water_score × W_water)
#
# This is identical to: output = W1*X1 + W2*X2
# Which is the formula for a SINGLE NEURON in a neural network.
#
def ai_decision(temp, humidity, water_adc):
    # Step 1: Calculate individual risk scores
    temp_score  = calculate_temp_score(temp)
    water_score = calculate_water_score(water_adc)
    
    # Step 2: Weighted combination (the neural network formula)
    final_score = (temp_score  * WEIGHT_TEMPERATURE) + \
                  (water_score * WEIGHT_WATER)
    
    # Step 3: Determine alert level based on final score
    if final_score < 15:
        alert_level   = "NORMAL"
        alert_message = "All systems normal. Environment is safe."
        explanation   = explain_normal(temp, humidity, water_adc)
    
    elif final_score < 40:
        alert_level   = "WARNING"
        alert_message = "Attention required. Conditions are suboptimal."
        explanation   = explain_warning(temp, humidity, water_adc, temp_score, water_score)
    
    elif final_score < 70:
        alert_level   = "CRITICAL"
        alert_message = "Critical conditions detected! Immediate action required."
        explanation   = explain_critical(temp, humidity, water_adc, temp_score, water_score)
    
    else:
        alert_level   = "EMERGENCY"
        alert_message = "EMERGENCY! System shutdown recommended."
        explanation   = explain_emergency(temp, water_adc)
    
    return {
        "alert_level":   alert_level,
        "final_score":   round(final_score, 1),
        "temp_score":    round(temp_score, 1),
        "water_score":   round(water_score, 1),
        "message":       alert_message,
        "explanation":   explanation,
        "recommendation": get_recommendation(alert_level, temp, water_adc)
    }


# =============================================================================
# EXPLANATION FUNCTIONS — The AI explains WHY it made a decision
# =============================================================================
#
# This is the "explainability" part of the AI (called XAI — Explainable AI).
# Instead of just saying "danger", the system explains the reasoning.
# This is exactly what your Flutter app shows when you tap "Explain".
#

def explain_normal(temp, humidity, water_adc):
    return "Temperature {}C is within safe range (18-27C). Humidity {}% is acceptable. Water level is low ({}/1023).".format(
        temp, humidity, water_adc
    )

def explain_warning(temp, humidity, water_adc, ts, ws):
    reasons = []
    if ts > 10:
        reasons.append("temperature {}C is above optimal range".format(temp))
    if ws > 10:
        reasons.append("water level is rising ({}/1023)".format(water_adc))
    if humidity > 70:
        reasons.append("humidity {}% is high".format(humidity))
    return "Warning triggered because: " + ", ".join(reasons) + "."

def explain_critical(temp, humidity, water_adc, ts, ws):
    reasons = []
    if ts > 40:
        reasons.append("temperature {}C significantly exceeds safe limit of 27C (risk score: {})".format(temp, round(ts,1)))
    if ws > 30:
        reasons.append("water level {}% is dangerously high (risk score: {})".format(
            round(water_adc/10.23, 0), round(ws,1)))
    return "Critical alert: " + " AND ".join(reasons) + ". Combined danger score exceeded threshold."

def explain_emergency(temp, water_adc):
    return "EMERGENCY: Temperature {}C and/or water level {}/1023 have reached values that risk permanent hardware damage. Immediate intervention required.".format(
        temp, water_adc
    )

def get_recommendation(level, temp, water_adc):
    if level == "NORMAL":
        return "Continue monitoring. No action needed."
    elif level == "WARNING":
        if temp > TEMP_MAX_SAFE:
            return "Check cooling system. Verify HVAC is functioning."
        else:
            return "Inspect area for water accumulation. Check drainage."
    elif level == "CRITICAL":
        return "Immediately check cooling units and water drainage. Consider moving sensitive equipment."
    else:
        return "EMERGENCY SHUTDOWN RECOMMENDED. Remove all hardware from area immediately."


# =============================================================================
# WIFI CONNECTION
# =============================================================================
def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if not wlan.isconnected():
        print("Connecting to WiFi...")
        wlan.connect(WIFI_SSID, WIFI_PASSWORD)
        
        timeout = 20   # Wait max 20 seconds
        while not wlan.isconnected() and timeout > 0:
            time.sleep(1)
            timeout -= 1
            print(".")
    
    if wlan.isconnected():
        print("WiFi connected! IP:", wlan.ifconfig()[0])
        return True
    else:
        print("WiFi connection failed!")
        return False


# =============================================================================
# HTTP SERVER — Serves JSON data to Flutter app
# =============================================================================
#
# NOTE: MicroPython's network stack is limited.
# We use a simple socket server instead of a full HTTP library.
#
import socket

def start_server():
    addr = socket.getaddrinfo('0.0.0.0', 80)[0][-1]
    s    = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(addr)
    s.listen(5)
    s.setblocking(False)   # Non-blocking so we can still measure sensors
    print("HTTP server started on port 80")
    return s


def read_sensors():
    """Read all sensors and return raw values."""
    try:
        dht_sensor.measure()
        temp     = dht_sensor.temperature()
        humidity = dht_sensor.humidity()
    except Exception as e:
        print("DHT read error:", e)
        temp     = 0
        humidity = 0
    
    water_adc = adc.read()   # 0-1023
    water_pct = round((water_adc / 1023.0) * 100, 1)
    
    return temp, humidity, water_adc, water_pct


def build_response(temp, humidity, water_adc, water_pct, ai_result):
    """Build the JSON response that Flutter will receive."""
    
    # Map alert_level to the flags Flutter expects
    is_critical = ai_result["alert_level"] in ("CRITICAL", "EMERGENCY")
    is_warning  = ai_result["alert_level"] == "WARNING"
    
    data = {
        "temperature":   temp,
        "humidity":      humidity,
        "water_leak":    water_adc > WATER_WARNING,
        "water_level":   water_adc,
        "water_percent": water_pct,
        "device_id":     "ESP8266-01",
        "alerts": {
            "temp_critical":  temp > TEMP_CRITICAL,
            "temp_warning":   temp > TEMP_WARNING,
            "humidity_low":   humidity < 20,
            "humidity_high":  humidity > 80,
            "water_high":     water_adc > WATER_HIGH
        },
        # AI-specific fields — shown in Flutter's "Explain" button
        "ai": {
            "alert_level":    ai_result["alert_level"],
            "danger_score":   ai_result["final_score"],
            "temp_score":     ai_result["temp_score"],
            "water_score":    ai_result["water_score"],
            "explanation":    ai_result["explanation"],
            "recommendation": ai_result["recommendation"]
        }
    }
    return ujson.dumps(data)


def handle_request(client, response_body):
    """Send HTTP response to Flutter."""
    try:
        request = client.recv(1024).decode('utf-8')
        
        if '/data' in request or '/' in request:
            http_response = (
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: application/json\r\n"
                "Access-Control-Allow-Origin: *\r\n"
                "Connection: close\r\n"
                "\r\n" + response_body
            )
            client.send(http_response.encode('utf-8'))
    except Exception as e:
        print("Request error:", e)
    finally:
        client.close()


# =============================================================================
# MAIN LOOP
# =============================================================================
def main():
    print("=== DataGuardian MicroPython AI ===")
    print("Initializing sensors...")
    time.sleep(2)   # Wait for DHT11 to stabilize
    
    # Connect to WiFi
    if not connect_wifi():
        print("Cannot connect to WiFi. Running in standalone mode.")
    
    # Start HTTP server
    server = start_server()
    
    last_measure  = 0
    last_response = '{"error": "initializing"}'
    
    print("System ready. Measuring every {} seconds.".format(MEASURE_INTERVAL))
    
    while True:
        current_time = time.time()
        
        # Measure sensors every MEASURE_INTERVAL seconds
        if current_time - last_measure >= MEASURE_INTERVAL:
            last_measure = current_time
            
            # Read sensors
            temp, humidity, water_adc, water_pct = read_sensors()
            
            # Run AI decision engine
            ai_result = ai_decision(temp, humidity, water_adc)
            
            # Build JSON response
            last_response = build_response(
                temp, humidity, water_adc, water_pct, ai_result
            )
            
            # Print to serial monitor
            print("\n--- Measurement ---")
            print("Temp: {}C | Humidity: {}% | Water: {}/1023 ({}%)".format(
                temp, humidity, water_adc, water_pct))
            print("AI Decision: {} (Score: {})".format(
                ai_result["alert_level"], ai_result["final_score"]))
            print("Explanation:", ai_result["explanation"])
            print("Action:", ai_result["recommendation"])
        
        # Handle incoming HTTP requests (non-blocking)
        try:
            client, addr = server.accept()
            handle_request(client, last_response)
        except OSError:
            pass   # No request waiting — continue
        
        time.sleep(0.1)   # Small delay to prevent CPU overload


# Start the system
main()
