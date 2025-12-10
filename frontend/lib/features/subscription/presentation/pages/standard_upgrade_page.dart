import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../../domain/entities/subscription.dart';

/// Standard Upgrade Page
///
/// Presents Standard subscription benefits and allows users to upgrade
/// to Standard plan for ₹50/month with 100 daily tokens and core features.
class StandardUpgradePage extends StatefulWidget {
  const StandardUpgradePage({super.key});

  @override
  State<StandardUpgradePage> createState() => _StandardUpgradePageState();
}

class _StandardUpgradePageState extends State<StandardUpgradePage>
    with WidgetsBindingObserver {
  bool _hasOpenedPayment = false;

  // Standard plan color
  static const Color _standardPurple = Color(0xFF6A4FB6);

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
    // Refresh subscription when returning to this page (works on web!)
    if (ModalRoute.of(context)?.isCurrent == true && _hasOpenedPayment) {
      debugPrint(
          '[StandardUpgrade] Page became visible after payment - checking subscription status');
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
          '[StandardUpgrade] App resumed after payment - checking subscription status');
      // Check if subscription is now active
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Upgrade to Standard',
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _standardPurple,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Manual refresh button for users to check subscription status
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              debugPrint(
                  '[StandardUpgrade] Manual refresh - checking subscription status');
              context
                  .read<SubscriptionBloc>()
                  .add(const GetActiveSubscription());
            },
            tooltip: 'Check Status',
          ),
        ],
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionCreated) {
            // Show success message and open authorization URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text('Subscription created! Opening payment page...'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 2),
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
                  '[StandardUpgrade] Subscription is now active - navigating back');

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Subscription activated! You now have Standard access.'),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 3),
                ),
              );

              // Navigate back to previous page to show updated status
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
                // Standard Badge
                _buildStandardBadge(),
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

  Widget _buildStandardBadge() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _standardPurple.withOpacity(0.1),
            _standardPurple.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _standardPurple.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 64,
            color: _standardPurple,
          ),
          const SizedBox(height: 12),
          Text(
            'Disciplefy Standard',
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _standardPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock powerful features for your Bible study',
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              _standardPurple,
              _standardPurple.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Best Value Badge
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Best Value',
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
                Text(
                  '₹',
                  style: AppFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '50',
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

  Widget _buildBenefitsList() {
    final benefits = [
      _BenefitItem(
        icon: Icons.generating_tokens_rounded,
        title: '100 AI Tokens Daily',
        description: 'Generate study guides without limits',
      ),
      _BenefitItem(
        icon: Icons.record_voice_over_rounded,
        title: 'AI Discipler',
        description: 'Voice assistant for interactive Bible study',
      ),
      _BenefitItem(
        icon: Icons.psychology_rounded,
        title: 'Memory Verses',
        description: 'Memorize scripture with spaced repetition',
      ),
      _BenefitItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Follow-up Questions',
        description: 'Dive deeper into any study topic',
      ),
      _BenefitItem(
        icon: Icons.history_rounded,
        title: 'Complete History',
        description: 'Access all your previous studies',
      ),
      _BenefitItem(
        icon: Icons.bookmark_outline_rounded,
        title: 'Bookmarks & Notes',
        description: 'Save and organize your favorites',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you get with Standard',
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _standardPurple,
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
            color: _standardPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            benefit.icon,
            size: 24,
            color: _standardPurple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                benefit.title,
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                benefit.description,
                style: AppFonts.inter(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
              'Free vs Standard',
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _standardPurple,
              ),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow(
              'Daily Tokens',
              '20',
              '100',
            ),
            _buildComparisonRow(
              'AI Discipler',
              '✗',
              '10/month',
            ),
            _buildComparisonRow(
              'Memory Verses',
              '✗',
              '✓',
            ),
            _buildComparisonRow(
              'Token Purchase',
              '✓',
              '✓',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String feature, String free, String standard) {
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
              free,
              style: AppFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              standard,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _standardPurple,
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
          color: _standardPurple.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _standardPurple,
                ),
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
    }

    final isLoading =
        state is SubscriptionLoading && state.operation == 'creating';

    return ElevatedButton(
      onPressed: isLoading
          ? null
          : () {
              context
                  .read<SubscriptionBloc>()
                  .add(const CreateStandardSubscription());
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: _standardPurple,
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
                const Icon(Icons.auto_awesome_rounded),
                const SizedBox(width: 8),
                Text(
                  'Upgrade to Standard',
                  style: AppFonts.inter(
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
        // Show helper message if payment was opened
        if (_hasOpenedPayment) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _standardPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _standardPurple.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _standardPurple,
                  size: 20,
                ),
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
