import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../../domain/entities/subscription.dart';

/// Premium Upgrade Page
///
/// Presents premium subscription benefits and allows users to upgrade
/// to premium plan for ₹100/month with unlimited tokens and features.
class PremiumUpgradePage extends StatefulWidget {
  const PremiumUpgradePage({super.key});

  @override
  State<PremiumUpgradePage> createState() => _PremiumUpgradePageState();
}

class _PremiumUpgradePageState extends State<PremiumUpgradePage>
    with WidgetsBindingObserver {
  bool _hasOpenedPayment = false;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);
    // Check subscription eligibility when page opens
    context.read<SubscriptionBloc>().add(const CheckSubscriptionEligibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ FIX: Refresh subscription when returning to this page (works on web!)
    // This detects when user comes back from payment page
    if (ModalRoute.of(context)?.isCurrent == true && _hasOpenedPayment) {
      debugPrint(
          '[PremiumUpgrade] Page became visible after payment - checking subscription status');
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes after user completes payment (mobile only)
    if (state == AppLifecycleState.resumed && _hasOpenedPayment) {
      debugPrint(
          '[PremiumUpgrade] App resumed after payment - checking subscription status');
      // Check if subscription is now active
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upgrade to Premium',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // ✅ Manual refresh button for users to check subscription status
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              debugPrint(
                  '[PremiumUpgrade] Manual refresh - checking subscription status');
              context
                  .read<SubscriptionBloc>()
                  .add(const GetActiveSubscription());
            },
            tooltip: 'Check subscription status',
          ),
        ],
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionCreated) {
            // Show success message and open authorization URL
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Subscription created! Opening payment authorization...'),
                backgroundColor: AppTheme.successColor,
                duration: Duration(seconds: 2),
              ),
            );

            // Mark that we've opened payment
            _hasOpenedPayment = true;

            // Open Razorpay authorization URL
            _openAuthorizationUrl(state.authorizationUrl);
          } else if (state is SubscriptionLoaded) {
            // User has returned from payment and subscription is active
            if (state.activeSubscription != null &&
                state.activeSubscription!.isActive) {
              debugPrint(
                  '[PremiumUpgrade] Subscription is now active - navigating back');

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('🎉 Premium subscription activated successfully!'),
                  backgroundColor: AppTheme.successColor,
                  duration: Duration(seconds: 3),
                ),
              );

              // Navigate back to Token Management to show updated status
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              });
            }
          } else if (state is SubscriptionError) {
            // Show error message
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium Badge
                _buildPremiumBadge(),
                const SizedBox(height: 24),

                // Pricing Card
                _buildPricingCard(),
                const SizedBox(height: 32),

                // Benefits List
                _buildBenefitsList(),
                const SizedBox(height: 32),

                // Plan Comparison
                _buildPlanComparison(),
                const SizedBox(height: 32),

                // Upgrade Button or Eligibility Message
                _buildActionButton(state),
                const SizedBox(height: 16),

                // Terms and Info
                _buildTermsInfo(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.secondaryColor.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Disciplefy Premium',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock unlimited access to all features',
            style: GoogleFonts.inter(
              fontSize: 14,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '100',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '/month',
                    style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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

  Widget _buildBenefitsList() {
    final benefits = [
      _BenefitItem(
        icon: Icons.all_inclusive_rounded,
        title: 'Unlimited Tokens',
        description: 'Generate study guides without daily limits',
      ),
      _BenefitItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Unlimited Follow-ups',
        description: 'Ask unlimited follow-up questions',
      ),
      _BenefitItem(
        icon: Icons.auto_awesome_rounded,
        title: 'Premium AI Models',
        description: 'Access to advanced AI for better insights',
      ),
      _BenefitItem(
        icon: Icons.history_rounded,
        title: 'Complete History',
        description: 'Access all your past study guides forever',
      ),
      _BenefitItem(
        icon: Icons.cloud_sync_rounded,
        title: 'Priority Support',
        description: 'Get help faster with premium support',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you get with Premium',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        ...benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildBenefitItem(benefit),
            )),
      ],
    );
  }

  Widget _buildBenefitItem(_BenefitItem benefit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            benefit.icon,
            size: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                benefit.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.check_circle_rounded,
          color: AppTheme.successColor,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildPlanComparison() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan Comparison',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow('Daily tokens', '100', 'Unlimited'),
            _buildComparisonRow('Follow-up questions', 'Limited', 'Unlimited'),
            _buildComparisonRow('AI model', 'Basic', 'Premium'),
            _buildComparisonRow('Support', 'Standard', 'Priority'),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String feature, String standard, String premium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              standard,
              style: GoogleFonts.inter(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              premium,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(SubscriptionState state) {
    if (state is SubscriptionEligibilityChecked) {
      if (!state.canSubscribe) {
        return Card(
          color: AppTheme.secondaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.eligibilityMessage,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final isLoading =
        state is SubscriptionLoading && state.operation == 'creating';

    return ElevatedButton(
      onPressed: isLoading
          ? null
          : () {
              context.read<SubscriptionBloc>().add(const CreateSubscription());
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                Icon(Icons.workspace_premium_rounded),
                const SizedBox(width: 8),
                Text(
                  'Upgrade to Premium',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTermsInfo() {
    return Column(
      children: [
        // ✅ Show helper message if payment was opened
        if (_hasOpenedPayment) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Completed payment? Tap the refresh button ↑ to check your subscription status',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          'By subscribing, you agree to our Terms of Service and Privacy Policy',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
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
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Secure payment via Razorpay',
              style: GoogleFonts.inter(
                fontSize: 12,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
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
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open payment URL: $url'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

class _BenefitItem {
  final IconData icon;
  final String title;
  final String description;

  _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
