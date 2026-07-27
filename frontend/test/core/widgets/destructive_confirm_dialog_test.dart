import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/widgets/destructive_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/mock_translation_provider.dart';
import 'destructive_confirm_dialog_test.mocks.dart';

@GenerateMocks([TranslationService])
void main() {
  late MockTranslationService mockTranslationService;

  setUpAll(() {
    mockTranslationService = MockTranslationService();
    when(mockTranslationService.getTranslation(any, any)).thenAnswer(
      (invocation) {
        final key = invocation.positionalArguments[0] as String;
        switch (key) {
          case TranslationKeys.resetProgressCancel:
            return 'Cancel';
          case TranslationKeys.resetProgressTypeToConfirm:
            return 'Type {word} to confirm';
          case TranslationKeys.resetProgressIrreversible:
            return 'This cannot be undone.';
          default:
            return key;
        }
      },
    );
    sl.registerLazySingleton<TranslationService>(() => mockTranslationService);
  });

  tearDownAll(() {
    sl.reset();
  });

  /// Pumps a screen with a button that opens the dialog, and records the
  /// value the dialog resolves with.
  Future<void> pumpHost(
    WidgetTester tester, {
    required List<bool?> results,
  }) async {
    await tester.pumpWidget(
      MockTranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final confirmed = await DestructiveConfirmDialog.show(
                    context,
                    title: 'Reset memory verses?',
                    consequences: const [
                      'All 42 verses will be deleted',
                      'Practice history will be deleted',
                    ],
                    confirmWord: 'RESET',
                    confirmLabel: 'Reset',
                  );
                  results.add(confirmed);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title and every consequence line', (tester) async {
    await pumpHost(tester, results: []);

    expect(find.text('Reset memory verses?'), findsOneWidget);
    expect(find.text('All 42 verses will be deleted'), findsOneWidget);
    expect(find.text('Practice history will be deleted'), findsOneWidget);
  });

  testWidgets('confirm button is disabled before anything is typed',
      (tester) async {
    await pumpHost(tester, results: []);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirm button stays disabled for the wrong word',
      (tester) async {
    await pumpHost(tester, results: []);

    await tester.enterText(find.byType(TextField), 'RESE');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirm button enables on the exact word and returns true',
      (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    await tester.enterText(find.byType(TextField), 'RESET');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('accepts the confirm word regardless of case and whitespace',
      (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    await tester.enterText(find.byType(TextField), '  reset ');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets(
      'accepts the English "RESET" fallback even when confirmWord is '
      'localized (hi/ml users without an Indic keyboard are not locked out)',
      (tester) async {
    final results = <bool?>[];
    await tester.pumpWidget(
      MockTranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final confirmed = await DestructiveConfirmDialog.show(
                    context,
                    title: 'Reset memory verses?',
                    consequences: const ['All verses will be deleted'],
                    confirmWord: 'रीसेट', // Hindi confirm word
                    confirmLabel: 'Reset',
                  );
                  results.add(confirmed);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Typing the English fallback instead of the Hindi word must still work.
    await tester.enterText(find.byType(TextField), 'reset');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('cancel resolves to false', (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    await tester.enterText(find.byType(TextField), 'RESET');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('dismissing via the barrier resolves to false', (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    // Tap the barrier away from its center, since the AlertDialog is
    // centered on the same point and would otherwise absorb the tap.
    final barrier = find.byType(ModalBarrier).last;
    await tester.tapAt(tester.getTopLeft(barrier) + const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Reset memory verses?'), findsNothing);
    expect(results, [false]);
  });
}
