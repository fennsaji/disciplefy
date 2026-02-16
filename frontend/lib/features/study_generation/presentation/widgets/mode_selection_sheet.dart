import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../subscription/domain/repositories/subscription_repository.dart';
import '../../domain/entities/study_mode.dart';
import '../../data/repositories/token_cost_repository.dart';

/// Bottom sheet for selecting study mode before generating a study guide.
///
/// Presents 4 study mode options (Quick, Standard, Deep, Lectio) with
/// visual icons, durations, and descriptions. Optionally allows users
/// to remember their choice for future sessions.
///
/// For learning paths, can highlight a recommended mode and offer an
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

  const ModeSelectionSheet({
    super.key,
    this.initialMode = StudyMode.standard,
    this.showRememberOption = true,
    this.recommendedMode,
    this.isFromLearningPath = false,
    this.learningPathTitle,
    required this.languageCode,
  });

  /// Shows the mode selection sheet as a modal bottom sheet.
  /// Returns a map with 'mode', 'rememberChoice', and 'alwaysUseRecommended'
  /// or null if the user cancelled.
  ///
  /// If [inputType] is provided, recommended mode is determined automatically:
  /// - 'scripture' → Deep Dive
  /// - 'topic' → Standard
  /// - 'question' → Standard
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String languageCode,
    StudyMode initialMode = StudyMode.standard,
    bool showRememberOption = true,
    StudyMode? recommendedMode,
    bool isFromLearningPath = false,
    String? learningPathTitle,
    String? inputType,
  }) {
    // Auto-determine recommended mode based on input type if not from learning path
    final effectiveRecommendedMode =
        recommendedMode ?? _getRecommendedModeForInputType(inputType);

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModeSelectionSheet(
        initialMode: effectiveRecommendedMode ?? initialMode,
        showRememberOption: showRememberOption,
        recommendedMode: effectiveRecommendedMode,
        isFromLearningPath: isFromLearningPath,
        learningPathTitle: learningPathTitle,
        languageCode: languageCode,
      ),
    );
  }

  /// Determine recommended mode based on input type
  static StudyMode? _getRecommendedModeForInputType(String? inputType) {
    if (inputType == null) return null;

    switch (inputType.toLowerCase()) {
      case 'scripture':
        return StudyMode.deep; // Scripture benefits from deep word studies
      case 'topic':
      case 'question':
        return StudyMode
            .standard; // Topics and questions work well with standard
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
          print(
              '⚠️ [MODE_SELECTION] Failed to get subscription: ${failure.message}');
          _userPlan = 'free'; // Default to free on error
        },
        (subscription) {
          _userPlan = subscription.currentPlan;
          print('👤 [MODE_SELECTION] User plan: $_userPlan');
        },
      );

      // Map StudyMode to feature flag keys
      final modeFeatureMap = {
        StudyMode.quick: 'quick_read_mode',
        StudyMode.standard: 'standard_study_mode',
        StudyMode.deep: 'deep_dive_mode',
        StudyMode.lectio: 'lectio_divina_mode',
        StudyMode.sermon: 'sermon_outline_mode',
      };

      // Check each mode for lock/hide status
      _availableModes = [];
      _lockedModes = {};

      for (final mode in StudyMode.values) {
        final featureKey = modeFeatureMap[mode];
        if (featureKey == null) {
          // Unknown mode - show it
          _availableModes.add(mode);
          _lockedModes[mode] = false;
          continue;
        }

        final shouldHide =
            _systemConfigService.shouldHideFeature(featureKey, _userPlan);
        final isLocked =
            _systemConfigService.isFeatureLocked(featureKey, _userPlan);

        if (shouldHide) {
          // Hide mode completely (display_mode='hide')
          print(
              '🙈 [MODE_SELECTION] Mode ${mode.name} ($featureKey) hidden for plan $_userPlan');
          continue; // Skip this mode
        }

        // Show mode (either unlocked or locked)
        _availableModes.add(mode);
        _lockedModes[mode] = isLocked;

        if (isLocked) {
          print(
              '🔒 [MODE_SELECTION] Mode ${mode.name} ($featureKey) locked for plan $_userPlan');
        }
      }

      print(
          '✅ [MODE_SELECTION] Available modes: ${_availableModes.map((m) => m.name).join(", ")}');
      print(
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
        print(
            'ℹ️ [MODE_SELECTION] Switching to ${_selectedMode.name} (originally selected mode not accessible)');
      }

      if (mounted) {
        setState(() {
          _isLoadingFeatureFlags = false;
        });
      }
    } catch (e) {
      print('❌ [MODE_SELECTION] Error loading feature flags: $e');
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
            print(
                '⚠️ [MODE_SELECTION] Failed to get cost for ${mode.name}: ${failure.message}');
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
      print('❌ [MODE_SELECTION] Error loading token costs: $e');
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
    // Map mode to feature key
    final modeFeatureMap = {
      StudyMode.quick: 'quick_read_mode',
      StudyMode.standard: 'standard_study_mode',
      StudyMode.deep: 'deep_dive_mode',
      StudyMode.lectio: 'lectio_divina_mode',
      StudyMode.sermon: 'sermon_outline_mode',
    };

    final featureKey = modeFeatureMap[mode];
    if (featureKey == null) return;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: bottomPadding + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                context.tr(TranslationKeys.modeSelectionTitle),
                style: AppFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(TranslationKeys.modeSelectionSubtitle),
                style: AppFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Scrollable content area
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading indicator while checking feature flags
                      if (_isLoadingFeatureFlags)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      // Mode options (with lock support)
                      else
                        ..._availableModes.map((mode) {
                          final isLocked = _lockedModes[mode] ?? false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ModeOptionCard(
                              mode: mode,
                              isSelected: _selectedMode == mode,
                              isRecommended: mode == widget.recommendedMode,
                              isLocked: isLocked,
                              translatedName:
                                  _getStudyModeTranslatedName(mode, context),
                              translatedDescription:
                                  _getStudyModeTranslatedDescription(
                                      mode, context),
                              recommendedBadgeText: widget.isFromLearningPath
                                  ? context.tr(TranslationKeys
                                      .learningPathRecommendedModeBadge)
                                  : context.tr(TranslationKeys
                                      .modeSelectionRecommendedBadge),
                              tokenCost: _tokenCosts[mode],
                              onTap: () {
                                if (isLocked) {
                                  // Show upgrade dialog for locked modes
                                  _showUpgradeDialogForMode(mode);
                                } else {
                                  // Select unlocked mode
                                  setState(() {
                                    _selectedMode = mode;
                                  });
                                }
                              },
                            ),
                          );
                        }),

                      const SizedBox(height: 8),

                      // Remember choice checkbox (dynamic text based on selection)
                      if (widget.showRememberOption)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (widget.isFromLearningPath &&
                                  widget.recommendedMode != null) {
                                // For learning paths, toggle alwaysUseRecommended when on recommended mode
                                if (_selectedMode == widget.recommendedMode) {
                                  _alwaysUseRecommended =
                                      !_alwaysUseRecommended;
                                } else {
                                  // If not on recommended mode, toggle rememberChoice
                                  _rememberChoice = !_rememberChoice;
                                }
                              } else {
                                // For non-learning path, always toggle rememberChoice
                                _rememberChoice = !_rememberChoice;
                              }
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 44,
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        // Use gold color if selected mode is recommended
                                        color: (widget.isFromLearningPath &&
                                                    _selectedMode ==
                                                        widget.recommendedMode
                                                ? _alwaysUseRecommended
                                                : _rememberChoice)
                                            ? (_selectedMode ==
                                                    widget.recommendedMode
                                                ? const Color(
                                                    0xFFF59E0B) // Gold for recommended
                                                : AppTheme.primaryColor)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (widget.isFromLearningPath &&
                                                      _selectedMode ==
                                                          widget.recommendedMode
                                                  ? _alwaysUseRecommended
                                                  : _rememberChoice)
                                              ? (_selectedMode ==
                                                      widget.recommendedMode
                                                  ? const Color(0xFFF59E0B)
                                                  : AppTheme.primaryColor)
                                              : isDark
                                                  ? Colors.white
                                                      .withOpacity(0.3)
                                                  : const Color(0xFFD1D5DB),
                                          width: 2,
                                        ),
                                      ),
                                      child: (widget.isFromLearningPath &&
                                                  _selectedMode ==
                                                      widget.recommendedMode
                                              ? _alwaysUseRecommended
                                              : _rememberChoice)
                                          ? Icon(
                                              _selectedMode ==
                                                      widget.recommendedMode
                                                  ? Icons.stars
                                                  : Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    // Dynamic text based on whether selected mode is recommended
                                    _selectedMode == widget.recommendedMode
                                        ? context.tr(TranslationKeys
                                            .modeSelectionAlwaysUseRecommended)
                                        : context.tr(TranslationKeys
                                            .modeSelectionRememberChoice),
                                    style: AppFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.7)
                                          : const Color(0xFF4B5563),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Continue button
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop({
                        'mode': _selectedMode,
                        'rememberChoice': _rememberChoice,
                        'alwaysUseRecommended': _alwaysUseRecommended,
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedMode.iconData,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context
                                .tr(TranslationKeys.modeSelectionStartButton)
                                .replaceAll(
                                    '{mode}',
                                    _getStudyModeTranslatedName(
                                        _selectedMode, context)),
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedMode.durationText,
                              style: AppFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get translated display name for study mode
  String _getStudyModeTranslatedName(StudyMode mode, BuildContext context) {
    switch (mode) {
      case StudyMode.quick:
        return context.tr(TranslationKeys.studyModeQuickName);
      case StudyMode.standard:
        return context.tr(TranslationKeys.studyModeStandardName);
      case StudyMode.deep:
        return context.tr(TranslationKeys.studyModeDeepName);
      case StudyMode.lectio:
        return context.tr(TranslationKeys.studyModeLectioName);
      case StudyMode.sermon:
        return context.tr(TranslationKeys.studyModeSermonName);
    }
  }

  /// Get translated description for study mode
  String _getStudyModeTranslatedDescription(
      StudyMode mode, BuildContext context) {
    switch (mode) {
      case StudyMode.quick:
        return context.tr(TranslationKeys.studyModeQuickDescription);
      case StudyMode.standard:
        return context.tr(TranslationKeys.studyModeStandardDescription);
      case StudyMode.deep:
        return context.tr(TranslationKeys.studyModeDeepDescription);
      case StudyMode.lectio:
        return context.tr(TranslationKeys.studyModeLectioDescription);
      case StudyMode.sermon:
        return context.tr(TranslationKeys.studyModeSermonDescription);
    }
  }
}

/// Individual mode option card widget.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isLocked ? 0.7 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? isDark
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : const Color(0xFFF3F0FF)
                : isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLocked
                  ? Colors.orange.withOpacity(0.5)
                  : isSelected
                      ? AppTheme.primaryColor
                      : isDark
                          ? Colors.white.withOpacity(0.1)
                          : const Color(0xFFE5E7EB),
              width: isLocked ? 2 : (isSelected ? 2 : 1),
            ),
            boxShadow: isSelected && !isLocked
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.15)
                      : isDark
                          ? Colors.white.withOpacity(0.1)
                          : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  mode.iconData,
                  size: 24,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : isDark
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            translatedName,
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : isDark
                                      ? Colors.white
                                      : const Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: recommendedBadgeText,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF4A3B1F) // Dark gold/amber for dark theme
                                    : const Color(
                                        0xFFFFFBF0), // Light gold for light theme
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B)
                                        .withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.stars,
                                size: 16,
                                color: isDark
                                    ? const Color(
                                        0xFFFBBF24) // Brighter gold for dark theme
                                    : const Color(
                                        0xFFF59E0B), // Standard gold for light theme
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Show recommended badge text below mode name
                    if (isRecommended) ...[
                      const SizedBox(height: 4),
                      Text(
                        recommendedBadgeText,
                        style: AppFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(
                                  0xFFFBBF24) // Brighter gold for dark theme
                              : const Color(
                                  0xFFF59E0B), // Standard gold for light theme
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      translatedDescription,
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              // Show lock badge if locked, otherwise show duration and token cost
              if (isLocked)
                // Locked badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Locked',
                        style: AppFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Duration and token cost badges
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Duration badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : isDark
                                ? Colors.white.withOpacity(0.1)
                                : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        mode.durationText,
                        style: AppFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF4B5563),
                        ),
                      ),
                    ),

                    // Token cost badge (for all modes)
                    if (tokenCost != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.2)
                              : isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.token,
                              size: 12,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : isDark
                                      ? Colors.white.withOpacity(0.7)
                                      : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$tokenCost',
                              style: AppFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : isDark
                                        ? Colors.white.withOpacity(0.7)
                                        : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

              const SizedBox(width: 8),

              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : isDark
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
