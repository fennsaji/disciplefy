import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/platform_detection_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logger.dart';
import '../../data/datasources/subscription_remote_data_source.dart';
import '../../data/models/subscription_v2_models.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../utils/plan_features_extractor.dart';

class PlusUpgradePage extends StatefulWidget {
  const PlusUpgradePage({super.key});

  @override
  State<PlusUpgradePage> createState() => _PlusUpgradePageState();
}

class _PlusUpgradePageState extends State<PlusUpgradePage>
    with WidgetsBindingObserver {
  bool _hasOpenedPayment = false;
  bool _isLoadingPlan = true;

  SubscriptionPlanModel? _plusPlan;
  SubscriptionPlanModel? _standardPlan; // for comparison
  List<String> _features = [];
  List<PlanComparisonRow> _comparisonRows = [];

  static const Color _plusColor = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<SubscriptionBloc>().add(const CheckSubscriptionEligibility());
    _loadPlanData();
  }

  Future<void> _loadPlanData() async {
    try {
      final dataSource = sl<SubscriptionRemoteDataSource>();
      final platformService = PlatformDetectionService();
      final provider = platformService
          .providerToString(platformService.getPreferredProvider());

      final response =
          await dataSource.getPlans(provider: provider, region: 'IN');

      SubscriptionPlanModel? plus;
      SubscriptionPlanModel? standard;

      for (final plan in response.plans) {
        if (plan.planCode.toLowerCase() == 'plus') plus = plan;
        if (plan.planCode.toLowerCase() == 'standard') standard = plan;
      }

      if (mounted && plus != null) {
        setState(() {
          _plusPlan = plus;
          _standardPlan = standard;
          _features = PlanFeaturesExtractor.extractFeaturesFromPlan(plus!);
          _comparisonRows =
              PlanFeaturesExtractor.buildComparisonRows(standard, plus);
          _isLoadingPlan = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    } catch (e) {
      Logger.error('[PlusUpgrade] Failed to load plan data', error: e);
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true && _hasOpenedPayment) {
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _hasOpenedPayment) {
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  String get _displayPrice {
    if (_plusPlan != null) {
      return _plusPlan!.displayPrice.toStringAsFixed(0);
    }
    return '149';
  }

  String get _planName => _plusPlan?.planName ?? 'Disciplefy Plus';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upgrade to Plus',
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _plusColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context
                .read<SubscriptionBloc>()
                .add(const GetActiveSubscription()),
            tooltip: 'Check Status',
          ),
        ],
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text('Subscription created! Opening payment page...'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 2),
              ),
            );
            _hasOpenedPayment = true;
            _openAuthorizationUrl(state.authorizationUrl);
          } else if (state is SubscriptionLoaded) {
            if (state.activeSubscription?.isActive == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Subscription activated! You now have Plus access.'),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.of(context).pop();
              });
            }
          } else if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_isLoadingPlan) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBadge(),
                const SizedBox(height: 24),
                _buildPricingCard(),
                const SizedBox(height: 32),
                _buildFeaturesList(),
                const SizedBox(height: 32),
                if (_comparisonRows.isNotEmpty) ...[
                  _buildComparison(),
                  const SizedBox(height: 32),
                ],
                _buildActionButton(state),
                const SizedBox(height: 16),
                _buildTermsInfo(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _plusColor.withOpacity(0.1),
            _plusColor.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _plusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.diamond_rounded, size: 64, color: _plusColor),
          const SizedBox(height: 12),
          Text(
            _planName,
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _plusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _plusPlan?.description ??
                'Enhanced features for serious Bible students',
            style: AppFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_plusColor, _plusColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Most Popular',
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_plusPlan?.hasDiscount == true) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, right: 8),
                    child: Text(
                      '₹${_plusPlan!.pricing.basePriceFormatted.toStringAsFixed(0)}',
                      style: AppFonts.inter(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.7),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
                Text(
                  '₹',
                  style: AppFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _displayPrice,
                  style: AppFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '/month',
                    style: AppFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Cancel anytime • Billed monthly',
                style: AppFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you get with Plus',
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _plusColor,
          ),
        ),
        const SizedBox(height: 16),
        ..._features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildFeatureRow(feature),
            )),
      ],
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _plusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.check_rounded, size: 18, color: _plusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    final prevName = _standardPlan?.planName ?? 'Standard';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$prevName vs ${_plusPlan?.planName ?? 'Plus'}',
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _plusColor,
              ),
            ),
            const SizedBox(height: 16),
            ..._comparisonRows.map((row) => _buildComparisonRow(
                  row.label,
                  row.previousValue,
                  row.currentValue,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
      String feature, String previousValue, String currentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              previousValue,
              style: AppFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              currentValue,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _plusColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(SubscriptionState state) {
    if (state is SubscriptionEligibilityChecked && !state.canSubscribe) {
      return Card(
        color: _plusColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _plusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.eligibilityMessage,
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isLoading =
        state is SubscriptionLoading && state.operation == 'creating';

    return ElevatedButton(
      onPressed: isLoading ? null : _handleUpgrade,
      style: ElevatedButton.styleFrom(
        backgroundColor: _plusColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond_rounded),
                const SizedBox(width: 8),
                Text(
                  'Upgrade to Plus',
                  style:
                      AppFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }

  Future<void> _handleUpgrade() async {
    String? promoCode;
    int? planPrice;
    try {
      final box = Hive.isBoxOpen('app_settings')
          ? Hive.box('app_settings')
          : await Hive.openBox('app_settings');
      promoCode = box.get('pending_promo_code') as String?;
      planPrice = box.get('selected_plan_price') as int?;
      if (promoCode != null) await box.delete('pending_promo_code');
    } catch (e) {
      Logger.debug('[PlusUpgrade] Failed to read Hive: $e');
    }

    if (!mounted) return;

    if (planPrice != null && planPrice == 0) {
      context.read<SubscriptionBloc>().add(
            ActivateFreeSubscription(planCode: 'plus', promoCode: promoCode),
          );
    } else {
      context
          .read<SubscriptionBloc>()
          .add(CreatePlusSubscription(promoCode: promoCode));
    }
  }

  Widget _buildTermsInfo() {
    return Column(
      children: [
        if (_hasOpenedPayment) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _plusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _plusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _plusColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Completed payment? Tap refresh to check your subscription status.',
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          'By subscribing, you agree to our Terms of Service and Privacy Policy.',
          style: AppFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Secure payment via Razorpay',
              style: AppFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openAuthorizationUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open payment URL: $url'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
