import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── App Colors (inline for self-contained file) ────────────────────────────
const _bgDark = Color(0xFF101722);
const _surface = Color(0xFF1A2332);
const _surfaceLight = Color(0xFF222D3D);
const _border = Color(0xFF2A3547);
const _primary = Color(0xFF3C83F6);
const _emerald = Color(0xFF10B981);
const _textPrimary = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF64748B);

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 4: DeviceDetailScreen  (ESP8266 Device Page)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// WIDGET TREE:
/// Scaffold
/// ├── AppBar  ← back button + device name + blinking dot + settings icon
/// ├── body: SingleChildScrollView
/// │   └── Column
/// │       ├── _DeviceInfoCard       ← firmware version + IP
/// │       ├── _LastUpdateRow        ← "Last Update: Today, 14:32:45"
/// │       ├── _LiveSensorsSection   ← 2-column grid: temp + humidity mini-cards
/// │       ├── _ConnectivityChart    ← bar chart (drawn with CustomPaint)
/// │       └── _ThresholdSection     ← toggle rows for each alert rule
/// └── bottomNavigationBar: _DeviceBottomNav
///
/// KEY LEARNING — 2-Column Grid:
///   HTML: <div class="grid grid-cols-2 gap-4">
///   Flutter: Row with two Expanded children
///   We DON'T use GridView here because we have exactly 2 fixed items.
///   GridView is better when you have a dynamic list of many items.
///
/// KEY LEARNING — Toggle Switch (Flutter built-in):
///   HTML fakes a toggle with a div + absolute positioned dot.
///   Flutter has a real Switch widget with built-in animation.
///   We store the toggle state in a StatefulWidget using setState().
/// ─────────────────────────────────────────────────────────────────────────────
class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  int _navIndex = 0;

  // Toggle states — these are the "state" for the threshold switches
  // When the user taps, setState() flips the bool and Flutter re-renders the Switch
  bool _criticalTempEnabled = true;
  bool _lowHumidityEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device info card
            _DeviceInfoCard(),
            // Last update row
            _LastUpdateRow(),
            // Live sensors 2-column grid
            _LiveSensorsSection(),
            // Connectivity bar chart
            _ConnectivityChart(),
            // Threshold toggle rows
            _ThresholdSection(
              criticalEnabled: _criticalTempEnabled,
              humidityEnabled: _lowHumidityEnabled,
              onCriticalChanged: (val) => setState(() => _criticalTempEnabled = val),
              onHumidityChanged: (val) => setState(() => _lowHumidityEnabled = val),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _DeviceBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 2) Navigator.pushReplacementNamed(context, '/history');
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _bgDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _textSecondary),
        /// Pop goes back to the previous screen — like browser back button
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESP8266-01-A42',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          Row(
            children: [
              // Blinking green dot — StatefulWidget handles animation
              _BlinkingConnectedDot(),
              const SizedBox(width: 6),
              const Text(
                'CONNECTED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _emerald,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: _textPrimary),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(color: _border, height: 1),
      ),
    );
  }
}

// ─── Device Info Card ─────────────────────────────────────────────────────────
/// HTML: <div class="bg-slate-900 rounded-xl p-4 flex items-center gap-4">
class _DeviceInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Icon container — HTML: <div class="bg-primary/10 rounded-lg p-3">
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.router, color: _primary, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Firmware Version', style: TextStyle(fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 2),
                const Text(
                  'v2.0.4 Build 8821',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
                ),
                const SizedBox(height: 4),
                const Text('IP: 192.168.1.104', style: TextStyle(fontSize: 11, color: _textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Last Update Row ──────────────────────────────────────────────────────────
/// HTML: <div class="flex items-center justify-between text-sm">
class _LastUpdateRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Last Update', style: TextStyle(fontSize: 13, color: _textSecondary)),
          const Text(
            'Today, 14:32:45',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primary),
          ),
        ],
      ),
    );
  }
}

// ─── Live Sensors Section ─────────────────────────────────────────────────────
/// HTML: <div class="grid grid-cols-2 gap-4">
/// Flutter: Row with two Expanded children — same effect as 2-column grid
class _LiveSensorsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Sensors',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'REAL-TIME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primary, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 2-column layout
          // HTML: grid-cols-2 = Flutter: Row with Expanded widgets
          Row(
            children: [
              Expanded(
                child: _SensorMiniCard(
                  icon: Icons.thermostat,
                  iconColor: Colors.orange,
                  label: 'Temperature',
                  value: '24.5°C',
                  delta: '+0.2°C',
                  deltaPositive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SensorMiniCard(
                  icon: Icons.water_drop_outlined,
                  iconColor: Colors.lightBlueAccent,
                  label: 'Humidity',
                  value: '48%',
                  delta: '-1%',
                  deltaPositive: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single live sensor mini-card
class _SensorMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String delta;
  final bool deltaPositive;

  const _SensorMiniCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 22),
              Text(
                delta,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: deltaPositive ? _emerald : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Connectivity Chart (Bar Chart using CustomPaint) ─────────────────────────
/// HTML uses divs with percentage heights as fake bars.
/// Flutter: CustomPaint draws real bars on a Canvas.
///
/// WHY CustomPaint here instead of a library?
///   For learning purposes — so you understand how charts work.
///   In production you'd use fl_chart or syncfusion_flutter_charts packages.
class _ConnectivityChart extends StatelessWidget {
  // Bar heights as percentages (0.0 to 1.0)
  static const _bars = [0.60, 0.65, 0.70, 0.62, 0.80, 0.75, 0.85, 0.90, 0.88, 0.95];
  static const _labels = ['13:45', '14:00', '14:15', '14:30', 'Now'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connectivity (Last Hour)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                // Bar chart area
                Expanded(
                  child: CustomPaint(
                    painter: _BarChartPainter(bars: _bars),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 8),
                // X-axis labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _labels.map((l) => Text(
                    l,
                    style: const TextStyle(fontSize: 9, color: _textMuted, fontWeight: FontWeight.w600),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the bar chart bars on a Canvas.
/// The bars get progressively more opaque (darker → brighter blue) from left to right.
class _BarChartPainter extends CustomPainter {
  final List<double> bars;
  const _BarChartPainter({required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    final count = bars.length;
    final gap = 4.0;
    final barWidth = (size.width - gap * (count - 1)) / count;

    for (int i = 0; i < count; i++) {
      // Opacity increases from left to right: 0.4 → 1.0
      final opacity = 0.4 + (i / (count - 1)) * 0.6;
      final paint = Paint()
        ..color = _primary.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      final barHeight = size.height * bars[i];
      final left = i * (barWidth + gap);
      final top = size.height - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.bars != bars;
}

// ─── Threshold Section ────────────────────────────────────────────────────────
/// HTML fakes toggle switches with CSS. Flutter has a built-in Switch widget.
///
/// Flutter Switch:
///   Switch(
///     value: _isEnabled,          // current state
///     onChanged: (newVal) { setState(() { _isEnabled = newVal; }); }
///   )
class _ThresholdSection extends StatelessWidget {
  final bool criticalEnabled;
  final bool humidityEnabled;
  final ValueChanged<bool> onCriticalChanged;
  final ValueChanged<bool> onHumidityChanged;

  const _ThresholdSection({
    required this.criticalEnabled,
    required this.humidityEnabled,
    required this.onCriticalChanged,
    required this.onHumidityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Configured Thresholds',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Edit', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ThresholdRow(
            iconBgColor: Colors.red.withOpacity(0.2),
            iconColor: Colors.redAccent,
            icon: Icons.warning_amber_rounded,
            title: 'Critical Temperature',
            subtitle: 'Alert if Temp > 35°C',
            isEnabled: criticalEnabled,
            onChanged: onCriticalChanged,
          ),
          const SizedBox(height: 8),
          _ThresholdRow(
            iconBgColor: Colors.amber.withOpacity(0.2),
            iconColor: Colors.amber,
            icon: Icons.water_drop_outlined,
            title: 'Low Humidity Warning',
            subtitle: 'Alert if Humidity < 20%',
            isEnabled: humidityEnabled,
            onChanged: onHumidityChanged,
          ),
        ],
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final Color iconBgColor;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _ThresholdRow({
    required this.iconBgColor,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6, // HTML: opacity-60 when disabled
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: _textSecondary)),
                ],
              ),
            ),
            // Flutter's built-in Switch replaces the HTML fake-toggle div
            Switch(
              value: isEnabled,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: _primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: _textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Nav (Device-specific) ────────────────────────────────────────────
class _DeviceBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DeviceBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.router, label: 'DEVICE'),
      _NavItem(icon: Icons.notifications_outlined, label: 'ALERTS'),
      _NavItem(icon: Icons.history, label: 'HISTORY'),
      _NavItem(icon: Icons.manage_accounts_outlined, label: 'PROFILE'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(items[i].icon, color: selected ? _primary : _textMuted, size: 26),
                const SizedBox(height: 2),
                Text(
                  items[i].label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selected ? _primary : _textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─── Blinking Connected Dot ───────────────────────────────────────────────────
class _BlinkingConnectedDot extends StatefulWidget {
  @override
  State<_BlinkingConnectedDot> createState() => _BlinkingConnectedDotState();
}

class _BlinkingConnectedDotState extends State<_BlinkingConnectedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: _emerald, shape: BoxShape.circle)),
    );
  }
}
