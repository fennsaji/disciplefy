import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/notifications/presentation/pages/notification_settings_screen.dart';

void main() {
  Future<TimeOfDay?> Function() openPicker(
    WidgetTester tester, {
    required ThemeData theme,
    required Locale locale,
  }) {
    late BuildContext hostContext;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return () async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('ml')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(builder: (context) {
          hostContext = context;
          return const Scaffold();
        }),
      ));
      TimeOfDay? result;
      showTimePicker(
        context: hostContext,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
        builder: (ctx, child) => Theme(
          data: reminderTimePickerTheme(Theme.of(ctx), ReaderPalette.of(ctx)),
          child: child!,
        ),
      ).then((value) => result = value);
      await tester.pumpAndSettle();
      return result;
    };
  }

  for (final (label, theme) in [
    ('dark', AppTheme.darkTheme),
    ('light', AppTheme.lightTheme),
  ]) {
    for (final lang in ['en', 'hi', 'ml']) {
      testWidgets('reminder picker uses palette in $label/$lang at 320x640',
          (tester) async {
        await openPicker(tester, theme: theme, locale: Locale(lang))();
        expect(tester.takeException(), isNull);

        final pickerContext = tester.element(find.byType(TimePickerDialog));
        final palette = ReaderPalette.of(pickerContext);
        final pickerTheme = Theme.of(pickerContext).timePickerTheme;
        expect(pickerTheme.backgroundColor, palette.card);
        expect(pickerTheme.dialHandColor, palette.ctaFill);
        expect(pickerTheme.dialBackgroundColor, palette.raised);
      });
    }
  }

  testWidgets('confirming the picker still returns the chosen time',
      (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Builder(builder: (context) {
        hostContext = context;
        return const Scaffold();
      }),
    ));
    TimeOfDay? result;
    showTimePicker(
      context: hostContext,
      initialTime: const TimeOfDay(hour: 8, minute: 30),
      builder: (ctx, child) => Theme(
        data: reminderTimePickerTheme(Theme.of(ctx), ReaderPalette.of(ctx)),
        child: child!,
      ),
    ).then((value) => result = value);
    await tester.pumpAndSettle();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 8, minute: 30));
  });
}
