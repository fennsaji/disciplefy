import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../domain/entities/token_status.dart';
import '../../domain/entities/saved_payment_method.dart';
import '../../domain/entities/payment_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/constants/payment_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../bloc/payment_method_bloc.dart';

/// Enhanced Token Purchase Dialog Widget with Saved Payment Methods
///
/// Features:
/// - Saved payment method selection
/// - One-click purchase with default method
/// - Payment preferences integration
/// - Mobile payment optimizations
/// - UPI and wallet support
class EnhancedTokenPurchaseDialog extends StatefulWidget {
  final TokenStatus tokenStatus;
  final Function(int tokenAmount) onCreateOrder;
  final Function(String orderId, int tokenAmount, double amount) onOrderCreated;
  final Function(PaymentSuccessResponse) onPaymentSuccess;
  final Function(PaymentFailureResponse) onPaymentFailure;
  final VoidCallback onCancel;
  final String userEmail;
  final String userPhone;

  const EnhancedTokenPurchaseDialog({
    super.key,
    required this.tokenStatus,
    required this.onCreateOrder,
    required this.onOrderCreated,
    required this.onPaymentSuccess,
    required this.onPaymentFailure,
    required this.onCancel,
    required this.userEmail,
    required this.userPhone,
  });

  @override
  State<EnhancedTokenPurchaseDialog> createState() =>
      _EnhancedTokenPurchaseDialogState();
}

class _EnhancedTokenPurchaseDialogState
    extends State<EnhancedTokenPurchaseDialog> with TickerProviderStateMixin {
  late PageController _pageController;
  late TextEditingController _customAmountController;

  int _currentStep =
      0; // 0: Select Amount, 1: Choose Payment Method, 2: Confirm
  int _selectedPackageTokens = 0;
  int _customTokens = 50;
  bool _isLoading = false;
  String? _currentOrderId;
  String _paymentStatus = 'ready';

  SavedPaymentMethod? _selectedPaymentMethod;
  PaymentPreferences? _paymentPreferences;
  final bool _saveNewPaymentMethod = false;

  // Predefined token packages
  static const List<TokenPackage> _packages = [
    TokenPackage(tokens: 50, rupees: 5),
    TokenPackage(tokens: 100, rupees: 9, discount: 10),
    TokenPackage(tokens: 250, rupees: 20, discount: 20),
    TokenPackage(tokens: 500, rupees: 35, discount: 30),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _customAmountController =
        TextEditingController(text: _customTokens.toString());

    // Load payment methods and preferences
    context.read<PaymentMethodBloc>().add(LoadPaymentMethods());
    context.read<PaymentMethodBloc>().add(LoadPaymentPreferences());

    PaymentService().initialize();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customAmountController.dispose();
    PaymentService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tokenStatus.userPlan != UserPlan.standard) {
      return _buildRestrictedDialog(context);
    }

    return Dialog(
      backgroundColor: AppColors.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final steps = ['Amount', 'Payment', 'Confirm'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Tokens',
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add more tokens to continue generating study guides',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCurrentBalance(),
          const SizedBox(height: 16),
          _buildProgressIndicator(steps),
        ],
      ),
    );
  }

  Widget _buildCurrentBalance() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Current Balance: ',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${widget.tokenStatus.totalTokens} tokens',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(List<String> steps) {
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= _currentStep;
        final isCompleted = index < _currentStep;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color:
                      isActive ? AppColors.primaryColor : AppColors.borderColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  steps[index],
                  style: AppTextStyles.captionSmall.copyWith(
                    color: isActive
                        ? AppColors.primaryColor
                        : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.primaryColor
                          : AppColors.borderColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildContent() {
    return BlocListener<PaymentMethodBloc, PaymentMethodState>(
      listener: (context, state) {
        if (state is PaymentPreferencesLoaded) {
          setState(() {
            _paymentPreferences = state.preferences;
          });
        }
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildAmountSelection(),
          _buildPaymentMethodSelection(),
          _buildConfirmation(),
        ],
      ),
    );
  }

  Widget _buildAmountSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Token Amount',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._packages.map((package) => _buildPackageCard(package)),
                  const SizedBox(height: 20),
                  _buildCustomAmountInput(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(TokenPackage package) {
    final isSelected = _selectedPackageTokens == package.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedPackageTokens = isSelected ? 0 : package.tokens;
            });
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryColor
                        : AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.token,
                    color: isSelected ? Colors.white : AppColors.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${package.tokens} Tokens',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${package.rupees}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (package.discount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${package.discount}% OFF',
                                style: AppTextStyles.captionSmall.copyWith(
                                  color: AppColors.successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(package.tokens / package.rupees).toStringAsFixed(1)} tokens/₹',
                        style: AppTextStyles.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custom Amount',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: 'Token Amount',
              hintText: 'Enter amount (10-9999)',
              prefixIcon: Icon(Icons.token, color: AppColors.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              final tokens = int.tryParse(value) ?? 0;
              if (tokens >= 10 && tokens <= 9999) {
                setState(() {
                  _customTokens = tokens;
                  _selectedPackageTokens = 0; // Clear package selection
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.highlightColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, color: AppColors.primaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Cost: ₹${(_customTokens / 10).toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryColor,
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

  Widget _buildPaymentMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
        builder: (context, state) {
          if (state is PaymentMethodsLoaded) {
            return _buildPaymentMethodsList(state.paymentMethods);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildPaymentMethodsList(List<SavedPaymentMethod> paymentMethods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Payment Method',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (paymentMethods.isNotEmpty) ...[
                  ...paymentMethods
                      .map((method) => _buildPaymentMethodTile(method)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                _buildAddNewPaymentMethodTile(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(SavedPaymentMethod method) {
    final isSelected = _selectedPaymentMethod?.id == method.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedPaymentMethod = isSelected ? null : method;
            });
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
                _buildMethodIcon(method.methodType),
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

  Widget _buildAddNewPaymentMethodTile() {
    final isSelected = _selectedPaymentMethod == null;

    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedPaymentMethod = null;
          });
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
                      'Use a new payment method for this purchase',
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
    );
  }

  Widget _buildMethodIcon(String methodType) {
    IconData iconData;

    switch (methodType) {
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

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: AppColors.primaryColor,
        size: 24,
      ),
    );
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

  Widget _buildConfirmation() {
    final tokenAmount =
        _selectedPackageTokens > 0 ? _selectedPackageTokens : _customTokens;
    final cost = _selectedPackageTokens > 0
        ? _packages.firstWhere((p) => p.tokens == _selectedPackageTokens).rupees
        : (_customTokens / 10).ceil();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm Purchase',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.highlightColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.highlightColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase Summary',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Token Amount:', '$tokenAmount tokens'),
                _buildSummaryRow('Total Cost:', '₹$cost'),
                if (_selectedPaymentMethod != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Payment Method:',
                    _selectedPaymentMethod!.displayName ??
                        _selectedPaymentMethod!.methodTypeLabel,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Payment Method:', 'New payment method'),
                  if (_paymentPreferences?.autoSavePaymentMethods == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment method will be saved for future use',
                              style: AppTextStyles.captionSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _goToPreviousStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: _currentStep == 2
                ? ElevatedButton(
                    onPressed: _canProceed() && !_isLoading
                        ? () => _handlePurchase()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Purchase'),
                  )
                : ElevatedButton(
                    onPressed: _canProceed() ? _goToNextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedDialog(BuildContext context) {
    String message;
    String actionText;

    switch (widget.tokenStatus.userPlan) {
      case UserPlan.free:
        message =
            'Free users cannot purchase additional tokens. Upgrade to Standard plan to buy extra tokens.';
        actionText = 'Upgrade Plan';
        break;
      case UserPlan.premium:
        message =
            'Premium users have unlimited tokens! No need to purchase additional tokens.';
        actionText = 'Got It';
        break;
      case UserPlan.standard:
      default:
        message = 'Standard users can purchase additional tokens.';
        actionText = 'Continue';
        break;
    }

    return AlertDialog(
      backgroundColor: AppColors.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            widget.tokenStatus.userPlan == UserPlan.premium
                ? Icons.star
                : Icons.info_outline,
            color: widget.tokenStatus.userPlan == UserPlan.premium
                ? Colors.amber
                : AppColors.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            widget.tokenStatus.userPlan == UserPlan.premium
                ? 'Premium Member'
                : 'Purchase Restricted',
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(actionText),
        ),
      ],
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedPackageTokens > 0 ||
            (_customTokens >= 10 && _customTokens <= 9999);
      case 1:
        return true; // Can always proceed from payment method selection
      case 2:
        return true;
      default:
        return false;
    }
  }

  void _goToNextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handlePurchase() async {
    final tokenAmount =
        _selectedPackageTokens > 0 ? _selectedPackageTokens : _customTokens;

    setState(() {
      _isLoading = true;
      _paymentStatus = 'creating_order';
    });

    try {
      widget.onCreateOrder(tokenAmount);
    } catch (e) {
      setState(() {
        _paymentStatus = 'ready';
        _isLoading = false;
      });

      widget.onPaymentFailure(PaymentFailureResponse(
        1, // code
        'Failed to initialize payment: ${e.toString()}', // message
        {'error': 'INITIALIZATION_ERROR'}, // data
      ));
    }
  }
}

class TokenPackage {
  final int tokens;
  final int rupees;
  final bool isPopular;
  final int discount;

  const TokenPackage({
    required this.tokens,
    required this.rupees,
    this.isPopular = false,
    this.discount = 0,
  });
}
