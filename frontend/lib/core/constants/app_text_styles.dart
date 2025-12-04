import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// Application text styles following Disciplefy brand guidelines.
///
/// Uses bundled fonts (Inter, Poppins) via AppFonts helper to avoid
/// GoogleFonts AssetManifest.json issues on web.
class AppTextStyles {
  // Display styles (Poppins for headings)
  static TextStyle displayLarge = AppFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.primary,
  );

  static TextStyle displayMedium = AppFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.primary,
  );

  // Headline styles
  static TextStyle headlineLarge = AppFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.primary,
  );

  static TextStyle headlineMedium = AppFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.primary,
  );

  // Title styles (Inter for better readability)
  static TextStyle titleLarge = AppFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static TextStyle titleMedium = AppFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static TextStyle titleSmall = AppFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Body text styles
  static TextStyle bodyLarge = AppFonts.inter(
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium = AppFonts.inter(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle bodySmall = AppFonts.inter(
    fontSize: 12,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  // Label styles
  static TextStyle labelLarge = AppFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static TextStyle labelMedium = AppFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSmall = AppFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  // Button text styles
  static TextStyle buttonLarge = AppFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle buttonMedium = AppFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle buttonSmall = AppFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Special text styles for specific use cases
  static TextStyle caption = AppFonts.inter(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static TextStyle overline = AppFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  // Payment-specific text styles
  static TextStyle paymentTitle = AppFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle paymentAmount = AppFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle paymentMethod = AppFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle error = AppFonts.inter(
    fontSize: 12,
    color: AppColors.error,
  );

  static TextStyle success = AppFonts.inter(
    fontSize: 12,
    color: AppColors.success,
  );

  // Additional getters for compatibility
  static TextStyle get headingMedium => titleMedium;
  static TextStyle get captionSmall => caption;
}
