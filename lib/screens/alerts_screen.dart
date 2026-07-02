// lib/screens/alerts_screen.dart
//
// CHANGES:
//   1. Removed the 3 hardcoded placeholder alerts (UI-only mock data).
//      Alerts now come exclusively from DatabaseHelper, which is populated
//      by AlertService.evaluate() on every ESP poll.
//   2. Added a subscription to EspService.dataStream so the list refreshes
//      automatically right after each poll — no manual pull-to-refresh
//      needed to see a brand-new alert appear.
//   3. _dismissAlert still only removes the alert from the local UI list
//      (NOT from SQLite) — resolution remains sensor-driven only, exactly
//      as AlertService intends. If the condition is still active on the
//      next poll, the alert will simply reappear (which is correct: it's
//      still a real, ongoing problem).
//   4. _explainAlert still uses EspService.instance.lastXai — the most
//      recent explanation payload received from the ESP8266 firmware.

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/esp_service.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int  _selectedTab = 0;
  bool _isLoading   = true;

  // ── Real alerts only — populated from SQLite via DatabaseHelper ───────────
  List<AlertModel> _allAlerts = [];

  StreamSubscription<EnvironmentData>? _dataSub;

  List<AlertModel> get _filteredAlerts {
    switch (_selectedTab) {
      case 1:  return _allAlerts.where((a) => a.severity == AlertSeverity.critical).toList();
      case 2:  return _allAlerts.where((a) => a.severity == AlertSeverity.warning).toList();
      case 3:  return _allAlerts.where((a) => a.isResolved).toList();
      default: return _allAlerts;
    }
  }

  String get _espId =>
      AuthService.instance.currentUser?.assignedEspId ?? 'ESP8266-01';

  @override
  void initState() {
    super.initState();
    _fetchAlerts();

    // Auto-refresh the alert list every time a new ESP reading comes in.
    // AlertService.evaluate() (triggered by EspService on each poll) is what
    // actually writes/resolves rows in SQLite — we just re-read after it runs.
    _dataSub = EspService.instance.dataStream.listen((_) {
      if (mounted) _fetchAlerts(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  // ── Loads active + recently resolved alerts from SQLite ───────────────────
  Future<void> _fetchAlerts({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);

    try {
      final espId = _espId;

      // Currently unresolved (ongoing) alerts
      final active = await DatabaseHelper.instance.getActiveAlerts(espId);

      // Resolved alerts from the last 24h, for the "Earlier Today" / "Resolved" tab
      final from = DateTime.now().subtract(const Duration(hours: 24));
      final recent = await DatabaseHelper.instance.getAlertsForExport(
        espId: espId,
        from:  from,
        to:    DateTime.now(),
      );
      final resolved = recent.where((a) => a.isResolved).toList();

      if (mounted) {
        setState(() {
          _allAlerts = [...active, ...resolved];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Dismiss removes from local UI list only ───────────────────────────────
  // Does NOT resolve the alert in SQLite. If the underlying condition is
  // still active, it will simply reappear on the next ESP poll — which is
  // the correct behaviour, since resolution must remain sensor-driven.
  void _dismissAlert(String alertId) {
    setState(() => _allAlerts.removeWhere((a) => a.id == alertId));
  }

  // ── Explain: fetch latest XAI from EspService and show bottom sheet ────────
  void _explainAlert(AlertModel alert) {
    final xai = EspService.instance.lastXai;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExplainBottomSheet(alert: alert, xai: xai),
    );
  }

  @override
  Widget build(BuildContext context) {
    final criticalAlerts =
        _filteredAlerts.where((a) => a.severity == AlertSeverity.critical && !a.isResolved).toList();
    final warningAlerts =
        _filteredAlerts.where((a) => a.severity == AlertSeverity.warning && !a.isResolved).toList();
    final resolvedAlerts =
        _filteredAlerts.where((a) => a.isResolved).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.9),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
        title: const Row(children: [
          Icon(Icons.sensors, color: AppColors.primary, size: 22),
          SizedBox(width: 10),
          Text('System Alerts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary),
                  onPressed: () {},
                ),
                if (_allAlerts.any((a) => !a.isResolved))
                  Positioned(
                    top: 8, right: 8,
                    child: _BlinkingDot(),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(children: [
        _FilterTabBar(
          selectedIndex: _selectedTab,
          onChanged:     (index) => setState(() => _selectedTab = index),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _fetchAlerts,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (criticalAlerts.isNotEmpty) ...[
                        _SectionLabel(
                          label:      'Critical Priority',
                          badgeText:  '${criticalAlerts.length} Active',
                          badgeColor: AppColors.red,
                        ),
                        const SizedBox(height: 8),
                        ...criticalAlerts.map((alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AlertCard(
                            alert:     alert,
                            onExplain: () => _explainAlert(alert),
                            onDismiss: () => _dismissAlert(alert.id),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                      if (warningAlerts.isNotEmpty) ...[
                        _SectionLabel(
                          label:      'Warning Status',
                          badgeText:  '${warningAlerts.length} Active',
                          badgeColor: AppColors.orange,
                        ),
                        const SizedBox(height: 8),
                        ...warningAlerts.map((alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AlertCard(
                            alert:     alert,
                            onExplain: () => _explainAlert(alert),
                            onDismiss: () => _dismissAlert(alert.id),
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
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
                            child: Text('No alerts',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ]),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
        },
      ),
    );
  }
}

// ─── Filter tab bar ────────────────────────────────────────────────────────────
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
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                margin:  const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(_tabs[index],
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary : AppColors.textSecondary)),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String  label;
  final String? badgeText;
  final Color?  badgeColor;
  const _SectionLabel({required this.label, this.badgeText, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 1.5)),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:         badgeColor!.withValues(alpha: 0.1),
              borderRadius:  BorderRadius.circular(4),
            ),
            child: Text(badgeText!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                    color: badgeColor)),
          ),
      ],
    );
  }
}

// ─── Resolved alert card ────────────────────────────────────────────────────────
class _ResolvedAlertCard extends StatelessWidget {
  final AlertModel alert;
  const _ResolvedAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        padding:    const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color:         AppColors.surface,
            borderRadius:  BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            padding:    const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color:         AppColors.surfaceLight,
                borderRadius:  BorderRadius.circular(8)),
            child: const Icon(Icons.router_outlined,
                color: AppColors.textMuted, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(alert.title,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary))),
                Text(alert.relativeTime,
                    style: const TextStyle(fontSize: 11,
                        color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 4),
              Text('${alert.location} • resolved',
                  style: const TextStyle(fontSize: 12,
                      color: AppColors.textSecondary)),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── Blinking dot ──────────────────────────────────────────────────────────────
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _animation,
    child: Container(width: 8, height: 8,
        decoration: const BoxDecoration(
            color: AppColors.red, shape: BoxShape.circle)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExplainBottomSheet
//
// Displays the real ESP-generated explanation:
//   • Risk Score (xai.score as percentage bar)
//   • Level (xai.levelDisplay)
//   • Reason (xai.reason — generated by ESP firmware, e.g. "T=34C
//     avertissement, hausse +1.2C/cycle")
// ─────────────────────────────────────────────────────────────────────────────
class _ExplainBottomSheet extends StatelessWidget {
  final AlertModel alert;
  final XaiData    xai;

  const _ExplainBottomSheet({required this.alert, required this.xai});

  Color get _levelColor {
    switch (xai.level.toLowerCase()) {
      case 'critique': return AppColors.red;
      case 'warning':  return AppColors.orange;
      default:         return AppColors.emerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Prevent sheet from hiding behind keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:      MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('AI Explanation',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // ── Alert title ──────────────────────────────────────────────────
            Text(alert.title,
                style: const TextStyle(fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // ── Risk Score ───────────────────────────────────────────────────
            Row(children: [
              const Text('Risk Score:',
                  style: TextStyle(fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Text(
                xai.score.toStringAsFixed(2),
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: _levelColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           xai.score.clamp(0.0, 1.0),
                    backgroundColor: AppColors.border,
                    color:           _levelColor,
                    minHeight:       6,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Level ────────────────────────────────────────────────────────
            Row(children: [
              const Text('Level:',
                  style: TextStyle(fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        _levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(
                      color: _levelColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  xai.levelDisplay.toUpperCase(),
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: _levelColor,
                      letterSpacing: 1.0),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Explanation reason ────────────────────────────────────────────
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.psychology_outlined,
                        color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Text('Explanation',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 8),
                  // ── xai.reason comes from ESP firmware — no hardcoded text ──
                  Text(
                    xai.reason,
                    style: const TextStyle(fontSize: 13,
                        color: AppColors.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Got it button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('Got it',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
