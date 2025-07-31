import 'package:flutter/material.dart';

/// Utility class for common UI-related functions
class UiUtils {
  // Private constructor to prevent instantiation
  UiUtils._();

  /// Calculates the best contrasting text color for a given background color
  /// 
  /// Uses luminance calculation to determine if the background is light or dark,
  /// then returns an appropriate text color for optimal readability.
  /// 
  /// Returns [Colors.black87] for light backgrounds and [Colors.white] for dark backgrounds
  /// to maintain WCAG contrast compliance.
  /// 
  /// Example:
  /// ```dart
  /// final textColor = UiUtils.getContrastColor(Colors.blue);
  /// ```
  static Color getContrastColor(Color backgroundColor) {
    // Calculate luminance to determine if background is light or dark
    final luminance = backgroundColor.computeLuminance();

    // Return dark text for light backgrounds, light text for dark backgrounds
    // Luminance threshold of 0.5 provides good contrast ratios
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Gets the appropriate text color with null safety
  /// 
  /// Provides a safe fallback if the background color is null
  /// 
  /// Example:
  /// ```dart
  /// final textColor = UiUtils.getSafeContrastColor(theme.colorScheme.surface);
  /// ```
  static Color getSafeContrastColor(Color? backgroundColor) {
    if (backgroundColor == null) {
      return Colors.black87; // Default fallback for null colors
    }
    return getContrastColor(backgroundColor);
  }
}