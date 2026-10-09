import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/depth_mode_cards.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/repositories/subscription_repository.dart';

/// Full-height "Choose depth" page for picking a study mode before a study
/// guide is generated.
///
/// Lists every study mode the user's plan can see (locked ones open the
/// upgrade dialog) with its description, duration and credit cost, and
/// optionally lets the user remember the choice.
///
/// For learning paths it can highlight a recommended mode and offer an
/// "Always use recommended" preference option.
class ModeSelectionSheet extends StatefulWidget {
  /// The initially selected mode (defaults to standard).
  final StudyMode initialMode;

  /// Whether to show the "Remember my choice" checkbox.
  final bool showRememberOption;

  /// Recommended study mode for this learning path (if from learning path).
  final StudyMode? recommendedMode;

  /// Whether this sheet is being shown from a learning path.
  final bool isFromLearningPath;

  /// Title of the learning path (for context in UI).
  final String? learningPathTitle;

  /// Language code for token cost calculation (en, hi, ml)
  final String languageCode;

  /// Gold eyebrow above the headline — what is being studied (the user's
  /// input). Falls back to [learningPathTitle]; hidden when neither is set.
  final String? eyebrow;

  const ModeSelectionSheet({
    super.key,
    this.initialMode = StudyMode.standard,
    this.showRememberOption = true,
    this.recommendedMode,
    this.isFromLearningPath = false,
    this.learningPathTitle,
    this.eyebrow,
    required this.languageCode,
  });

  /// Shows the depth chooser as a full-height modal sheet.
  /// Returns a map with 'mode', 'rememberChoice', and 'alwaysUseRecommended'
  /// or null if the user cancelled.
  ///
  /// If [inputType] is provided, recommended mode is determined automatically
  /// (Standard for scripture, topic and question).
  ///
  /// [preselectedMode] overrides the initial selection (e.g. the depth
  /// already chosen inline on the Generate tab) while still marking the
  /// recommended mode.
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String languageCode,
    StudyMode initialMode = StudyMode.standard,
    bool showRememberOption = true,
    StudyMode? recommendedMode,
    bool isFromLearningPath = false,
    String? learningPathTitle,
    String? inputType,
    String? eyebrow,
    StudyMode? preselectedMode,
  }) {
    // Auto-determine recommended mode based on input type if not from learning path
    final effectiveRecommendedMode =
        recommendedMode ?? _getRecommendedModeForInputType(inputType);

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModeSelectionSheet(
        initialMode: preselectedMode ?? effectiveRecommendedMode ?? initialMode,
        showRememberOption: showRememberOption,
        recommendedMode: effectiveRecommendedMode,
        isFromLearningPath: isFromLearningPath,
        learningPathTitle: learningPathTitle,
        eyebrow: eyebrow,
        languageCode: languageCode,
      ),
    );
  }

  /// Determine recommended mode based on input type
  static StudyMode? _getRecommendedModeForInputType(String? inputType) {
    if (inputType == null) return null;

    switch (inputType.toLowerCase()) {
      case 'scripture':
      case 'topic':
      case 'question':
        return StudyMode.standard; // Standard is the default for all inputs
      default:
        return null;
    }
  }

  @override
  State<ModeSelectionSheet> createState() => _ModeSelectionSheetState();
}

class _ModeSelectionSheetState extends State<ModeSelectionSheet> {
  late StudyMode _selectedMode;
  bool _rememberChoice = false;
  bool _alwaysUseRecommended = false;

  // Token costs for each mode (fetched from backend)
  final Map<StudyMode, int> _tokenCosts = {};
  bool _isLoadingCosts = true;

  late final TokenCostRepository _tokenCostRepository;
  late final SystemConfigService _systemConfigService;
  late final SubscriptionRepository _subscriptionRepository;

  // All modes (no longer filtering)
  List<StudyMode> _availableModes = [];
  // Track which modes are locked (for lock overlay display)
  Map<StudyMode, bool> _lockedModes = {};
  String _userPlan = 'free';
  bool _isLoadingFeatureFlags = true;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _tokenCostRepository = sl<TokenCostRepository>();
    _systemConfigService = sl<SystemConfigService>();
    _subscriptionRepository = sl<SubscriptionRepository>();
    _loadUserPlanAndFeatureFlags();
    _loadTokenCosts();
  }

  /// Load user's plan and filter available modes based on feature flags
  Future<void> _loadUserPlanAndFeatureFlags() async {
    try {
      // Get user's current subscription plan
      final result = await _subscriptionRepository.getSubscriptionStatus();

      result.fold(
        (failure) {
          Logger.warning(
              '⚠️ [MODE_SELECTION] Failed to get subscription: ${ErrorMessageSanitizer.sanitize(failure)}');
          _userPlan = 'free'; // Default to free on error
        },
        (subscription) {
          _userPlan = subscription.currentPlan;
          Logger.debug('👤 [MODE_SELECTION] User plan: $_userPlan');
        },
      );

      // Check each mode for lock/hide status
      _availableModes = [];
      _lockedModes = {};

      for (final mode in StudyMode.values) {
        final featureKey = mode.featureKey;
        final shouldHide =
            _systemConfigService.shouldHideFeature(featureKey, _userPlan);
        final isLocked =
            _systemConfigService.isFeatureLocked(featureKey, _userPlan);

        if (shouldHide) {
          // Hide mode completely (display_mode='hide')
          Logger.debug(
              '🙈 [MODE_SELECTION] Mode ${mode.name} ($featureKey) hidden for plan $_userPlan');
          continue; // Skip this mode
        }

        // Show mode (either unlocked or locked)
        _availableModes.add(mode);
        _lockedModes[mode] = isLocked;

        if (isLocked) {
          Logger.info(
              '🔒 [MODE_SELECTION] Mode ${mode.name} ($featureKey) locked for plan $_userPlan');
        }
      }

      Logger.info(
          '✅ [MODE_SELECTION] Available modes: ${_availableModes.map((m) => m.name).join(", ")}');
      Logger.debug(
          '🔒 [MODE_SELECTION] Locked modes: ${_lockedModes.entries.where((e) => e.value).map((e) => e.key.name).join(", ")}');

      // If selected mode is locked or hidden, switch to first unlocked mode
      if (_lockedModes[_selectedMode] == true ||
          !_availableModes.contains(_selectedMode)) {
        final firstUnlockedMode = _availableModes.firstWhere(
          (mode) => _lockedModes[mode] != true,
          orElse: () => _availableModes.isNotEmpty
              ? _availableModes.first
              : StudyMode.standard,
        );
        _selectedMode = firstUnlockedMode;
        Logger.debug(
            'ℹ️ [MODE_SELECTION] Switching to ${_selectedMode.name} (originally selected mode not accessible)');
      }

      if (mounted) {
        setState(() {
          _isLoadingFeatureFlags = false;
        });
      }
    } catch (e) {
      Logger.error('❌ [MODE_SELECTION] Error loading feature flags: $e');
      // On error, show all modes (fail open)
      _availableModes = StudyMode.values;
      if (mounted) {
        setState(() {
          _isLoadingFeatureFlags = false;
        });
      }
    }
  }

  /// Load token costs for all study modes from backend API
  /// Repository handles fallback logic internally
  Future<void> _loadTokenCosts() async {
    try {
      // Use the selected language for token cost calculation
      final languageCode = widget.languageCode;

      // Fetch costs for all modes from backend via repository
      // Repository will use fallback if API fails
      for (final mode in StudyMode.values) {
        final result = await _tokenCostRepository.getTokenCost(
          languageCode,
          mode.value,
        );

        result.fold(
          (failure) {
            // Repository fallback failed - don't show cost for this mode
            Logger.warning(
                '⚠️ [MODE_SELECTION] Failed to get cost for ${mode.name}: ${ErrorMessageSanitizer.sanitize(failure)}');
            // Don't set cost - badge won't be shown
          },
          (cost) {
            _tokenCosts[mode] = cost;
          },
        );
      }

      if (mounted) {
        setState(() {
          _isLoadingCosts = false;
        });
      }
    } catch (e) {
      Logger.error('❌ [MODE_SELECTION] Error loading token costs: $e');
      // Don't set costs - badges won't be shown
      if (mounted) {
        setState(() {
          _isLoadingCosts = false;
        });
      }
    }
  }

  /// Show upgrade dialog for locked study mode
  void _showUpgradeDialogForMode(StudyMode mode) {
    final featureKey = mode.featureKey;

    final requiredPlans = _systemConfigService.getRequiredPlans(featureKey);
    final upgradePlan =
        _systemConfigService.getUpgradePlan(featureKey, _userPlan);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpgradeDialog(
        featureKey: featureKey,
        currentPlan: _userPlan,
        requiredPlans: requiredPlans,
        upgradePlan: upgradePlan,
      ),
    );
  }

  /// Whether the remember checkbox is currently ticked (the learning-path
  /// recommended mode uses "always use recommended" instead).
  bool get _rememberTicked =>
      widget.isFromLearningPath && _selectedMode == widget.recommendedMode
          ? _alwaysUseRecommended
          : _rememberChoice;

  void _toggleRemember() {
    setState(() {
      if (widget.isFromLearningPath &&
          widget.recommendedMode != null &&
          _selectedMode == widget.recommendedMode) {
        _alwaysUseRecommended = !_alwaysUseRecommended;
      } else {
        _rememberChoice = !_rememberChoice;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final eyebrow = widget.eyebrow ?? widget.learningPathTitle;

    return Material(
      color: palette.page,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: double.infinity,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: back arrow + page title
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_rounded, color: palette.text),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.generateStudyChooseDepth),
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null && eyebrow.trim().isNotEmpty) ...[
                            Text(
                              eyebrow.trim().toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: palette.gold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            context
                                .tr(TranslationKeys.modeSelectionTimeQuestion),
                            style: AppFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(TranslationKeys.modeSelectionSubtitle),
                            style: AppFonts.inter(
                              fontSize: 14,
                              color: palette.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingFeatureFlags)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._availableModes.map((mode) {
                        final isLocked = _lockedModes[mode] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ModeOptionCard(
                            mode: mode,
                            isSelected: _selectedMode == mode,
                            isRecommended: mode == widget.recommendedMode,
                            isLocked: isLocked,
                            translatedName: mode.localizedName(context),
                            translatedDescription:
                                mode.localizedDescription(context),
                            recommendedBadgeText: widget.isFromLearningPath
                                ? context.tr(TranslationKeys
                                    .learningPathRecommendedModeBadge)
                                : context.tr(TranslationKeys
                                    .modeSelectionRecommendedBadge),
                            tokenCost: _tokenCosts[mode],
                            onTap: () {
                              if (isLocked) {
                                _showUpgradeDialogForMode(mode);
                              } else {
                                setState(() => _selectedMode = mode);
                              }
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),

              // Remember choice + start button, pinned to the bottom.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.showRememberOption)
                      _RememberChoiceToggle(
                        ticked: _rememberTicked,
                        label: _selectedMode == widget.recommendedMode
                            ? context.tr(TranslationKeys
                                .modeSelectionAlwaysUseRecommended)
                            : context.tr(
                                TranslationKeys.modeSelectionRememberChoice),
                        onTap: _toggleRemember,
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const Key('mode_selection_start'),
                        onPressed: _isLoadingFeatureFlags
                            ? null
                            : () => Navigator.of(context).pop({
                                  'mode': _selectedMode,
                                  'rememberChoice': _rememberChoice,
                                  'alwaysUseRecommended': _alwaysUseRecommended,
                                }),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.ctaFill,
                          foregroundColor: palette.ctaInk,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.tr(TranslationKeys.modeSelectionStartButton,
                                {'mode': _selectedMode.localizedName(context)}),
                            maxLines: 1,
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.ctaInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox row for "Remember my choice" / "Always use recommended".
class _RememberChoiceToggle extends StatelessWidget {
  final bool ticked;
  final String label;
  final VoidCallback onTap;

  const _RememberChoiceToggle({
    required this.ticked,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      checked: ticked,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: ticked ? palette.selectedFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ticked ? palette.selectedFill : palette.outline,
                    width: 2,
                  ),
                ),
                child: ticked
                    ? Icon(Icons.check, size: 14, color: palette.onSelected)
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One depth row: icon | name + description | duration over cost.
class _ModeOptionCard extends StatelessWidget {
  final StudyMode mode;
  final bool isSelected;
  final bool isRecommended;
  final bool isLocked; // Whether this mode is locked for the user's plan
  final String translatedName;
  final String translatedDescription;
  final String recommendedBadgeText;
  final VoidCallback onTap;
  final int? tokenCost; // Token cost for this mode

  const _ModeOptionCard({
    required this.mode,
    required this.isSelected,
    this.isRecommended = false,
    this.isLocked = false,
    required this.translatedName,
    required this.translatedDescription,
    required this.recommendedBadgeText,
    required this.onTap,
    this.tokenCost,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // Selected depth: the card keeps its fill and gains a gold ring and wash,
    // as the design's depth list.
    final titleColor = palette.text;
    final secondary = palette.muted;
    final radius = BorderRadius.circular(20);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Opacity(
        opacity: isLocked ? 0.6 : 1,
        child: Material(
          color: isSelected
              ? Color.alphaBlend(
                  palette.selectedFill
                      .withValues(alpha: palette.isDark ? 0.10 : 0.08),
                  palette.card)
              : palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: isSelected ? palette.selectedFill : palette.hairline,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey('mode_option_${mode.name}'),
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(
                    mode.outlineIcon,
                    size: 22,
                    color: palette.accentIcon,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translatedName,
                          style: AppFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(height: 2),
                          Text(
                            recommendedBadgeText.toUpperCase(),
                            style: AppFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: palette.gold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          translatedDescription,
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            color: secondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right column: duration above cost (no progress bars).
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        mode.localizedDuration(context),
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isLocked)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 14, color: secondary),
                            const SizedBox(width: 4),
                            Text(
                              context.tr(TranslationKeys.learningPathsLocked),
                              style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: secondary,
                              ),
                            ),
                          ],
                        )
                      else if (tokenCost != null)
                        CreditCost(
                          cost: tokenCost!,
                          color: palette.gold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
