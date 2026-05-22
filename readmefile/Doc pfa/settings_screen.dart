import 'package:flutter/material.dart';

const _bgDark = Color(0xFF101722);
const _surface = Color(0xFF1A2332);
const _border = Color(0xFF2A3547);
const _primary = Color(0xFF3C83F6);
const _textPrimary = Color(0xFFF1F5F9);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF64748B);

/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN 7: SettingsScreen (Admin Settings)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// WIDGET TREE:
/// Scaffold
/// ├── AppBar  ← back + "Admin Settings" + search icon
/// └── body: SingleChildScrollView
///     └── Column
///         ├── _AdminProfileHeader  ← avatar + name + subtitle
///         ├── Section label "CORE CONFIGURATION"
///         ├── _SettingsMenuItem × 4  ← tappable rows with icon + chevron
///         ├── _LogOutButton
///         └── Text "DataCenter OS v2.4.0"
///
/// KEY LEARNING — Settings List Pattern:
///   HTML: A list of <a> tags with flex layout + hover effects.
///   Flutter equivalent: A Column of InkWell-wrapped Container rows.
///   We could also use ListView, but Column is simpler when items are fixed.
///
///   The chevron_right icon is Flutter's equivalent of the > arrow.
///   The hover effect: HTML's hover:bg-slate-800 = Flutter's InkWell splash.
///
/// KEY LEARNING — Navigation from Settings Items:
///   Each menu item has an onTap that calls Navigator.pushNamed().
///   Since these sub-screens don't exist yet, we show a placeholder SnackBar.
///   Replace with actual routes when you build those screens.
/// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Admin Settings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _textSecondary),
            onPressed: () {},
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: _border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin profile header
            _AdminProfileHeader(),

            // Section label
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                'CORE CONFIGURATION',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // Settings menu items
            // Each item is a reusable widget — same pattern as reusable cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SettingsMenuItem(
                    icon: Icons.speed,
                    title: 'Threshold Configuration',
                    subtitle: 'Manage alert limits and system triggers',
                    onTap: () => _showComingSoon(context, 'Threshold Configuration'),
                  ),
                  _SettingsMenuItem(
                    icon: Icons.memory,
                    title: 'Device Management',
                    subtitle: 'Monitor and configure hardware nodes',
                    onTap: () => Navigator.pushNamed(context, '/device-detail'),
                  ),
                  _SettingsMenuItem(
                    icon: Icons.shield_outlined,
                    title: 'User Access Control',
                    subtitle: 'Role-based permissions and security',
                    onTap: () => _showComingSoon(context, 'User Access Control'),
                  ),
                  _SettingsMenuItem(
                    icon: Icons.description_outlined,
                    title: 'Report Export',
                    subtitle: 'Schedule and format data analytics',
                    onTap: () => _showComingSoon(context, 'Report Export'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Log Out button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _LogOutButton(
                onTap: () {
                  // Navigate back to login and clear the navigation stack
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false, // Remove ALL previous routes
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Version footer
            const Center(
              child: Text(
                'DATACENTER OS V2.4.0',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _SettingsBottomNav(),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Admin Profile Header ─────────────────────────────────────────────────────
/// HTML: <div class="p-6 flex items-center gap-4">
///         <div class="size-14 rounded-full bg-primary/20">
class _AdminProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Avatar circle — HTML: rounded-full bg-primary/20 border border-primary/30
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(0.2),
              border: Border.all(color: _primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.admin_panel_settings, color: _primary, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'System Administrator',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
              SizedBox(height: 2),
              Text(
                'Manage global data center parameters',
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Settings Menu Item ───────────────────────────────────────────────────────
/// A single tappable row: [icon] [title + subtitle] [>]
///
/// HTML: <a class="flex items-center gap-4 hover:bg-slate-800 ...">
/// Flutter: InkWell wraps a Row — InkWell provides the ripple tap effect
///
/// WHY InkWell instead of GestureDetector?
///   InkWell shows a Material ripple animation on tap.
///   GestureDetector just detects the tap silently.
///   For a settings list, InkWell feels more native and polished.
class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: _primary.withOpacity(0.08),
          highlightColor: _primary.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _primary, size: 22),
                ),
                const SizedBox(width: 16),
                // Text content — Expanded takes remaining width
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: _textSecondary)),
                    ],
                  ),
                ),
                // Chevron right arrow
                const Icon(Icons.chevron_right, color: _textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Log Out Button ───────────────────────────────────────────────────────────
/// HTML: <button class="border border-red-500/20 bg-red-500/5 text-red-500">
class _LogOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
          backgroundColor: Colors.red.withOpacity(0.05),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────────────────
class _SettingsBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          _NavTab(icon: Icons.dashboard_outlined, label: 'Dashboard', isActive: false, onTap: () => Navigator.pushReplacementNamed(context, '/dashboard')),
          _NavTab(icon: Icons.dns_outlined, label: 'Devices', isActive: false, onTap: () => Navigator.pushReplacementNamed(context, '/device-detail')),
          _NavTab(icon: Icons.notifications_outlined, label: 'Alerts', isActive: false, onTap: () => Navigator.pushReplacementNamed(context, '/alerts')),
          _NavTab(icon: Icons.settings, label: 'Settings', isActive: true, onTap: () {}),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? _primary : _textMuted, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: isActive ? _primary : _textMuted)),
          ],
        ),
      ),
    );
  }
}
