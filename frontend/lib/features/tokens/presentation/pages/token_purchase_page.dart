import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/payment_responses.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/apple_consumable_purchase_service.dart';
import 'package:disciplefy_bible_study/core/services/payment_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/platform_utils.dart';
import 'package:disciplefy_bible_study/features/tokens/data/datasources/token_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_pricing.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/payment_success_view.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// "Get credits" in the quiet-ledger design.
///
/// Pricing comes from the backend; packs are shown as a two-column grid and a
/// custom amount tab is offered where Razorpay is used. On iOS purchases go
/// through App Store In-App Purchase (packs only).
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

  /// Pack selection parked while the Custom tab is showing, so the CTA always
  /// reflects the visible tab and switching back restores the pack.
  int _parkedPackageTokens = 0;

  // Store current purchase details for payment confirmation
  int _currentPurchaseTokens = 0;
  String _currentOrderId = '';

  /// What the current purchase costs, for the success screen.
  String? _currentPurchasePrice;

  // Pricing configuration from backend
  bool _isPricingLoading = true;
  String? _pricingError;
  int _tokensPerRupee = 2; // Default
  List<TokenPackage> _packages = const [];

  // iOS: App Store consumable products keyed by token count. Purchases on iOS
  // must go through In-App Purchase (App Store guideline 3.1.1) — Razorpay and
  // custom amounts are Android/web only.
  final bool _useAppleIAP = PlatformUtils.isIOS;
  Map<int, ProductDetails> _iosProducts = {};
  AppleConsumablePurchaseService? _consumableService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _customAmountController =
        TextEditingController(text: _customTokens.toString());

    if (_useAppleIAP) {
      _setupAppleIAP();
    } else {
      // Initialize PaymentService (Razorpay)
      PaymentService().initialize();
    }

    // Fetch pricing from backend (no fallback - show error if fails)
    _fetchTokenPricing();
  }

  void _setupAppleIAP() {
    final service = sl<AppleConsumablePurchaseService>();
    service.bind();
    // These callbacks fire for EVERY confirmed consumable — including background
    // sandbox replays and double-deliveries. Only react to the purchase this
    // page initiated (which set _isLoading); otherwise a stray success would
    // pop the page again → popped past the root → black screen.
    service.onSuccess = (result) {
      if (!mounted || !_isLoading) return;
      setState(() => _isLoading = false);
      if (result.kind != ConsumableKind.tokens) return;
      context.read<TokenBloc>().add(const RefreshTokenStatus());
      _showSuccessAndClose(
        creditsAdded: result.tokensCredited,
        receipt: null,
      );
    };
    service.onError = (message) {
      if (!mounted || !_isLoading) return;
      setState(() => _isLoading = false);
      showAppSnackBar(
        context,
        message,
        tone: AppSnackTone.error,
      );
    };
    service.onCancelled = () {
      if (!mounted || !_isLoading) return;
      setState(() => _isLoading = false);
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.commonPurchaseCancelled),
      );
    };
    _consumableService = service;
  }

  Future<void> _loadAppleProducts() async {
    try {
      final products = await _consumableService!
          .loadTokenPackProducts(_packages.map((p) => p.tokens).toList());
      if (mounted) {
        setState(() {
          _iosProducts = products;
          _preselectPopularPackage();
        });
      }
    } catch (e) {
      Logger.debug(
          '❌ [TokenPurchasePage] Failed to load App Store products: $e');
      if (mounted) {
        setState(() =>
            _pricingError = context.tr(TranslationKeys.ledgerPacksUnavailable));
      }
    }
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

      if (!mounted) return;
      setState(() {
        _tokensPerRupee = pricingData.tokensPerRupee;
        _packages = pricingData.packages;
        _isPricingLoading = false;
        _preselectPopularPackage();
      });

      Logger.debug(
          '💰 [TokenPurchasePage] Pricing loaded: $_tokensPerRupee tokens/₹, ${_packages.length} packages');

      // iOS: resolve packages to App Store products for compliant purchasing
      if (_useAppleIAP) {
        await _loadAppleProducts();
      }
    } catch (e) {
      Logger.debug('❌ [TokenPurchasePage] Failed to fetch pricing: $e');
      if (!mounted) return;
      setState(() {
        _pricingError = context.tr(TranslationKeys.ledgerPricesError);
        _isPricingLoading = false;
      });
    }
  }

  /// Starts on the pack marked popular, as the design shows, once the packs
  /// the user can actually buy are known.
  void _preselectPopularPackage() {
    if (_selectedPackageTokens > 0 || _tabController.index != 0) return;
    for (final p in _visiblePackages) {
      if (p.isPopular) {
        _selectedPackageTokens = p.tokens;
        return;
      }
    }
  }

  List<TokenPackage> get _visiblePackages => _useAppleIAP
      ? _packages.where((p) => _iosProducts.containsKey(p.tokens)).toList()
      : _packages;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      if (_tabController.index == 1 && _selectedPackageTokens > 0) {
        _parkedPackageTokens = _selectedPackageTokens;
        _selectedPackageTokens = 0;
      } else if (_tabController.index == 0 &&
          _selectedPackageTokens == 0 &&
          _parkedPackageTokens > 0) {
        _selectedPackageTokens = _parkedPackageTokens;
        _parkedPackageTokens = 0;
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _customAmountController.dispose();
    if (!_useAppleIAP) {
      PaymentService().dispose();
    }
    _consumableService?.onSuccess = null;
    _consumableService?.onError = null;
    _consumableService?.onCancelled = null;
    super.dispose();
  }

  /// Shows the payment-success step, then closes this page with `true` as
  /// before. "Start a study" continues to the generate screen.
  Future<void> _showSuccessAndClose({
    required int creditsAdded,
    required String? receipt,
  }) async {
    final router = GoRouter.maybeOf(context);
    final action = await showPaymentSuccess(
      context,
      creditsAdded: creditsAdded,
      newBalance: widget.tokenStatus.totalTokens + creditsAdded,
      amountPaid: _currentPurchasePrice,
      receipt: receipt,
    );
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    if (action == PaymentSuccessAction.startStudy) {
      router?.go(AppRoutes.generateStudy);
    }
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
      Logger.debug('[TokenPurchasePage] Token Amount: $tokenAmount');

      final dataSource = sl<TokenRemoteDataSource>();
      await dataSource.confirmPayment(
        paymentId: response.paymentId!,
        orderId: response.orderId!,
        signature: response.signature!,
        tokenAmount: tokenAmount,
      );

      Logger.debug('[TokenPurchasePage] Payment confirmed successfully!');

      if (mounted) {
        // Refresh token balance
        context.read<TokenBloc>().add(const RefreshTokenStatus());
        setState(() => _isLoading = false);
        await _showSuccessAndClose(
          creditsAdded: tokenAmount,
          receipt: response.paymentId,
        );
      }
    } catch (e) {
      Logger.debug('[TokenPurchasePage] ❌ Failed to confirm payment: $e');

      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.ledgerPaymentPending),
          tone: AppSnackTone.warning,
        );

        // Refresh token balance - tokens may have been credited by webhook
        context.read<TokenBloc>().add(const RefreshTokenStatus());

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

    // Razorpay code 2 = user cancelled — show no error snackbar (user-initiated).
    if (response.code == 2) return;

    if (mounted) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.ledgerPaymentFailed),
        tone: AppSnackTone.error,
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
      _parkedPackageTokens = 0;
    });
  }

  TokenPackage? get _selectedPackage {
    // Avoid firstWhere+orElse — at runtime _packages holds TokenPackageModel
    // objects, and DDC (web) enforces the generic element type on orElse,
    // causing a TypeError when orElse returns the base TokenPackage class.
    for (final p in _packages) {
      if (p.tokens == _selectedPackageTokens) return p;
    }
    return null;
  }

  int get _purchaseTokens =>
      _selectedPackageTokens > 0 ? _selectedPackageTokens : _customTokens;

  /// Price label for the current selection, as it will be charged.
  String? get _purchasePriceLabel {
    if (_useAppleIAP) return _iosProducts[_selectedPackageTokens]?.price;
    final pkg = _selectedPackage;
    if (pkg != null) return '₹${pkg.rupees}';
    if (_customTokens <= 0) return null;
    return '₹${(_customTokens / _tokensPerRupee).ceil()}';
  }

  void _handlePurchase() {
    final tokenAmount = _purchaseTokens;

    if (tokenAmount <= 0) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.ledgerChoosePackOrAmount),
        tone: AppSnackTone.warning,
      );
      return;
    }

    // iOS: purchase through the App Store (guideline 3.1.1) — packages only.
    if (_useAppleIAP) {
      final product = _iosProducts[_selectedPackageTokens];
      if (product == null) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.ledgerChoosePack),
          tone: AppSnackTone.warning,
        );
        return;
      }
      setState(() {
        _isLoading = true;
        _currentPurchasePrice = product.price;
      });
      _consumableService!.purchase(product);
      return;
    }

    // Determine the discounted rupee amount for this purchase.
    // For a selected package, use its pre-loaded discounted price.
    // For a custom amount, compute from the base rate (no discount).
    final selectedPackage = _selectedPackage;
    final int rupeeAmount =
        selectedPackage?.rupees ?? (_customTokens / _tokensPerRupee).ceil();

    setState(() {
      _isLoading = true;
      _currentPurchasePrice = '₹$rupeeAmount';
    });

    // Create order via BLoC, passing the discounted price so Razorpay charges correctly.
    context.read<TokenBloc>().add(CreatePaymentOrder(
          tokenAmount: tokenAmount,
          rupeeAmount: rupeeAmount,
        ));
  }

  @override
  Widget build(BuildContext context) {
    // Kill switch: token purchase disabled by admin
    if (!sl<SystemConfigService>().isTokenPurchaseEnabled) {
      return _buildMessagePage(
        icon: Icons.shopping_bag_outlined,
        title: context.tr(TranslationKeys.ledgerPurchasePausedTitle),
        body: context.tr(TranslationKeys.ledgerPurchasePausedBody),
      );
    }

    // Premium users cannot purchase (they have unlimited)
    if (widget.tokenStatus.userPlan == UserPlan.premium) {
      return _buildMessagePage(
        icon: Icons.all_inclusive_rounded,
        title: context.tr(TranslationKeys.ledgerPremiumUnlimitedTitle),
        body: context.tr(TranslationKeys.ledgerPremiumUnlimitedBody),
      );
    }

    final palette = ReaderPalette.of(context);
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
            keyId: state.keyId,
            onSuccess: _handlePaymentSuccess,
            onError: _handlePaymentError,
            onExternalWallet: _handleExternalWallet,
          );
        } else if (state is TokenError && state.operation == 'order_creation') {
          setState(() {
            _isLoading = false;
          });

          showAppSnackBar(
            context,
            ErrorMessageSanitizer.sanitize(state.failure),
            tone: AppSnackTone.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: palette.page,
        appBar: LedgerTopBar(
          title: context.tr(TranslationKeys.tokenPurchaseTitle),
          subtitle: context.tr(TranslationKeys.ledgerBalanceSubtitle,
              {'count': widget.tokenStatus.totalTokens}),
          onBack: () => Navigator.of(context).pop(),
        ),
        body: _isPricingLoading
            ? LedgerLoading(
                label: context.tr(TranslationKeys.ledgerLoadingPrices))
            : _pricingError != null
                ? LedgerMessage(
                    icon: Icons.cloud_off_rounded,
                    isError: true,
                    title: _pricingError!,
                    actionLabel: context.tr(TranslationKeys.commonRetry),
                    onAction: _fetchTokenPricing,
                  )
                : _buildPurchaseContent(),
      ),
    );
  }

  Widget _buildMessagePage({
    required IconData icon,
    required String title,
    required String body,
  }) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: LedgerTopBar(
        title: context.tr(TranslationKeys.tokenPurchaseTitle),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: LedgerMessage(icon: icon, title: title, body: body),
    );
  }

  Widget _buildPurchaseContent() {
    // iOS: App Store consumables only — no custom amounts (IAP products are
    // fixed), so no tabs.
    if (_useAppleIAP) {
      return Column(
        children: [
          Expanded(child: _buildPackagesTab()),
          _buildPurchaseButton(),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: _SegmentedTabs(
            controller: _tabController,
            labels: [
              context.tr(TranslationKeys.tokenPurchasePackages),
              context.tr(TranslationKeys.tokenPurchaseCustom),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPackagesTab(),
              _buildCustomTab(),
            ],
          ),
        ),
        _buildPurchaseButton(),
      ],
    );
  }

  Widget _buildPackagesTab() {
    final palette = ReaderPalette.of(context);
    final visiblePackages = _visiblePackages;

    if (visiblePackages.isEmpty) {
      return LedgerMessage(
        icon: Icons.inventory_2_outlined,
        title: context.tr(TranslationKeys.ledgerNoPacks),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Two packs per row; each row is as tall as its tallest card so
        // long translations grow the cards instead of clipping them.
        for (var row = 0; row < visiblePackages.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = row; index < row + 2; index++) ...[
                  if (index > row) const SizedBox(width: 10),
                  Expanded(
                    child: index < visiblePackages.length
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 116),
                            child: _packCardAt(visiblePackages, index),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          context.tr(TranslationKeys.ledgerNeverExpire),
          textAlign: TextAlign.center,
          style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
        ),
      ],
    );
  }

  Widget _packCardAt(List<TokenPackage> visiblePackages, int index) {
    final package = visiblePackages[index];
    final iosProduct = _useAppleIAP ? _iosProducts[package.tokens] : null;
    return _PackCard(
      package: package,
      // iOS: App Store sets the charged price — show its localized
      // value, not the Razorpay rupee price.
      price: iosProduct?.price ?? '₹${package.rupees}',
      showDiscount: iosProduct == null && package.discount > 0,
      // Unit price only for rupee packs; App Store prices are
      // localized strings.
      unitPrice: iosProduct == null && package.tokens > 0
          ? context.tr(TranslationKeys.ledgerPaisePerCredit, {
              'paise':
                  (package.rupees * 100 / package.tokens).toStringAsFixed(1),
            })
          : null,
      selected: _selectedPackageTokens == package.tokens,
      onTap: () => _onPackageSelected(package),
    );
  }

  Widget _buildCustomTab() {
    final palette = ReaderPalette.of(context);
    final cost = (_customTokens / _tokensPerRupee).ceil();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        LedgerSectionLabel(context.tr(TranslationKeys.ledgerCustomLabel)),
        TextField(
          key: const Key('credits_custom_amount'),
          controller: _customAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: palette.text,
            fontFeatures: kLedgerTabular,
          ),
          decoration: InputDecoration(
            hintText: context.tr(TranslationKeys.ledgerCustomHint),
            hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
            prefixIcon: Icon(Icons.toll_outlined, color: palette.gold),
            filled: true,
            fillColor: palette.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: palette.selectedFill, width: 1.5),
            ),
          ),
          onChanged: _onCustomAmountChanged,
        ),
        const SizedBox(height: 14),
        LedgerRow(
          label: context.tr(TranslationKeys.ledgerCreditsLabel),
          value: '$_customTokens',
        ),
        LedgerRow(
          label: context.tr(TranslationKeys.ledgerCostLabel),
          value: '₹$cost',
          valueColor: palette.gold,
        ),
        const LedgerHairline(verticalMargin: 10),
        Text(
          context
              .tr(TranslationKeys.ledgerCustomRate, {'rate': _tokensPerRupee}),
          style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(TranslationKeys.ledgerCustomTip),
          style: AppFonts.inter(fontSize: 12.5, color: palette.gold),
        ),
      ],
    );
  }

  Widget _buildPurchaseButton() {
    final tokenAmount = _purchaseTokens;
    final price = _purchasePriceLabel;
    final isValid = tokenAmount > 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: LedgerPrimaryButton(
            key: const Key('credits_buy_cta'),
            icon: Icons.lock_outline_rounded,
            loading: _isLoading,
            label: price == null
                ? context.tr(TranslationKeys.tokenPurchaseButton,
                    {'amount': tokenAmount.toString()})
                : context.tr(TranslationKeys.ledgerBuyCta,
                    {'count': tokenAmount, 'price': price}),
            onPressed: isValid && !_isLoading ? _handlePurchase : null,
          ),
        ),
      ),
    );
  }
}

/// Two-segment pill switch driving a [TabController].
class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const _SegmentedTabs({required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: BoxDecoration(
          color: palette.isDark ? palette.page : palette.card,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: palette.text,
        unselectedLabelColor: palette.muted,
        labelStyle: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: [
          for (final label in labels)
            Tab(
              height: 40,
              // Shrinks a long (Malayalam) label instead of cutting it.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1),
              ),
            ),
        ],
      ),
    );
  }
}

/// One credit pack: coins + amount, price and discount; gold ring when
/// selected.
class _PackCard extends StatelessWidget {
  final TokenPackage package;
  final String price;
  final bool showDiscount;
  final String? unitPrice;
  final bool selected;
  final VoidCallback onTap;

  const _PackCard({
    required this.package,
    required this.price,
    required this.showDiscount,
    required this.unitPrice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ring = palette.selectedFill;
    return Semantics(
      button: true,
      selected: selected,
      label: '${package.tokens} · $price',
      child: Material(
        color: selected
            ? ring.withValues(alpha: palette.isDark ? 0.16 : 0.07)
            : palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? ring : palette.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('credits_pack_${package.tokens}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Amount and the "Popular" tag share a line when they fit
                // and wrap otherwise, so neither is cut.
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.toll_outlined,
                            size: 18, color: palette.gold),
                        const SizedBox(width: 6),
                        Text(
                          '${package.tokens}',
                          style: AppFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                            fontFeatures: kLedgerTabular,
                          ),
                        ),
                      ],
                    ),
                    if (package.isPopular)
                      _PopularPill(
                          label: context.tr(TranslationKeys.ledgerPopular)),
                  ],
                ),
                const Spacer(),
                // Price and discount share a line when they fit; the
                // discount wraps under the price otherwise.
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      price,
                      style: AppFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        fontFeatures: kLedgerTabular,
                      ),
                    ),
                    if (showDiscount)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          context.tr(TranslationKeys.ledgerPercentOff,
                              {'percent': package.discount}),
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.appSuccess,
                          ),
                        ),
                      ),
                  ],
                ),
                if (unitPrice != null)
                  Text(
                    unitPrice!,
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: palette.muted,
                      fontFeatures: kLedgerTabular,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold "POPULAR" tag on the recommended pack.
class _PopularPill extends StatelessWidget {
  final String label;

  const _PopularPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.selectedFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: AppFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: palette.onSelected,
        ),
      ),
    );
  }
}
