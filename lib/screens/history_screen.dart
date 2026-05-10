// lib/screens/history_screen.dart
//
// CHANGES:
//   1. Added debug prints inside _loadData() to diagnose loading issues
//   2. Adapted for alerts-only storage — no sensor readings in SQLite anymore
//      The screen now shows:
//        - Critical alerts history (from SQLite)
//        - Live sensor values are shown on Dashboard only
//   3. _isLoading bug fix: try/catch ensures _isLoading always becomes false

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
  int  _selectedPeriod = 0; // 0 = 24H, 1 = 7D, 2 = 30D
  bool _isLoading      = true;

  List<AlertModel> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    debugPrint('DEBUG: Starting _loadData()');

    final hours = [24, 168, 720][_selectedPeriod];
    final from  = DateTime.now().subtract(Duration(hours: hours));
    const espId = 'ESP8266-01';

    try {
      final alerts = await DatabaseHelper.instance.getAlertsForExport(
        espId: espId,
        from:  from,
        to:    DateTime.now(),
      );
      debugPrint('DEBUG: Got ${alerts.length} alerts from SQLite');

      if (mounted) {
        setState(() {
          _alerts    = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG: Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101722),
      appBar: _buildAppBar(context),
      body: Column(children: [
        _PeriodTabBar(
          selected:  _selectedPeriod,
          onChanged: (i) {
            setState(() => _selectedPeriod = i);
            _loadData();
          },
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _alerts.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          _SummaryCard(alerts: _alerts),
                          const SizedBox(height: 16),
                          ..._alerts.reversed.map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AlertHistoryCard(alert: alert),
                          )),
                        ],
                      ),
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
    title: const Text(
      'Alert History',
      style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
    ),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 16),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          icon: const Icon(Icons.notifications_active_outlined,
              color: AppColors.textPrimary, size: 14),
          label: Text(
            '${_alerts.length} alerts',
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
          ),
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

// ─── Summary card at top ──────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final List<AlertModel> alerts;
  const _SummaryCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final critical  = alerts.where((a) => a.severity == AlertSeverity.critical).length;
    final resolved  = alerts.where((a) => a.isResolved).length;
    final unresolved = alerts.where((a) => !a.isResolved).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Summary',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatChip(
              label: 'Critical', value: '$critical', color: AppColors.red)),
          const SizedBox(width: 8),
          Expanded(child: _StatChip(
              label: 'Unresolved', value: '$unresolved', color: AppColors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _StatChip(
              label: 'Resolved', value: '$resolved', color: AppColors.emerald)),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.textSecondary)),
    ]),
  );
}

// ─── Single alert history card ────────────────────────────────────────────────
class _AlertHistoryCard extends StatelessWidget {
  final AlertModel alert;
  const _AlertHistoryCard({required this.alert});

  Color get _severityColor {
    switch (alert.severity) {
      case AlertSeverity.critical: return AppColors.red;
      case AlertSeverity.warning:  return AppColors.orange;
      case AlertSeverity.info:     return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _severityColor, width: 3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _severityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            alert.severity == AlertSeverity.critical
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: _severityColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              Text(alert.location,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const Text(' • ',
                  style: TextStyle(color: AppColors.textMuted)),
              Text(
                '${alert.timestamp.day}/${alert.timestamp.month} '
                '${alert.timestamp.hour.toString().padLeft(2, '0')}:'
                '${alert.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ]),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: alert.isResolved
                ? AppColors.emerald.withValues(alpha: 0.1)
                : AppColors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            alert.isResolved ? 'Resolved' : 'Active',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: alert.isResolved ? AppColors.emerald : AppColors.red,
            ),
          ),
        ),
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
      Icon(Icons.notifications_none_outlined,
          color: AppColors.textMuted, size: 56),
      SizedBox(height: 12),
      Text('No critical alerts yet',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      SizedBox(height: 4),
      Text('Alerts appear here when the ESP\ndetects critical conditions',
          textAlign: TextAlign.center,
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
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: sel ? AppColors.primary : Colors.transparent,
                        width: 2))),
            child: Text(
              tabs[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? AppColors.primary : AppColors.textSecondary),
            ),
          ),
        ));
      })),
    );
  }
}

