# ─────────────────────────────────────────────────────────────────────────────
# Dépendances à ajouter dans votre pubspec.yaml
# ─────────────────────────────────────────────────────────────────────────────
#
# Ajoutez ces lignes dans la section "dependencies:" de votre pubspec.yaml :
#
# dependencies:
#   flutter:
#     sdk: flutter
#
#   # HTTP pour appeler l'API de l'ESP8266
#   http: ^1.2.0
#
#   # Parsing JSON (déjà inclus dans Dart, pas besoin de package externe)
#   # dart:convert est natif
#
# ─────────────────────────────────────────────────────────────────────────────
# Ensuite dans le terminal :
#   flutter pub get
# ─────────────────────────────────────────────────────────────────────────────
#
# ANDROID — Permissions réseau :
# Ajoutez dans android/app/src/main/AndroidManifest.xml, AVANT <application> :
#
#   <uses-permission android:name="android.permission.INTERNET"/>
#   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
#
# Pour HTTP (non-HTTPS) en Android 9+ :
# Dans android/app/src/main/AndroidManifest.xml, dans <application> :
#   android:usesCleartextTraffic="true"
#
# ─────────────────────────────────────────────────────────────────────────────
# iOS — Info.plist (si vous déployez sur iPhone) :
# Ajoutez dans ios/Runner/Info.plist :
#
#   <key>NSAppTransportSecurity</key>
#   <dict>
#     <key>NSAllowsArbitraryLoads</key>
#     <true/>
#   </dict>
# ─────────────────────────────────────────────────────────────────────────────

# Structure des fichiers à créer/modifier :
#
# lib/
# ├── config/
# │   └── api_config.dart          ← NOUVEAU : IP de l'ESP8266
# ├── services/
# │   └── esp_service.dart         ← NOUVEAU : polling HTTP
# ├── models/
# │   └── models.dart              ← MODIFIÉ : fromJson mis à jour
# └── screens/
#     └── dashboard_screen.dart    ← MODIFIÉ : données en temps réel
