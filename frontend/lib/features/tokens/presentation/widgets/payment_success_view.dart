import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// What the user chose on the [PaymentSuccessView].
enum PaymentSuccessAction { startStudy, backToCredits }

/// Shows [PaymentSuccessView] as a full-screen step over the purchase page and
/// resolves with the button the user tapped ([PaymentSuccessAction.backToCredits]
/// when dismissed with the system back gesture).
Future<PaymentSuccessAction> showPaymentSuccess(
  BuildContext context, {
  required int creditsAdded,
  required int newBalance,
  String? amountPaid,
  String? receipt,
  DateTime? paidAt,
}) async {
  final action = await Navigator.of(context).push<PaymentSuccessAction>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaymentSuccessView(
        creditsAdded: creditsAdded,
        newBalance: newBalance,
        amountPaid: amountPaid,
        receipt: receipt,
        paidAt: paidAt ?? DateTime.now(),
      ),
    ),
  );
  return action ?? PaymentSuccessAction.backToCredits;
}

/// "Payment successful" confirmation after a credit pack purchase: a green
/// check, the credits added, the new balance and a small receipt ledger.
class PaymentSuccessView extends StatelessWidget {
  final int creditsAdded;
  final int newBalance;
  final String? amountPaid;
  final String? receipt;
  final DateTime paidAt;

  const PaymentSuccessView({
    super.key,
    required this.creditsAdded,
    required this.newBalance,
    required this.paidAt,
    this.amountPaid,
    this.receipt,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final green = context.appSuccess;
    final date = DateFormat('MMM d, y · h:mm a').format(paidAt);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(PaymentSuccessAction.backToCredits);
      },
      child: Scaffold(
        backgroundColor: palette.page,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success
                              .withValues(alpha: palette.isDark ? 0.14 : 0.12),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 72,
                          height: 72,
                          // White on Emerald-800 is 7.7:1 (2.5:1 on -500).
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.successDark,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 38, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      LedgerSectionLabel(
                        context.tr(TranslationKeys.ledgerPaymentSuccessful),
                        color: green,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(TranslationKeys.ledgerCreditsAdded,
                            {'count': creditsAdded}),
                        textAlign: TextAlign.center,
                        style: AppFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          height: 1.2,
                          fontFeatures: kLedgerTabular,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(TranslationKeys.ledgerNewBalance,
                            {'count': newBalance}),
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: palette.muted,
                          fontFeatures: kLedgerTabular,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (amountPaid != null)
                        LedgerRow(
                          label: context.tr(TranslationKeys.ledgerPaid),
                          value: amountPaid,
                        ),
                      if (receipt != null && receipt!.isNotEmpty)
                        LedgerRow(
                          label: context.tr(TranslationKeys.ledgerReceipt),
                          value: receipt,
                        ),
                      LedgerRow(
                        label: context.tr(TranslationKeys.ledgerDate),
                        value: date,
                      ),
                      const LedgerHairline(verticalMargin: 10),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LedgerPrimaryButton(
                      key: const Key('payment_success_start_study'),
                      label: context.tr(TranslationKeys.ledgerStartStudy),
                      icon: Icons.auto_awesome_outlined,
                      onPressed: () => Navigator.of(context)
                          .pop(PaymentSuccessAction.startStudy),
                    ),
                    const SizedBox(height: 10),
                    LedgerSecondaryButton(
                      key: const Key('payment_success_back'),
                      label: context.tr(TranslationKeys.ledgerBackToCredits),
                      onPressed: () => Navigator.of(context)
                          .pop(PaymentSuccessAction.backToCredits),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
