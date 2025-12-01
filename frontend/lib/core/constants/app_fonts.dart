import 'package:flutter/material.dart';

/// Application fonts using bundled font families.
///
/// This class provides helper methods to create TextStyles using the bundled
/// fonts (Inter and Poppins) from pubspec.yaml without relying on GoogleFonts
/// package which requires runtime fetching or AssetManifest.json lookup.
///
/// Usage:
/// ```dart
/// Text('Hello', style: AppFonts.inter(fontSize: 16, fontWeight: FontWeight.w500))
/// Text('Title', style: AppFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold))
/// ```
class AppFonts {
  /// Font family names as defined in pubspec.yaml
  static const String interFamily = 'Inter';
  static const String poppinsFamily = 'Poppins';

  /// Creates a TextStyle using the Inter font family (bundled).
  ///
  /// Inter is used for body text, titles, labels, and UI elements
  /// for better readability across all sizes.
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextBaseline? textBaseline,
    String? debugLabel,
    TextOverflow? overflow,
  }) {
    return TextStyle(
      fontFamily: interFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      color: color,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      textBaseline: textBaseline,
      debugLabel: debugLabel,
      overflow: overflow,
    );
  }

  /// Creates a TextStyle using the Poppins font family (bundled).
  ///
  /// Poppins is used for headings and display text to provide
  /// visual hierarchy and brand consistency.
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextBaseline? textBaseline,
    String? debugLabel,
    TextOverflow? overflow,
  }) {
    return TextStyle(
      fontFamily: poppinsFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      color: color,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      textBaseline: textBaseline,
      debugLabel: debugLabel,
      overflow: overflow,
    );
  }
}
