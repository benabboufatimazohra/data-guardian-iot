# DataGuardian IoT — Flutter App
## Complete conversion from HTML/CSS → Flutter (Dart)

---

## 📁 Project Structure

```
lib/
├── main.dart                    ← App entry point + route definitions
├── theme/
│   └── app_colors.dart          ← Color constants, text styles, spacing (like CSS variables)
├── models/
│   └── models.dart              ← Data classes (EnvironmentData, AlertModel, etc.)
├── widgets/
│   └── widgets.dart             ← Reusable components (SensorGaugeCard, AlertCard, etc.)
└── screens/
    ├── login_screen.dart        ← Screen 1: Login
    ├── dashboard_screen.dart    ← Screen 2: Main dashboard
    └── alerts_screen.dart       ← Screen 3: Alerts list
```

---

## 🧠 HTML → Flutter Conversion Cheat Sheet

| HTML / CSS                          | Flutter Widget / Property               |
|-------------------------------------|-----------------------------------------|
| `<div>`                             | `Container` or `SizedBox`               |
| `<p>`, `<h1>`, `<span>`             | `Text`                                  |
| `<button>`                          | `ElevatedButton`, `TextButton`, `OutlinedButton` |
| `<input type="text">`               | `TextField`                             |
| `<input type="checkbox">`           | `Checkbox`                              |
| `display: flex; flex-direction: row`| `Row`                                   |
| `display: flex; flex-direction: col`| `Column`                                |
| `flex: 1`                           | `Expanded`                              |
| `gap: 16px`                         | `SizedBox(width/height: 16)`            |
| `padding: 16px`                     | `Padding(padding: EdgeInsets.all(16))`  |
| `margin: 16px`                      | `Container(margin: EdgeInsets.all(16))` |
| `align-items: center`               | `crossAxisAlignment: CrossAxisAlignment.center` |
| `justify-content: space-between`    | `mainAxisAlignment: MainAxisAlignment.spaceBetween` |
| `position: relative + absolute`     | `Stack` + `Positioned`                  |
| `overflow: scroll`                  | `SingleChildScrollView`                 |
| `border-radius: 12px`               | `BorderRadius.circular(12)`             |
| `box-shadow`                        | `BoxShadow` inside `BoxDecoration`      |
| `opacity: 0.6`                      | `Opacity(opacity: 0.6, child: ...)`     |
| `<nav>` bottom fixed                | `Scaffold.bottomNavigationBar`          |
| `<header>` sticky                   | `Scaffold.appBar`                       |
| `<svg>`                             | `CustomPaint` with `CustomPainter`      |
| `:root { --color: ... }`            | `class AppColors { static const ... }`  |
| `@keyframes` animations             | `AnimationController` + `Tween`         |
| `background: linear-gradient(...)`  | `LinearGradient` inside `BoxDecoration` |

---

## 📐 Widget Tree Overview

### Screen 1 — Login
```
Scaffold
└── Stack
    ├── _TechPatternBackground (CustomPaint dot grid)
    └── SafeArea
        └── Column
            ├── _BrandHeader (logo + status)
            └── SingleChildScrollView
                └── _LoginCard
                    ├── _LockIconSection
                    ├── Text "Secure Access"
                    ├── _InputField (email)
                    ├── _PasswordField (password + toggle)
                    ├── Checkbox (remember device)
                    ├── ElevatedButton (Sign In)
                    ├── _OrDivider
                    ├── Row
                    │   ├── _SsoButton (Google)
                    │   └── _SsoButton (SAML SSO)
                    └── _FooterLinks
```

### Screen 2 — Dashboard
```
Scaffold
├── AppBar (Server Room A + Online badge)
├── body: SingleChildScrollView + RefreshIndicator
│   └── Column
│       ├── _SystemStatusCard
│       ├── _SectionHeader "Environmental Metrics"
│       ├── _EnvironmentGrid
│       │   ├── SensorGaugeCard (Temperature)
│       │   ├── SensorGaugeCard (Humidity)
│       │   └── WaterLeakCard
│       ├── _SectionHeader "Recent Activity"
│       └── _ActivityList
│           └── ListView.separated
│               └── ActivityListItem × 3
└── bottomNavigationBar: AppBottomNavBar
```

### Screen 3 — Alerts
```
Scaffold
├── AppBar (System Alerts + _BlinkingDot)
├── body: Column
│   ├── _FilterTabBar (All / Critical / Warning / Resolved)
│   └── Expanded > ListView
│       ├── _SectionLabel "Critical Priority"
│       ├── AlertCard (critical)
│       ├── _SectionLabel "Warning Status"
│       ├── AlertCard (warning)
│       ├── _SectionLabel "Earlier Today"
│       └── _ResolvedAlertCard
└── bottomNavigationBar: AppBottomNavBar
```

---

## ⚡ API Integration Guide

### Where to Place API Calls

```dart
class _DashboardScreenState extends State<DashboardScreen> {

  @override
  void initState() {
    super.initState();
    _fetchEnvironmentData();  // ← Runs ONCE when screen first appears
    
    // Optional: Poll every 30 seconds for live updates
    // Timer.periodic(Duration(seconds: 30), (_) => _fetchEnvironmentData());
  }

  Future<void> _fetchEnvironmentData() async {
    setState(() => _isLoading = true);  // Show loading spinner
    
    final response = await http.get(
      Uri.parse('https://your-api.com/api/v1/environment'),
    );
    
    final data = EnvironmentData.fromJson(jsonDecode(response.body));
    
    setState(() {        // ← This triggers a UI rebuild with new data
      _envData = data;
      _isLoading = false;
    });
  }
}
```

### How setState() Works (Step by Step)

```
1. User opens Dashboard screen
2. initState() is called → _fetchEnvironmentData() starts
3. setState(() { _isLoading = true }) → Flutter shows CircularProgressIndicator
4. API call completes with { "temperature": 28.5, "humidity": 52 }
5. setState(() { _envData = data; _isLoading = false })
   → Flutter calls build() again
   → SensorGaugeCard receives new temperature value
   → The number on screen changes from 24°C to 28.5°C
6. User sees updated data without doing anything
```

---

## 🔄 StatefulWidget vs StatelessWidget

| Use `StatelessWidget` when...         | Use `StatefulWidget` when...              |
|---------------------------------------|-------------------------------------------|
| Data never changes (static UI)        | Data changes over time (live sensor data) |
| Pure display (icons, labels, cards)   | User interacts (form input, tabs, toggle) |
| No API calls needed                   | API calls update the UI                   |
| Example: AlertCard, SensorGaugeCard   | Example: DashboardScreen, AlertsScreen    |

---

## 📦 Dependencies to add to pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0          # For API calls (like fetch() in JS)
  shared_preferences: ^2.2.0  # For storing auth token locally

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

---

## 🚀 Running the App

```bash
flutter pub get
flutter run
```
