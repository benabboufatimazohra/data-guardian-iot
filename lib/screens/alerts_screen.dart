import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 3: AlertsScreen
/// ─────────────────────────────────────────────────────────────────────────────
///
/// WIDGET TREE:
/// Scaffold
/// ├── AppBar  ← "System Alerts" + blinking notification bell
/// ├── body: Column
/// │   ├── _FilterTabBar        ← All / Critical / Warning / Resolved tabs
/// │   └── Expanded
/// │       └── ListView
/// │           ├── _SectionLabel "Critical Priority"
/// │           ├── AlertCard (critical)
/// │           ├── _SectionLabel "Warning Status"
/// │           ├── AlertCard (warning)
/// │           ├── _SectionLabel "Earlier Today"
/// │           └── _ResolvedCard
/// └── bottomNavigationBar: AppBottomNavBar (Alerts tab active)
///
/// KEY CONCEPTS IN THIS SCREEN:
///
/// 1. Filter tabs — we track which tab is selected with an int _selectedTab.
///    setState() re-filters the alert list when a tab changes.
///
/// 2. AlertCard receives a callback (onDismiss) that removes the alert from
///    the list. This is like event delegation in JavaScript:
///    ```javascript
///    DOM code: element.addEventListener('click', handler)
///    Flutter: onPressed: () { setState(() { _alerts.remove(alert); }); }
///    ```
///
/// 3. WHERE API CALL GOES: initState() calls _fetchAlerts().
///    The API returns a JSON array, which gets parsed into `List<AlertModel>`.
///    setState updates the list and Flutter re-renders the ListView.
/// ─────────────────────────────────────────────────────────────────────────────
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _selectedTab = 0; // 0=All, 1=Critical, 2=Warning, 3=Resolved
  bool _isLoading = false;

  /// STATE: The alerts list. API data goes here.
  final List<AlertModel> _allAlerts = [
    AlertModel(
      id: '1',
      severity: AlertSeverity.critical,
      title: 'High Temperature Detected - 35.2°C',
      deviceId: 'ESP8266-01',
      location: 'Rack A-04',
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    AlertModel(
      id: '2',
      severity: AlertSeverity.warning,
      title: 'Humidity Threshold Near',
      deviceId: 'ESP8266-04',
      location: 'Rack C-12',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AlertModel(
      id: '3',
      severity: AlertSeverity.info,
      title: 'Network Latency Spike Resolved',
      deviceId: 'Gateway-02',
      location: 'Node Gateway-02',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isResolved: true,
    ),
  ];

  /// Filtered list based on selected tab
  List<AlertModel> get _filteredAlerts {
    switch (_selectedTab) {
      case 1: return _allAlerts.where((a) => a.severity == AlertSeverity.critical).toList();
      case 2: return _allAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
      case 3: return _allAlerts.where((a) => a.isResolved).toList();
      default: return _allAlerts;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  /// API CALL: Fetch alerts from your backend
  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);

    // ─── API call goes here ─────────────────────────────────────────────
    // final response = await http.get(
    //   Uri.parse('https://your-api.com/api/v1/alerts'),
    //   headers: {'Authorization': 'Bearer $token'},
    // );
    //
    // if (response.statusCode == 200) {
    //   final List<dynamic> jsonList = jsonDecode(response.body);
    //   setState(() {
    //     _allAlerts = jsonList.map((j) => AlertModel.fromJson(j)).toList();
    //   });
    // }
    // ───────────────────────────────────────────────────────────────────

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isLoading = false);
  }

  /// Dismiss an alert — removes it from the list
  /// In production: also call DELETE /api/v1/alerts/{id}
  void _dismissAlert(String alertId) {
    setState(() {
      _allAlerts.removeWhere((a) => a.id == alertId);
    });
  }

  /// Show AI explanation for an alert (placeholder for your LLM integration)
  void _explainAlert(AlertModel alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExplainBottomSheet(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final criticalAlerts = _filteredAlerts.where((a) => a.severity == AlertSeverity.critical && !a.isResolved).toList();
    final warningAlerts = _filteredAlerts.where((a) => a.severity == AlertSeverity.warning && !a.isResolved).toList();
    final resolvedAlerts = _filteredAlerts.where((a) => a.isResolved).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.9),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.sensors, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Text(
              'System Alerts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
                /// Blinking red dot — HTML: animate-ping class
                if (_allAlerts.any((a) => !a.isResolved))
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _BlinkingDot(),
                  ),
              ],
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          /// Filter tab bar — sticky below the AppBar
          /// HTML: <nav class="sticky top-[73px] ...">
          _FilterTabBar(
            selectedIndex: _selectedTab,
            onChanged: (index) => setState(() => _selectedTab = index),
          ),

          /// Scrollable alerts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _fetchAlerts,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        /// Critical section
                        if (criticalAlerts.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'Critical Priority',
                            badgeText: '${criticalAlerts.length} Active',
                            badgeColor: AppColors.red,
                          ),
                          const SizedBox(height: 8),
                          ...criticalAlerts.map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AlertCard(
                              alert: alert,
                              onExplain: () => _explainAlert(alert),
                              onDismiss: () => _dismissAlert(alert.id),
                            ),
                          )),
                          const SizedBox(height: 16),
                        ],

                        /// Warning section
                        if (warningAlerts.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'Warning Status',
                            badgeText: '${warningAlerts.length} Active',
                            badgeColor: AppColors.orange,
                          ),
                          const SizedBox(height: 8),
                          ...warningAlerts.map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AlertCard(
                              alert: alert,
                              onExplain: () => _explainAlert(alert),
                              onDismiss: () => _dismissAlert(alert.id),
                            ),
                          )),
                          const SizedBox(height: 16),
                        ],

                        /// Resolved / Earlier today section
                        if (resolvedAlerts.isNotEmpty) ...[
                          const _SectionLabel(label: 'Earlier Today'),
                          const SizedBox(height: 8),
                          ...resolvedAlerts.map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ResolvedAlertCard(alert: alert),
                          )),
                        ],

                        if (_filteredAlerts.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48),
                              child: Text('No alerts', style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),

      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2, // Alerts tab is active
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: _FilterTabBar
// HTML: <nav class="..."><button class="border-b-2 border-primary">All Alerts</button>...
// ─────────────────────────────────────────────────────────────────────────────
class _FilterTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FilterTabBar({required this.selectedIndex, required this.onChanged});

  static const _tabs = ['All Alerts', 'Critical', 'Warning', 'Resolved'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // HTML: overflow-x: auto
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      /// HTML: border-b-2 border-primary (if active) or border-transparent
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: _SectionLabel
// HTML: <h2 class="text-xs font-bold uppercase tracking-widest text-slate-400">
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? badgeText;
  final Color? badgeColor;

  const _SectionLabel({required this.label, this.badgeText, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor!.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText!,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: badgeColor),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: _ResolvedAlertCard
// Dimmed card for past/resolved alerts — HTML: opacity-60
// ─────────────────────────────────────────────────────────────────────────────
class _ResolvedAlertCard extends StatelessWidget {
  final AlertModel alert;
  const _ResolvedAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6, // HTML: opacity-60
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.router_outlined, color: AppColors.textMuted, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alert.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      ),
                      Text(alert.relativeTime, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${alert.location} • 45ms average', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: _BlinkingDot
// HTML: <span class="animate-ping ...">  (Tailwind's ping animation)
// Flutter: Uses an AnimationController to pulse opacity
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    /// AnimationController drives the animation over time
    /// HTML: @keyframes ping { 0% { opacity: 1; } 100% { opacity: 0; } }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true); // Repeats back and forth (like ping)

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose(); // Always dispose animation controllers!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: _ExplainBottomSheet
// A modal bottom sheet explaining the alert — like a mobile popup
// HTML: would be a modal <dialog> or overlay div
// ─────────────────────────────────────────────────────────────────────────────
class _ExplainBottomSheet extends StatelessWidget {
  final AlertModel alert;
  const _ExplainBottomSheet({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('AI Explanation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'This alert was triggered because the sensor reading exceeded the configured threshold. '
            'High temperatures in server racks can lead to hardware throttling, reduced lifespan, '
            'or unexpected shutdowns. Immediate cooling action is recommended.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Got it', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
