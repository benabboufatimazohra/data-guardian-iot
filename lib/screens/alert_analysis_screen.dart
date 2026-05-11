import 'package:flutter/material.dart';

const _bgDark = Color(0xFF101722);
const _surface = Color(0xFF1A2332);
const _border = Color(0xFF2A3547);
const _primary = Color(0xFF3C83F6);
const _textPrimary = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF64748B);

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 6: AlertAnalysisScreen (XAI Explainability Screen)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// This screen opens when the user taps "Explain" on an alert.
/// It shows:
///  - The alert title + severity + sensor info
///  - Two comparison cards (triggered value vs threshold)
///  - XAI reasoning box (AI explanation)
///  - Recommended action card
///  - Asset location map placeholder
///
/// WIDGET TREE:
/// Scaffold
/// ├── AppBar  ← back + "Alert Analysis" + share icon
/// └── body: SingleChildScrollView
///     └── Column (padded)
///         ├── _AlertTitleSection
///         ├── _ComparisonCards (Row: triggered value + threshold)
///         ├── _XaiReasoningBox
///         ├── _RecommendedActionCard
///         └── _AssetLocationCard (map placeholder)
///
/// KEY LEARNING — Passing Data Between Screens:
///   In the previous screens, AlertCard had an onExplain callback.
///   In a real app, you pass the AlertModel to this screen via route arguments:
///
///   // In alerts_screen.dart:
///   Navigator.pushNamed(context, '/alert-analysis', arguments: alert);
///
///   // In this screen:
///   final alert = ModalRoute.of(context)!.settings.arguments as AlertModel;
///
///   For now, we hardcode the values so the screen renders.
///   Replace with real passed-in data when you connect the backend.
/// ─────────────────────────────────────────────────────────────────────────────
class AlertAnalysisScreen extends StatelessWidget {
  const AlertAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Alert Analysis',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _textPrimary),
            onPressed: () {
              // TODO: implement share functionality
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
            _AlertTitleSection(),
            const SizedBox(height: 20),
            _ComparisonCards(),
            const SizedBox(height: 20),
            _XaiReasoningBox(),
            const SizedBox(height: 20),
            _RecommendedActionSection(),
            const SizedBox(height: 20),
            _AssetLocationCard(),
          ],
        ),
      ),
      bottomNavigationBar: _AnalysisBottomNav(),
    );
  }
}

// ─── Alert Title Section ──────────────────────────────────────────────────────
/// HTML: red dot + "CRITICAL PRIORITY" label + big title + subtitle
class _AlertTitleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "● CRITICAL PRIORITY" badge row
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text(
              'CRITICAL PRIORITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Big headline
        const Text(
          'Critical temperature detected',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle
        const Text(
          'Triggered 2 mins ago • Sensor ID: TH-9942',
          style: TextStyle(fontSize: 13, color: _textSecondary),
        ),
      ],
    );
  }
}

// ─── Comparison Cards ─────────────────────────────────────────────────────────
/// HTML: <div class="flex flex-wrap gap-4">  → Flutter: Row with two Expanded cards
class _ComparisonCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Triggered Value card
        Expanded(
          child: _DataCard(
            icon: Icons.thermostat,
            label: 'Triggered Value',
            mainValue: '35.2°C',
            bottomWidget: Row(
              children: const [
                Icon(Icons.trending_up, color: Colors.redAccent, size: 14),
                SizedBox(width: 4),
                Text(
                  '+0.2°C deviation',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Threshold card
        Expanded(
          child: _DataCard(
            icon: Icons.rule_outlined,
            label: 'Threshold',
            mainValue: '35.0°C',
            bottomWidget: const Text(
              'Upper Safety Limit',
              style: TextStyle(fontSize: 12, color: _textMuted, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String mainValue;
  final Widget bottomWidget;

  const _DataCard({
    required this.icon,
    required this.label,
    required this.mainValue,
    required this.bottomWidget,
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
            children: [
              Icon(icon, size: 14, color: _textSecondary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          const SizedBox(height: 8),
          bottomWidget,
        ],
      ),
    );
  }
}

// ─── XAI Reasoning Box ────────────────────────────────────────────────────────
/// HTML: <div class="rounded-xl p-5 bg-primary/5 border border-primary/20">
/// The blue tinted box showing the AI's reasoning
class _XaiReasoningBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: const [
              Icon(Icons.psychology_outlined, color: _primary, size: 22),
              SizedBox(width: 8),
              Text(
                'XAI Reasoning',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Explanation text with bold inline values
          // HTML: normal text + <span class="font-bold"> for emphasis
          // Flutter: RichText with TextSpan allows mixed styles in one text block
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: _textSecondary, height: 1.6),
              children: [
                TextSpan(text: 'The sensor detected a reading of '),
                TextSpan(
                  text: '35.2°C',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
                ),
                TextSpan(text: ', which exceeds the predefined safety threshold of '),
                TextSpan(
                  text: '35.0°C',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary),
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Rule applied box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: _primary, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'RULE APPLIED',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 1.2),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Thermal Safety Limit v1.2',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
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

// ─── Recommended Action Section ───────────────────────────────────────────────
class _RecommendedActionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended Action',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        const SizedBox(height: 12),
        // Tappable action card — HTML: hover:border-primary transition-colors
        // Flutter: InkWell for tap ripple effect
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                // Fan icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.air, color: _primary, size: 24), // closest to mode_fan
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Check Cooling System / HVAC Units',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manual inspection of Unit-B4 cooling cycle required.',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Asset Location Card ──────────────────────────────────────────────────────
/// Shows a map placeholder with a red location pin.
/// HTML uses an <img> tag with a satellite image.
/// Flutter: We use a Container with a map-like dark background + Icon overlay.
///
/// When your backend is ready, replace this with google_maps_flutter package.
class _AssetLocationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ASSET LOCATION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 1.5),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View Map',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Map placeholder — Stack layers the pin on top of the background
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A), // Dark map-like color
                  borderRadius: BorderRadius.circular(8),
                ),
                // Grid lines to simulate a map grid
                child: CustomPaint(painter: _MapGridPainter()),
              ),
              const Icon(Icons.location_on, color: Colors.red, size: 40),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws a faint grid overlay to simulate a map
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter _) => false;
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────
class _AnalysisBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_outlined, 'DASHBOARD', '/dashboard'),
      (Icons.notifications, 'ALERTS', '/alerts'),
      (Icons.inventory_2_outlined, 'ASSETS', null),
      (Icons.settings_outlined, 'SETTINGS', '/settings'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _bgDark,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: items.map((item) {
          final (icon, label, route) = item;
          final isAlerts = label == 'ALERTS';
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (route != null) Navigator.pushReplacementNamed(context, route);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: isAlerts ? _primary : _textMuted, size: 24),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isAlerts ? _primary : _textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
