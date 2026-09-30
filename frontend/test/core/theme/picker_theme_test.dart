import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/status_message_view.dart';
import 'package:disciplefy_bible_study/main.dart' show ErrorApp;

/// The stock date and time pickers are themed app-wide from the reader
/// palette, and the fatal init screen uses the app themes.
void main() {
  void useSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final dark in [true, false]) {
    final name = dark ? 'dark' : 'light';
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final palette = ReaderPalette.resolve(
      isDark: dark,
      page: dark ? AppColors.darkScaffold : AppColors.lightScaffold,
    );

    test('$name: picker themes use the palette card, gold and ctaFill', () {
      final time = theme.timePickerTheme;
      expect(time.backgroundColor, palette.card);
      expect(time.helpTextStyle?.color, palette.gold);
      expect(time.dialHandColor, palette.ctaFill);
      final hourMinute = time.hourMinuteColor! as WidgetStateColor;
      expect(hourMinute.resolve({WidgetState.selected}), palette.ctaFill);
      expect(hourMinute.resolve({}), palette.raised);

      final date = theme.datePickerTheme;
      expect(date.backgroundColor, palette.card);
      expect(date.surfaceTintColor, Colors.transparent);
      expect(date.headerHelpStyle?.color, palette.gold);
      expect(
        date.dayBackgroundColor?.resolve({WidgetState.selected}),
        palette.ctaFill,
      );
      expect(date.todayBorder?.color, palette.gold);
    });

    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        }),
      ));
      return host;
    }

    testWidgets('$name: time picker opens at 320x640 and OK returns the time',
        (tester) async {
      useSurface(tester, const Size(320, 640));
      final host = await pumpHost(tester);
      TimeOfDay? picked;
      showTimePicker(
        context: host,
        initialTime: const TimeOfDay(hour: 7, minute: 30),
      ).then((value) => picked = value);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(picked, const TimeOfDay(hour: 7, minute: 30));
    });

    testWidgets('$name: date picker opens at 320x640 and OK returns the date',
        (tester) async {
      useSurface(tester, const Size(320, 640));
      final host = await pumpHost(tester);
      DateTime? picked;
      showDatePicker(
        context: host,
        initialDate: DateTime(2026, 9, 30),
        firstDate: DateTime(2026),
        lastDate: DateTime(2027),
      ).then((value) => picked = value);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 9, 30));
    });

    testWidgets('$name: init-failure screen uses the status view',
        (tester) async {
      useSurface(tester, const Size(320, 640));
      tester.platformDispatcher.platformBrightnessTestValue =
          dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const ErrorApp());
      await tester.pumpAndSettle();

      expect(find.byType(StatusMessageView), findsOneWidget);
      expect(find.text('App failed to initialize'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
