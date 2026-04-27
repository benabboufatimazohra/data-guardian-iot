import 'dart:math' as math;
import 'package:flutter/material.dart';

const _bgDark = Color(0xFF101722);
const _surface = Color(0xFF1A2332);
const _border = Color(0xFF2A3547);
const _primary = Color(0xFF3C83F6);
const _emerald = Color(0xFF10B981);
const _textPrimary = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF64748B);

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 5: HistoryScreen (History & Analytics)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// WIDGET TREE:
/// Scaffold
/// ├── AppBar  ← back + title + "Last 24 Hours" date chip
/// ├── _PeriodTabBar  ← 24H / 7D / 30D tabs (sticky)
/// └── body: SingleChildScrollView
///     └── Column
///         ├── _TrendChart (temperature, blue)
///         ├── _TrendChart (humidity, green)
///         └── _AlertFrequencyChart (bar chart)
///
/// KEY LEARNING — Area Charts (SVG → Flutter CustomPaint):
///   HTML uses SVG <path> with a gradient fill to make area charts.
///   Flutter: We use CustomPaint with a Path object.
///
///   SVG path command "M0 100 Q 50 20, 100 80" (quadratic bezier curve)
///   Flutter equivalent: path.quadraticBezierTo(cpX, cpY, x, y)
///
///   The trick is:
///   1. Draw the line (stroke path)
///   2. Connect the end points down to the bottom to close the shape
///   3. Fill with a LinearGradient shader
///
/// KEY LEARNING — Empty Charts (No Data):
///   Since you have NO backend yet, the charts show example curves.
///   When your API is ready, replace the mock data points with real values.
///   The chart widget accepts a List<double> so you just pass API values in.
/// ─────────────────────────────────────────────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedPeriod = 0; // 0=24H, 1=7D, 2=30D
  int _navIndex = 1; // Analytics tab active

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // Period tab bar — sticky below AppBar
          _PeriodTabBar(
            selected: _selectedPeriod,
            onChanged: (i) => setState(() => _selectedPeriod = i),
          ),
          // Scrollable charts
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                children: [
                  // Temperature area chart
                  _TrendChartCard(
                    title: 'Temperature Trend (°C)',
                    currentValue: '22.5°C',
                    changePercent: '-1.2%',
                    isPositive: false,
                    chartColor: _primary,
                    // Mock data points (normalized 0.0–1.0, will come from API)
                    dataPoints: const [0.67, 0.13, 0.53, 0.40, 0.80, 0.20, 0.60],
                    xLabels: const ['00:00', '06:00', '12:00', '18:00', '23:59'],
                  ),
                  const SizedBox(height: 16),
                  // Humidity area chart
                  _TrendChartCard(
                    title: 'Humidity Trend (%)',
                    currentValue: '45%',
                    changePercent: '+2.4%',
                    isPositive: true,
                    chartColor: _emerald,
                    dataPoints: const [0.80, 0.73, 0.67, 0.33, 0.73, 0.20, 0.80],
                    xLabels: const ['00:00', '06:00', '12:00', '18:00', '23:59'],
                  ),
                  const SizedBox(height: 16),
                  // Alert frequency bar chart
                  _AlertFrequencyCard(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _HistoryBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 0) Navigator.pushReplacementNamed(context, '/dashboard');
          if (i == 3) Navigator.pushReplacementNamed(context, '/settings');
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
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'History & Analytics',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
      ),
      actions: [
        // Date range chip — HTML: <button class="px-3 py-2 bg-slate-800 rounded-lg">
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.calendar_today_outlined, color: _textPrimary, size: 14),
            label: const Text('Last 24 Hours', style: TextStyle(color: _textPrimary, fontSize: 13)),
            onPressed: () {},
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(color: _border, height: 1),
      ),
    );
  }
}

// ─── Period Tab Bar (24H / 7D / 30D) ─────────────────────────────────────────
/// HTML: <nav class="flex border-b"><button class="flex-1 border-b-2 border-primary">
class _PeriodTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _PeriodTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = ['24H', '7D', '30D'];
    return Container(
      decoration: const BoxDecoration(
        color: _bgDark,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? _primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _primary : _textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Trend Chart Card ─────────────────────────────────────────────────────────
/// Contains the header (title + current value) and the SVG-like area chart.
class _TrendChartCard extends StatelessWidget {
  final String title;
  final String currentValue;
  final String changePercent;
  final bool isPositive;
  final Color chartColor;
  final List<double> dataPoints; // Normalized 0.0–1.0
  final List<String> xLabels;

  const _TrendChartCard({
    required this.title,
    required this.currentValue,
    required this.changePercent,
    required this.isPositive,
    required this.chartColor,
    required this.dataPoints,
    required this.xLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: _textSecondary)),
              // Change badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? _emerald : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive ? _emerald : Colors.redAccent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      changePercent,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? _emerald : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currentValue,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          const SizedBox(height: 16),
          // Chart area — CustomPaint draws the area chart
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _AreaChartPainter(points: dataPoints, color: chartColor),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: xLabels
                .map((l) => Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _textMuted)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Draws an area chart using Bezier curves — equivalent to SVG <path> with quadratic curves.
///
/// Steps:
/// 1. Convert normalized data points to canvas coordinates
/// 2. Draw a smooth curve through the points (using cubicTo for smooth curves)
/// 3. Close the path down to the bottom
/// 4. Fill with gradient shader
/// 5. Draw the stroke line on top
class _AreaChartPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _AreaChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final n = points.length;
    // Convert normalized points to pixel coordinates
    // y is inverted: 0.0 = top of chart = max value
    final coords = List.generate(n, (i) {
      final x = size.width * i / (n - 1);
      final y = size.height * (1 - points[i]);
      return Offset(x, y);
    });

    // Build the smooth curve path
    final linePath = Path()..moveTo(coords[0].dx, coords[0].dy);
    for (int i = 1; i < n; i++) {
      // Use cubic bezier for smooth S-curve between points
      final prev = coords[i - 1];
      final curr = coords[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    // Build the filled area path (closes the shape at the bottom)
    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath
      ..lineTo(coords.last.dx, size.height)
      ..lineTo(coords.first.dx, size.height)
      ..close();

    // Fill with gradient (opaque at top → transparent at bottom)
    // HTML: <linearGradient><stop offset="0%" stop-opacity="0.3"/><stop offset="100%" stop-opacity="0"/>
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, gradientPaint);

    // Draw the stroke line on top
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, strokePaint);
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) => old.points != points || old.color != color;
}

// ─── Alert Frequency Bar Chart ────────────────────────────────────────────────
class _AlertFrequencyCard extends StatelessWidget {
  static const _bars = [0.20, 0.45, 0.85, 0.60, 0.30, 0.50, 0.15];
  static const _labels = ['00h', '04h', '08h', '12h', '16h', '20h', '24h'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alert Frequency by Hour',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_bars.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: _bars[i],
                              child: Container(
                                decoration: BoxDecoration(
                                  // High bars get red tint
                                  color: _bars[i] > 0.7
                                      ? Colors.redAccent.withOpacity(0.5)
                                      : _border,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_labels[i], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _textMuted)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────
class _HistoryBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _HistoryBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_outlined, Icons.dashboard, 'DASHBOARD'),
      (Icons.analytics_outlined, Icons.analytics, 'ANALYTICS'),
      (Icons.router_outlined, Icons.router, 'DEVICES'),
      (Icons.settings_outlined, Icons.settings, 'SETTINGS'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: _bgDark,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: List.generate(items.length, (i) {
          final sel = i == currentIndex;
          final (outIcon, filledIcon, label) = items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sel ? filledIcon : outIcon, color: sel ? _primary : _textMuted, size: 24),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sel ? _primary : _textMuted, letterSpacing: 0.5)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}