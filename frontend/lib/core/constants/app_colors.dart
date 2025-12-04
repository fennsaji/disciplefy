import 'package:flutter/material.dart';

/// Application colors based on Disciplefy brand guidelines
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color secondaryPurple =
      Color(0xFF6366F1); // Indigo (for gradients)
  static const Color secondary = Color(0xFFFFEFC0); // Golden Glow
  static const Color accent = Color(0xFFFF6B6B); // Action/Alert

  // Background colors
  static const Color background = Color(0xFFFFFFFF); // Background
  static const Color surface = Color(0xFFFFFFFF); // White

  // Text colors
  static const Color textPrimary = Color(0xFF1E1E1E); // Text Primary
  static const Color textSecondary = Color(0xFF6B7280); // Gray text

  // Status colors
  static const Color error = Color(0xFFEF4444); // Red
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color success = Color(0xFF10B981); // Emerald

  // UI element colors
  static const Color divider = Color(0xFFE5E7EB);
  static const Color disabled = Color(0xFF9CA3AF);
  static const Color shadowLight = Color(0x0F000000);
  static const Color shadowMedium = Color(0x1A000000);

  // Additional getters for compatibility
  static Color get primaryColor => primary;
  static Color get secondaryColor => secondary;
  static Color get errorColor => error;
  static Color get successColor => success;
  static Color get warningColor => warning;
  static Color get surfaceColor => surface;
  static Color get textTertiary => textSecondary;
}
