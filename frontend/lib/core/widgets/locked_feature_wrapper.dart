import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/tokens/presentation/bloc/token_bloc.dart';
import '../../features/tokens/presentation/bloc/token_state.dart';
import '../services/system_config_service.dart';
import '../di/injection_container.dart';
import 'upgrade_dialog.dart';

/// Wrapper widget that handles locked feature display and upgrade prompts
///
/// Usage:
/// ```dart
/// LockedFeatureWrapper(
///   featureKey: 'ai_discipler',
///   child: VoiceConversationButton(),
/// )
/// ```
///
/// Behavior:
/// - If user has access → renders child normally
/// - If locked (display_mode='lock' && no access) → renders child with lock overlay
/// - If hidden (display_mode='hide' && no access) → renders nothing
/// - If disabled globally → renders nothing
class LockedFeatureWrapper extends StatelessWidget {
  final Widget child;
  final String featureKey;
  final bool showLockOverlay;
  final String? customLockedMessage;

  const LockedFeatureWrapper({
    super.key,
    required this.child,
    required this.featureKey,
    this.showLockOverlay = true,
    this.customLockedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TokenBloc, TokenState>(
      builder: (context, tokenState) {
        // Get user plan
        String userPlan = 'free';
        if (tokenState is TokenLoaded) {
          userPlan = tokenState.tokenStatus.userPlan.name;
        }

        final systemConfig = sl<SystemConfigService>();

        // Check feature access
        final hasAccess = systemConfig.hasFeatureAccess(featureKey, userPlan);
        final isLocked = systemConfig.isFeatureLocked(featureKey, userPlan);
        final shouldHide = systemConfig.shouldHideFeature(featureKey, userPlan);

        // If should be hidden, don't render anything
        if (shouldHide) {
          return const SizedBox.shrink();
        }

        // If user has access, render child normally
        if (hasAccess) {
          return child;
        }

        // If locked, render with lock overlay
        if (isLocked && showLockOverlay) {
          return _buildLockedFeature(context, userPlan);
        }

        // Fallback: hide
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLockedFeature(BuildContext context, String currentPlan) {
    final systemConfig = sl<SystemConfigService>();
    final requiredPlans = systemConfig.getRequiredPlans(featureKey);
    final upgradePlan = systemConfig.getUpgradePlan(featureKey, currentPlan);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Original child (dimmed)
          Opacity(
            opacity: 0.5,
            child: IgnorePointer(
              child: child,
            ),
          ),

          // Lock overlay - positioned with negative margin to cover button border
          Positioned(
            left: -2,
            right: -2,
            top: -2,
            bottom: -2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showUpgradeDialog(
                  context,
                  currentPlan,
                  requiredPlans,
                  upgradePlan,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      width: 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Lock icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Upgrade text
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            customLockedMessage ?? 'Tap to Upgrade',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(
    BuildContext context,
    String currentPlan,
    List<String> requiredPlans,
    String? upgradePlan,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpgradeDialog(
        featureKey: featureKey,
        currentPlan: currentPlan,
        requiredPlans: requiredPlans,
        upgradePlan: upgradePlan,
      ),
    );
  }
}
