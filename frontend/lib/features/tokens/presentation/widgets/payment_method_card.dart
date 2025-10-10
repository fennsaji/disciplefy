import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/saved_payment_method.dart';

class PaymentMethodCard extends StatelessWidget {
  final SavedPaymentMethod paymentMethod;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;

  const PaymentMethodCard({
    super.key,
    required this.paymentMethod,
    this.onSetDefault,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: paymentMethod.isDefault
              ? BorderSide(color: AppColors.primaryColor, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildMethodIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              paymentMethod.displayName ??
                                  paymentMethod.methodTypeLabel,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (paymentMethod.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Default',
                                  style: AppTextStyles.captionSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildSubtitle(),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'set_default':
                          onSetDefault?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!paymentMethod.isDefault)
                        const PopupMenuItem(
                          value: 'set_default',
                          child: Row(
                            children: [
                              Icon(Icons.star_outline, size: 20),
                              SizedBox(width: 8),
                              Text('Set as Default'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 20, color: AppColors.errorColor),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: AppColors.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (paymentMethod.methodType == 'card' &&
                  paymentMethod.isExpired) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        size: 16,
                        color: AppColors.errorColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Card Expired',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (paymentMethod.lastUsedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last used: ${_formatLastUsed()}',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodIcon() {
    IconData iconData;
    Color iconColor = AppColors.primaryColor;

    switch (paymentMethod.methodType) {
      case 'card':
        iconData = Icons.credit_card;
        break;
      case 'upi':
        iconData = Icons.account_balance_wallet;
        break;
      case 'netbanking':
        iconData = Icons.account_balance;
        break;
      case 'wallet':
        iconData = Icons.wallet;
        break;
      default:
        iconData = Icons.payment;
    }

    if (paymentMethod.methodType == 'card' && paymentMethod.isExpired) {
      iconColor = AppColors.errorColor;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  String _buildSubtitle() {
    switch (paymentMethod.methodType) {
      case 'card':
        final parts = <String>[];
        if (paymentMethod.brand != null) {
          parts.add(paymentMethod.brand!);
        }
        if (paymentMethod.lastFour != null) {
          parts.add('•••• ${paymentMethod.lastFour}');
        }
        if (paymentMethod.expiryMonth != null &&
            paymentMethod.expiryYear != null) {
          parts.add(
              '${paymentMethod.expiryMonth!.toString().padLeft(2, '0')}/${paymentMethod.expiryYear! % 100}');
        }
        return parts.join(' • ');
      case 'upi':
        return paymentMethod.provider;
      case 'netbanking':
        return 'Net Banking • ${paymentMethod.provider}';
      case 'wallet':
        return '${paymentMethod.provider} Wallet';
      default:
        return paymentMethod.provider;
    }
  }

  String _formatLastUsed() {
    if (paymentMethod.lastUsedAt == null) return '';

    final now = DateTime.now();
    final lastUsed = paymentMethod.lastUsedAt!;
    final difference = now.difference(lastUsed);

    if (difference.inDays > 30) {
      return '${lastUsed.day}/${lastUsed.month}/${lastUsed.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return 'Just now';
    }
  }
}
