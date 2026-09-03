import 'dart:ui';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contrastRatio matches known WCAG values', () {
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21, 0.01));
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFF000000)),
        closeTo(1, 0.01));
    // The measured failure that prompted this: brand indigo on the dark card.
    expect(contrastRatio(AppColors.brandPrimary, const Color(0xFF1F1E2F)),
        closeTo(2.6, 0.15));
  });

  test('ensureContrast lifts a failing accent to AA', () {
    const card = Color(0xFF1F1E2F);
    final fixed = ensureContrast(AppColors.brandPrimary, card);
    expect(contrastRatio(fixed, card),
        greaterThanOrEqualTo(kMinContrastNormalText));
  });

  test('ensureContrast leaves an already-passing colour untouched', () {
    const bg = Color(0xFF121212);
    const fg = Color(0xFFE0E0E0);
    expect(ensureContrast(fg, bg), fg);
  });

  test('darkens rather than lightens on a light background', () {
    const light = Color(0xFFFFFFFF);
    final fixed = ensureContrast(const Color(0xFFF59E0B), light);
    expect(fixed.computeLuminance(),
        lessThan(const Color(0xFFF59E0B).computeLuminance()));
    expect(contrastRatio(fixed, light),
        greaterThanOrEqualTo(kMinContrastNormalText));
  });

  test('every semantic accent is readable on both theme surfaces', () {
    const surfaces = {
      'dark': AppColors.darkSurfaceVariant,
      'light': AppColors.lightSurface,
    };
    const accents = {
      'brandPrimary': AppColors.brandPrimary,
      'info': AppColors.info,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'error': AppColors.error,
    };

    for (final surface in surfaces.entries) {
      for (final accent in accents.entries) {
        final fixed = ensureContrast(accent.value, surface.value);
        expect(
          contrastRatio(fixed, surface.value),
          greaterThanOrEqualTo(kMinContrastNormalText),
          reason: '${accent.key} on ${surface.key} surface',
        );
      }
    }
  });
}
