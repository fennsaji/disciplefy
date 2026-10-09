import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/models/app_language.dart';

/// Phone widths every redesigned surface must fit: the 360px target and the
/// narrowest supported (320px).
const fitWidths = <double>[360, 320];

/// The languages whose script runs widest.
const fitLanguages = <String>['hi', 'ml'];

/// One combination of width, language and theme for a fit test.
class FitCase {
  final double width;
  final String lang;
  final bool dark;

  const FitCase(this.width, this.lang, this.dark);

  AppLanguage get language => AppLanguage.fromCode(lang);

  Size size([double height = 780]) => Size(width, height);

  /// e.g. "360px ml dark".
  String get name => '${width.toInt()}px $lang ${dark ? 'dark' : 'light'}';

  @override
  String toString() => name;
}

/// Every width x language x theme combination (8 by default).
List<FitCase> fitCases({
  List<double> widths = fitWidths,
  List<String> languages = fitLanguages,
  List<bool> themes = const [false, true],
}) =>
    [
      for (final width in widths)
        for (final lang in languages)
          for (final dark in themes) FitCase(width, lang, dark),
    ];

/// Sets the test surface to [c]'s width (dpr 1) and resets it afterwards.
void useFitSurface(WidgetTester tester, FitCase c, {double height = 780}) {
  tester.view.physicalSize = c.size(height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
