import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/payment_responses.dart';
import '../../domain/entities/token_status.dart';
import '../../domain/entities/token_pricing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/datasources/token_remote_data_source.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/logger.dart';

/// Token Purchase Page
///
/// Full-screen page for purchasing tokens with:
/// - Dynamic pricing from backend API
/// - Predefined token packages
/// - Custom token amount input
/// - Razorpay payment integration
class TokenPurchasePage extends StatefulWidget {
  final TokenStatus tokenStatus;
  final String userEmail;
  final String userPhone;

  const TokenPurchasePage({
    super.key,
    required this.tokenStatus,
    required this.userEmail,
    required this.userPhone,
  });

  @override
  State<TokenPurchasePage> createState() => _TokenPurchasePageState();
}

class _TokenPurchasePageState extends State<TokenPurchasePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _customAmountController;

  int _selectedPackageTokens = 0;
  int _customTokens = 50;
  bool _isLoading = false;

  // Store current purchase details for payment confirmation
  int _currentPurchaseTokens = 0;
  String _currentOrderId = '';

  // Pricing configuration from backend
  bool _isPricingLoading = true;
  String? _pricingError;
  int _tokensPerRupee = 2; // Default
  List<TokenPackage> _packages = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _customAmountController =
        TextEditingController(text: _customTokens.toString());

    // Initialize PaymentService
    PaymentService().initialize();

    // Fetch pricing from backend (no fallback - show error if fails)
    _fetchTokenPricing();
  }

  /// Fetches token pricing configuration from backend API
  /// If it fails, shows error state instead of falling back to hardcoded values
  Future<void> _fetchTokenPricing() async {
    try {
      setState(() {
        _isPricingLoading = true;
        _pricingError = null;
      });

      final dataSource = sl<TokenRemoteDataSource>();
      final pricingData = await dataSource.getTokenPricing(region: 'IN');

      setState(() {
        _tokensPerRupee = pricingData.tokensPerRupee;
        _packages = pricingData.packages;
        _isPricingLoading = false;
      });

      Logger.debug(
          '💰 [TokenPurchasePage] Pricing loaded: $_tokensPerRupee tokens/₹, ${_packages.length} packages');
    } catch (e) {
      Logger.debug('❌ [TokenPurchasePage] Failed to fetch pricing: $e');
      setState(() {
        _pricingError =
            'Failed to load pricing. Please check your connection and try again.';
        _isPricingLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAmountController.dispose();
    PaymentService().dispose();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    Logger.debug('✅ Payment Success: ${response.paymentId}');

    // Use stored token amount from when order was created
    final tokenAmount = _currentPurchaseTokens;

    if (tokenAmount == 0) {
      Logger.debug(
          '[TokenPurchasePage] ⚠️ Warning: Token amount is 0, payment may not be credited');
    }

    try {
      // Call backend to confirm payment and credit tokens
      Logger.debug('[TokenPurchasePage] Confirming payment with backend...');
      Logger.debug('[TokenPurchasePage] Payment ID: ${response.paymentId}');
      Logger.debug('[TokenPurchasePage] Order ID: ${response.orderId}');
      Logger.debug('[TokenPurchasePage] Signature: ${response.signature}');
      Logger.debug('[TokenPurchasePage] Token Amount: $tokenAmount');

      final dataSource = sl<TokenRemoteDataSource>();
      await dataSource.confirmPayment(
        paymentId: response.paymentId!,
        orderId: response.orderId!,
        signature: response.signature!,
        tokenAmount: tokenAmount,
      );

      Logger.debug('[TokenPurchasePage] Payment confirmed successfully!');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Payment successful! Tokens have been credited to your account.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh token balance
        context.read<TokenBloc>().add(const RefreshTokenStatus());

        // Close the page and return success
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.debug('[TokenPurchasePage] ❌ Failed to confirm payment: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Payment received but confirmation failed: ${e.toString()}'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 5),
          ),
        );

        // Still close the page - tokens will be credited by webhook
        Navigator.of(context).pop(true);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Logger.debug('❌ Payment Error: ${response.code} - ${response.message}');

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Logger.debug('💼 External Wallet: ${response.walletName}');
  }

  void _onPackageSelected(TokenPackage package) {
    setState(() {
      _selectedPackageTokens = package.tokens;
      _tabController.index = 0; // Switch to packages tab
    });
  }

  void _onCustomAmountChanged(String value) {
    final amount = int.tryParse(value) ?? 0;
    setState(() {
      _customTokens = amount;
      _selectedPackageTokens = 0; // Deselect package when custom amount changes
    });
  }

  void _handlePurchase() {
    final tokenAmount =
        _selectedPackageTokens > 0 ? _selectedPackageTokens : _customTokens;

    if (tokenAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please select a package or enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Create order via BLoC
    context.read<TokenBloc>().add(CreatePaymentOrder(tokenAmount: tokenAmount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Premium users cannot purchase (they have unlimited)
    if (widget.tokenStatus.userPlan == UserPlan.premium) {
      return _buildRestrictedPage(context);
    }

    return BlocListener<TokenBloc, TokenState>(
      listener: (context, state) {
        if (state is TokenOrderCreated) {
          Logger.debug('[TokenPurchasePage] Order created: ${state.orderId}');

          // Store purchase details for later confirmation
          setState(() {
            _currentPurchaseTokens = state.tokensToPurchase;
            _currentOrderId = state.orderId;
          });

          Logger.debug(
              '[TokenPurchasePage] Stored purchase context: $_currentPurchaseTokens tokens, order $_currentOrderId');

          // Open payment gateway using PaymentService
          PaymentService().openCheckout(
            orderId: state.orderId,
            amount: state.amount,
            description: '${state.tokensToPurchase} Tokens',
            userEmail: widget.userEmail,
            userPhone: widget.userPhone,
            onSuccess: _handlePaymentSuccess,
            onError: _handlePaymentError,
            onExternalWallet: _handleExternalWallet,
          );
        } else if (state is TokenError && state.operation == 'order_creation') {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Something went wrong. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr(TranslationKeys.tokenPurchaseTitle)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isPricingLoading
            ? _buildLoadingState()
            : _pricingError != null
                ? _buildErrorState()
                : _buildPurchaseContent(theme),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading pricing...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            SizedBox(height: 16),
            Text(
              _pricingError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchTokenPricing,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictedPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Token Purchase'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: AppColors.warning),
              SizedBox(height: 16),
              Text(
                'Premium users have unlimited tokens',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'You don\'t need to purchase tokens!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseContent(ThemeData theme) {
    return Column(
      children: [
        // Current balance card
        _buildBalanceCard(theme),

        // Tabs for Packages vs Custom
        TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(
              icon: Icon(Icons.loyalty),
              text: 'Packages',
            ),
            Tab(
              icon: Icon(Icons.edit),
              text: 'Custom',
            ),
          ],
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPackagesTab(theme),
              _buildCustomTab(theme),
            ],
          ),
        ),

        // Purchase button
        _buildPurchaseButton(theme),
      ],
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary),
          SizedBox(width: 12),
          Text(
            'Current Balance: ${widget.tokenStatus.availableTokens} tokens',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesTab(ThemeData theme) {
    if (_packages.isEmpty) {
      return Center(child: Text('No packages available'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        final isSelected = _selectedPackageTokens == package.tokens;

        return GestureDetector(
          onTap: () => _onPackageSelected(package),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? theme.colorScheme.primary : theme.dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Token icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.token,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(width: 16),

                // Package details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${package.tokens} Tokens',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (package.isPopular) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${package.rupees}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (package.discount > 0) ...[
                            SizedBox(width: 8),
                            Text(
                              '${package.discount}% OFF',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${(package.rupees * 100 / package.tokens).toStringAsFixed(1)} paise/token',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomTab(ThemeData theme) {
    final cost = (_customTokens / _tokensPerRupee).ceil();

    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter custom token amount:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Token Amount',
              hintText: 'Enter number of tokens',
              prefixIcon: Icon(Icons.token),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _onCustomAmountChanged,
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tokens:', style: TextStyle(fontSize: 16)),
                    Text(
                      '$_customTokens',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cost:', style: TextStyle(fontSize: 16)),
                    Text(
                      '₹$cost',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Rate: ₹0.50 per token (no discount)',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '💡 Tip: Choose a package above for better discounts!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(ThemeData theme) {
    final tokenAmount =
        _selectedPackageTokens > 0 ? _selectedPackageTokens : _customTokens;
    final isValid = tokenAmount > 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: isValid && !_isLoading ? _handlePurchase : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: Size(double.infinity, 56),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Purchase $tokenAmount Tokens',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
