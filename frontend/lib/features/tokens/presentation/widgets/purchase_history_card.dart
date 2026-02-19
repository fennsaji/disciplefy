import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/purchase_history.dart';
import '../../../purchase_issue/presentation/widgets/report_issue_bottom_sheet.dart';

class PurchaseHistoryCard extends StatelessWidget {
  final PurchaseHistory purchase;

  const PurchaseHistoryCard({
    super.key,
    required this.purchase,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - Tokens and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.token,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${purchase.tokenAmount} tokens',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _StatusChip(status: purchase.status),
              ],
            ),

            const SizedBox(height: 12),

            // Amount and Payment Method
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount Paid',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${purchase.costRupees.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Payment Method',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPaymentMethodIcon(purchase.paymentMethod),
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getPaymentMethodLabel(purchase.paymentMethod),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date and Receipt
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Date',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormatter.format(purchase.purchasedAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (purchase.receiptNumber != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Receipt #',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _copyToClipboard(
                          context,
                          purchase.receiptNumber!,
                          'Receipt number copied',
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              purchase.receiptNumber!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Transaction IDs (Expandable)
            ExpansionTile(
              title: Text(
                'Transaction Details',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
              children: [
                _TransactionDetailRow(
                  label: 'Payment ID',
                  value: purchase.paymentId,
                ),
                const SizedBox(height: 8),
                _TransactionDetailRow(
                  label: 'Order ID',
                  value: purchase.orderId,
                ),
                const SizedBox(height: 16),
                // Report Issue Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        showReportIssueBottomSheet(context, purchase),
                    icon: Icon(
                      Icons.report_problem_outlined,
                      size: 18,
                      color: AppColors.warningDark,
                    ),
                    label: Text(
                      'Report Issue',
                      style: TextStyle(
                        color: AppColors.warningDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'card':
      case 'credit_card':
      case 'debit_card':
        return Icons.credit_card;
      case 'upi':
        return Icons.account_balance_wallet;
      case 'netbanking':
        return Icons.account_balance;
      case 'wallet':
        return Icons.wallet;
      case 'razorpay':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodLabel(String paymentMethod) {
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

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = AppColors.success.withOpacity(0.1);
        textColor = AppColors.successDark;
        icon = Icons.check_circle;
        break;
      case 'pending':
        backgroundColor = AppColors.warning.withOpacity(0.1);
        textColor = AppColors.warningDark;
        icon = Icons.schedule;
        break;
      case 'failed':
        backgroundColor = AppColors.error.withOpacity(0.1);
        textColor = AppColors.errorDark;
        icon = Icons.error;
        break;
      default:
        backgroundColor = theme.colorScheme.surface;
        textColor = theme.colorScheme.onSurface;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _TransactionDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () => _copyToClipboard(context, value, '$label copied'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
