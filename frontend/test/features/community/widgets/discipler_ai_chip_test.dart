import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';

/// The chip is a filled pill, and dark mode resolves the primary to the *light*
/// indigo — so a hardcoded white label sat at roughly 1.6:1 and read as a
/// smudge. The label colour has to follow the fill.
double _contrast(Color a, Color b) {
  double luminance(Color c) => c.computeLuminance();
  final l1 = luminance(a), l2 = luminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<Color> _labelColour(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: Center(child: DisciplerAiChip())),
  ));
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.text('AI')).style!.color!;
}

void main() {
  testWidgets('the AI label stays readable on the light theme', (tester) async {
    final theme = AppTheme.lightTheme;
    final label = await _labelColour(tester, theme);

    expect(_contrast(label, theme.colorScheme.primary), greaterThan(4.5));
  });

  testWidgets('the AI label stays readable on the dark theme', (tester) async {
    final theme = AppTheme.darkTheme;
    final label = await _labelColour(tester, theme);

    // The regression: white here scored ~1.6:1 against the pale indigo fill.
    expect(_contrast(label, theme.colorScheme.primary), greaterThan(4.5));
    expect(label, isNot(Colors.white));
  });
}
