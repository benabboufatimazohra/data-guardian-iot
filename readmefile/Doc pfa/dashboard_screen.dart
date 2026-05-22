// lib/screens/dashboard_screen.dart
//
// Modifications par rapport à la version originale :
//   ✓ Utilise EspService.instance pour le polling en temps réel
//   ✓ Affiche l'état de connexion (ONLINE / OFFLINE)
//   ✓ Génère des alertes automatiquement depuis les données ESP
//   ✓ Affiche "Il y a X secondes" pour la dernière mise à jour

import 'dart:async';
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
  bool _isLoading = true;
  bool _isConnected = false;
  String? _errorMessage;

  // Abonnements aux streams de EspService
  StreamSubscription<EnvironmentData>? _dataSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();

    // S'abonner aux données en temps réel
    _dataSub = EspService.instance.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _envData     = data;
          _isLoading   = false;
          _errorMessage = null;
        });
      }
    });

    // S'abonner aux erreurs réseau
    _errorSub = EspService.instance.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isLoading    = false;
        });
      }
    });

    // S'abonner à l'état de connexion
    _connectionSub = EspService.instance.connectionStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    // Démarrer le polling (5s d'intervalle, défini dans ApiConfig)
    EspService.instance.startPolling();
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
    // NE PAS appeler stopPolling() ici — d'autres screens en ont besoin
    super.dispose();
  }

  // Refresh manuel (pull-to-refresh)
  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await EspService.instance.fetchOnce();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withOpacity(0.9),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.dns, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Text('Server Room A',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
        actions: [
          // Badge ONLINE / OFFLINE selon la connexion ESP
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_isConnected ? AppColors.emerald : AppColors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: (_isConnected ? AppColors.emerald : AppColors.red).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? AppColors.emerald : AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1,
                    color: _isConnected ? AppColors.emerald : AppColors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

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
              // ── Bannière d'erreur si ESP non joignable ──────────────────
              if (_errorMessage != null && !_isConnected)
                _ErrorBanner(message: _errorMessage!),

              // ── Carte de statut système ─────────────────────────────────
              _SystemStatusCard(
                isConnected: _isConnected,
                lastUpdatedText: _envData.lastUpdatedText,
                hasAlerts: _envData.alerts.hasAnyAlert || _envData.waterLeakDetected,
              ),
              const SizedBox(height: 24),

              // ── Métriques environnementales ─────────────────────────────
              _SectionHeader(icon: Icons.thermostat, label: 'Environmental Metrics'),
              const SizedBox(height: 12),

              _isLoading
                ? const _LoadingShimmer()
                : _EnvironmentGrid(data: _envData),

              const SizedBox(height: 24),

              // ── Activité récente ────────────────────────────────────────
              _SectionHeader(icon: Icons.history, label: 'Recent Activity'),
              const SizedBox(height: 12),
              _ActivityList(data: _envData),
            ],
          ),
        ),
      ),

      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _navIndex,
        onTap: (index) {
          setState(() => _navIndex = index);
          if (index == 2) Navigator.pushNamed(context, '/alerts');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
      ),
    );
  }
}

// ─── Bannière d'erreur réseau ─────────────────────────────────────────────────
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
        color: AppColors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton loader pendant le chargement ────────────────────────────────────
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      )),
    );
  }
}

// ─── Carte de statut système ──────────────────────────────────────────────────
class _SystemStatusCard extends StatelessWidget {
  final bool isConnected;
  final String lastUpdatedText;
  final bool hasAlerts;

  const _SystemStatusCard({
    required this.isConnected,
    required this.lastUpdatedText,
    required this.hasAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = hasAlerts ? AppColors.red
        : (isConnected ? AppColors.emerald : AppColors.orange);
    final statusText  = hasAlerts ? 'ALERTE'
        : (isConnected ? 'NORMAL' : 'HORS LIGNE');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary.withOpacity(0.15), Colors.transparent],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 3),
                  color: statusColor.withOpacity(0.1),
                ),
                child: Icon(
                  hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: statusColor,
                  size: 40,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OVERALL HEALTH',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.textMuted, letterSpacing: 2)),
                const SizedBox(height: 4),
                const Text('System Status',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(statusText,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                            color: statusColor)),
                    const SizedBox(width: 10),
                    Text('Dernière MAJ : $lastUpdatedText',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/alerts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View Alerts',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─── Grille de capteurs ───────────────────────────────────────────────────────
class _EnvironmentGrid extends StatelessWidget {
  final EnvironmentData data;
  const _EnvironmentGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final tempFill = ((data.temperature - 18) / (26 - 18)).clamp(0.0, 1.0);
    final humFill  = ((data.humidity - 40) / (60 - 40)).clamp(0.0, 1.0);

    // Couleur dynamique selon les alertes
    final tempColor = data.alerts.tempCritical ? AppColors.red
        : (data.alerts.tempWarning ? AppColors.orange : AppColors.primary);

    return Column(
      children: [
        SensorGaugeCard(
          label: 'Temperature',
          value: '${data.temperature.toStringAsFixed(1)}°C',
          status: data.alerts.tempCritical ? 'Critical'
              : (data.alerts.tempWarning ? 'Warning' : 'Optimal'),
          rangeText: 'Range: 18°C - 26°C',
          gaugeColor: tempColor,
          fillPercent: tempFill,
        ),
        const SizedBox(height: 12),
        SensorGaugeCard(
          label: 'Humidity',
          value: '${data.humidity.toStringAsFixed(0)}%',
          status: data.alerts.humidityLow ? 'Low'
              : (data.alerts.humidityHigh ? 'High' : 'Normal'),
          rangeText: 'Range: 40% - 60%',
          gaugeColor: AppColors.sky,
          fillPercent: humFill,
        ),
        const SizedBox(height: 12),
        WaterLeakCard(leakDetected: data.waterLeakDetected),
      ],
    );
  }
}

// ─── Liste d'activité (générée dynamiquement depuis les données ESP) ──────────
class _ActivityList extends StatelessWidget {
  final EnvironmentData data;
  const _ActivityList({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ActivityListItem(
            icon: Icons.thermostat,
            iconColor: data.alerts.tempCritical ? AppColors.red : AppColors.emerald,
            iconBgColor: (data.alerts.tempCritical ? AppColors.red : AppColors.emerald).withOpacity(0.1),
            title: 'Température : ${data.temperature.toStringAsFixed(1)}°C',
            subtitle: '${data.deviceId} • ${data.lastUpdatedText}',
          ),
          const Divider(color: AppColors.border, height: 1),
          ActivityListItem(
            icon: Icons.water_drop_outlined,
            iconColor: data.alerts.humidityLow ? AppColors.orange : AppColors.primary,
            iconBgColor: (data.alerts.humidityLow ? AppColors.orange : AppColors.primary).withOpacity(0.1),
            title: 'Humidité : ${data.humidity.toStringAsFixed(0)}%',
            subtitle: '${data.deviceId} • ${data.lastUpdatedText}',
          ),
          const Divider(color: AppColors.border, height: 1),
          ActivityListItem(
            icon: data.waterLeakDetected ? Icons.water_damage : Icons.water_drop,
            iconColor: data.waterLeakDetected ? AppColors.red : AppColors.emerald,
            iconBgColor: (data.waterLeakDetected ? AppColors.red : AppColors.emerald).withOpacity(0.1),
            title: data.waterLeakDetected ? 'Fuite d\'eau détectée !' : 'Pas de fuite d\'eau',
            subtitle: '${data.deviceId} • ${data.lastUpdatedText}',
          ),
        ],
      ),
    );
  }
}
