import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';

void main() {
  for (final dark in [false, true]) {
    final palette = ReaderPalette.resolve(
        isDark: dark,
        page: dark ? AppColors.darkScaffold : AppColors.lightScaffold);
    final scrim = photoHeaderScrim(palette);
    // Header text sits in the top half of the hero (first two stops).
    for (var i = 0; i < 2; i++) {
      test('${dark ? "dark" : "light"} header text clears 4.5:1 at stop $i',
          () {
        final eyebrow = dark ? palette.gold : palette.text;
        final photo = dark ? photoLightestPixel : photoDarkestPixel;
        final bg = Color.alphaBlend(scrim[i], photo);
        expect(contrastRatio(eyebrow, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(dark ? Colors.white : palette.text, bg),
            greaterThanOrEqualTo(4.5));
      });
    }
  }
}
