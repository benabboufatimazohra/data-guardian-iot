import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// REUSABLE WIDGETS
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY SPLIT INTO WIDGETS?
///
/// Think of reusable widgets like HTML components or CSS classes.
/// Instead of copy-pasting the same temperature card code 3 times,
/// you create ONE widget and pass data into it.
///
/// HTML approach (BAD — repeated code):
///   <div class="card">Temperature: 24°C</div>
///   <div class="card">Humidity: 45%</div>
///
/// Flutter approach (GOOD — reusable widget):
///   SensorGaugeCard(label: 'Temperature', value: '24°C', ...)
///   SensorGaugeCard(label: 'Humidity', value: '45%', ...)
///
/// Benefits:
///  1. Change the design in ONE place → affects all cards
///  2. Easier to test individual components
///  3. Code reads like a story: what it does, not how it's built
/// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET 1: AppBottomNavBar
// ═══════════════════════════════════════════════════════════════════════════════
/// Converts HTML <nav> bottom bar to Flutter's BottomNavigationBar.
///
/// HTML equivalent:
///   <nav class="fixed bottom-0 ...">
///     <a href="#"><span>dashboard</span><span>Dashboard</span></a>
///     ...
///   </nav>
///
/// WHY BottomNavigationBar instead of manual Row?
///   Flutter's built-in BottomNavigationBar handles:
///   - Safe area insets (notch on iPhone)
///   - Active/inactive state management
///   - Accessible tap targets automatically
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
    /// HTML: border-t border-slate-800 bg-slate-900/90 backdrop-blur-md
    /// Flutter: We achieve this with a DecoratedBox wrapping NavigationBar
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2332),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.lan_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.lan, color: AppColors.primary),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: _AlertIcon(hasAlert: true), // Custom badge widget (see below)
            selectedIcon: _AlertIcon(hasAlert: true, isSelected: true),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Custom widget for the alert icon with a red dot badge.
///
/// HTML equivalent:
///   <span class="material-symbols-outlined">notifications</span>
///   <span class="absolute top-0 right-0 size-2 bg-red-500 rounded-full"></span>
///
/// WHY a separate widget?
///   Flutter doesn't have a built-in badge+icon combo that matches our design,
///   so we use Stack to layer the dot on top of the icon.
///
/// HTML: position: relative + position: absolute = Flutter: Stack + Positioned
class _AlertIcon extends StatelessWidget {
  final bool hasAlert;
  final bool isSelected;

  const _AlertIcon({this.hasAlert = false, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none, // Allow badge to overflow bounds
      children: [
        Icon(
          isSelected ? Icons.notifications : Icons.notifications_outlined,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        if (hasAlert)
          /// Positioned works like CSS: position: absolute; top: -2px; right: -2px;
          const Positioned(
            top: -2,
            right: -2,
            child: CircleAvatar(
              radius: 4,
              backgroundColor: AppColors.red,
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET 2: SensorGaugeCard
// ═══════════════════════════════════════════════════════════════════════════════
/// Renders the circular gauge cards (Temperature, Humidity).
///
/// HTML equivalent:
///   <div class="bg-slate-900 border rounded-xl flex flex-col items-center">
///     <svg> <!-- circular gauge --> </svg>
///     <p>Temperature</p>
///     <p>Range: 18°C - 26°C</p>
///   </div>
///
/// HTML svg circular gauge → Flutter: CustomPaint with arc drawing
/// flex-col + items-center → Flutter: Column with crossAxisAlignment.center
class SensorGaugeCard extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final String rangeText;
  final Color gaugeColor;
  final double fillPercent; // 0.0 to 1.0

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
      /// Column is HTML's flex-direction: column
      /// crossAxisAlignment.center is HTML's align-items: center
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// CustomPaint draws the circular SVG-like gauge
          /// HTML: <svg><circle .../></svg> → Flutter: CustomPaint
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _GaugePainter(
                fillPercent: fillPercent,
                color: gaugeColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// SizedBox is HTML's margin-top / gap
          const SizedBox(height: 12),

          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rangeText,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// CustomPainter draws custom graphics — like SVG but in Flutter.
///
/// The HTML SVG approach:
///   stroke-dasharray="364" stroke-dashoffset="100"
///   These values control how much of the circle stroke is visible.
///
/// Flutter equivalent:
///   canvas.drawArc() with a sweep angle calculated from fillPercent.
///
/// Think of canvas as a drawing surface — you tell it where to draw,
/// what color, and what shape.
class _GaugePainter extends CustomPainter {
  final double fillPercent;
  final Color color;

  const _GaugePainter({required this.fillPercent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Paint for the background track (gray circle)
    final trackPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Paint for the filled portion
    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw full background circle
    canvas.drawCircle(center, radius, trackPaint);

    // Draw arc — starts at -90° (top) and sweeps clockwise by fillPercent
    // HTML: stroke-dashoffset controls this; we use sweep angle instead
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,                    // Start at top (-90 degrees)
      2 * math.pi * fillPercent,        // Sweep by percentage of full circle
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.fillPercent != fillPercent || oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET 3: WaterLeakCard
// ═══════════════════════════════════════════════════════════════════════════════
/// Displays the water leak status indicator.
///
/// HTML equivalent:
///   <div class="size-32 rounded-full bg-emerald-500/10 flex items-center justify-center">
///     <span class="material-symbols-outlined text-emerald-500 text-6xl">water_drop</span>
///   </div>
///   <p class="text-emerald-500">No Leaks Detected</p>
class WaterLeakCard extends StatelessWidget {
  final bool leakDetected;

  const WaterLeakCard({super.key, required this.leakDetected});

  @override
  Widget build(BuildContext context) {
    final color = leakDetected ? AppColors.red : AppColors.emerald;
    final label = leakDetected ? 'Leak Detected!' : 'No Leaks Detected';
    final sublabel = leakDetected ? 'Positive Status' : 'Negative Status';
    final icon = leakDetected ? Icons.water_damage : Icons.water_drop;

    return _AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// CircleAvatar is great for rounded containers.
          /// HTML: div with rounded-full + background-color opacity
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: Icon(icon, color: color, size: 60),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(sublabel, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET 4: ActivityListItem
// ═══════════════════════════════════════════════════════════════════════════════
/// A single row in the Recent Activity list.
///
/// HTML equivalent:
///   <div class="p-4 flex items-center gap-4">
///     <div class="size-10 rounded-full bg-emerald-500/10">
///       <span class="material-symbols-outlined">info</span>
///     </div>
///     <div>
///       <p>System backup completed</p>
///       <p>Server A-12 • 12 minutes ago</p>
///     </div>
///   </div>
///
/// flex items-center → Flutter: Row with crossAxisAlignment.center
/// gap-4 → Flutter: SizedBox(width: 16) between children
class ActivityListItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;

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
      /// HTML: p-4 = padding: 16px all sides
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        /// HTML: align-items: center
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// Circular icon container
          /// HTML: <div class="size-10 rounded-full">
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),

          /// HTML: gap-4 between the icon and text
          const SizedBox(width: AppSpacing.md),

          /// Expanded takes all remaining horizontal space
          /// HTML: flex: 1 (flex-1 class)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET 5: AlertCard
// ═══════════════════════════════════════════════════════════════════════════════
/// Alert card with colored left border, icon, action buttons.
///
/// HTML equivalent:
///   <div class="rounded-xl border-l-4 border-red-500 p-4 shadow-sm">
///     ...
///   </div>
///
/// border-l-4 = Flutter: Container with Border(left: BorderSide(width: 4))
/// shadow-sm = Flutter: BoxShadow
class AlertCard extends StatelessWidget {
  final AlertModel alert;
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
      case AlertSeverity.warning: return AppColors.orange;
      case AlertSeverity.info: return AppColors.primary;
    }
  }

  Color get _iconBgColor => _borderColor.withOpacity(0.1);

  IconData get _icon {
    switch (alert.severity) {
      case AlertSeverity.critical: return Icons.device_thermostat;
      case AlertSeverity.warning: return Icons.water_drop_outlined;
      case AlertSeverity.info: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          /// HTML: border-l-4 border-red-500
          left: BorderSide(color: _borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Left icon section
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: _borderColor, size: 24),
          ),

          const SizedBox(width: AppSpacing.md),

          /// Right content section — Expanded takes remaining width
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Row for title + timestamp
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(alert.relativeTime, style: AppTextStyles.caption),
                  ],
                ),

                const SizedBox(height: 6),

                /// Device badge + location
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.deviceId,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('• ${alert.location}', style: AppTextStyles.caption),
                  ],
                ),

                const SizedBox(height: 12),

                /// Action buttons row
                /// HTML: <div class="flex gap-2">
                Row(
                  children: [
                    /// "Explain" button — primary style for critical, outlined for warning
                    Expanded(
                      child: _ActionButton(
                        label: 'Explain',
                        icon: Icons.info_outline,
                        isPrimary: alert.severity == AlertSeverity.critical,
                        onPressed: onExplain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Dismiss',
                        isPrimary: false,
                        onPressed: onDismiss,
                      ),
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

/// Small action button used inside AlertCard
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    this.icon,
    required this.isPrimary,
    this.onPressed,
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
          if (icon != null) ...[
            Icon(icon, size: 14),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET 6: _AppCard (internal base card)
// ═══════════════════════════════════════════════════════════════════════════════
/// Shared base card style — reduces repetition.
/// HTML: bg-slate-900 border border-slate-800 p-5 rounded-xl
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

// Export AppSpacing here so other files can import just widgets.dart
// ignore: non_constant_identifier_names
AppSpacing get Spacing => AppSpacing._();
