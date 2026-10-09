import 'package:flutter/material.dart';

/// Visual style for learning path tiles, keyed by the path's `disciple_level`.
///
/// Every path tile/card uses these gradients (same in light and dark theme).
class PathLevelStyle {
  PathLevelStyle._();

  static const _seeker = [Color(0xFF2563EB), Color(0xFF0EA5E9)];
  static const _follower = [Color(0xFF0F766E), Color(0xFF059669)];
  static const _disciple = [Color(0xFF6D28D9), Color(0xFFBE185D)];
  static const _leader = [Color(0xFFB45309), Color(0xFFEA580C)];

  /// Tracked gold used for tile eyebrows on top of the gradient.
  static const Color eyebrowGold = Color(0xFFF5C451);

  /// The two gradient stops for [discipleLevel]; unknown levels use seeker.
  static List<Color> colorsFor(String? discipleLevel) {
    switch (discipleLevel?.trim().toLowerCase()) {
      case 'follower':
        return _follower;
      case 'disciple':
        return _disciple;
      case 'leader':
        return _leader;
      case 'seeker':
      default:
        return _seeker;
    }
  }

  /// 135° (top-left → bottom-right) linear gradient for [discipleLevel].
  static LinearGradient gradientFor(String? discipleLevel) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colorsFor(discipleLevel),
    );
  }

  /// White highlight in the top-right corner fading to transparent.
  static const RadialGradient highlight = RadialGradient(
    center: Alignment.topRight,
    radius: 1.1,
    colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
  );

  /// Dark scrim at the bottom so text stays readable.
  static const LinearGradient bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 1.0],
    colors: [Color(0x00000000), Color(0x8C000000)],
  );

  /// Faint white used for the large icon motif.
  static const Color motifColor = Color(0x59FFFFFF);

  /// Full layered decoration: gradient + highlight + scrim.
  ///
  /// Use as the background of a [Stack]; draw the icon motif and text on top.
  static Widget background(String? discipleLevel, {BorderRadius? radius}) {
    final r = radius ?? BorderRadius.circular(18);
    return ClipRRect(
      borderRadius: r,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradientFor(discipleLevel)),
        child: const DecoratedBox(
          decoration: BoxDecoration(gradient: highlight),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: bottomScrim),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
