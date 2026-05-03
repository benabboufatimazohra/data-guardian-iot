// lib/screens/history_screen.dart
//
// ERREURS CORRIGÉES :
//   1. ambiguous_import SensorReading / SensorStats
//      → database_helper.dart contenait ces classes en double.
//        Solution : les supprimer de database_helper.dart (voir ce fichier).
//
//   2. duplicate_definition (HistoryScreen, _StatsRow, etc.)
//      → L'ancien fichier et le nouveau avaient été collés ensemble.
//        Solution : ce fichier est la seule version, l'ancien contenu est supprimé.
//
//   3. return_of_invalid_type dans _normalizeTemp() / _normalizeHumid()
//      → .map() sans type retourne List<dynamic>.
//        Solution : .map<double>(...) force le bon type de retour.
//
//   4. withOpacity() déprécié → remplacé par .withValues(alpha: ...)

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int  _selectedPeriod = 0;
  bool _isLoading      = true;

  List<SensorReading> _readings = [];
  SensorStats         _stats    = SensorStats.empty();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final hours = [24, 168, 720][_selectedPeriod];
    const espId = 'ESP8266-01';

    final readings = await DatabaseHelper.instance.getReadingsLastHours(espId, hours);
    final stats    = await DatabaseHelper.instance.getStats(espId: espId, hoursBack: hours);

    if (mounted) {
      setState(() {
        _readings  = readings;
        _stats     = stats;
        _isLoading = false;
      });
    }
  }

  List<double> _normalizeTemp() {
    if (_readings.isEmpty) return [0.5];
    final vals  = _readings.reversed.map((r) => r.temperature).toList();
    final range = (_stats.tempMax - _stats.tempMin).clamp(1.0, double.infinity);
    return vals.map<double>((v) => ((v - _stats.tempMin) / range).clamp(0.0, 1.0)).toList();
  }

  List<double> _normalizeHumid() {
    if (_readings.isEmpty) return [0.5];
    final vals  = _readings.reversed.map((r) => r.humidity).toList();
    final range = (_stats.humMax - _stats.humMin).clamp(1.0, double.infinity);
    return vals.map<double>((v) => ((v - _stats.humMin) / range).clamp(0.0, 1.0)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101722),
      appBar: _buildAppBar(context),
      body: Column(children: [
        _PeriodTabBar(
          selected:  _selectedPeriod,
          onChanged: (i) { setState(() => _selectedPeriod = i); _loadData(); },
        ),
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _readings.isEmpty
              ? const _EmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(children: [
                    _StatsRow(stats: _stats),
                    const SizedBox(height: 16),
                    _TrendChartCard(
                      title: 'Temperature (°C)',
                      currentValue: '${_stats.tempAvg.toStringAsFixed(1)}°C avg',
                      minValue: '${_stats.tempMin.toStringAsFixed(1)}°C',
                      maxValue: '${_stats.tempMax.toStringAsFixed(1)}°C',
                      chartColor: AppColors.primary,
                      dataPoints: _normalizeTemp(),
                      totalReadings: _stats.totalReadings,
                    ),
                    const SizedBox(height: 16),
                    _TrendChartCard(
                      title: 'Humidity (%)',
                      currentValue: '${_stats.humAvg.toStringAsFixed(0)}% avg',
                      minValue: '${_stats.humMin.toStringAsFixed(0)}%',
                      maxValue: '${_stats.humMax.toStringAsFixed(0)}%',
                      chartColor: AppColors.sky,
                      dataPoints: _normalizeHumid(),
                      totalReadings: _stats.totalReadings,
                    ),
                    const SizedBox(height: 16),
                    _LeakHistoryCard(readings: _readings),
                  ]),
                ),
        ),
      ]),
      bottomNavigationBar: AppBottomNavBar(currentIndex: 1, onTap: (_) {}),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    backgroundColor: const Color(0xFF101722),
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('History & Analytics',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 16),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.storage_outlined, color: AppColors.textPrimary, size: 14),
          label: Text('${_stats.totalReadings} records',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          onPressed: null,
        ),
      ),
    ],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(color: AppColors.border, height: 1),
    ),
  );
}

// ─── Stats summary row ────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final SensorStats stats;
  const _StatsRow({required this.stats});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _StatChip(
      label: 'Temp Max',
      value: '${stats.tempMax.toStringAsFixed(1)}°C',
      color: stats.tempMax > 35 ? AppColors.red : AppColors.primary,
    )),
    const SizedBox(width: 8),
    Expanded(child: _StatChip(
      label: 'Hum Avg',
      value: '${stats.humAvg.toStringAsFixed(0)}%',
      color: AppColors.sky,
    )),
    const SizedBox(width: 8),
    Expanded(child: _StatChip(
      label: 'Leaks',
      value: stats.hadLeak ? 'YES' : 'None',
      color: stats.hadLeak ? AppColors.red : AppColors.emerald,
    )),
  ]);
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]),
  );
}

// ─── Trend chart card ─────────────────────────────────────────────────────────
class _TrendChartCard extends StatelessWidget {
  final String title, currentValue, minValue, maxValue;
  final Color chartColor;
  final List<double> dataPoints;
  final int totalReadings;
  const _TrendChartCard({
    required this.title, required this.currentValue,
    required this.minValue, required this.maxValue,
    required this.chartColor, required this.dataPoints,
    required this.totalReadings,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Row(children: [
          _MiniChip('min $minValue', AppColors.textMuted),
          const SizedBox(width: 6),
          _MiniChip('max $maxValue', chartColor),
        ]),
      ]),
      const SizedBox(height: 4),
      Text(currentValue, style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 16),
      SizedBox(height: 120, child: CustomPaint(
        painter: _AreaChartPainter(points: dataPoints, color: chartColor),
        size: Size.infinite,
      )),
      const SizedBox(height: 8),
      Text('Based on $totalReadings readings',
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ]),
  );
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color  color;
  const _MiniChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

// ─── Leak history card ────────────────────────────────────────────────────────
class _LeakHistoryCard extends StatelessWidget {
  final List<SensorReading> readings;
  const _LeakHistoryCard({required this.readings});
  @override
  Widget build(BuildContext context) {
    final leakEvents = readings.where((r) => r.waterLeak).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.water_damage, color: AppColors.sky, size: 18),
          const SizedBox(width: 8),
          const Text('Water Leak Events',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          _MiniChip('${leakEvents.length} events',
              leakEvents.isEmpty ? AppColors.emerald : AppColors.red),
        ]),
        const SizedBox(height: 12),
        if (leakEvents.isEmpty)
          const Text('No leak events recorded.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted))
        else
          ...leakEvents.take(5).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                '${r.recordedAt.month}/${r.recordedAt.day} '
                '${r.recordedAt.hour.toString().padLeft(2, '0')}:'
                '${r.recordedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text('${r.waterPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.red,
                      fontWeight: FontWeight.w600)),
            ]),
          )),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.storage_outlined, color: AppColors.textMuted, size: 48),
      SizedBox(height: 12),
      Text('No data yet', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      SizedBox(height: 4),
      Text('Data will appear once the ESP is connected',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );
}

// ─── Period tab bar ───────────────────────────────────────────────────────────
class _PeriodTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _PeriodTabBar({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    const tabs = ['24H', '7D', '30D'];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101722),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: List.generate(tabs.length, (i) {
        final sel = i == selected;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(
              color: sel ? AppColors.primary : Colors.transparent, width: 2))),
            child: Text(tabs[i], textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: sel ? AppColors.primary : AppColors.textSecondary)),
          ),
        ));
      })),
    );
  }
}

// ─── Area chart painter ───────────────────────────────────────────────────────
class _AreaChartPainter extends CustomPainter {
  final List<double> points;
  final Color        color;
  const _AreaChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final n      = points.length;
    final coords = List.generate(n, (i) => Offset(
      size.width * i / (n - 1),
      size.height * (1 - points[i]),
    ));
    final linePath = Path()..moveTo(coords[0].dx, coords[0].dy);
    for (int i = 1; i < n; i++) {
      final cpX = (coords[i - 1].dx + coords[i].dx) / 2;
      linePath.cubicTo(cpX, coords[i - 1].dy, cpX, coords[i].dy,
          coords[i].dx, coords[i].dy);
    }
    final fillPath = Path()
      ..addPath(linePath, Offset.zero)
      ..lineTo(coords.last.dx, size.height)
      ..lineTo(coords.first.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);
    canvas.drawPath(linePath, Paint()
      ..color = color ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      old.points != points || old.color != color;
}
