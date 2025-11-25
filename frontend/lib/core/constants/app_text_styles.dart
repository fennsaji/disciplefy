import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Application text styles following Disciplefy brand guidelines
class AppTextStyles {
  // Display styles (Playfair Display for headings)
  static TextStyle displayLarge = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.primary,
  );

  static TextStyle displayMedium = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.primary,
  );

  // Headline styles
  static TextStyle headlineLarge = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.primary,
  );

  static TextStyle headlineMedium = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.primary,
  );

  // Title styles (Inter for better readability)
  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Body text styles
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  // Label styles
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  );

  // Button text styles
  static TextStyle buttonLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle buttonMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // Special text styles for specific use cases
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static TextStyle overline = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  // Payment-specific text styles
  static TextStyle paymentTitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle paymentAmount = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle paymentMethod = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle error = GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.error,
  );

  static TextStyle success = GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.success,
  );

  // Additional getters for compatibility
  static TextStyle get headingSmall => titleSmall;
  static TextStyle get headingMedium => titleMedium;
  static TextStyle get headingLarge => titleLarge;
  static TextStyle get captionSmall => caption;
  static TextStyle get bodyText => bodyMedium;
}
