// lib/screens/alert_analysis_screen.dart
//
// ISSUE 2 FIX:
//   All hardcoded values removed.
//   This screen now receives route arguments: {alert: AlertModel, xai: XaiData}
//   and displays real ESP-generated XAI data.
//
// HOW TO NAVIGATE HERE:
//   Navigator.pushNamed(context, '/alert-analysis', arguments: {
//     'alert': myAlertModel,
//     'xai':   EspService.instance.lastXai,
//   });

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/esp_service.dart';

const _bgDark        = Color(0xFF101722);
const _surface       = Color(0xFF1A2332);
const _border        = Color(0xFF2A3547);
const _primary       = Color(0xFF3C83F6);
const _textPrimary   = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted     = Color(0xFF64748B);

class AlertAnalysisScreen extends StatelessWidget {
  const AlertAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Receive route arguments ──────────────────────────────────────────────
    final args = ModalRoute.of(context)?.settings.arguments;
    AlertModel? alert;
    XaiData     xai = EspService.instance.lastXai;

    if (args is Map<String, dynamic>) {
      alert = args['alert'] as AlertModel?;
      xai   = args['xai']   as XaiData? ?? xai;
    }

    // Fallback: if navigated without args, use last known data
    final title    = alert?.title    ?? 'Alert Analysis';
    final location = alert?.location ?? 'Unknown Location';
    final severity = alert?.severity ?? AlertSeverity.warning;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Alert Analysis',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: _textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: _border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AlertTitleSection(
                title: title, severity: severity,
                relativeTime: alert?.relativeTime ?? ''),
            const SizedBox(height: 20),
            _XaiReasoningBox(xai: xai),
            const SizedBox(height: 20),
            _RecommendedActionSection(severity: severity),
            const SizedBox(height: 20),
            _AssetLocationCard(location: location),
          ],
        ),
      ),
      bottomNavigationBar: _AnalysisBottomNav(),
    );
  }
}

// ─── Alert title section ────────────────────────────────────────────────────────
class _AlertTitleSection extends StatelessWidget {
  final String        title;
  final AlertSeverity severity;
  final String        relativeTime;

  const _AlertTitleSection({
    required this.title,
    required this.severity,
    required this.relativeTime,
  });

  Color get _color {
    switch (severity) {
      case AlertSeverity.critical: return Colors.redAccent;
      case AlertSeverity.warning:  return const Color(0xFFF97316);
      case AlertSeverity.info:     return _primary;
    }
  }

  String get _label {
    switch (severity) {
      case AlertSeverity.critical: return 'CRITICAL PRIORITY';
      case AlertSeverity.warning:  return 'WARNING';
      case AlertSeverity.info:     return 'INFORMATION';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(_label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _color, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                color: _textPrimary, height: 1.2)),
        if (relativeTime.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Triggered $relativeTime ago',
              style: const TextStyle(fontSize: 13, color: _textSecondary)),
        ],
      ],
    );
  }
}

// ─── XAI Reasoning Box ──────────────────────────────────────────────────────────
// ISSUE 2 FIX: fully driven by XaiData — no hardcoded values
class _XaiReasoningBox extends StatelessWidget {
  final XaiData xai;
  const _XaiReasoningBox({required this.xai});

  Color get _levelColor {
    switch (xai.level.toLowerCase()) {
      case 'critique': return Colors.redAccent;
      case 'warning':  return const Color(0xFFF97316);
      default:         return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(children: [
            Icon(Icons.psychology_outlined, color: _primary, size: 22),
            SizedBox(width: 8),
            Text('XAI Reasoning',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: _primary)),
          ]),
          const SizedBox(height: 16),

          // Risk Score row
          Row(children: [
            const Text('Risk Score:',
                style: TextStyle(fontSize: 13, color: _textSecondary)),
            const SizedBox(width: 8),
            Text(xai.score.toStringAsFixed(2),
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: _levelColor)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           xai.score.clamp(0.0, 1.0),
                  backgroundColor: _border,
                  color:           _levelColor,
                  minHeight:       6,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Level badge
          Row(children: [
            const Text('Level:',
                style: TextStyle(fontSize: 13, color: _textSecondary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        _levelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(
                    color: _levelColor.withValues(alpha: 0.4)),
              ),
              child: Text(xai.levelDisplay.toUpperCase(),
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: _levelColor,
                      letterSpacing: 1.0)),
            ),
          ]),
          const SizedBox(height: 16),

          // Explanation reason from ESP — no hardcoded text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        _bgDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: _primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // ── xai.reason is generated by ESP firmware ──────────
                    xai.reason,
                    style: const TextStyle(fontSize: 13,
                        color: _textSecondary, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recommended action ─────────────────────────────────────────────────────────
class _RecommendedActionSection extends StatelessWidget {
  final AlertSeverity severity;
  const _RecommendedActionSection({required this.severity});

  String get _actionTitle {
    switch (severity) {
      case AlertSeverity.critical: return 'Check Cooling System / HVAC Units';
      case AlertSeverity.warning:  return 'Monitor Sensor Readings';
      case AlertSeverity.info:     return 'Review System Logs';
    }
  }

  String get _actionSubtitle {
    switch (severity) {
      case AlertSeverity.critical: return 'Manual inspection of cooling cycle required.';
      case AlertSeverity.warning:  return 'Continue monitoring — escalate if value increases.';
      case AlertSeverity.info:     return 'No immediate action required.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recommended Action',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const SizedBox(height: 12),
        Container(
          padding:    const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        _surface,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: _border),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color:        _primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.air, color: _primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_actionTitle,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(_actionSubtitle,
                    style: const TextStyle(fontSize: 12,
                        color: _textSecondary)),
              ],
            )),
            const Icon(Icons.chevron_right, color: _textMuted),
          ]),
        ),
      ],
    );
  }
}

// ─── Asset location card ────────────────────────────────────────────────────────
class _AssetLocationCard extends StatelessWidget {
  final String location;
  const _AssetLocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _border),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ASSET LOCATION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: _textMuted, letterSpacing: 1.5)),
            Text(location,
                style: const TextStyle(fontSize: 12,
                    color: _textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width:  double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color:        const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(painter: _MapGridPainter()),
            ),
            const Icon(Icons.location_on, color: Colors.red, size: 40),
          ],
        ),
      ]),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color      = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    const step = 20.0;
    for (double x = 0; x < size.width;  x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_MapGridPainter _) => false;
}

// ─── Bottom nav ─────────────────────────────────────────────────────────────────
class _AnalysisBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_outlined, 'DASHBOARD', '/dashboard'),
      (Icons.notifications,      'ALERTS',    '/alerts'),
      (Icons.inventory_2_outlined,'ASSETS',   null),
      (Icons.settings_outlined,  'SETTINGS',  '/settings'),
    ];
    return Container(
      decoration: const BoxDecoration(
          color: _bgDark,
          border: Border(top: BorderSide(color: _border))),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: items.map((item) {
          final (icon, label, route) = item;
          final isAlerts = label == 'ALERTS';
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (route != null) {
                  Navigator.pushReplacementNamed(context, route);
                }
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: isAlerts ? _primary : _textMuted, size: 24),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isAlerts ? _primary : _textMuted,
                        letterSpacing: 0.5)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}