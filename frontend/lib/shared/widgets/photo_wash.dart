import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/hero_images.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// A scenery photo reduced to a soft colour wash behind the top of a
/// community screen (My fellowships, Discover, Fellowship home).
///
/// The photo must never read as a picture, only as a tint. Blur filters are
/// too heavy for low-end phones, so the photo is decoded at a tiny width
/// ([decodeWidth] pixels) and scaled up: the upscale smears it into a wash for
/// free. A vertical gradient then fades it into the page colour.
///
/// Lays out as a [Stack]: page colour, the wash across the top [height]
/// logical pixels, then [child] on top filling the whole area.
/// Width, in pixels, a scenery photo is decoded at when it should read as a
/// soft blurred wash rather than a picture. Upscaling a photo this small
/// blurs it for free, with no blur filter.
const int photoWashDecodeWidth = 8;

/// Lightest and darkest pixels the scenery photos can show, used to check
/// text over the wash against the worst case.
const Color photoLightestPixel = Color(0xFFF6DCCB);
const Color photoDarkestPixel = Color(0xFF7A4A3A);

/// Scrim over a photo under header text (study guide hero). Dark: black strong
/// enough that gold and white text clear 4.5:1 over the lightest photo pixel;
/// light: a page-colour veil that keeps ink readable over the darkest one.
List<Color> photoHeaderScrim(ReaderPalette palette) => palette.isDark
    ? [
        Colors.black.withValues(alpha: 0.74),
        Colors.black.withValues(alpha: 0.72),
        palette.page.withValues(alpha: 0.7),
        palette.page,
      ]
    : [
        palette.page.withValues(alpha: 0.94),
        palette.page.withValues(alpha: 0.9),
        palette.page.withValues(alpha: 0.92),
        palette.page,
      ];

/// Stops for [photoHeaderScrim].
const List<double> photoHeaderScrimStops = [0, 0.5, 0.8, 1];

class PhotoWash extends StatelessWidget {
  /// The photo used by the Community tab (My fellowships and Discover).
  static const String communityTabImage = 'assets/images/hero/valley_mist.webp';

  /// Asset path of the photo, from [heroImages].
  final String image;

  /// Content drawn over the wash.
  final Widget child;

  /// How far down the screen the wash reaches before it is page colour.
  final double height;

  /// Width, in pixels, the photo is decoded at. Tiny on purpose.
  final int decodeWidth;

  const PhotoWash({
    super.key,
    required this.image,
    required this.child,
    this.height = 440,
    this.decodeWidth = photoWashDecodeWidth,
  });

  /// A wash whose photo is picked from [key] (e.g. a fellowship id), so the
  /// same fellowship always keeps the same tint.
  factory PhotoWash.forKey({
    Key? key,
    required String photoKey,
    required Widget child,
    double height = 440,
  }) =>
      PhotoWash(
        key: key,
        image: heroImageForKey(photoKey),
        height: height,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final page = palette.page;
    // Dark: a slight darkening at the top so white titles hold, fully page
    // colour by ~75%. Light: a page-colour veil so dark ink stays readable.
    final shade = palette.isDark
        ? [
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.5).withValues(alpha: 0.6),
            page.withValues(alpha: 0.88),
            page,
          ]
        : [
            page.withValues(alpha: 0.85),
            page.withValues(alpha: 0.8),
            page.withValues(alpha: 0.93),
            page,
          ];

    return ColoredBox(
      color: page,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    image,
                    fit: BoxFit.cover,
                    cacheWidth: decodeWidth,
                    // Default filterQuality (medium) smooths the upscale.
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => ColoredBox(color: page),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: shade,
                        stops: const [0, 0.3, 0.62, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
