import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/saved_payment_method.dart';
import '../../domain/entities/payment_preferences.dart';
import '../bloc/payment_method_bloc.dart';
import 'mobile_payment_methods_widget.dart';
import 'upi_quick_pay_widget.dart';

/// Optimized Mobile Payment Flow Widget
///
/// Provides a streamlined, mobile-first payment experience with:
/// - Quick payment method selection
/// - UPI integration with app shortcuts
/// - Mobile wallet support
/// - One-click payments with saved methods
/// - Progressive disclosure for advanced options
class OptimizedMobilePaymentFlow extends StatefulWidget {
  final double amount;
  final String description;
  final List<SavedPaymentMethod> savedPaymentMethods;
  final PaymentPreferences? preferences;
  final Function(SavedPaymentMethod) onSavedMethodSelected;
  final Function(String paymentType, String provider) onNewMethodSelected;
  final Function(String upiId) onUPIPayment;
  final VoidCallback onAddPaymentMethod;

  const OptimizedMobilePaymentFlow({
    super.key,
    required this.amount,
    required this.description,
    required this.savedPaymentMethods,
    this.preferences,
    required this.onSavedMethodSelected,
    required this.onNewMethodSelected,
    required this.onUPIPayment,
    required this.onAddPaymentMethod,
  });

  @override
  State<OptimizedMobilePaymentFlow> createState() =>
      _OptimizedMobilePaymentFlowState();
}

class _OptimizedMobilePaymentFlowState extends State<OptimizedMobilePaymentFlow>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SavedPaymentMethod? _selectedSavedMethod;
  String _selectedPaymentFlow = 'quick'; // 'quick', 'saved', 'new', 'upi'

  @override
  void initState() {
    super.initState();

    // Determine initial flow based on user preferences and saved methods
    if (widget.preferences?.enableOneClickPurchase == true &&
        widget.savedPaymentMethods.isNotEmpty) {
      _selectedPaymentFlow = 'saved';
      _selectedSavedMethod = widget.savedPaymentMethods.firstWhere(
        (method) => method.isDefault,
        orElse: () => widget.savedPaymentMethods.first,
      );
    } else if (widget.preferences?.preferredWallet != null ||
        widget.preferences?.defaultPaymentType == 'upi') {
      _selectedPaymentFlow = 'upi';
    } else {
      _selectedPaymentFlow = 'quick';
    }

    _tabController = TabController(
      length: _getTabCount(),
      vsync: this,
      initialIndex: _getInitialTabIndex(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getTabCount() {
    int count = 1; // Always have quick pay
    if (widget.savedPaymentMethods.isNotEmpty) count++; // Saved methods
    count++; // UPI
    return count;
  }

  int _getInitialTabIndex() {
    switch (_selectedPaymentFlow) {
      case 'saved':
        return widget.savedPaymentMethods.isNotEmpty ? 1 : 0;
      case 'upi':
        return widget.savedPaymentMethods.isNotEmpty ? 2 : 1;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 600),
      child: Column(
        children: [
          _buildHeader(),
          _buildQuickActions(),
          const SizedBox(height: 16),
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.mobile_friendly,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile Payment',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${widget.amount.toStringAsFixed(2)}',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total',
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final hasDefault =
        widget.savedPaymentMethods.any((method) => method.isDefault);
    final defaultMethod = hasDefault
        ? widget.savedPaymentMethods.firstWhere((method) => method.isDefault)
        : null;

    if (!hasDefault || !(widget.preferences!.enableOneClickPurchase ?? false)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.highlightColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.highlightColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on,
                color: AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'One-Click Payment',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => widget.onSavedMethodSelected(defaultMethod),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getMethodIcon(defaultMethod!.methodType),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pay with ${defaultMethod.displayName ?? defaultMethod.methodTypeLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = <Widget>[];

    tabs.add(const Tab(text: 'Quick Pay'));

    if (widget.savedPaymentMethods.isNotEmpty) {
      tabs.add(const Tab(text: 'Saved'));
    }

    tabs.add(const Tab(text: 'UPI'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryColor,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: tabs,
      ),
    );
  }

  Widget _buildTabContent() {
    final tabViews = <Widget>[];

    // Quick Pay tab
    tabViews.add(_buildQuickPayTab());

    // Saved Methods tab (if available)
    if (widget.savedPaymentMethods.isNotEmpty) {
      tabViews.add(_buildSavedMethodsTab());
    }

    // UPI tab
    tabViews.add(_buildUPITab());

    return TabBarView(
      controller: _tabController,
      children: tabViews,
    );
  }

  Widget _buildQuickPayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MobilePaymentMethodsWidget(
        onPaymentMethodSelected: (paymentType, provider) {
          widget.onNewMethodSelected(paymentType, provider);
        },
      ),
    );
  }

  Widget _buildSavedMethodsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved Payment Methods',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose from your saved payment methods',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.savedPaymentMethods
              .map((method) => _buildSavedMethodTile(method)),
          const SizedBox(height: 16),
          _buildAddNewMethodTile(),
        ],
      ),
    );
  }

  Widget _buildSavedMethodTile(SavedPaymentMethod method) {
    final isSelected = _selectedSavedMethod?.id == method.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedSavedMethod = method;
            });
            widget.onSavedMethodSelected(method);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getMethodIcon(method.methodType),
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            method.displayName ?? method.methodTypeLabel,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (method.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
                        _buildMethodSubtitle(method),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddNewMethodTile() {
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onAddPaymentMethod,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
            color: AppColors.surfaceColor,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Payment Method',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Credit/Debit Card, UPI, Net Banking',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUPITab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: UPIQuickPayWidget(
        amount: widget.amount,
        description: widget.description,
        onUPIIdEntered: widget.onUPIPayment,
        onUPIAppSelected: (appName) {
          // Handle UPI app selection
          widget.onNewMethodSelected(
              'upi', appName.toLowerCase().replaceAll(' ', '_'));
        },
        onQRCodeRequested: () {
          // Handle QR code generation request
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('QR code generation coming soon'),
              backgroundColor: AppColors.primaryColor,
            ),
          );
        },
      ),
    );
  }

  IconData _getMethodIcon(String methodType) {
    switch (methodType) {
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.account_balance_wallet;
      case 'netbanking':
        return Icons.account_balance;
      case 'wallet':
        return Icons.wallet;
      default:
        return Icons.payment;
    }
  }

  String _buildMethodSubtitle(SavedPaymentMethod method) {
    switch (method.methodType) {
      case 'card':
        final parts = <String>[];
        if (method.brand != null) {
          parts.add(method.brand!);
        }
        if (method.lastFour != null) {
          parts.add('•••• ${method.lastFour}');
        }
        return parts.join(' • ');
      case 'upi':
        return method.provider;
      case 'netbanking':
        return 'Net Banking • ${method.provider}';
      case 'wallet':
        return '${method.provider} Wallet';
      default:
        return method.provider;
    }
  }
}
