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
import '../bloc/token_bloc.dart';
import '../bloc/token_state.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Token Purchase Dialog Widget
///
/// Provides an intuitive interface for purchasing additional tokens with:
/// - Predefined token packages with pricing
/// - Custom token amount input
/// - Razorpay payment integration
/// - Real-time cost calculation
/// - Plan-specific restrictions
class TokenPurchaseDialog extends StatefulWidget {
  final TokenStatus tokenStatus;
  final List<SavedPaymentMethod> savedPaymentMethods;
  final PaymentPreferences? paymentPreferences;
  final Function(int tokenAmount) onCreateOrder;
  final Function(String orderId, int tokenAmount, double amount) onOrderCreated;
  final Function(PaymentSuccessResponse) onPaymentSuccess;
  final Function(PaymentFailureResponse) onPaymentFailure;
  final VoidCallback onCancel;
  final String userEmail;
  final String userPhone;
  final Function(SavedPaymentMethod)? onUsePaymentMethod;
  final Function(String methodType, Map<String, dynamic> paymentData)?
      onSavePaymentMethod;

  const TokenPurchaseDialog({
    super.key,
    required this.tokenStatus,
    this.savedPaymentMethods = const [],
    this.paymentPreferences,
    required this.onCreateOrder,
    required this.onOrderCreated,
    required this.onPaymentSuccess,
    required this.onPaymentFailure,
    required this.onCancel,
    required this.userEmail,
    required this.userPhone,
    this.onUsePaymentMethod,
    this.onSavePaymentMethod,
  });

  @override
  State<TokenPurchaseDialog> createState() => _TokenPurchaseDialogState();
}

class _TokenPurchaseDialogState extends State<TokenPurchaseDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _customAmountController;

  int _selectedPackageTokens = 0;
  int _customTokens = 50;
  bool _isLoading = false;
  String? _currentOrderId;
  String _paymentStatus =
      'ready'; // ready, creating_order, payment_opened, processing

  // Payment method selection
  SavedPaymentMethod? _selectedPaymentMethod;
  String _selectedPaymentType = 'card'; // card, upi, netbanking, wallet
  bool _savePaymentMethod = false;

  // Predefined token packages with attractive pricing tiers
  static const List<TokenPackage> _packages = [
    TokenPackage(tokens: 50, rupees: 5),
    TokenPackage(tokens: 100, rupees: 9, discount: 10), // ₹1 discount
    TokenPackage(tokens: 250, rupees: 20, discount: 20), // ₹5 discount
    TokenPackage(tokens: 500, rupees: 35, discount: 30), // ₹15 discount
  ];

  @override
  void initState() {
    super.initState();
    // Determine number of tabs based on available payment methods
    final tabCount = widget.savedPaymentMethods.isNotEmpty ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _customAmountController =
        TextEditingController(text: _customTokens.toString());

    // Initialize payment preferences
    _initializePaymentPreferences();

    // Initialize PaymentService
    PaymentService().initialize();
  }

  void _initializePaymentPreferences() {
    if (widget.paymentPreferences != null) {
      _savePaymentMethod =
          widget.paymentPreferences!.autoSavePaymentMethods ?? false;
      _selectedPaymentType =
          widget.paymentPreferences!.defaultPaymentType ?? 'card';

      // Set default payment method if one-click purchase is enabled
      if ((widget.paymentPreferences!.enableOneClickPurchase ?? false) &&
          widget.savedPaymentMethods.isNotEmpty) {
        _selectedPaymentMethod = widget.savedPaymentMethods
            .where((method) => method.isDefault)
            .firstOrNull;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAmountController.dispose();
    PaymentService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Only Premium users cannot purchase tokens (they have unlimited)
    if (widget.tokenStatus.userPlan == UserPlan.premium) {
      return _buildRestrictedDialog(context);
    }

    return BlocListener<TokenBloc, TokenState>(
      listener: (context, state) {
        if (state is TokenOrderCreated) {
          // Order created successfully - only call external callback
          // Payment gateway opening is handled by parent (TokenManagementPage)
          debugPrint('[TokenPurchaseDialog] Order created: ${state.orderId}');

          widget.onOrderCreated(
            state.orderId,
            state.tokensToPurchase,
            state.amount,
          );
        } else if (state is TokenError && state.operation == 'order_creation') {
          // Order creation failed
          setState(() {
            _isLoading = false;
            _paymentStatus = 'ready';
          });

          // Handle the error
          widget.onPaymentFailure(PaymentFailureResponse(
            1, // code
            state.failure.message, // message
            {'error': 'ORDER_CREATION_FAILED'}, // data
          ));
        }
      },
      child: Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              Flexible(child: _buildContent(theme)),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
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
                  color: theme.colorScheme.primary,
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
                      context.tr(TranslationKeys.tokenPurchaseDialogTitle),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(TranslationKeys.tokenPurchaseDialogSubtitle),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCurrentBalance(theme),
        ],
      ),
    );
  }

  Widget _buildCurrentBalance(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${context.tr(TranslationKeys.tokenPurchaseDialogCurrentBalance)}: ',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            '${widget.tokenStatus.totalTokens} ${context.tr(TranslationKeys.tokenPurchaseDialogTokens)}',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              if (widget.savedPaymentMethods.isNotEmpty)
                Tab(
                  icon: const Icon(Icons.payment, size: 20),
                  text: context
                      .tr(TranslationKeys.tokenPurchaseDialogSavedMethods),
                ),
              Tab(
                icon: const Icon(Icons.local_offer, size: 20),
                text: context.tr(TranslationKeys.tokenPurchaseDialogPackages),
              ),
              Tab(
                icon: const Icon(Icons.edit, size: 20),
                text: context.tr(TranslationKeys.tokenPurchaseDialogCustom),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                if (widget.savedPaymentMethods.isNotEmpty)
                  _buildSavedPaymentMethods(theme),
                _buildPackageSelection(theme),
                _buildCustomAmountInput(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPaymentMethods(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.tokenPurchaseDialogChooseSavedMethod),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.savedPaymentMethods
              .map((method) => _buildSavedPaymentMethodCard(method, theme)),
          const SizedBox(height: 16),
          // Show token amount selection for saved methods
          Text(
            context.tr(TranslationKeys.tokenPurchaseDialogChooseAmount),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._packages.map((package) => _buildPackageCard(package)),
        ],
      ),
    );
  }

  Widget _buildSavedPaymentMethodCard(
      SavedPaymentMethod method, ThemeData theme) {
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
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.05)
                  : theme.cardColor,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getPaymentMethodIcon(method.methodType),
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            method.displayName ??
                                _getPaymentMethodName(method.methodType),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (method.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.tr(
                                    TranslationKeys.tokenPurchaseDialogDefault),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPaymentMethodDetails(method),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      if (method.lastUsed != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr(TranslationKeys.tokenPurchaseDialogLastUsed)}: ${_formatLastUsed(method.lastUsed!)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
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

  Widget _buildPackageSelection(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            context.tr(TranslationKeys.tokenPurchaseDialogChoosePackage),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ..._packages.map((package) => _buildPackageCard(package)),
        ],
      ),
    );
  }

  Widget _buildPackageCard(TokenPackage package) {
    final isSelected = _selectedPackageTokens == package.tokens;
    final theme = Theme.of(context);

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
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.05)
                  : theme.cardColor,
            ),
            child: Stack(
              children: [
                if (package.isPopular)
                  Positioned(
                    right: 0,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.tr(TranslationKeys.tokenPurchaseDialogPopular),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.token,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${package.rupees}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (package.discount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${package.discount}% ${context.tr(TranslationKeys.tokenPurchaseDialogOff)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(package.tokens / package.rupees).toStringAsFixed(1)} ${context.tr(TranslationKeys.tokenPurchaseDialogTokensPerRupee)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountInput(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.tokenPurchaseDialogEnterCustom),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText:
                  context.tr(TranslationKeys.tokenPurchaseDialogTokenAmount),
              hintText:
                  context.tr(TranslationKeys.tokenPurchaseDialogAmountHint),
              prefixIcon: Icon(Icons.token, color: theme.colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
            onChanged: (value) {
              final tokens = int.tryParse(value) ?? 0;
              if (tokens >= 10 && tokens <= 9999) {
                setState(() {
                  _customTokens = tokens;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.secondary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context
                          .tr(TranslationKeys.tokenPurchaseDialogPricingInfo),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${context.tr(TranslationKeys.tokenPurchaseDialogRate)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '• ${context.tr(TranslationKeys.tokenPurchaseDialogMinimum)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '• ${context.tr(TranslationKeys.tokenPurchaseDialogMaximum)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${context.tr(TranslationKeys.tokenPurchaseDialogCost)}: ₹${(_customTokens / 10).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final isPackageSelected = _selectedPackageTokens > 0;
    final isCustomValid = _customTokens >= 10 && _customTokens <= 9999;
    final currentTab = _tabController.index;
    final hasSavedMethods = widget.savedPaymentMethods.isNotEmpty;

    // Determine purchase readiness based on current tab
    bool canPurchase;
    int tokenAmount;
    int cost;

    if (hasSavedMethods && currentTab == 0) {
      // Saved payment methods tab
      canPurchase = _selectedPaymentMethod != null && isPackageSelected;
      tokenAmount = _selectedPackageTokens;
      cost = _packages
          .firstWhere((p) => p.tokens == _selectedPackageTokens,
              orElse: () => const TokenPackage(tokens: 0, rupees: 0))
          .rupees;
    } else if ((hasSavedMethods && currentTab == 1) ||
        (!hasSavedMethods && currentTab == 0)) {
      // Packages tab
      canPurchase = isPackageSelected;
      tokenAmount = _selectedPackageTokens;
      cost = _packages
          .firstWhere((p) => p.tokens == _selectedPackageTokens,
              orElse: () => const TokenPackage(tokens: 0, rupees: 0))
          .rupees;
    } else {
      // Custom amount tab
      canPurchase = isCustomValid;
      tokenAmount = _customTokens;
      cost = (_customTokens / 10).ceil();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          if (canPurchase) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${context.tr(TranslationKeys.tokenPurchaseDialogTotalCost)}:',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '₹$cost ${context.tr(TranslationKeys.tokenPurchaseDialogForTokens).replaceAll('{count}', tokenAmount.toString())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: Text(
                      context.tr(TranslationKeys.tokenPurchaseDialogCancel)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (canPurchase && !_isLoading)
                      ? () => _handlePurchase(tokenAmount)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onPrimary),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getPaymentStatusIcon(), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _getPaymentStatusText(canPurchase),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a dialog for Premium users who don't need to purchase tokens
  Widget _buildRestrictedDialog(BuildContext context) {
    final theme = Theme.of(context);

    // This dialog is now only shown for Premium users
    final message = context.tr(TranslationKeys.tokenPurchaseRestrictedPremium);
    final actionText = context.tr(TranslationKeys.tokenPurchaseDialogGotIt);

    return AlertDialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(
            Icons.star,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Text(
            context.tr(TranslationKeys.tokenPurchaseDialogPremiumMember),
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            context.tr(TranslationKeys.tokenPurchaseDialogCancel),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: widget.onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: Text(actionText),
        ),
      ],
    );
  }

  String _getPaymentStatusText(bool canPurchase) {
    if (!canPurchase) {
      return context.tr(TranslationKeys.tokenPurchaseDialogSelectAmount);
    }

    switch (_paymentStatus) {
      case 'creating_order':
        return context.tr(TranslationKeys.tokenPurchaseDialogCreatingOrder);
      case 'payment_opened':
        return context.tr(TranslationKeys.tokenPurchaseDialogPaymentOpened);
      case 'processing':
        return context.tr(TranslationKeys.tokenPurchaseDialogProcessing);
      case 'ready':
      default:
        return context.tr(TranslationKeys.tokenPurchaseDialogPurchase);
    }
  }

  IconData _getPaymentStatusIcon() {
    switch (_paymentStatus) {
      case 'creating_order':
        return Icons.hourglass_empty;
      case 'payment_opened':
        return Icons.open_in_new;
      case 'processing':
        return Icons.sync;
      case 'ready':
      default:
        return Icons.payment;
    }
  }

  Future<void> _handlePurchase(int tokenAmount) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _paymentStatus = 'creating_order';
    });

    try {
      // If using saved payment method, handle differently
      if (_selectedPaymentMethod != null) {
        await _handleSavedPaymentMethodPurchase(tokenAmount);
      } else {
        // Standard payment flow
        widget.onCreateOrder(tokenAmount);
      }
    } catch (e) {
      setState(() {
        _paymentStatus = 'ready';
        _isLoading = false;
      });

      // Handle errors
      widget.onPaymentFailure(PaymentFailureResponse(
        1, // code
        'Failed to initialize payment: ${e.toString()}', // message
        {'error': 'INITIALIZATION_ERROR'}, // data
      ));
    }
  }

  Future<void> _handleSavedPaymentMethodPurchase(int tokenAmount) async {
    if (_selectedPaymentMethod == null || widget.onUsePaymentMethod == null) {
      throw Exception('Saved payment method not properly configured');
    }

    setState(() {
      _paymentStatus = 'processing';
    });

    try {
      // Use the saved payment method
      widget.onUsePaymentMethod!(_selectedPaymentMethod!);

      // For now, we'll still go through the normal payment flow
      // In a real implementation, this might directly charge the saved method
      widget.onCreateOrder(tokenAmount);
    } catch (e) {
      setState(() {
        _paymentStatus = 'ready';
        _isLoading = false;
      });
      rethrow;
    }
  }

  // Helper methods for payment method display
  IconData _getPaymentMethodIcon(String methodType) {
    switch (methodType.toLowerCase()) {
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.account_balance;
      case 'netbanking':
        return Icons.account_balance;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodName(String methodType) {
    switch (methodType.toLowerCase()) {
      case 'card':
        return context.tr(TranslationKeys.tokenPurchaseDialogPaymentMethodCard);
      case 'upi':
        return context.tr(TranslationKeys.tokenPurchaseDialogPaymentMethodUpi);
      case 'netbanking':
        return context
            .tr(TranslationKeys.tokenPurchaseDialogPaymentMethodNetbanking);
      case 'wallet':
        return context
            .tr(TranslationKeys.tokenPurchaseDialogPaymentMethodWallet);
      default:
        return context.tr(TranslationKeys.tokenPurchaseDialogPaymentMethod);
    }
  }

  String _getPaymentMethodDetails(SavedPaymentMethod method) {
    if (method.methodType.toLowerCase() == 'card' && method.lastFour != null) {
      final brand = method.brand ?? 'Card';
      return '$brand •••• ${method.lastFour}';
    }
    if (method.methodType.toLowerCase() == 'upi' && method.lastFour != null) {
      return '${method.lastFour}@upi';
    }
    if (method.methodType.toLowerCase() == 'wallet' && method.brand != null) {
      return method.brand!;
    }
    return method.provider;
  }

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return context
            .tr(TranslationKeys.tokenPurchaseDialogMinutesAgo)
            .replaceAll('{count}', difference.inMinutes.toString());
      }
      return context
          .tr(TranslationKeys.tokenPurchaseDialogHoursAgo)
          .replaceAll('{count}', difference.inHours.toString());
    } else if (difference.inDays < 30) {
      return context
          .tr(TranslationKeys.tokenPurchaseDialogDaysAgo)
          .replaceAll('{count}', difference.inDays.toString());
    } else {
      return '${lastUsed.day}/${lastUsed.month}/${lastUsed.year}';
    }
  }

  /// Called when order is created successfully - opens Razorpay payment gateway
  Future<void> _openPaymentGateway(
      String orderId, int tokenAmount, double amount, String keyId) async {
    setState(() {
      _currentOrderId = orderId;
      _paymentStatus = 'payment_opened';
    });

    try {
      await PaymentService().openCheckout(
        orderId: orderId,
        amount: amount,
        description: '$tokenAmount tokens for Disciplefy Bible Study',
        userEmail: widget.userEmail,
        userPhone: widget.userPhone,
        keyId: keyId, // Pass the keyId from API response
        onSuccess: (PaymentSuccessResponse response) {
          setState(() {
            _paymentStatus = 'processing';
          });

          // Handle payment success
          widget.onPaymentSuccess(response);

          // Close dialog after successful payment
          Navigator.of(context).pop();
        },
        onError: (PaymentFailureResponse response) {
          setState(() {
            _paymentStatus = 'ready';
            _isLoading = false;
          });

          // Handle payment failure
          widget.onPaymentFailure(response);
        },
        onExternalWallet: (ExternalWalletResponse response) {
          print('External wallet selected: ${response.walletName}');
        },
      );
    } catch (e) {
      setState(() {
        _paymentStatus = 'ready';
        _isLoading = false;
      });

      // Handle errors
      widget.onPaymentFailure(PaymentFailureResponse(
        2, // code
        'Failed to open payment gateway: ${e.toString()}', // message
        {'error': 'GATEWAY_ERROR'}, // data
      ));
    }
  }
}

/// Token Package Model
///
/// Represents predefined token purchase packages with pricing and discounts
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

  double get tokensPerRupee => tokens / rupees;

  int get originalPrice => (tokens / 10).ceil();

  int get savings => originalPrice - rupees;
}
