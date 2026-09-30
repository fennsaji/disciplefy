import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/domain/entities/purchase_issue_entity.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/bloc/purchase_issue_bloc.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/bloc/purchase_issue_event.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/bloc/purchase_issue_state.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/widgets/report_issue_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/purchase_history.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/purchase_history_card.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockPurchaseIssueBloc
    extends MockBloc<PurchaseIssueEvent, PurchaseIssueState>
    implements PurchaseIssueBloc {}

final _purchase = PurchaseHistory(
  id: 'p1',
  tokenAmount: 100,
  costRupees: 49,
  costPaise: 4900,
  paymentId: 'pay_Nx8a7b6c5d4e3f',
  orderId: 'order_1',
  paymentMethod: 'upi',
  status: 'completed',
  purchasedAt: DateTime(2026, 9, 1, 10, 30),
);

final _formReady = PurchaseIssueFormReady(
  purchaseId: 'p1',
  paymentId: 'pay_Nx8a7b6c5d4e3f',
  orderId: 'order_1',
  tokenAmount: 100,
  costRupees: 49,
  purchasedAt: DateTime(2026, 9, 1, 10, 30),
);

const _languages = [
  AppLanguage.english,
  AppLanguage.hindi,
  AppLanguage.malayalam,
];

void main() {
  late FakeTranslationService translations;
  late _MockPurchaseIssueBloc bloc;

  setUpAll(() async {
    await loadAppFonts();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDownAll(sl.reset);

  setUp(() {
    translations.language = AppLanguage.english;
    bloc = _MockPurchaseIssueBloc();
    when(() => bloc.state).thenReturn(_formReady);
    if (sl.isRegistered<PurchaseIssueBloc>()) {
      sl.unregister<PurchaseIssueBloc>();
    }
    sl.registerFactory<PurchaseIssueBloc>(() => bloc);
  });

  /// Pumps a page whose button opens the sheet the way the app does.
  Future<void> openSheet(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showReportIssueBottomSheet(context, _purchase),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final language in _languages) {
      testWidgets(
          '${dark ? 'dark' : 'light'} 320x640 ${language.code}: '
          'no overflow or cut-off text', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await openSheet(tester, dark: dark);

        expect(find.byType(ReportIssueBottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(truncatedTexts(tester), isEmpty);

        // Scroll to the submit pill and check the lower half too.
        await tester.dragUntilVisible(
          find.byType(PopupPrimaryButton),
          find.byType(ReportIssueBottomSheet),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(truncatedTexts(tester), isEmpty);
      });
    }
  }

  testWidgets('shows translated header and transaction details',
      (tester) async {
    await openSheet(tester, dark: true);
    expect(find.text('Report Issue'), findsOneWidget);
    expect(find.text('PURCHASE SUPPORT'), findsOneWidget);
    expect(find.text('TRANSACTION DETAILS'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('₹49.00'), findsOneWidget);
    expect(find.text('pay_Nx8a7b6c5d4e3f'), findsOneWidget);
    expect(find.text('Other Issue'), findsOneWidget);
  });

  testWidgets('submit is disabled until 10 characters, then submits',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    await openSheet(tester, dark: false);

    FilledButton submit() => tester.widget<FilledButton>(find.descendant(
        of: find.byType(PopupPrimaryButton),
        matching: find.byType(FilledButton)));

    expect(submit().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'short');
    await tester.pump();
    expect(find.text('Please enter at least 10 characters'), findsOneWidget);
    expect(submit().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Charged twice today');
    await tester.pump();
    verify(() => bloc
            .add(const DescriptionChanged(description: 'Charged twice today')))
        .called(1);
    expect(submit().onPressed, isNotNull);

    await tester.ensureVisible(find.byType(PopupPrimaryButton));
    await tester.tap(find.byType(PopupPrimaryButton));
    verify(() => bloc.add(const SubmitPurchaseIssueRequested())).called(1);
  });

  testWidgets('choosing an issue type dispatches IssueTypeChanged',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    await openSheet(tester, dark: true);

    await tester.tap(find.text('Other Issue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate Charge').last);
    await tester.pumpAndSettle();

    verify(() => bloc.add(const IssueTypeChanged(
        issueType: PurchaseIssueType.duplicateCharge))).called(1);
    expect(find.text('Duplicate Charge'), findsOneWidget);
  });

  testWidgets('success shows the app snackbar and closes the sheet',
      (tester) async {
    whenListen(
      bloc,
      Stream<PurchaseIssueState>.fromIterable([
        const PurchaseIssueSubmitSuccess(message: 'Report sent'),
      ]),
      initialState: _formReady,
    );
    await openSheet(tester, dark: true);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Report sent'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(ReportIssueBottomSheet), findsNothing);
  });

  group('PurchaseHistoryCard', () {
    final withReceipt = PurchaseHistory(
      id: 'p2',
      tokenAmount: 100,
      costRupees: 49,
      costPaise: 4900,
      paymentId: 'pay_1',
      orderId: 'order_1',
      paymentMethod: 'upi',
      status: 'failed',
      receiptNumber: 'RCPT-0042',
      purchasedAt: DateTime(2026, 9, 1, 10, 30),
    );

    Future<void> pumpCard(WidgetTester tester, {required bool dark}) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PurchaseHistoryCard(purchase: withReceipt),
          ),
        ),
      ));
    }

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'}: copying shows the app snackbar',
          (tester) async {
        await pumpCard(tester, dark: dark);
        await tester.tap(find.text('RCPT-0042'));
        await tester.pumpAndSettle();

        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.behavior, SnackBarBehavior.floating);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      });
    }

    testWidgets('report issue link still opens the report sheet',
        (tester) async {
      await pumpCard(tester, dark: true);
      await tester.tap(find.textContaining('Report'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportIssueBottomSheet), findsOneWidget);
    });
  });
}
