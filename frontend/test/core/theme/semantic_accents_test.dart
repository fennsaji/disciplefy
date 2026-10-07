import 'dart:ui';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:flutter_test/flutter_test.dart';

/// The theme-resolved accents must be legible as icons (3:1) and as text
/// (4.5:1) on the surfaces of their own theme. The base tokens are not:
/// warning is 2.2:1 on white, brandGold 1.9:1 on the light page.
void main() {
  const darkSurfaces = [
    AppColors.darkBackground,
    AppColors.darkSurface,
    AppColors.darkSurfaceVariant,
  ];
  const lightSurfaces = [
    AppColors.lightBackground,
    AppColors.lightSurface,
    AppColors.lightSurfaceVariant,
  ];

  const darkAccents = {
    'success': AppColors.successLighter,
    'warning': AppColors.warningLighter,
    'error': AppColors.errorLighter,
    'info': AppColors.infoLighter,
    'brand': AppColors.brandGold,
  };
  const lightAccents = {
    'success': AppColors.successDark,
    'warning': AppColors.warningDark,
    'error': AppColors.errorDark,
    'info': AppColors.infoDark,
    'brand': AppColors.brandGoldDeep,
  };

  void check(Map<String, Color> accents, List<Color> surfaces, String theme) {
    accents.forEach((name, colour) {
      for (final surface in surfaces) {
        expect(
          contrastRatio(colour, surface),
          greaterThanOrEqualTo(kMinContrastLargeText),
          reason: '$name on $theme surface '
              '${surface.toARGB32().toRadixString(16)} is too faint for icons',
        );
      }
    });
  }

  test('dark-theme accents clear the icon threshold', () {
    check(darkAccents, darkSurfaces, 'dark');
  });

  test('light-theme accents clear the icon threshold', () {
    check(lightAccents, lightSurfaces, 'light');
  });
}
