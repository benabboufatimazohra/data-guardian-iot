import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AppColors — Global Color Constants
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY: Instead of writing Color(0xFF3C83F6) everywhere (like inline CSS),
/// we define named constants once. This is Flutter's equivalent of CSS variables.
///
/// HTML/CSS approach:
///   :root { --primary: #3c83f6; }
///   .button { background: var(--primary); }
///
/// Flutter approach:
///   Container(color: AppColors.primary)
/// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._(); // Private constructor — this class should never be instantiated

  static const Color primary = Color(0xFF3C83F6);       // Blue accent
  static const Color backgroundDark = Color(0xFF101722); // Main dark background
  static const Color surface = Color(0xFF1A2332);        // Cards / elevated surfaces
  static const Color surfaceLight = Color(0xFF222D3D);   // Slightly lighter surface
  static const Color border = Color(0xFF2A3547);         // Border color

  static const Color emerald = Color(0xFF10B981);        // Green — "normal/ok" states
  static const Color red = Color(0xFFEF4444);            // Red — critical alerts
  static const Color orange = Color(0xFFF97316);         // Orange — warning alerts
  static const Color sky = Color(0xFF38BDF8);            // Sky blue — humidity

  static const Color textPrimary = Color(0xFFF1F5F9);   // Main text (slate-100)
  static const Color textSecondary = Color(0xFF94A3B8); // Muted text (slate-400)
  static const Color textMuted = Color(0xFF64748B);     // Very muted (slate-500)
}

/// ─────────────────────────────────────────────────────────────────────────────
/// AppTextStyles — Reusable Text Styles
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY: Just like CSS classes for typography, these prevent style duplication.
/// HTML: <h1 class="text-3xl font-bold">
/// Flutter: Text('title', style: AppTextStyles.heading)
/// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.2,
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// AppSpacing — Spacing Constants
/// ─────────────────────────────────────────────────────────────────────────────
/// HTML Tailwind: p-4 = 16px, p-6 = 24px, gap-2 = 8px
/// Flutter: EdgeInsets.all(AppSpacing.md)
/// ─────────────────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}