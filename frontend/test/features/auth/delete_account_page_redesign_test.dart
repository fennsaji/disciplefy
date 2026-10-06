import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/delete_account_page.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  setUpAll(loadAppFonts);

  final launched = <MethodCall>[];

  setUp(() {
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlChannel, (call) async {
      launched.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlChannel, null);
  });

  Widget app(Widget home, {required bool dark}) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: home,
      );

  group('DeleteAccountPage', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';

      testWidgets('$mode: palette page, all sections, fits 320x640',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(welcomeApp(
            screen: const DeleteAccountPage(),
            path: '/delete-account',
            dark: dark));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(DeleteAccountPage));
        final palette = ReaderPalette.of(context);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, palette.page);
        expect(find.byType(AppBar), findsNothing);

        for (final text in [
          'Delete Account',
          'Delete Your Disciplefy Account',
          'Permanent Deletion',
          'HOW TO DELETE YOUR ACCOUNT',
          'WHAT GETS DELETED',
          'WHAT IS KEPT',
          'QUESTIONS?',
          'contact@disciplefy.in',
          'Profile — name, picture, and preferences',
          'Confirm the deletion in the dialog that appears.',
        ]) {
          await tester.scrollUntilVisible(find.text(text), 80,
              scrollable: find.byType(Scrollable).first);
          expect(find.text(text), findsOneWidget, reason: text);
        }

        final eyebrow = tester.widget<Text>(find.text('WHAT GETS DELETED'));
        expect(eyebrow.style?.color, palette.gold);

        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('delete-account-request')), 80,
            scrollable: find.byType(Scrollable).first);
        final cta = tester.widget<SettingsButton>(
            find.byKey(const ValueKey('delete-account-request')));
        expect(cta.kind, SettingsButtonKind.destructive);
        expect(truncatedTexts(tester), isEmpty);
      });
    }

    testWidgets('request CTA opens the deletion email', (tester) async {
      useSurface(tester, const Size(320, 640));
      await tester.pumpWidget(welcomeApp(
          screen: const DeleteAccountPage(),
          path: '/delete-account',
          dark: true));
      await tester.pumpAndSettle();
      final cta = find.byKey(const ValueKey('delete-account-request'));
      await tester.scrollUntilVisible(cta, 80,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      final urls = launched
          .map((c) => (c.arguments as Map)['url'] as String?)
          .whereType<String>()
          .toList();
      expect(urls, isNotEmpty);
      expect(urls.first, startsWith('mailto:contact@disciplefy.in'));
      expect(launched.map((c) => c.method), contains('launch'));
    });

    test('deletion email carries subject and body', () {
      final uri = DeleteAccountPage.deletionEmailUri;
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'contact@disciplefy.in');
      expect(uri.queryParameters['subject'], 'Account Deletion Request');
      expect(uri.queryParameters['body'], contains('Registered email'));
    });

    testWidgets('back arrow only when the page can pop', (tester) async {
      await tester.pumpWidget(welcomeApp(
          screen: const DeleteAccountPage(), path: '/delete-account'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('SettingsLoaderCard', () {
    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'}: card with gold spinner',
          (tester) async {
        await tester.pumpWidget(app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsLoader(context),
              child: const Text('go'),
            ),
          ),
          dark: dark,
        ));
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SettingsLoaderCard), findsOneWidget);
        final palette =
            ReaderPalette.of(tester.element(find.byType(SettingsLoaderCard)));
        final spinner = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        expect(spinner.color, palette.gold);

        // Not dismissible by tapping the barrier.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SettingsLoaderCard), findsOneWidget);

        Navigator.of(tester.element(find.byType(SettingsLoaderCard)),
                rootNavigator: true)
            .pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(SettingsLoaderCard), findsNothing);
      });
    }
  });
}
