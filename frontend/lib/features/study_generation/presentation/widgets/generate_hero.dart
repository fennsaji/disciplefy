import 'dart:math' as math;

import 'package:disciplefy_bible_study/core/constants/hero_images.dart';
import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/depth_mode_cards.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';

/// Photo behind the Generate screen's hero.
const String generateHeroImage = 'assets/images/hero/snow_peaks.webp';

/// Photo behind the Generate tab's header, washed so the header text reads
/// (dark shade in dark mode, light wash in light mode) and faded into the
/// page background at its bottom edge.
class GenerateHeroBackdrop extends StatelessWidget {
  const GenerateHeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final page = palette.page;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    // Dark: a light black shade, so the mountains still read behind the
    // verse row and "Choose depth" as in the design; from 60% of the hero
    // down (where the depth header sits) secondary text still clears 4.5:1
    // over the blurred photo. Light: the design fades the photo into the
    // page by the chips row, so the wash reaches 94% page colour there.
    final shade = palette.isDark
        ? [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.30),
            page.withValues(alpha: 0.62),
            page,
          ]
        : [
            page.withValues(alpha: 0.88),
            page.withValues(alpha: 0.72),
            page.withValues(alpha: 0.94),
            page,
          ];
    final stops = palette.isDark
        ? const [0.0, 0.42, 0.72, 1.0]
        : const [0.0, 0.40, 0.56, 0.72];

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          // Decode only the pixels shown: the photo is 3:2 and covers the
          // box, so decode width follows whichever side "cover" fills.
          final coverWidth = math.max(box.maxWidth, box.maxHeight * 1.5);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                generateHeroImage,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                // Tiny decode: the upscale blurs the photo into a wash.
                cacheWidth: photoWashDecodeWidth,
                errorBuilder: (_, __, ___) => ColoredBox(color: page),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: shade,
                    stops: stops,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Text colours for content drawn over [GenerateHeroBackdrop].
class GenerateHeroInk {
  final Color text;
  final Color muted;

  const GenerateHeroInk._(this.text, this.muted);

  factory GenerateHeroInk.of(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return palette.isDark
        ? GenerateHeroInk._(Colors.white, Colors.white.withValues(alpha: 0.62))
        : GenerateHeroInk._(palette.text, palette.muted);
  }
}

/// Gold outlined credit balance pill in the header.
class TokenBalancePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  /// Shown when the balance could not be refreshed (last known value).
  final bool isStale;

  const TokenBalancePill({
    super.key,
    required this.label,
    required this.onTap,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final color = isStale ? AppColors.warningDark : palette.gold;
    return Semantics(
      button: true,
      child: Material(
        color: color.withValues(alpha: palette.isDark ? 0.10 : 0.08),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.55)),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isStale ? Icons.warning_amber_rounded : Icons.toll_outlined,
                  size: 17,
                  color: color,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Underlined text tabs (Scripture / Topic / Question) over the hero.
class InputTypeTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const InputTypeTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = GenerateHeroInk.of(context);

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Flexible(
            child: Semantics(
              selected: i == selectedIndex,
              button: true,
              child: InkWell(
                key: ValueKey('input_type_tab_$i'),
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shrinks on narrow phones instead of cutting.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == selectedIndex ? ink.text : ink.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == selectedIndex
                              ? palette.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 24),
        ],
      ],
    );
  }
}

/// Full-width primary pill: "Generate study" + credit cost chip.
class GenerateStudyButton extends StatelessWidget {
  final String label;
  final int? cost;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  /// Drawn over the pill (e.g. the offline notice).
  final Widget? overlay;

  const GenerateStudyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.cost,
    this.enabled = true,
    this.loading = false,
    this.overlay,
  });

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final active = enabled && !loading;
    final fill = active ? palette.ctaFill : palette.disabledFill;
    final ink = active ? palette.ctaInk : palette.disabledInk;
    // Cost chip: a soft gold wash on the white dark-theme pill, a white
    // wash on the ink light-theme pill.
    final chipFill = !active
        ? Colors.transparent
        : palette.isDark
            ? palette.gold.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.2);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: fill,
              shape: const StadiumBorder(),
              child: InkWell(
                key: const Key('generate_study_button'),
                onTap: active ? onPressed : null,
                customBorder: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading) ...[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(ink),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: AppFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                      if (!loading && cost != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: chipFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CreditCost(cost: cost!, color: ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (overlay != null) Positioned.fill(child: overlay!),
        ],
      ),
    );
  }
}
