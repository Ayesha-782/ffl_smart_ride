import 'package:flutter/material.dart';

class AppColors {
  // Brand colors - Modern Smart-Mobility Jade / Electric Teal
  static const Color primary = Color(0xFF0D9488); // Modern Jade/Teal
  static const Color primaryDark = Color(0xFF0F766E); // Deep Teal
  static const Color primaryLight = Color(0xFFE6FFFA); // Soft Jade Mist
  static const Color primaryAccent = Color(0xFF14B8A6); // Vibrant Mint Teal

  // Background & surfaces - Very light, soothing mint/slate tint
  static const Color background = Color(0xFFF2F8F6); // Ultra-light refreshing mint mist
  static const Color surface = Color(0xFFE7F2EE); // Layered soft surface
  static const Color cardBg = Colors.white;

  // Text & Neutral colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color border = Color(0xFFE2E8F0); // Subtle Border

  // Accent & Status colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Coral Red
  static const Color info = Color(0xFF0EA5E9); // Sky Blue
  static const Color accentIndigo = Color(0xFF6366F1); // Electric Indigo

  // Modern Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF134E4A), Color(0xFF042F2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ecoGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
