# 🗺️ Complete Navigation Map — DataGuardian IoT

## All 7 Screens & Their Connections

```
┌─────────────────────────────────────────────────────────────────────┐
│                        APP NAVIGATION MAP                            │
└─────────────────────────────────────────────────────────────────────┘

/login  ──[Sign In button]──────────────────────► /dashboard
                                                       │
                          ┌────────────────────────────┤
                          │                            │
               [Devices tab]                  [View Full Report]
                          │                            │
                          ▼                            ▼
                    /device-detail              /history
                          │
               [History tab on device nav]
                          │
                          ▼
                       /history

/dashboard ──[Alerts tab]──────────────────────► /alerts
                                                    │
                                        [Explain button on alert card]
                                                    │
                                                    ▼
                                           /alert-analysis
                                                    │
                                          [Back arrow / pop]
                                                    │
                                                    ▼
                                                /alerts

/dashboard ──[Settings tab]────────────────────► /settings
                                                    │
                                           [Log Out button]
                                                    │
                              pushNamedAndRemoveUntil (clears all history)
                                                    │
                                                    ▼
                                                /login

/settings ──[Device Management row]────────────► /device-detail
```

---

## Button-by-Button Navigation Reference

| Screen | Element | What happens |
|--------|---------|--------------|
| Login | Sign In button | `pushReplacementNamed('/dashboard')` |
| Login | Google SSO | (placeholder — add OAuth) |
| Login | SAML SSO | (placeholder) |
| Dashboard | View Full Report | `pushNamed('/history')` |
| Dashboard | Devices tab | `pushNamed('/device-detail')` |
| Dashboard | Alerts tab | `pushNamed('/alerts')` |
| Dashboard | Settings tab | `pushNamed('/settings')` |
| Alerts | Explain button | `pushNamed('/alert-analysis')` |
| Alerts | Dismiss button | removes alert from list (setState) |
| Alerts | Dashboard tab | `pushReplacementNamed('/dashboard')` |
| Alert Analysis | ← back | `pop()` |
| Alert Analysis | Share icon | (placeholder — add share_plus package) |
| Device Detail | ← back | `pop()` |
| Device Detail | Settings icon | `pushNamed('/settings')` |
| Device Detail | History tab | `pushReplacementNamed('/history')` |
| History | ← back | `pop()` |
| History | Dashboard tab | `pushReplacementNamed('/dashboard')` |
| Settings | ← back | `pop()` |
| Settings | Device Management | `pushNamed('/device-detail')` |
| Settings | Log Out | `pushNamedAndRemoveUntil('/login', (_) => false)` |

---

## Flutter Navigation Methods Explained

### `Navigator.pushNamed(context, '/route')`
- Adds new screen ON TOP of current screen
- User can go back with ← button
- HTML equivalent: `history.pushState()` / `<a href="/route">`
- Use for: drilling into details (alerts → analysis)

### `Navigator.pop(context)`
- Removes current screen, goes back to previous
- HTML equivalent: `history.back()`
- Use for: back buttons, closing modals

### `Navigator.pushReplacementNamed(context, '/route')`
- Replaces current screen (no back button)
- HTML equivalent: `location.replace('/route')`
- Use for: tab navigation (you don't "go back" to a tab)

### `Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false)`
- Goes to /login AND removes ALL previous screens from memory
- HTML equivalent: `location.replace('/login')` after clearing session
- Use for: Log Out (user can't press back to get back in)

---

## How to Pass Data to Alert Analysis Screen

When you have real alerts, pass the alert ID in route arguments:

```dart
// In alerts_screen.dart — when user taps Explain:
Navigator.pushNamed(
  context,
  '/alert-analysis',
  arguments: {'alertId': alert.id, 'title': alert.title},
);

// In alert_analysis_screen.dart — to receive it:
@override
Widget build(BuildContext context) {
  final args = ModalRoute.of(context)!.settings.arguments
      as Map<String, dynamic>;
  final alertId = args['alertId'] as String;
  final title = args['title'] as String;
  // now use alertId to fetch details from API
}
```

---

## File Structure

```
lib/
├── main.dart                     ← Routes defined here
├── theme/
│   └── app_colors.dart           ← Colors, text styles (CSS variables)
├── models/
│   └── models.dart               ← Data classes (parse API JSON here)
├── widgets/
│   └── widgets.dart              ← Shared reusable widgets
└── screens/
    ├── login_screen.dart         ← Screen 1
    ├── dashboard_screen.dart     ← Screen 2
    ├── alerts_screen.dart        ← Screen 3
    ├── device_detail_screen.dart ← Screen 4
    ├── history_screen.dart       ← Screen 5
    ├── alert_analysis_screen.dart← Screen 6
    └── settings_screen.dart      ← Screen 7
```
