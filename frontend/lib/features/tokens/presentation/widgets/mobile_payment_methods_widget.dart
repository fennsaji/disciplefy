import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Mobile Payment Methods Widget
///
/// Optimized UI for mobile payments including:
/// - UPI payment options
/// - Mobile wallets
/// - Quick payment shortcuts
/// - Mobile-first design
class MobilePaymentMethodsWidget extends StatefulWidget {
  final Function(String paymentType, String provider)? onPaymentMethodSelected;
  final String? selectedProvider;
  final bool enableUPI;
  final bool enableWallets;

  const MobilePaymentMethodsWidget({
    super.key,
    this.onPaymentMethodSelected,
    this.selectedProvider,
    this.enableUPI = true,
    this.enableWallets = true,
  });

  @override
  State<MobilePaymentMethodsWidget> createState() =>
      _MobilePaymentMethodsWidgetState();
}

class _MobilePaymentMethodsWidgetState
    extends State<MobilePaymentMethodsWidget> {
  String? _selectedProvider;

  final List<MobilePaymentProvider> _upiProviders = [
    MobilePaymentProvider(
      id: 'google_pay',
      name: 'Google Pay',
      icon: '🟢', // Google Pay green circle
      type: 'upi',
      isPopular: true,
    ),
    MobilePaymentProvider(
      id: 'phonepe',
      name: 'PhonePe',
      icon: '🟣', // PhonePe purple circle
      type: 'upi',
      isPopular: true,
    ),
    MobilePaymentProvider(
      id: 'paytm',
      name: 'Paytm',
      icon: '🔵', // Paytm blue circle
      type: 'upi',
    ),
    MobilePaymentProvider(
      id: 'bhim',
      name: 'BHIM UPI',
      icon: '🟠', // BHIM orange circle
      type: 'upi',
    ),
    MobilePaymentProvider(
      id: 'amazon_pay',
      name: 'Amazon Pay',
      icon: '🟡', // Amazon Pay yellow circle
      type: 'upi',
    ),
  ];

  final List<MobilePaymentProvider> _walletProviders = [
    MobilePaymentProvider(
      id: 'paytm_wallet',
      name: 'Paytm Wallet',
      icon: '💙',
      type: 'wallet',
      isPopular: true,
    ),
    MobilePaymentProvider(
      id: 'mobikwik',
      name: 'MobiKwik',
      icon: '🔴',
      type: 'wallet',
    ),
    MobilePaymentProvider(
      id: 'freecharge',
      name: 'Freecharge',
      icon: '🟢',
      type: 'wallet',
    ),
    MobilePaymentProvider(
      id: 'ola_money',
      name: 'Ola Money',
      icon: '🟡',
      type: 'wallet',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.selectedProvider;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.enableUPI) ...[
          _buildSectionHeader('UPI Payment', 'Quick & secure payments'),
          const SizedBox(height: 12),
          _buildPaymentGrid(_upiProviders),
          const SizedBox(height: 20),
        ],
        if (widget.enableWallets) ...[
          _buildSectionHeader('Mobile Wallets', 'Digital wallet payments'),
          const SizedBox(height: 12),
          _buildPaymentGrid(_walletProviders),
          const SizedBox(height: 20),
        ],
        _buildQuickPaymentTip(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentGrid(List<MobilePaymentProvider> providers) {
    // Sort providers: popular first, then alphabetically
    final sortedProviders = [...providers]..sort((a, b) {
        if (a.isPopular && !b.isPopular) return -1;
        if (!a.isPopular && b.isPopular) return 1;
        return a.name.compareTo(b.name);
      });

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sortedProviders.length,
      itemBuilder: (context, index) {
        final provider = sortedProviders[index];
        return _buildPaymentProviderTile(provider);
      },
    );
  }

  Widget _buildPaymentProviderTile(MobilePaymentProvider provider) {
    final isSelected = _selectedProvider == provider.id;

    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedProvider = isSelected ? null : provider.id;
          });

          if (widget.onPaymentMethodSelected != null && !isSelected) {
            widget.onPaymentMethodSelected!(provider.type, provider.id);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? AppColors.primaryColor : AppColors.borderColor,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? AppColors.primaryColor.withOpacity(0.05)
                : AppColors.surfaceColor,
          ),
          child: Stack(
            children: [
              if (provider.isPopular)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'POPULAR',
                      style: AppTextStyles.captionSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          provider.icon,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            provider.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            provider.type == 'upi' ? 'UPI' : 'Wallet',
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
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

  Widget _buildQuickPaymentTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.highlightColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.highlightColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.flash_on,
              color: AppColors.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Payment Tip',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'UPI payments are instant and secure. Choose your preferred app for quick checkout.',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile Payment Provider Model
class MobilePaymentProvider {
  final String id;
  final String name;
  final String icon;
  final String type; // 'upi' or 'wallet'
  final bool isPopular;

  const MobilePaymentProvider({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.isPopular = false,
  });
}
