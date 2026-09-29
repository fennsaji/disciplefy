import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/purchase_issue/presentation/widgets/report_issue_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/purchase_history.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// One credit-pack purchase as a ledger entry: credits and status pill,
/// date · method and amount, the receipt, and "Report an issue".
///
/// Payment and order IDs sit behind a "Details" toggle; every ID copies on
/// tap.
class PurchaseHistoryCard extends StatefulWidget {
  final PurchaseHistory purchase;

  const PurchaseHistoryCard({
    super.key,
    required this.purchase,
  });

  @override
  State<PurchaseHistoryCard> createState() => _PurchaseHistoryCardState();
}

class _PurchaseHistoryCardState extends State<PurchaseHistoryCard> {
  bool _showDetails = false;

  PurchaseHistory get purchase => widget.purchase;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final status = purchase.status.toLowerCase();
    final isSuccess = status == 'completed' || status == 'success';
    final date = DateFormat('MMM d · h:mm a').format(purchase.purchasedAt);
    final amount = purchase.costRupees == purchase.costRupees.roundToDouble()
        ? '₹${purchase.costRupees.toStringAsFixed(0)}'
        : '₹${purchase.costRupees.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.toll_outlined, size: 20, color: palette.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(TranslationKeys.ledgerCreditsCount,
                      {'count': purchase.tokenAmount}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    fontFeatures: kLedgerTabular,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 6),
          LedgerRow(
            label: '$date · ${_paymentMethodLabel(purchase.paymentMethod)}',
            value: amount,
          ),
          if (purchase.receiptNumber != null)
            LedgerRow(
              label: context.tr(TranslationKeys.ledgerReceipt),
              valueWidget: _CopyText(
                text: purchase.receiptNumber!,
                color: palette.accentIcon,
              ),
            ),
          if (_showDetails) ...[
            LedgerRow(
              label: context.tr(TranslationKeys.ledgerPaymentId),
              valueWidget:
                  _CopyText(text: purchase.paymentId, color: palette.muted),
            ),
            LedgerRow(
              label: context.tr(TranslationKeys.ledgerOrderId),
              valueWidget:
                  _CopyText(text: purchase.orderId, color: palette.muted),
            ),
          ],
          const SizedBox(height: 2),
          Wrap(
            spacing: 18,
            children: [
              if (!isSuccess || _showDetails)
                LedgerLink(
                  label: context.tr(TranslationKeys.ledgerReportIssue),
                  trailingIcon: Icons.arrow_forward_rounded,
                  onTap: () => showReportIssueBottomSheet(context, purchase),
                ),
              LedgerLink(
                label: context.tr(_showDetails
                    ? TranslationKeys.ledgerHideDetails
                    : TranslationKeys.ledgerDetails),
                onTap: () => setState(() => _showDetails = !_showDetails),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'card':
      case 'credit_card':
        return 'Credit Card';
      case 'debit_card':
        return 'Debit Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      case 'razorpay':
        return 'Razorpay';
      default:
        return paymentMethod.toUpperCase();
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'completed':
      case 'success':
        return LedgerStatusPill(
          label: context.tr(TranslationKeys.ledgerStatusSuccess),
          tone: LedgerTone.success,
        );
      case 'pending':
        return LedgerStatusPill(
          label: context.tr(TranslationKeys.ledgerStatusPending),
          tone: LedgerTone.warning,
        );
      case 'failed':
        return LedgerStatusPill(
          label: context.tr(TranslationKeys.ledgerStatusFailed),
          tone: LedgerTone.error,
        );
      default:
        return LedgerStatusPill(
          label: status.isEmpty
              ? status
              : status[0].toUpperCase() + status.substring(1),
          tone: LedgerTone.neutral,
        );
    }
  }
}

/// Tabular text that copies itself to the clipboard on tap.
class _CopyText extends StatelessWidget {
  final String text;
  final Color color;

  const _CopyText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(TranslationKeys.ledgerCopied)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: kLedgerTabular,
        ),
      ),
    );
  }
}
