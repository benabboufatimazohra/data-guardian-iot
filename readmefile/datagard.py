#code micropython
# datagard.ino — MicroPython + Explainable AI (on-device, no cloud)
# Flash: esptool erase_flash → write esp8266 firmware → mpremote cp datagard.ino :main.py

import gc, time, math, socket, network, ujson
from machine import Pin
import dht

# ── Config ────────────────────────────────────────────────────────────
from wifi_secrets import SSID, WIFI_PASSWORD  # gitignored, see wifi_secrets.example.py
DEVICE_ID     = "ESP8266-01"

TEMP_WARNING  = 32.0
TEMP_CRITICAL = 38.0
HUM_LOW       = 20.0
HUM_HIGH      = 80.0

# ── Capteurs ──────────────────────────────────────────────────────────
sensor = dht.DHT11(Pin(2))   # D4
water  = Pin(14, Pin.IN)     # D5

# ═════════════════════════════════════════════════════════════════════
#  EXPLAINABLE AI — fenêtre glissante de 5 mesures
#  Calcule: tendance, score de risque, explication textuelle
# ═════════════════════════════════════════════════════════════════════

WINDOW = 5  # nombre de mesures gardées en mémoire (~60 octets RAM)

_buf_t = []   # historique températures
_buf_h = []   # historique humidités

def _push(buf, val):
    buf.append(val)
    if len(buf) > WINDOW:
        buf.pop(0)

def _trend(buf):
    """Pente linéaire simple (dernier - premier) / n  →  °C ou % par cycle."""
    if len(buf) < 2:
        return 0.0
    return (buf[-1] - buf[0]) / len(buf)

def _mean(buf):
    return sum(buf) / len(buf) if buf else 0.0

def _zscore(val, buf):
    """Écart à la moyenne en unités d'écart-type (≥2 = anomalie)."""
    if len(buf) < 2:
        return 0.0
    m = _mean(buf)
    s = math.sqrt(sum((x - m) ** 2 for x in buf) / len(buf))
    return (val - m) / s if s > 0 else 0.0

def _norm(val, lo, hi):
    """Normalise val dans [lo, hi] → 0.0–1.0, clampé."""
    if hi == lo:
        return 0.0
    return max(0.0, min(1.0, (val - lo) / (hi - lo)))

# ── Score de risque (0.0 = ok, 1.0 = critique) ────────────────────────
# Poids: température 50%, humidité 30%, eau 20%
def risk_score(t, h, w, trend_t, trend_h):
    s_t = _norm(t, TEMP_WARNING, TEMP_CRITICAL + 4)   # temp
    s_h = max(_norm(HUM_LOW + 5, h, HUM_LOW),         # hum basse
               _norm(h, HUM_HIGH - 5, HUM_HIGH + 10)) # hum haute
    s_w = 1.0 if w else 0.0                            # eau
    s_tt = _norm(trend_t, 0, 2.0)                      # tendance montante temp
    score = 0.40 * s_t + 0.20 * s_h + 0.20 * s_w + 0.20 * s_tt
    return round(min(score, 1.0), 2)

# ── Génération de l'explication (texte court, ~80 chars max) ──────────
def explain(t, h, w, trend_t, trend_h, score):
    parts = []

    # Température
    if t > TEMP_CRITICAL:
        parts.append("T={}C CRITIQUE (+{}C/seuil)".format(t, round(t - TEMP_CRITICAL, 1)))
    elif t > TEMP_WARNING:
        parts.append("T={}C avertissement".format(t))
    if trend_t > 0.5:
        parts.append("hausse +{}C/cycle".format(round(trend_t, 1)))
    elif trend_t < -0.5:
        parts.append("baisse {}C/cycle".format(round(trend_t, 1)))

    # Humidité
    if h < HUM_LOW:
        parts.append("H={}% trop sec".format(h))
    elif h > HUM_HIGH:
        parts.append("H={}% trop humide".format(h))

    # Eau
    if w:
        parts.append("FUITE detectee")

    # Corrélation multi-facteurs
    if t > TEMP_WARNING and h > 70:
        parts.append("T+H elevees=risque condensation")

    if not parts:
        parts.append("parametres normaux")

    level = "critique" if score >= 0.7 else "warning" if score >= 0.4 else "ok"
    return {"score": score, "level": level, "reason": ", ".join(parts)}

# ── Mise à jour fenêtre + calcul XAI ──────────────────────────────────
def compute_xai(t, h, w):
    _push(_buf_t, t)
    _push(_buf_h, h)
    trend_t = _trend(_buf_t)
    trend_h = _trend(_buf_h)
    score   = risk_score(t, h, w, trend_t, trend_h)
    return explain(t, h, w, trend_t, trend_h, score)

# ═════════════════════════════════════════════════════════════════════

# ── Lecture capteurs ──────────────────────────────────────────────────
_last = {"t": 0.0, "h": 0.0, "w": 0}

def read():
    try:
        sensor.measure()
        _last["t"] = sensor.temperature()
        _last["h"] = sensor.humidity()
    except:
        pass
    _last["w"] = water.value()
    return _last["t"], _last["h"], _last["w"]

# ── WiFi ──────────────────────────────────────────────────────────────
def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    if not wlan.isconnected():
        wlan.connect(SSID, WIFI_PASSWORD)
        for _ in range(40):
            if wlan.isconnected(): break
            time.sleep(0.5)
    print("WiFi:", wlan.ifconfig()[0])

# ── Réponses HTTP ──────────────────────────────────────────────────────
_JSON_HDR = (b"HTTP/1.1 200 OK\r\n"
             b"Content-Type: application/json\r\n"
             b"Access-Control-Allow-Origin: *\r\n\r\n")

def handle(conn):
    try:
        path = conn.recv(256).decode("utf-8", "ignore").split(" ")[1]
    except:
        conn.close(); return

    t, h, w = read()
    xai     = compute_xai(t, h, w)

    if path == "/data":
        body = ujson.dumps({
            "temperature": t,
            "humidity":    h,
            "water_leak":  bool(w),
            "device_id":   DEVICE_ID,
            "alerts": {
                "temp_critical": t > TEMP_CRITICAL,
                "temp_warning":  t > TEMP_WARNING,
                "humidity_low":  h < HUM_LOW,
                "humidity_high": h > HUM_HIGH,
                "water_high":    bool(w),
            },
            "xai": xai,   # {"score":0.72, "level":"warning", "reason":"..."}
        })
        conn.sendall(_JSON_HDR + body.encode())

    elif path == "/health":
        conn.sendall(_JSON_HDR + b'{"status":"ok"}')

    elif path == "/xai":
        conn.sendall(_JSON_HDR + ujson.dumps(xai).encode())

    else:
        conn.sendall(
            b"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
            + ("<h2>DataGuardian XAI</h2>"
               "<p>T:{} H:{} Eau:{}</p>"
               "<p>Score: <b>{}</b> [{}]</p>"
               "<p>{}</p>"
               "<a href='/data'>/data</a> &nbsp; <a href='/xai'>/xai</a>".format(
                   t, h, "OUI" if w else "non",
                   xai["score"], xai["level"], xai["reason"]
               )).encode()
        )

    conn.close()
    gc.collect()

# ── Main ──────────────────────────────────────────────────────────────
connect_wifi()
srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("", 80))
srv.listen(3)
print("Serveur pret.")

while True:
    try:
        conn, _ = srv.accept()
        handle(conn)
    except Exception as e:
        print("err:", e)
        gc.collect()
