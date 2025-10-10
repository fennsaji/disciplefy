import 'package:flutter/material.dart';

/// Application colors based on Disciplefy brand guidelines
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF6A4FB6); // Spiritual Lavender
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

  // Payment method colors
  static const Color cardBackground = Color(0xFFF8FAFC);
  static const Color upiGreen = Color(0xFF059669);
  static const Color netbankingBlue = Color(0xFF2563EB);
  static const Color walletOrange = Color(0xFFF59E0B);

  // Token purchase colors
  static const Color tokenGold = Color(0xFFFFD700);
  static const Color purchaseSuccess = Color(0xFF10B981);
  static const Color purchaseFailure = Color(0xFFEF4444);

  // Preference colors
  static const Color preferenceSelected = Color(0xFFE0E7FF);
  static const Color preferenceUnselected = Color(0xFFF9FAFB);

  // Additional getters for compatibility
  static Color get primaryColor => primary;
  static Color get secondaryColor => secondary;
  static Color get errorColor => error;
  static Color get successColor => success;
  static Color get warningColor => warning;
  static Color get surfaceColor => surface;
  static Color get borderColor => divider;
  static Color get textTertiary => textSecondary;
  static Color get highlightColor => secondary;
}
