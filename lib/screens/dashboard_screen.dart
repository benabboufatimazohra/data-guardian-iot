// lib/screens/dashboard_screen.dart
// Version finale — affiche température, humidité + niveau d'eau en temps réel

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/esp_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  EnvironmentData _envData = EnvironmentData.mock();
  bool  _isLoading   = true;
  bool  _isConnected = false;
  String? _errorMsg;

  StreamSubscription<EnvironmentData>? _dataSub;
  StreamSubscription<String>?          _errorSub;
  StreamSubscription<bool>?            _connSub;

  @override
  void initState() {
    super.initState();
    _dataSub = EspService.instance.dataStream.listen((data) {
      if (mounted) setState(() { _envData = data; _isLoading = false; _errorMsg = null; });
    });
    _errorSub = EspService.instance.errorStream.listen((err) {
      if (mounted) setState(() { _errorMsg = err; _isLoading = false; });
    });
    _connSub = EspService.instance.connectionStream.listen((c) {
      if (mounted) setState(() => _isConnected = c);
    });
    EspService.instance.startPolling();
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _errorSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await EspService.instance.fetchOnce();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière erreur réseau
              if (_errorMsg != null && !_isConnected) _ErrorBanner(message: _errorMsg!),

              // Carte statut global
              _SystemStatusCard(
                isConnected: _isConnected,
                lastUpdatedText: _envData.lastUpdatedText,
                hasAlerts: _envData.alerts.hasAnyAlert,
              ),
              const SizedBox(height: 24),

              _SectionHeader(icon: Icons.thermostat, label: 'Environmental Metrics'),
              const SizedBox(height: 12),

              _isLoading
                  ? _LoadingCards()
                  : _SensorGrid(data: _envData),

              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.history, label: 'Recent Activity'),
              const SizedBox(height: 12),
              _LiveActivityList(data: _envData),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 2) Navigator.pushNamed(context, '/alerts');
          if (i == 3) Navigator.pushNamed(context, '/settings');
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.9),
      elevation: 0,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(color: AppColors.border, height: 1),
      ),
      title: const Row(children: [
        Icon(Icons.dns, color: AppColors.primary, size: 22),
        SizedBox(width: 10),
        Text('Server Room A',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
      actions: [
        _ConnectionBadge(isConnected: _isConnected),
      ],
    );
  }
}

// ─── Badge ONLINE / OFFLINE ───────────────────────────────────────────────────
class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  const _ConnectionBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.emerald : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(isConnected ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1, color: color)),
      ]),
    );
  }
}

// ─── Bannière erreur ──────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off, color: AppColors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: const TextStyle(fontSize: 12, color: AppColors.red))),
      ]),
    );
  }
}

// ─── Carte statut système ─────────────────────────────────────────────────────
class _SystemStatusCard extends StatelessWidget {
  final bool isConnected;
  final String lastUpdatedText;
  final bool hasAlerts;
  const _SystemStatusCard({
    required this.isConnected, required this.lastUpdatedText, required this.hasAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = hasAlerts ? AppColors.red
        : isConnected ? AppColors.emerald : AppColors.orange;
    final statusText = hasAlerts ? 'ALERTE'
        : isConnected ? 'NORMAL' : 'HORS LIGNE';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 3),
                color: statusColor.withValues(alpha: 0.1),
              ),
              child: Icon(hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: statusColor, size: 40),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('OVERALL HEALTH', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
            const SizedBox(height: 4),
            const Text('System Status', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(children: [
              Text(statusText, style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w700, color: statusColor)),
              const SizedBox(width: 10),
              Text('MAJ : $lastUpdatedText',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/alerts'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('View Alerts',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 22),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
        color: AppColors.textPrimary)),
  ]);
}

// ─── Skeleton loader ──────────────────────────────────────────────────────────
class _LoadingCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(3, (_) => Container(
      height: 160, margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: const Center(child: CircularProgressIndicator(
          color: AppColors.primary, strokeWidth: 2)),
    )),
  );
}

// ─── Grille capteurs (Temp + Humid + Niveau eau) ──────────────────────────────
class _SensorGrid extends StatelessWidget {
  final EnvironmentData data;
  const _SensorGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final tempFill  = ((data.temperature - 18) / (27 - 18)).clamp(0.0, 1.0);
    final humFill   = ((data.humidity - 40) / (60 - 40)).clamp(0.0, 1.0);
    final waterFill = (data.waterLevelPercent / 100.0).clamp(0.0, 1.0);

    final tempColor = data.alerts.tempCritical ? AppColors.red
        : data.alerts.tempWarning ? AppColors.orange : AppColors.primary;
    final waterColor = data.alerts.waterHigh ? AppColors.red
        : data.waterLevelPercent > 50 ? AppColors.orange : AppColors.sky;

    return Column(children: [
      // Température
      SensorGaugeCard(
        label: 'Temperature',
        value: '${data.temperature.toStringAsFixed(1)}°C',
        status: data.alerts.tempCritical ? 'Critical'
            : data.alerts.tempWarning ? 'Warning' : 'Optimal',
        rangeText: 'Range: 18°C – 27°C',
        gaugeColor: tempColor,
        fillPercent: tempFill,
      ),
      const SizedBox(height: 12),

      // Humidité
      SensorGaugeCard(
        label: 'Humidity',
        value: '${data.humidity.toStringAsFixed(0)}%',
        status: data.alerts.humidityLow ? 'Low'
            : data.alerts.humidityHigh ? 'High' : 'Normal',
        rangeText: 'Range: 40% – 60%',
        gaugeColor: AppColors.sky,
        fillPercent: humFill,
      ),
      const SizedBox(height: 12),

      // Niveau d'eau — carte personnalisée avec jauge verticale
      _WaterLevelCard(
        levelPercent: data.waterLevelPercent,
        levelRaw:     data.waterLevelRaw,
        isAlert:      data.alerts.waterHigh,
        color:        waterColor,
        fillPercent:  waterFill,
      ),
    ]);
  }
}

// ─── Carte niveau d'eau avec jauge verticale ──────────────────────────────────
class _WaterLevelCard extends StatelessWidget {
  final double levelPercent;
  final int    levelRaw;
  final bool   isAlert;
  final Color  color;
  final double fillPercent;

  const _WaterLevelCard({
    required this.levelPercent, required this.levelRaw,
    required this.isAlert,      required this.color,
    required this.fillPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Jauge verticale type "tube"
          SizedBox(
            width: 60, height: 120,
            child: CustomPaint(
              painter: _WaterTubePainter(fill: fillPercent, color: color),
              child: Center(
                child: Text(
                  '${levelPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAlert ? 'Niveau Élevé !' : 'Niveau Normal',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            'Valeur brute ADC : $levelRaw / 1023',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Dessine un tube rempli d'eau
class _WaterTubePainter extends CustomPainter {
  final double fill;  // 0.0 – 1.0
  final Color  color;
  const _WaterTubePainter({required this.fill, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(r),
    );

    // Fond (tube vide)
    canvas.drawRRect(rect, Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.fill);

    // Remplissage proportionnel au niveau
    final fillHeight = size.height * fill;
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight),
      Radius.circular(r),
    );
    canvas.drawRRect(fillRect, Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill);

    // Contour
    canvas.drawRRect(rect, Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_WaterTubePainter old) => old.fill != fill || old.color != color;
}

// ─── Liste d'activité live ────────────────────────────────────────────────────
class _LiveActivityList extends StatelessWidget {
  final EnvironmentData data;
  const _LiveActivityList({required this.data});

  @override
  Widget build(BuildContext context) {
    final tempColor  = data.alerts.tempCritical ? AppColors.red
        : data.alerts.tempWarning ? AppColors.orange : AppColors.emerald;
    final waterColor = data.alerts.waterHigh ? AppColors.red : AppColors.sky;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        ActivityListItem(
          icon: Icons.thermostat,
          iconColor:   tempColor,
          iconBgColor: tempColor.withValues(alpha: 0.1),
          title:    'Température : ${data.temperature.toStringAsFixed(1)}°C',
          subtitle: '${data.deviceId} · ${data.lastUpdatedText}',
        ),
        const Divider(color: AppColors.border, height: 1),
        ActivityListItem(
          icon: Icons.water_drop_outlined,
          iconColor:   AppColors.sky,
          iconBgColor: AppColors.sky.withValues(alpha: 0.1),
          title:    'Humidité : ${data.humidity.toStringAsFixed(0)}%',
          subtitle: '${data.deviceId} · ${data.lastUpdatedText}',
        ),
        const Divider(color: AppColors.border, height: 1),
        ActivityListItem(
          icon: data.alerts.waterHigh ? Icons.water_damage : Icons.water,
          iconColor:   waterColor,
          iconBgColor: waterColor.withValues(alpha: 0.1),
          title:    'Niveau eau : ${data.waterLevelPercent.toStringAsFixed(0)}% (ADC: ${data.waterLevelRaw})',
          subtitle: '${data.deviceId} · ${data.lastUpdatedText}',
        ),
      ]),
    );
  }
}

