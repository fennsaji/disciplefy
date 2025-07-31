import 'package:flutter/material.dart';

/// Centralized UI constants for consistent design system.
/// 
/// Contains spacing, sizing, typography, and other design tokens
/// to ensure visual consistency across the application.
class UIConstants {
  // Prevent instantiation
  UIConstants._();

  // === SPACING CONSTANTS ===
  
  /// Standard padding and margin values following 8px grid system
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  /// Common EdgeInsets patterns
  static const EdgeInsets paddingXs = EdgeInsets.all(spacingXs);
  static const EdgeInsets paddingSm = EdgeInsets.all(spacingSm);
  static const EdgeInsets paddingMd = EdgeInsets.all(spacingMd);
  static const EdgeInsets paddingLg = EdgeInsets.all(spacingLg);
  static const EdgeInsets paddingXl = EdgeInsets.all(spacingXl);

  /// Horizontal padding patterns
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: spacingSm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: spacingMd);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: spacingLg);

  /// Vertical padding patterns
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: spacingSm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: spacingMd);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: spacingLg);

  /// Page-level margins
  static const EdgeInsets pageMarginHorizontal = EdgeInsets.symmetric(horizontal: spacingLg);
  static const EdgeInsets sectionMarginVertical = EdgeInsets.symmetric(vertical: spacingMd);

  // === BORDER RADIUS CONSTANTS ===
  
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusCircular = 50.0;

  /// Common BorderRadius patterns
  static const BorderRadius borderRadiusXs = BorderRadius.all(Radius.circular(radiusXs));
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));

  // === TYPOGRAPHY CONSTANTS ===
  
  /// Font size scale following Material Design type scale
  static const double fontSizeXs = 10.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeMd = 14.0;
  static const double fontSizeLg = 16.0;
  static const double fontSizeXl = 18.0;
  static const double fontSizeXxl = 20.0;
  static const double fontSizeXxxl = 24.0;
  static const double fontSizeHeadline = 28.0;
  static const double fontSizeDisplay = 32.0;

  /// Font weight constants
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // === SIZING CONSTANTS ===
  
  /// Icon sizes
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 40.0;

  /// Avatar/Profile image sizes
  static const double avatarSizeSm = 32.0;
  static const double avatarSizeMd = 48.0;
  static const double avatarSizeLg = 64.0;
  static const double avatarSizeXl = 80.0;

  /// Button heights
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 52.0;

  /// Card and container sizing
  static const double cardMinHeight = 120.0;
  static const double cardMaxWidth = 400.0;
  static const double containerMaxWidth = 600.0;

  // === ELEVATION CONSTANTS ===
  
  static const double elevationNone = 0.0;
  static const double elevationSm = 1.0;
  static const double elevationMd = 2.0;
  static const double elevationLg = 4.0;
  static const double elevationXl = 8.0;

  // === OPACITY CONSTANTS ===
  
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.60;
  static const double opacityLight = 0.12;
  static const double opacityOverlay = 0.16;

  // === ANIMATION CONSTANTS ===
  
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  /// Common animation curves
  static const Curve animationCurveDefault = Curves.easeInOut;
  static const Curve animationCurveEmphasized = Curves.easeOutCubic;

  // === BREAKPOINT CONSTANTS ===
  
  static const double breakpointMobile = 480.0;
  static const double breakpointTablet = 768.0;
  static const double breakpointDesktop = 1024.0;

  // === SPECIALIZED SIZING ===
  
  /// Language tab specific sizing
  static const double languageTabHeight = 44.0;
  static const double languageTabPadding = 14.0;

  /// Action button specific sizing  
  static const double actionButtonPadding = 12.0;
  static const double actionButtonSpacing = 16.0;

  /// Profile section specific sizing
  static const double profileSectionPadding = 16.0;
  static const double profileAvatarSize = avatarSizeLg; // 64.0
  static const double profileInfoSpacing = 16.0;

  /// Chip styling
  static const double chipPaddingHorizontal = 8.0;
  static const double chipPaddingVertical = 4.0;
  static const double chipBorderRadius = radiusMd; // 12.0
  static const double chipIconSize = iconSizeXs; // 16.0

  // === HELPER METHODS ===
  
  /// Get responsive padding based on screen width
  static EdgeInsets getResponsivePadding(double screenWidth) {
    if (screenWidth < breakpointMobile) {
      return paddingMd; // 16px on mobile
    } else if (screenWidth < breakpointTablet) {
      return paddingLg; // 20px on large mobile/small tablet
    } else {
      return paddingXl; // 24px on tablet/desktop
    }
  }

  /// Get responsive text size based on screen width
  static double getResponsiveFontSize(double screenWidth, double baseFontSize) {
    if (screenWidth < breakpointMobile) {
      return baseFontSize * 0.9; // Slightly smaller on mobile
    } else if (screenWidth < breakpointTablet) {
      return baseFontSize; // Base size on tablet
    } else {
      return baseFontSize * 1.1; // Slightly larger on desktop
    }
  }

  /// Get appropriate spacing based on content density
  static double getContextualSpacing({
    required bool isCompact,
    double normalSpacing = spacingMd,
  }) => isCompact ? normalSpacing * 0.75 : normalSpacing;
}