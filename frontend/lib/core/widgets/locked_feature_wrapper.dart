import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../connectivity/connectivity_bloc.dart';
import '../constants/app_fonts.dart';
import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../theme/reader_palette.dart';
import '../../shared/widgets/app_snackbar.dart';
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
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      buildWhen: (prev, next) => prev.runtimeType != next.runtimeType,
      builder: (context, connectivityState) =>
          BlocBuilder<TokenBloc, TokenState>(
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
          final shouldHide =
              systemConfig.shouldHideFeature(featureKey, userPlan);

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
            final isOffline = connectivityState is ConnectivityOffline;
            return _buildLockedFeature(context, userPlan, isOffline: isOffline);
          }

          // Fallback: hide
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLockedFeature(BuildContext context, String currentPlan,
      {bool isOffline = false}) {
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
                onTap: () {
                  if (isOffline) {
                    showAppSnackBar(
                      context,
                      context.tr(TranslationKeys.appChromeLockConnectToUpgrade),
                      tone: AppSnackTone.warning,
                    );
                    return;
                  }
                  _showUpgradeDialog(
                    context,
                    currentPlan,
                    requiredPlans,
                    upgradePlan,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: LockedFeatureScrim(
                  label: isOffline
                      ? context
                          .tr(TranslationKeys.appChromeLockNotAvailableOffline)
                      : (customLockedMessage ??
                          context
                              .tr(TranslationKeys.appChromeLockTapToUpgrade)),
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
      useRootNavigator: true,
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

/// Palette scrim over a locked feature: a soft page-coloured wash, a hairline
/// outline and a centred pill with a gold lock and the call to action. The
/// pill scales down rather than cutting its label on very small tiles.
class LockedFeatureScrim extends StatelessWidget {
  final String label;

  const LockedFeatureScrim({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.page.withValues(alpha: palette.isDark ? 0.45 : 0.35),
        border: Border.all(color: palette.outline),
      ),
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 16, color: palette.gold),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
