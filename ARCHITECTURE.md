# DataGuardian IoT — Architecture Détaillée

## 1. Vue d'ensemble du système

```mermaid
graph TB
    subgraph HARDWARE["⚙️ Couche Matérielle (ESP8266)"]
        DHT11["DHT11\nTempérature & Humidité\n(GPIO D4)"]
        WLS["Capteur Niveau d'eau\n(GPIO D5 — Digital)"]
        ESP["ESP8266\nNodeMCU\n192.168.11.174:80"]
        DHT11 -->|"UART / GPIO"| ESP
        WLS -->|"GPIO Digital"| ESP
    end

    subgraph FIRMWARE["🔧 Firmware ESP8266 — MicroPython (datagard.ino)"]
        THRESH["Calcul des seuils\n• Temp: Warn 32°C / Crit 38°C\n• Hum: Low <20% / High >80%\n• Eau: détection digitale"]
        XAI_ENGINE["Moteur XAI on-device\n• Buffer circulaire 5 mesures\n• Tendance (pente)\n• Score de risque 0.0–1.0\n• Explication textuelle"]
        HTTP_SRV["Serveur HTTP Port 80\nGET /data → JSON + xai{}\nGET /health\nGET /xai\nGET /"]
        ESP --> THRESH
        THRESH --> XAI_ENGINE
        XAI_ENGINE --> HTTP_SRV
    end

    subgraph APP["📱 Application Flutter (DataGuardian)"]
        direction TB
        subgraph SERVICES["Services"]
            ESP_SVC["EspService\nPolling HTTP (2 min)"]
            AUTH_SVC["AuthService\nSingleton — Session"]
            EXPORT_SVC["ExportService\nExcel / PDF"]
        end
        subgraph MODELS["Modèles"]
            ENV_DATA["EnvironmentData"]
            ALERT_MODEL["AlertModel"]
            APP_USER["AppUser"]
            ESP_DEVICE["EspDevice"]
        end
        subgraph DB["Base de Données (SQLite)"]
            USERS_TBL[("users")]
            DEVICES_TBL[("esp_devices")]
            READINGS_TBL[("sensor_readings")]
            ALERTS_TBL[("alerts")]
        end
        subgraph SCREENS["Écrans"]
            LOGIN["LoginScreen"]
            DASH["DashboardScreen"]
            ALERTS_SCR["AlertsScreen"]
            HIST["HistoryScreen"]
            EXPORT_SCR["ExportScreen"]
            SETTINGS["SettingsScreen"]
            DEV_DETAIL["DeviceDetailScreen"]
            ALERT_ANALYSIS["AlertAnalysisScreen"]
        end
    end

    HTTP_SRV -->|"GET /data JSON (2 min)"| ESP_SVC
    ESP_SVC -->|"Parse JSON"| ENV_DATA
    ENV_DATA -->|"Stream broadcast"| DASH
    ENV_DATA -->|"AlertModel.fromEspData()"| ALERT_MODEL
    ALERT_MODEL -->|"Si CRITIQUE → INSERT"| ALERTS_TBL
    AUTH_SVC --> USERS_TBL
    EXPORT_SVC --> ALERTS_TBL
    EXPORT_SVC -->|"Partage natif"| USER_DEVICE["📲 Utilisateur"]
```

---

## 2. Flux de données complet (Data Flow)

```mermaid
sequenceDiagram
    participant DHT as DHT11
    participant ESP as ESP8266
    participant SVC as EspService (Flutter)
    participant STREAM as dataStream
    participant UI as Dashboard UI
    participant DB as SQLite
    participant EXPORT as ExportService

    loop Toutes les 2 minutes
        ESP->>ESP: Lire DHT11 (temp, hum)
        ESP->>ESP: Lire pin D5 (water_leak)
        ESP->>ESP: _push(buf_t, t) / _push(buf_h, h)
        ESP->>ESP: trend() + risk_score() → score 0.0-1.0
        ESP->>ESP: explain() → reason string
        SVC->>ESP: GET /data HTTP
        ESP-->>SVC: JSON {temperature, humidity, water_leak,\nalerts{…}, xai:{score, level, reason}}
        SVC->>SVC: EnvironmentData.fromJson()
        SVC->>STREAM: broadcast(EnvironmentData)
        STREAM->>UI: setState() → mise à jour gauges + xai reason
        SVC->>SVC: AlertModel.fromEspData()
        alt Alerte CRITIQUE détectée
            SVC->>DB: INSERT INTO alerts (ConflictAlgorithm.replace)
            SVC->>DB: setEspOnline(espId, true)
        end
    end

    note over SVC,DB: Seules les alertes critiques sont persistées

    UI->>EXPORT: Demander rapport (date range)
    EXPORT->>DB: getAlertsForExport()
    DB-->>EXPORT: List<AlertModel>
    EXPORT->>EXPORT: Générer Excel (.xlsx) ou PDF (.pdf)
    EXPORT->>UI: Partage natif (share_plus)
```

---

## 3. Architecture de la base de données SQLite

```mermaid
erDiagram
    users {
        INTEGER id PK
        TEXT full_name
        TEXT email UK
        TEXT password_hash "SHA-256"
        TEXT role "admin | responsable"
        TEXT assigned_esp_id FK
        TEXT created_at "ISO8601"
    }

    esp_devices {
        TEXT id PK "ex: ESP8266-01"
        TEXT name
        TEXT ip_address
        TEXT location
        TEXT room
        INTEGER is_online "0 | 1"
        TEXT firmware "v2.0.4"
        TEXT last_seen "ISO8601"
        TEXT created_at "ISO8601"
    }

    sensor_readings {
        INTEGER id PK
        TEXT esp_id FK
        REAL temperature "°C"
        REAL humidity "%"
        INTEGER water_leak "0 | 1"
        INTEGER water_level "ADC 0-1023"
        REAL water_pct "0.0-100.0%"
        TEXT recorded_at "ISO8601"
    }

    alerts {
        TEXT id PK "ex: live-temp-critical"
        TEXT esp_id FK
        TEXT device_id
        TEXT severity "critical | warning | info"
        TEXT title
        TEXT location
        INTEGER is_resolved "0 | 1"
        TEXT created_at "ISO8601"
    }

    users ||--o{ esp_devices : "assigned_esp_id"
    esp_devices ||--o{ sensor_readings : "esp_id"
    esp_devices ||--o{ alerts : "esp_id"
```

---

## 4. Flux d'authentification et contrôle d'accès

```mermaid
flowchart TD
    START([Lancement App]) --> LOGIN_SCR[LoginScreen]
    LOGIN_SCR -->|"Email + Mot de passe"| HASH["SHA-256(password)"]
    HASH -->|"SELECT * FROM users WHERE email=? AND password_hash=?"| DB[(SQLite)]
    DB -->|"Utilisateur trouvé"| SESSION["AuthService.currentUser = AppUser"]
    DB -->|"Non trouvé"| ERROR["Erreur: identifiants invalides"]
    ERROR --> LOGIN_SCR

    SESSION --> ROLE{Rôle ?}

    ROLE -->|"admin"| ADMIN_ACCESS["Accès complet\n• Tous les ESP\n• Gestion utilisateurs\n• Gestion appareils\n• SettingsScreen complet"]

    ROLE -->|"responsable"| RESP_ACCESS["Accès limité\n• Uniquement ESP assigné\n(assigned_esp_id)\n• Pas de gestion utilisateurs"]

    ADMIN_ACCESS --> DASH_FULL[DashboardScreen\nTous les appareils]
    RESP_ACCESS --> DASH_LIMITED[DashboardScreen\nAppareil assigné uniquement]

    DASH_FULL --> NAV[Navigation Bottom Bar\n• Dashboard\n• Devices\n• Alerts\n• Settings]
    DASH_LIMITED --> NAV

    NAV -->|"Déconnexion"| LOGOUT["AuthService.logout()\ncurrentUser = null"]
    LOGOUT --> LOGIN_SCR
```

---

## 5. Architecture des composants Flutter

```mermaid
graph LR
    subgraph ENTRY["Point d'entrée"]
        MAIN["main.dart\nDataGuardianApp\nMaterialApp + Routes"]
    end

    subgraph CONFIG["Configuration"]
        API_CFG["api_config.dart\n• baseUrl: 192.168.11.174\n• pollingInterval: 2 min\n• timeout: 3 min"]
    end

    subgraph THEME["Design System"]
        COLORS["app_colors.dart\n• Primary: #3C83F6\n• Background: #101722\n• Surface: #1A2332\n• Critical: #EF4444\n• Warning: #F97316\n• Normal: #10B981"]
    end

    subgraph MODELS_BOX["Modèles de données"]
        ENV_D["EnvironmentData\n• temperature\n• humidity\n• waterLeakDetected\n• waterLevelRaw\n• waterLevelPercent\n• EspAlerts"]
        ESP_A["EspAlerts\n• tempCritical\n• tempWarning\n• humidityLow\n• humidityHigh\n• waterHigh"]
        ALERT_M["AlertModel\n• id\n• espId\n• severity\n• title\n• isResolved\n.fromEspData()"]
        APP_U["AppUser\n• id\n• fullName\n• email\n• role\n• assignedEspId"]
        ESP_DEV["EspDevice\n• id\n• name\n• ipAddress\n• isOnline\n• firmware"]
        SENS_R["SensorReading\n• espId\n• temperature\n• humidity\n• waterLeak"]
        SENS_S["SensorStats\n• min / max / avg\n• temperature\n• humidity"]
    end

    subgraph SERVICES_BOX["Services"]
        ESP_S["EspService\n• startPolling()\n• stopPolling()\n• fetchOnce()\n• checkHealth()\n• dataStream (broadcast)\n• errorStream\n• connectionStream"]
        AUTH_S["AuthService (Singleton)\n• login(email, pwd)\n• logout()\n• currentUser\n• isAdmin"]
        EXPORT_S["ExportService\n• generateExcel()\n• generatePDF()\n• shareFile()"]
        DB_H["DatabaseHelper\n• getUsers()\n• insertAlert()\n• getAlertsForExport()\n• resolveAlert()\n• getEspsForUser()\n• setEspOnline()"]
    end

    subgraph WIDGETS_BOX["Widgets réutilisables"]
        NAV_BAR["AppBottomNavBar\n4 destinations"]
        GAUGE["SensorGaugeCard\nJauge circulaire custom"]
        WATER_C["WaterLeakCard\nNiveau d'eau %"]
        ALERT_C["AlertCard\nCouleur selon sévérité"]
        ACTIVITY["ActivityListItem\nJournal d'activité"]
        APP_C["AppCard\nConteneur élevé"]
    end

    MAIN --> CONFIG
    MAIN --> THEME
    MAIN --> SERVICES_BOX
    ENV_D --> ESP_A
    ESP_S --> ENV_D
    DB_H --> ALERT_M
    DB_H --> APP_U
    DB_H --> ESP_DEV
    DB_H --> SENS_R
    DB_H --> SENS_S
    GAUGE --> COLORS
    ALERT_C --> COLORS
```

---

## 6. Firmware ESP8266 — MicroPython + XAI

```mermaid
flowchart TD
    BOOT([Démarrage ESP8266\nMicroPython]) --> WIFI["connect_wifi()\nSSID + password"]
    WIFI -->|"OK"| HTTP_START["socket.bind port 80\nsrv.listen(3)"]
    WIFI -->|"40 tentatives"| RETRY["Retry loop\n× 40 × 0.5s"]
    RETRY --> WIFI

    HTTP_START --> LOOP{conn, _ =\nsrv.accept()}

    LOOP -->|"GET /health"| HEALTH_RESP['{"status":"ok"}']
    LOOP -->|"GET /xai"| XAI_ONLY["ujson.dumps(xai)"]
    LOOP -->|"GET /"| HTML_RESP["Page HTML\nT / H / score / reason"]
    LOOP -->|"GET /data"| READ

    READ["read()\nsensor.measure()\nwater.value()"] --> PUSH["_push(buf_t, t)\n_push(buf_h, h)"]

    PUSH --> TREND["_trend(buf)\n= (last - first) / n"]
    PUSH --> SCORE

    TREND --> SCORE["risk_score()\n0.40×T + 0.20×H\n+ 0.20×eau + 0.20×tendance"]

    SCORE --> EXPLAIN["explain()\nif t > CRITICAL → 'T=X CRITIQUE'\nif trend > 0.5 → 'hausse +X/cycle'\nif t>warn & h>70 → 'condensation'\n→ reason string"]

    EXPLAIN --> BUILD["Construire JSON\n{temperature, humidity,\nwater_leak, device_id,\nalerts{…},\nxai:{score, level, reason}}"]

    BUILD --> CORS["sendall(HDR_JSON + body)\nAccess-Control-Allow-Origin: *"]
    CORS --> GC["gc.collect()"]
    GC --> LOOP
    HEALTH_RESP --> LOOP
    XAI_ONLY --> LOOP
    HTML_RESP --> LOOP
```

---

## 7. Cycle de vie des alertes

```mermaid
stateDiagram-v2
    [*] --> Détectée : ESP retourne flag=true\ndans JSON /data

    Détectée --> Évaluée : AlertModel.fromEspData()\ndans EspService

    Évaluée --> NonPersistée : severity = warning | info
    Évaluée --> Persistée : severity = critical

    NonPersistée --> AffichéeDashboard : Stream broadcast\n→ Dashboard UI
    Persistée --> AffichéeDashboard : Stream broadcast\n→ Dashboard UI
    Persistée --> SQLite : INSERT INTO alerts\n(ConflictAlgorithm.replace)\nid fixe: 'live-temp-critical'

    SQLite --> Consultable : AlertsScreen\nfiltrage All/Critical/Warning/Resolved

    Consultable --> Résolue : resolveAlert(id)\nis_resolved = 1

    Résolue --> Exportée : ExportService\ngetAlertsForExport(dateRange)
    Exportée --> [*] : Fichier Excel/PDF\nPartagé via share_plus

    NonPersistée --> [*] : Perdue au prochain\ncycle de polling
```

---

## 8. Structure de navigation des écrans

```mermaid
graph TD
    SPLASH([Lancement]) -->|"AuthService.isLoggedIn ?"| CHECK{Session\nactive ?}
    CHECK -->|Non| LOGIN["/login\nLoginScreen"]
    CHECK -->|Oui| DASH

    LOGIN -->|"Authentification réussie"| DASH["/dashboard\nDashboardScreen\n• Jauges temp/hum\n• Statut eau\n• Journal activité\n• Statut système"]

    DASH <-->|"Bottom Nav"| DEV["/device-detail\nDeviceDetailScreen\n• Liste ESP\n• Statut online\n• Firmware\n• Dernière connexion"]

    DASH <-->|"Bottom Nav"| ALERTS["/alerts\nAlertsScreen\n• Onglets: All/Critical\n  Warning/Resolved\n• Filtrage par sévérité"]

    DASH <-->|"Bottom Nav"| SETTINGS["/settings\nSettingsScreen\n[Admin uniquement]\n• Gestion utilisateurs\n• Gestion appareils\n• Attribution rôles"]

    ALERTS -->|"Voir analyse"| ANALYSIS["/alert-analysis\nAlertAnalysisScreen\n• Tendances\n• Statistiques\n• Graphiques"]

    DASH -->|"Historique"| HISTORY["/history\nHistoryScreen\n• Séries temporelles\n• Min/Max/Moy\n• SensorStats"]

    DASH -->|"Exporter"| EXPORT["/export\nExportScreen\n• Sélection plage date\n• Format: Excel/PDF\n• Partage natif"]

    style LOGIN fill:#1A2332,color:#F1F5F9
    style DASH fill:#1A2332,color:#F1F5F9
    style DEV fill:#1A2332,color:#F1F5F9
    style ALERTS fill:#1A2332,color:#F1F5F9
    style SETTINGS fill:#1A2332,color:#F1F5F9
    style ANALYSIS fill:#1A2332,color:#F1F5F9
    style HISTORY fill:#1A2332,color:#F1F5F9
    style EXPORT fill:#1A2332,color:#F1F5F9
```

---

## 9. Moteur XAI embarqué — pipeline complet

```mermaid
flowchart LR
    subgraph BUFFER["Buffer circulaire (WINDOW=5)"]
        B1["buf_t\n[t-4, t-3, t-2, t-1, t]"]
        B2["buf_h\n[h-4, h-3, h-2, h-1, h]"]
    end

    subgraph FEATURES["Extraction de features"]
        TR_T["_trend(buf_t)\n= (t - t-4) / 5\n→ pente °C/cycle"]
        TR_H["_trend(buf_h)\n→ pente %/cycle"]
        ZS["_zscore(val, buf)\n= (val - mean) / std\n→ anomalie si |z| >= 2"]
        NM["_norm(val, lo, hi)\n→ 0.0 – 1.0"]
    end

    subgraph SCORE["Score de risque"]
        RS["risk_score()\n0.40 × norm(T, 32, 42)\n+ 0.20 × norm(H, écarts)\n+ 0.20 × water\n+ 0.20 × norm(trend_t, 0, 2)\n────────────────\n→ score 0.0 – 1.0"]
        LV["level\nscore >= 0.7 → critique\nscore >= 0.4 → warning\nscore  < 0.4 → ok"]
    end

    subgraph EXPLAIN["Génération explication"]
        EX["explain()\nRègles ordonnées par priorité:\n1. T > CRITICAL → 'T=X CRITIQUE (+Y/seuil)'\n2. T > WARNING  → 'T=X avertissement'\n3. trend_t > 0.5 → 'hausse +X/cycle'\n4. H < HUM_LOW  → 'H=X trop sec'\n5. H > HUM_HIGH → 'H=X trop humide'\n6. water = 1    → 'FUITE detectee'\n7. T>warn & H>70 → 'condensation'\n→ join(parts, ', ')"]
    end

    subgraph OUTPUT["Sortie JSON /data"]
        OUT['"xai": {\n  "score": 0.72,\n  "level": "warning",\n  "reason": "T=35C avertissement,\n   hausse +1.2/cycle"\n}']
    end

    BUFFER --> FEATURES
    FEATURES --> SCORE
    RS --> LV
    LV --> EXPLAIN
    SCORE --> EXPLAIN
    EXPLAIN --> OUTPUT
```

---

## 10. Seuils et niveaux d'alerte

```mermaid
graph LR
    subgraph TEMP["Température (°C)"]
        T1["< 18°C\n❄️ Trop froid"]
        T2["18 – 27°C\n✅ Normal"]
        T3["27 – 32°C\n⚠️ Attention"]
        T4["32 – 38°C\n🔶 Warning"]
        T5["> 38°C\n🔴 Critique"]
        T1 --> T2 --> T3 --> T4 --> T5
    end

    subgraph HUM["Humidité (%)"]
        H1["< 20%\n🔴 Trop sec\nhumidity_low"]
        H2["20 – 80%\n✅ Normal"]
        H3["> 80%\n🔴 Trop humide\nhumidity_high"]
        H1 --> H2 --> H3
    end

    subgraph WATER["Niveau d'eau"]
        W1["0 – 70%\n✅ Normal"]
        W2["> 70%\n🔴 Critique\nwater_high"]
        W3["Pin D5 = HIGH\n🔴 Fuite détectée\nwater_leak"]
        W1 --> W2
        W3
    end

    subgraph SEVERITY["Persistance SQLite"]
        CRIT["🔴 CRITIQUE\n→ Persisté SQLite\n→ Exportable"]
        WARN["🔶 WARNING\n→ Affiché uniquement\n→ Non persisté"]
        INFO["ℹ️ INFO\n→ Affiché uniquement\n→ Non persisté"]
    end

    T5 --> CRIT
    T4 --> WARN
    H1 --> CRIT
    H3 --> CRIT
    W2 --> CRIT
    W3 --> CRIT
```

---

## 11. Déploiement et infrastructure réseau

```mermaid
graph TB
    subgraph LOCAL_NETWORK["🌐 Réseau Local (Wi-Fi)"]
        subgraph IOT_DEVICE["Appareil IoT"]
            ESP_HW["ESP8266 NodeMCU\nIP: 192.168.11.174\nPort: 80"]
            DHT_HW["DHT11\nTemp & Hum"]
            WATER_HW["Capteur eau\nDigital"]
            DHT_HW --> ESP_HW
            WATER_HW --> ESP_HW
        end

        subgraph FLUTTER_DEVICE["Appareil mobile / desktop"]
            FLUTTER_APP["Application Flutter\nAndroid / iOS / Windows\n/ macOS / Linux"]
            SQLITE_FILE["dataguardian_v2.db\nfichier local SQLite"]
            EXPORT_FILE["Exports générés\n.xlsx / .pdf"]
            FLUTTER_APP --> SQLITE_FILE
            FLUTTER_APP --> EXPORT_FILE
        end

        ESP_HW <-->|"HTTP GET /data\n(toutes les 2 min)\nHTTP GET /health"| FLUTTER_APP
    end

    EXPORT_FILE -->|"share_plus\nPartage natif"| EXTERNAL["📧 Email / Messaging\n📁 Stockage local"]

    subgraph NO_CLOUD["❌ Pas de cloud"]
        NOTE["Firebase: Non\nCloud Backend: Non\nPush Notifications: Non\nExternal APIs: Non"]
    end
```

---

> **Résumé technique :**
> DataGuardian IoT est une application Flutter autonome (sans cloud) qui interroge périodiquement un ESP8266 via HTTP REST sur le réseau local. Le firmware est écrit en **MicroPython** et embarque un moteur **Explainable AI on-device** : fenêtre glissante de 5 mesures, calcul de tendance, score de risque pondéré (0.0–1.0) et génération d'une explication textuelle — le tout sans appel externe. Le champ `xai` est retourné directement dans la réponse `/data`. Seules les alertes critiques sont persistées dans SQLite. L'application supporte deux rôles (admin / responsable) et permet l'export des rapports en Excel ou PDF.
