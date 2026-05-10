// lib/widgets/widgets.dart
// FIXED: AppBottomNavBar now navigates correctly to all 4 tabs
// Only this widget changes — keep everything else in your widgets.dart the same

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FIXED: AppBottomNavBar
// ═══════════════════════════════════════════════════════════════════════════════
//
// THE BUG: The original onTap only handled index 0 (Dashboard) and index 2
// (Alerts). Devices (index 1) and Settings (index 3) had no navigation.
//
// THE FIX: Handle all 4 indices with pushReplacementNamed so the back stack
// doesn't pile up when switching tabs.
//
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // Always call the parent callback so currentIndex updates
          onTap(index);

          // Navigate — use pushReplacementNamed to avoid stacking screens
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/dashboard');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/device-detail');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/alerts');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/settings');
              break;
          }
        },
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.dashboard_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.dashboard,          color: AppColors.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon:         Icon(Icons.lan_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.lan,          color: AppColors.primary),
            label: 'Devices',
          ),
          NavigationDestination(
            icon:         _AlertIcon(hasAlert: true),
            selectedIcon: _AlertIcon(hasAlert: true, isSelected: true),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.settings,          color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _AlertIcon extends StatelessWidget {
  final bool hasAlert;
  final bool isSelected;
  const _AlertIcon({this.hasAlert = false, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isSelected ? Icons.notifications : Icons.notifications_outlined,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        if (hasAlert)
          const Positioned(
            top: -2, right: -2,
            child: CircleAvatar(radius: 4, backgroundColor: AppColors.red),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Keep all your existing widgets below unchanged:
// SensorGaugeCard, WaterLeakCard, ActivityListItem, AlertCard, _AppCard
// (paste them here from your original widgets.dart)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── SensorGaugeCard ─────────────────────────────────────────────────────────
class SensorGaugeCard extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final String rangeText;
  final Color  gaugeColor;
  final double fillPercent;

  const SensorGaugeCard({
    super.key,
    required this.label,
    required this.value,
    required this.status,
    required this.rangeText,
    required this.gaugeColor,
    required this.fillPercent,
  });

  @override
  Widget build(BuildContext context) {
    return _AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120, height: 120,
            child: CustomPaint(
              painter: _GaugePainter(fillPercent: fillPercent, color: gaugeColor),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(value, style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  Text(status.toUpperCase(), style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 1)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(rangeText, style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fillPercent;
  final Color  color;
  const _GaugePainter({required this.fillPercent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = size.width / 2 - 8;
    const strokeWidth = 8.0;

    canvas.drawCircle(center, radius, Paint()
      ..color = AppColors.border
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fillPercent,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fillPercent != fillPercent || old.color != color;
}

// ─── WaterLeakCard ────────────────────────────────────────────────────────────
class WaterLeakCard extends StatelessWidget {
  final bool leakDetected;
  const WaterLeakCard({super.key, required this.leakDetected});

  @override
  Widget build(BuildContext context) {
    final color    = leakDetected ? AppColors.red : AppColors.emerald;
    final label    = leakDetected ? 'Leak Detected!'    : 'No Leaks Detected';
    final sublabel = leakDetected ? 'Positive Status'   : 'Negative Status';
    final icon     = leakDetected ? Icons.water_damage  : Icons.water_drop;

    return _AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
            child: Icon(icon, color: color, size: 60),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 2),
          Text(sublabel, style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── ActivityListItem ─────────────────────────────────────────────────────────
class ActivityListItem extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBgColor;
  final String   title;
  final String   subtitle;

  const ActivityListItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
          ],
        )),
      ]),
    );
  }
}

// ─── AlertCard ────────────────────────────────────────────────────────────────
class AlertCard extends StatelessWidget {
  final AlertModel  alert;
  final VoidCallback? onExplain;
  final VoidCallback? onDismiss;

  const AlertCard({
    super.key,
    required this.alert,
    this.onExplain,
    this.onDismiss,
  });

  Color get _borderColor {
    switch (alert.severity) {
      case AlertSeverity.critical: return AppColors.red;
      case AlertSeverity.warning:  return AppColors.orange;
      case AlertSeverity.info:     return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (alert.severity) {
      case AlertSeverity.critical: return Icons.device_thermostat;
      case AlertSeverity.warning:  return Icons.water_drop_outlined;
      case AlertSeverity.info:     return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _borderColor, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _borderColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_icon, color: _borderColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(alert.title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary))),
              const SizedBox(width: 8),
              Text(alert.relativeTime, style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(alert.deviceId, style: const TextStyle(
                    fontSize: 11, fontFamily: 'monospace',
                    color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 6),
              Text('• ${alert.location}', style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ActionButton(
                  label: 'Explain', icon: Icons.info_outline,
                  isPrimary: alert.severity == AlertSeverity.critical,
                  onPressed: onExplain)),
              const SizedBox(width: 8),
              Expanded(child: _ActionButton(
                  label: 'Dismiss', isPrimary: false, onPressed: onDismiss)),
            ]),
          ],
        )),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String     label;
  final IconData?  icon;
  final bool       isPrimary;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label, this.icon,
    required this.isPrimary, this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.primary : AppColors.surfaceLight,
        foregroundColor: isPrimary ? Colors.white : AppColors.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── _AppCard base ────────────────────────────────────────────────────────────
class _AppCard extends StatelessWidget {
  final Widget child;
  const _AppCard({required this.child});

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
      child: child,
    );
  }
}

// ─── AppSpacing (needed by some screens) ─────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

