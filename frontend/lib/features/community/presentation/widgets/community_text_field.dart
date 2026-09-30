import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Input decoration for community text fields (comment composer, report
/// reason, search, new post): raised fill, hairline outline, accent outline
/// when focused.
///
/// [pill] rounds the field fully (single-line composer and search fields).
InputDecoration communityInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool pill = false,
  EdgeInsetsGeometry? contentPadding,
  int hintMaxLines = 3,
}) {
  final palette = ReaderPalette.of(context);
  final radius = BorderRadius.circular(pill ? 28 : 16);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
    labelStyle: AppFonts.inter(fontSize: 14, color: palette.muted),
    hintMaxLines: hintMaxLines,
    filled: true,
    fillColor: palette.raised,
    isDense: true,
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    border: border(palette.hairline),
    enabledBorder: border(palette.hairline),
    focusedBorder: border(palette.accentIcon, 1.5),
  );
}
