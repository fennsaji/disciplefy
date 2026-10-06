import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/study_mode_preferences.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/keyboard_aware_scaffold.dart';
import '../../../../core/widgets/locked_feature_wrapper.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/device_keyboard_handler.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/error/failures.dart';
import '../../domain/mappers/app_language_mapper.dart';
import '../../domain/usecases/get_default_study_language.dart';
import '../../../../core/navigation/study_navigator.dart';
import '../../../../core/usecases/usecase.dart';
import '../bloc/study_bloc.dart';
import '../bloc/study_event.dart';
import '../bloc/study_state.dart';
import '../widgets/recent_guides_section.dart';
import '../widgets/mode_selection_sheet.dart';
import '../../domain/entities/study_mode.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_event.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';
import '../../../../core/router/app_router.dart';
import '../../../subscription/presentation/widgets/upgrade_required_dialog.dart';
import '../../../subscription/presentation/widgets/insufficient_tokens_dialog.dart';
import '../../data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/study_launch_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/constants/bible_books.dart';
import '../../../../core/constants/bible_book_transliterations.dart';
import '../../../../core/di/injection_container.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';
import '../../../../core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/depth_mode_cards.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/generate_hero.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/language_pill.dart';

/// Generate Study Screen allowing users to input scripture reference or topic.
///
/// Wraps [_GenerateStudyScreenContent] in a [ShowCaseWidget] so that walkthrough
/// tooltips can call [ShowCaseWidget.of(context)] from descendant context.
class GenerateStudyScreen extends StatelessWidget {
  const GenerateStudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.generate),
      builder: (context) => const _GenerateStudyScreenContent(),
    );
  }
}

class _GenerateStudyScreenContent extends StatefulWidget {
  const _GenerateStudyScreenContent();

  @override
  State<_GenerateStudyScreenContent> createState() =>
      _GenerateStudyScreenState();
}

class _GenerateStudyScreenState extends State<_GenerateStudyScreenContent>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  StudyInputMode _selectedMode = StudyInputMode.topic;
  StudyLanguage _selectedLanguage = StudyLanguage.english;
  bool _isLanguageDefault = true; // Track if using default (app language)
  bool _isInputValid = false;
  bool _isGeneratingStudyGuide = false;
  String? _validationError;

  // Token status for consumption calculation
  TokenStatus? _currentTokenStatus;

  // Track whether user has navigated away to prevent excessive token refreshes
  bool _hasNavigatedAway = false;

  // Track if we've already triggered a token refresh to prevent loops
  bool _isRefreshingTokens = false;

  // Router listener for detecting tab-switch back to this screen
  GoRouter? _goRouter;
  String? _lastListenedPath;

  // Timer to ensure loading state doesn't get stuck
  Timer? _generationTimeoutTimer;

  // Track if we're currently navigating to prevent multiple navigations
  bool _isNavigating = false;

  // Language preference service for database integration
  late final LanguagePreferenceService _languagePreferenceService;

  // System config service for feature flags
  late final SystemConfigService _systemConfigService;

  // Stream subscription for language changes (to be cancelled in dispose)
  StreamSubscription<AppLanguage>? _languageChangeSubscription;

  // Navigation service
  late final StudyNavigator _navigator;

  // Token cost repository for fetching costs from backend
  late final TokenCostRepository _tokenCostRepository;

  // Track the saved study mode preference to show token costs
  String?
      _savedStudyModePreference; // null (ask every time), 'recommended', or specific mode

  // Depth chosen inline on the page (ruling: the Generate button uses it
  // directly). Seeded from the saved preference until the user picks one.
  StudyMode _selectedStudyMode = recommendedStudyMode;
  bool _userPickedStudyMode = false;

  // Credit cost per mode for the selected language (null entry = unknown).
  final Map<StudyMode, int> _modeCosts = {};

  bool _isInputFocused = false;

  // Book-pill tooltip: shown once per session when pills first appear.
  bool _showBookTooltip = false;
  bool _bookTooltipShown = false;
  Timer? _bookTooltipTimer;

  // Suggestions are now loaded from translations to support multiple languages
  // See _getFilteredSuggestions() method for implementation

  static const List<String> _apologeticsQuestions = [
    'Why did Jesus die for us?',
    'Why did God create evil?',
    'How do we know the Bible is true?',
    'If God is good, why is there suffering?',
    'Is Jesus the only way to salvation?',
    'Did Jesus really rise from the dead?',
    'Why does God allow innocent people to suffer?',
    'Can I trust the Bible that has been passed down?',
    'How can God be three yet one?',
    'Why did God command violence in the Old Testament?',
    'What happens to people who never heard about Jesus?',
    'Is Christianity just a copy of other religions?',
    'Does science disprove God?',
    'Why would a loving God send people to hell?',
    'Was Jesus just a good teacher or truly God?',
    'How do we know God exists?',
    'Why does God seem different in the Old and New Testament?',
    'Is faith just believing without evidence?',
    'How can a good God predestine some to damnation?',
    'Why pray if God already knows what will happen?',
    'What is the purpose of suffering in a Christian\'s life?',
    'Are miracles possible in a scientific world?',
    'Why did Jesus have to be born of a virgin?',
    'Is the resurrection historically credible?',
    'How should Christians respond to doubt?',
  ];

  @override
  void initState() {
    super.initState();
    _languagePreferenceService = GetIt.instance<LanguagePreferenceService>();
    _systemConfigService = GetIt.instance<SystemConfigService>();
    _navigator = GetIt.instance<StudyNavigator>();
    _tokenCostRepository = GetIt.instance<TokenCostRepository>();
    _inputController.addListener(_validateInput);
    _inputFocusNode.addListener(() {
      if (mounted) setState(() => _isInputFocused = _inputFocusNode.hasFocus);
    });
    _loadDefaultLanguage();
    _loadSavedStudyModePreference();
    _setupLanguageChangeListener();

    // Register app lifecycle observer to detect when returning from study guide
    WidgetsBinding.instance.addObserver(this);

    // Trigger walkthrough on first visit
    _triggerWalkthroughIfNeeded();

    // Load initial token status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // First, check if token status is already loaded in the bloc
        final currentState = context.read<TokenBloc>().state;
        Logger.info(
            '🔄 [GENERATE_STUDY] initState - current bloc state: ${currentState.runtimeType}');

        if (currentState is TokenLoaded) {
          // Token already loaded - use it directly
          Logger.info(
              '✅ [GENERATE_STUDY] Token already loaded on init: ${currentState.tokenStatus.userPlan}');
          setState(() {
            _currentTokenStatus = currentState.tokenStatus;
          });
        } else {
          // Token not loaded - request it
          Logger.debug('🔄 [GENERATE_STUDY] Token not loaded - requesting...');
          context.read<TokenBloc>().add(const GetTokenStatus());
        }

        // Update token cost display after preferences are loaded
        _loadModeCosts();
      }
    });
  }

  /// Load the default language from user preferences
  Future<void> _loadDefaultLanguage() async {
    try {
      final getDefaultStudyLanguage = GetIt.instance<GetDefaultStudyLanguage>();
      final result = await getDefaultStudyLanguage(NoParams());

      // Check if study content language is set to default
      final isDefault =
          await _languagePreferenceService.isStudyContentLanguageDefault();

      result.fold(
        (failure) {
          Logger.error(
              '❌ [GENERATE STUDY] Failed to load default language: ${ErrorMessageSanitizer.sanitize(failure)}');
        },
        (language) {
          if (mounted) {
            setState(() {
              _selectedLanguage = language;
              _isLanguageDefault = isDefault;
            });
            Logger.info(
                '✅ [GENERATE STUDY] Loaded language: ${language.code}, isDefault: $isDefault');
          }
        },
      );
    } catch (e) {
      Logger.error('❌ [GENERATE STUDY] Error loading default language: $e');
    }
  }

  /// Listen for app language preference changes from settings
  /// When app language changes, study content language is reset to default,
  /// so we need to refresh the language selection to reflect the new app language.
  void _setupLanguageChangeListener() {
    Logger.debug('[GENERATE_STUDY] Setting up language change listener');

    // Cancel any existing subscription before creating a new one
    _languageChangeSubscription?.cancel();

    // Store the subscription to ensure proper cleanup
    _languageChangeSubscription =
        _languagePreferenceService.languageChanges.listen((newLanguage) async {
      Logger.debug(
          '[GENERATE_STUDY] App language changed to: ${newLanguage.displayName}');

      // When app language changes, study content language is automatically reset to default
      // Reload the language to reflect the new default
      if (mounted) {
        await _loadDefaultLanguage();
        Logger.debug(
            '[GENERATE_STUDY] Language refreshed after app language change');
      }
    });
  }

  /// Load the saved study mode preference to show appropriate token costs
  Future<void> _loadSavedStudyModePreference() async {
    try {
      final savedMode =
          await _languagePreferenceService.getStudyModePreferenceRaw();
      if (mounted) {
        setState(() {
          _savedStudyModePreference = savedMode;
          if (!_userPickedStudyMode) {
            _selectedStudyMode = resolveInitialStudyMode(
              savedMode,
              available: _visibleStudyModes,
              locked: _lockedStudyModes,
            );
          }
        });
        Logger.debug(
            '✅ [GENERATE STUDY] Loaded saved study mode preference: $savedMode');
      }
    } catch (e) {
      Logger.debug(
          '❌ [GENERATE STUDY] Error loading study mode preference: $e');
    }
  }

  void _onRouterChanged() {
    if (!mounted || _goRouter == null) return;
    final currentPath = _goRouter!.routerDelegate.currentConfiguration.uri.path;
    final wasElsewhere = _lastListenedPath != null &&
        _lastListenedPath != AppRoutes.generateStudy;
    _lastListenedPath = currentPath;
    if (currentPath == AppRoutes.generateStudy &&
        wasElsewhere &&
        !_isRefreshingTokens) {
      _isRefreshingTokens = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TokenBloc>().add(const RefreshTokenStatus());
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up the router listener once so we can detect tab-switch back to this screen
    if (_goRouter == null && mounted) {
      _goRouter = GoRouter.of(context);
      _lastListenedPath =
          _goRouter!.routerDelegate.currentConfiguration.uri.path;
      _goRouter!.routerDelegate.addListener(_onRouterChanged);
    }
    Logger.debug(
        '🔄 [DEBUG] didChangeDependencies called, _hasNavigatedAway: $_hasNavigatedAway, mounted: $mounted');
    // Always refresh tokens when dependencies change and we don't have current status
    // This handles the case where user returns from navigation and token state is stale
    if (mounted &&
        (_hasNavigatedAway || _currentTokenStatus == null) &&
        !_isRefreshingTokens) {
      _hasNavigatedAway = false; // Reset the flag
      _isRefreshingTokens = true; // Prevent multiple simultaneous refreshes
      Logger.info(
          '✅ [DEBUG] Triggering token refresh from didChangeDependencies (hasNavigatedAway OR null status)');
      // Use a short delay to ensure the context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Logger.debug(
              '🔄 [DEBUG] Executing RefreshTokenStatus from didChangeDependencies');
          context.read<TokenBloc>().add(const RefreshTokenStatus());
        }
      });
    } else {
      Logger.error(
          '❌ [DEBUG] Not triggering token refresh - conditions not met (isRefreshing: $_isRefreshingTokens)');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh token status when app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<TokenBloc>().add(const GetTokenStatus());
    }
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    _goRouter?.routerDelegate.removeListener(_onRouterChanged);
    _generationTimeoutTimer?.cancel();
    _bookTooltipTimer?.cancel();
    _languageChangeSubscription?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// Start loading state with timeout protection
  void _startGenerationWithTimeout() {
    setState(() {
      _isGeneratingStudyGuide = true;
      _isNavigating = false;
    });

    // Cancel any existing timer
    _generationTimeoutTimer?.cancel();

    // Set timeout to reset loading state after 30 seconds
    _generationTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isGeneratingStudyGuide) {
        Logger.debug(
            '⏱️ [GENERATE_STUDY] Study generation timeout - resetting loading state');
        _resetLoadingState();
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.studyUiGenerationTimeout),
          tone: AppSnackTone.warning,
        );
      }
    });
  }

  /// Reset loading state and cancel timer
  void _resetLoadingState() {
    if (mounted) {
      setState(() {
        _isGeneratingStudyGuide = false;
        _isNavigating = false;
      });
      _generationTimeoutTimer?.cancel();
    }
  }

  void _validateInput() {
    final text = _inputController.text.trim();
    setState(() {
      if (text.isEmpty) {
        _isInputValid = false;
        _validationError = null;
      } else if (_selectedMode == StudyInputMode.scripture) {
        _isInputValid = _validateScriptureReference(text);
        // Don't show error while user is still typing the book name (no digit yet)
        final hasDigit = text.runes.any((r) => r >= 48 && r <= 57);
        _validationError = (_isInputValid || !hasDigit)
            ? null
            : context.tr(TranslationKeys.generateStudyScriptureError);
      } else if (_selectedMode == StudyInputMode.question) {
        _isInputValid = text.length >= 10;
        _validationError = _isInputValid
            ? null
            : context.tr(TranslationKeys.generateStudyQuestionError);
      } else {
        // Topic mode
        _isInputValid = text.length >= 2;
        _validationError = _isInputValid
            ? null
            : context.tr(TranslationKeys.generateStudyTopicError);
      }

      // Show book-pill tooltip the first time suggestions appear.
      if (_selectedMode == StudyInputMode.scripture && !_bookTooltipShown) {
        if (_getBookNameSuggestions().isNotEmpty) {
          _showBookTooltip = true;
          _bookTooltipShown = true;
          _bookTooltipTimer?.cancel();
          _bookTooltipTimer = Timer(const Duration(milliseconds: 2500), () {
            if (mounted) setState(() => _showBookTooltip = false);
          });
        }
      }
    });
  }

  bool _validateScriptureReference(String text) {
    // Unicode-aware regex pattern for scripture references
    // Uses [\p{L}\p{M}]+ to match letters AND combining marks
    // (required for Malayalam, Hindi, and other Indic scripts)
    // Allows multi-word book names like "भजन संहिता" or "Song of Solomon"
    final scripturePattern = RegExp(
      r'^[1-3]?\s*[\p{L}\p{M}]+(?:\s+[\p{L}\p{M}]+)*\s+\d+(?::\d+(?:-\d+)?)?$',
      unicode: true,
    );
    return scripturePattern.hasMatch(text);
  }

  /// Fetch the credit cost of every mode for the selected language (shown on
  /// the depth cards and the Generate button). The repository caches and
  /// falls back internally; a failed mode simply shows no cost.
  Future<void> _loadModeCosts() async {
    final language = _selectedLanguage.code;
    final costs = <StudyMode, int>{};
    for (final mode in StudyMode.values) {
      try {
        final result =
            await _tokenCostRepository.getTokenCost(language, mode.value);
        result.fold(
          (failure) => Logger.warning(
              '⚠️ [TOKEN_COST] No cost for ${mode.name}: ${ErrorMessageSanitizer.sanitize(failure)}'),
          (cost) => costs[mode] = cost,
        );
      } catch (e) {
        Logger.error('❌ [TOKEN_COST] Error for ${mode.name}: $e');
      }
    }
    // Ignore a stale response if the language changed meanwhile.
    if (!mounted || language != _selectedLanguage.code) return;
    setState(() {
      _modeCosts
        ..clear()
        ..addAll(costs);
    });
  }

  String get _userPlan => _currentTokenStatus?.userPlan.name ?? 'free';

  /// Modes the user's plan can see (display_mode 'hide' removes a mode).
  List<StudyMode> get _visibleStudyModes {
    final visible = StudyMode.values
        .where((m) =>
            !_systemConfigService.shouldHideFeature(m.featureKey, _userPlan))
        .toList();
    // Fail open: never leave the page without a depth to pick.
    return visible.isEmpty ? StudyMode.values : visible;
  }

  /// Visible modes that are locked for the user's plan.
  Set<StudyMode> get _lockedStudyModes => StudyMode.values
      .where(
          (m) => _systemConfigService.isFeatureLocked(m.featureKey, _userPlan))
      .toSet();

  void _selectStudyMode(StudyMode mode) {
    setState(() {
      _selectedStudyMode = mode;
      _userPickedStudyMode = true;
    });
  }

  void _showUpgradeDialogForMode(StudyMode mode) {
    final featureKey = mode.featureKey;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpgradeDialog(
        featureKey: featureKey,
        currentPlan: _userPlan,
        requiredPlans: _systemConfigService.getRequiredPlans(featureKey),
        upgradePlan: _systemConfigService.getUpgradePlan(featureKey, _userPlan),
      ),
    );
  }

  /// "All 5": the full-height depth chooser. Its choice becomes the inline
  /// selection (and is remembered if asked); "Start" then generates straight
  /// away when the input is ready.
  Future<void> _openDepthChooser() async {
    final input = _inputController.text.trim();
    final result = await ModeSelectionSheet.show(
      context: context,
      languageCode: _selectedLanguage.code,
      recommendedMode: recommendedStudyMode,
      preselectedMode: _selectedStudyMode,
      eyebrow: input.isEmpty ? null : input,
    );
    if (result == null || !mounted) return;

    final mode = result['mode'] as StudyMode;
    final remember = (result['rememberChoice'] as bool? ?? false) ||
        (result['alwaysUseRecommended'] as bool? ?? false);
    _selectStudyMode(mode);

    if (remember) {
      // Same mapping as before: the recommended mode is stored as
      // 'recommended' so it follows future recommendation changes.
      final raw = mode == recommendedStudyMode
          ? StudyModePreferences.recommended
          : mode.value;
      try {
        await _languagePreferenceService.saveStudyModePreferenceRaw(raw);
        if (mounted) setState(() => _savedStudyModePreference = raw);
      } catch (e) {
        Logger.error('❌ [GENERATE_STUDY] Failed to save mode preference: $e');
      }
    }

    if (!mounted) return;
    final isOffline =
        context.read<ConnectivityBloc>().state is ConnectivityOffline;
    final isBusy = _isGeneratingStudyGuide ||
        context.read<StudyBloc>().state is StudyGenerationInProgress;
    if (_isInputValid && !isOffline && !isBusy) {
      await _generateStudyGuide();
    }
  }

  /// Navigate to token management page
  void _navigateToTokenManagement() {
    // Set flag to indicate navigation away (will trigger token refresh on return)
    _hasNavigatedAway = true;
    Logger.debug(
        '🚀 [DEBUG] Navigating to token management, _hasNavigatedAway set to true');
    context.go('/token-management');
  }

  List<String> _getFilteredSuggestions() {
    // Get suggestions from translations based on selected mode
    final List<String> suggestions;
    if (_selectedMode == StudyInputMode.scripture) {
      final translatedList =
          context.trList(TranslationKeys.generateStudyScriptureSuggestions);
      suggestions = translatedList.isNotEmpty
          ? translatedList
          : [
              'John 3:16',
              'Psalm 23:1',
              'Romans 8:28',
              'Matthew 5:16',
              'Philippians 4:13'
            ];
    } else if (_selectedMode == StudyInputMode.topic) {
      final translatedList =
          context.trList(TranslationKeys.generateStudyTopicSuggestions);
      suggestions = translatedList.isNotEmpty
          ? translatedList
          : ['Forgiveness', 'Love', 'Faith', 'Hope', 'Prayer'];
    } else {
      // Question mode — use full apologetics question list
      suggestions = _apologeticsQuestions;
    }

    final query = _inputController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _selectedMode == StudyInputMode.question
          ? suggestions
          : suggestions.take(3).toList();
    }

    return suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .take(_selectedMode == StudyInputMode.question ? suggestions.length : 5)
        .toList();
  }

  /// Returns book name suggestions based on the current query and content language.
  ///
  /// Detection rules (in order):
  ///  1. Hindi script → search BibleBooks.hindi (shows native Hindi names)
  ///  2. Malayalam script → search BibleBooks.malayalam (shows native Malayalam names)
  ///  3. Roman script → English prefix match + Hinglish (hi mode) / Manglish (ml mode)
  List<_BookSuggestion> _getBookNameSuggestions() {
    if (_selectedMode != StudyInputMode.scripture) return [];
    final query = _inputController.text.trim();
    if (query.isEmpty) return [];
    if (query.contains(RegExp(r'[\d:]'))) return [];

    // Detect Unicode script
    final isHindiScript = query.runes.any((r) => r >= 0x0900 && r <= 0x097F);
    final isMalayalamScript =
        query.runes.any((r) => r >= 0x0D00 && r <= 0x0D7F);

    // Native Hindi script input — use API-loaded list
    if (isHindiScript) {
      return BibleBooks.allHindi
          .where((b) => b.startsWith(query))
          .take(5)
          .map((b) => _BookSuggestion(label: b, insertText: b))
          .toList();
    }

    // Native Malayalam script input — use API-loaded list, insert full forms
    if (isMalayalamScript) {
      return BibleBooks.allMalayalam
          .where((b) {
            final full = BibleBooks.getMalayalamFullForm(b);
            return b.startsWith(query) || full.startsWith(query);
          })
          .take(5)
          .map((b) {
            final full = BibleBooks.getMalayalamFullForm(b);
            return _BookSuggestion(label: full, insertText: full);
          })
          .toList();
    }

    // Roman script input — language-specific results first, then English fallbacks
    final q = query.toLowerCase();
    final results = <_BookSuggestion>[];
    // Track by canonical English name so the same book isn't shown twice
    final seenEnglish = <String>{};

    // Hindi language: show Hinglish matches FIRST with Hindi script insertText
    if (_selectedLanguage == StudyLanguage.hindi) {
      for (final e in BibleBookTransliterations.searchHindi(q)) {
        if (seenEnglish.add(e.english)) {
          results.add(_BookSuggestion(
            label: '${e.localDisplay} · ${e.english}',
            insertText: e.localDisplay, // insert Hindi script name
            badge: 'हिं',
          ));
        }
      }
    }

    // Malayalam language: show Manglish matches FIRST with full Malayalam script name
    if (_selectedLanguage == StudyLanguage.malayalam) {
      for (final e in BibleBookTransliterations.searchMalayalam(q)) {
        if (seenEnglish.add(e.english)) {
          final full = BibleBooks.getMalayalamFullForm(e.localDisplay);
          results.add(_BookSuggestion(
            label: '$full · ${e.english}',
            insertText: full, // insert full Malayalam script name
            badge: 'മ',
          ));
        }
      }
    }

    // English canonical + abbreviation matches (uses API-loaded data)
    // BibleBooks.searchEnglish handles both full names and abbreviations like
    // "Mt" → Matthew, "Mk" → Mark, "Lk" → Luke, "Jn" → John, etc.
    for (final book in BibleBooks.searchEnglish(q)) {
      if (seenEnglish.add(book)) {
        results.add(_BookSuggestion(label: book, insertText: book));
      }
    }

    // Fallback: Hinglish if no results yet (user typed Hinglish with English language)
    if (results.isEmpty) {
      for (final e in BibleBookTransliterations.searchHindi(q)) {
        if (seenEnglish.add(e.english)) {
          results.add(_BookSuggestion(
            label: '${e.localDisplay} · ${e.english}',
            insertText: e.english,
            badge: 'हिं',
          ));
        }
      }
    }

    // Fallback: Manglish if still no results
    if (results.isEmpty) {
      for (final e in BibleBookTransliterations.searchMalayalam(q)) {
        if (seenEnglish.add(e.english)) {
          final full = BibleBooks.getMalayalamFullForm(e.localDisplay);
          results.add(_BookSuggestion(
            label: '$full · ${e.english}',
            insertText: e.english,
            badge: 'മ',
          ));
        }
      }
    }

    return results.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // Check if we need to refresh tokens on build (fallback for didChangeDependencies)
    if ((_hasNavigatedAway || _currentTokenStatus == null) &&
        !_isRefreshingTokens) {
      _hasNavigatedAway = false; // Reset the navigation flag
      _isRefreshingTokens = true; // Prevent multiple simultaneous refreshes
      Logger.info(
          '✅ [DEBUG] Triggering token refresh from build method (hasNavigatedAway OR null status)');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Logger.debug('🔄 [DEBUG] Executing GetTokenStatus from build method');
          context.read<TokenBloc>().add(const GetTokenStatus());
        }
      });
    }

    // 🔧 Phase 2: Enhanced device-specific keyboard handling
    final useAdvancedKeyboardHandling =
        DeviceKeyboardHandler.needsCustomKeyboardHandling;

    if (kDebugMode && useAdvancedKeyboardHandling) {
      Logger.debug(
          '🔧 [GENERATE STUDY] Using KeyboardAwareScaffold for: ${DeviceKeyboardHandler.deviceManufacturer}');
    }

    final body = MultiBlocListener(
      listeners: [
        BlocListener<StudyBloc, StudyState>(
          listener: (context, state) {
            // Handle success state first
            if (state is StudyGenerationSuccess) {
              // Study guide generated successfully - navigate and reset state
              if (!_isNavigating) {
                Logger.debug(
                    '✅ [GENERATE_STUDY] Study guide generated - navigating to study guide screen');
                _isNavigating = true;
                _resetLoadingState();

                // Refresh token status after successful generation
                context.read<TokenBloc>().add(const GetTokenStatus());

                // Set flag to indicate navigation away
                _hasNavigatedAway = true;

                _navigator.navigateToStudyGuide(
                  context,
                  studyGuide: state.studyGuide,
                  source: StudyNavigationSource.generate,
                );
              }
              return; // Exit early
            }

            // Handle failure state
            if (state is StudyGenerationFailure) {
              // Generation failed - reset state and show error
              Logger.debug(
                  '❌ [GENERATE_STUDY] Study guide generation failed: ${state.failure.message}');
              _resetLoadingState();

              // Refresh token status after failure
              context.read<TokenBloc>().add(const GetTokenStatus());

              final displayMessage = kDebugMode
                  ? state.failure.message
                  : context.tr(TranslationKeys.commonErrorTryAgain);

              _showErrorDialog(
                  context, displayMessage, state.isRetryable, state.failure);
              return; // Exit early
            }

            // Handle in-progress state
            if (state is StudyGenerationInProgress) {
              // Start generation with timeout protection
              _startGenerationWithTimeout();
              return; // Exit early
            }

            // Handle initial/reset state
            if (state is StudyInitial) {
              // Clear loading state when returning to initial state
              if (!_isNavigating) {
                Logger.debug(
                    '🔄 [GENERATE_STUDY] Returned to initial state - clearing loader');
                _resetLoadingState();
              }
            }
          },
        ),
        BlocListener<TokenBloc, TokenState>(
          listener: (context, state) {
            Logger.debug(
                '🎯 [GENERATE_STUDY] TokenBloc state changed: ${state.runtimeType}');
            if (state is TokenLoaded) {
              Logger.debug(
                  '💰 [GENERATE_STUDY] Token loaded - totalTokens: ${state.tokenStatus.totalTokens}, userPlan: ${state.tokenStatus.userPlan}, isPremium: ${state.tokenStatus.isPremium}');
              setState(() {
                _currentTokenStatus = state.tokenStatus;
                _isRefreshingTokens =
                    false; // Reset refresh flag when tokens load
                // The plan decides which depths are hidden/locked; re-seed
                // the default depth until the user picks one.
                if (!_userPickedStudyMode) {
                  _selectedStudyMode = resolveInitialStudyMode(
                    _savedStudyModePreference,
                    available: _visibleStudyModes,
                    locked: _lockedStudyModes,
                  );
                }
              });
            } else if (state is TokenLoading) {
              Logger.error('⏳ [GENERATE_STUDY] Token loading...');
            } else if (state is TokenError) {
              Logger.error(
                  '❌ [GENERATE_STUDY] Token error: ${state.failure.message}');
              if (state.previousTokenStatus != null) {
                Logger.error(
                    '❌ [GENERATE_STUDY] Using previous status - totalTokens: ${state.previousTokenStatus!.totalTokens}');
                setState(() {
                  _currentTokenStatus = state.previousTokenStatus;
                  _isRefreshingTokens =
                      false; // Reset refresh flag even on error
                });
              }
            }
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom +
              (isKeyboardVisible ? 20 : 32),
        ),
        child: Stack(
          children: [
            // Photo header behind the top of the page; it fades into the
            // page background around the depth cards.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + _heroHeight,
              child: const GenerateHeroBackdrop(),
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _padded(_buildHeader()),
                  SizedBox(height: isLargeScreen ? 28 : 20),

                  // Input type tabs (Scripture / Topic / Question)
                  _padded(WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.generateModeToggle,
                    title: AppLocalizations.of(context)!
                        .walkthroughGenerateModeTitle,
                    description: AppLocalizations.of(context)!
                        .walkthroughGenerateModeDesc,
                    screen: WalkthroughScreen.generate,
                    stepNumber: 1,
                    totalSteps: _totalWalkthroughSteps,
                    tooltipPosition: TooltipPosition.bottom,
                    onNext: _onNext,
                    child: _buildInputTypeTabs(),
                  )),
                  const SizedBox(height: 20),

                  // Search field with the language pill
                  _padded(WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.generateInput,
                    title: AppLocalizations.of(context)!
                        .walkthroughGenerateInputTitle,
                    description: AppLocalizations.of(context)!
                        .walkthroughGenerateInputDesc,
                    screen: WalkthroughScreen.generate,
                    stepNumber: 2,
                    totalSteps: _totalWalkthroughSteps,
                    tooltipPosition: TooltipPosition.bottom,
                    onNext: _onNext,
                    child: _buildInputSection(),
                  )),
                  const SizedBox(height: 14),
                  _padded(_buildSuggestions()),
                  const SizedBox(height: 28),

                  _buildDepthSection(),
                  const SizedBox(height: 28),

                  // Generate button
                  _padded(WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.generateButton,
                    title: AppLocalizations.of(context)!
                        .walkthroughGenerateButtonTitle,
                    description: AppLocalizations.of(context)!
                        .walkthroughGenerateButtonDesc,
                    screen: WalkthroughScreen.generate,
                    stepNumber: 3,
                    totalSteps: _totalWalkthroughSteps,
                    onNext: _onNext,
                    child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
                      builder: (context, connectivityState) {
                        final isOffline =
                            connectivityState is ConnectivityOffline;
                        return BlocBuilder<StudyBloc, StudyState>(
                          builder: (context, state) =>
                              _buildGenerateButton(state, isOffline: isOffline),
                        );
                      },
                    ),
                  )),

                  // Only show additional sections when keyboard is hidden
                  if (!isKeyboardVisible) ...[
                    const SizedBox(height: 32),

                    // Continue reading (its "See all" opens the library)
                    _padded(const RecentGuidesSection()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    // Choose appropriate scaffold based on device requirements
    if (useAdvancedKeyboardHandling) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: KeyboardAwareScaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: body,
        ),
      );
    } else {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          resizeToAvoidBottomInset: true,
          body: body,
        ),
      );
    }
  }

  /// Height of the photo header below the status bar.
  static const double _heroHeight = 430;

  /// Horizontal page gutter.
  static const double _gutter = 20;

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        child: child,
      );

  /// Gold eyebrow + credit pill, then the Poppins headline.
  Widget _buildHeader() {
    final palette = ReaderPalette.of(context);
    final ink = GenerateHeroInk.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(TranslationKeys.generateStudyEyebrow).toUpperCase(),
                style: AppFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: palette.gold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            BlocBuilder<TokenBloc, TokenState>(
              builder: (context, tokenState) {
                final TokenStatus? status;
                final bool isStale;
                if (tokenState is TokenLoaded) {
                  status = tokenState.tokenStatus;
                  isStale = false;
                } else if (tokenState is TokenError &&
                    tokenState.previousTokenStatus != null) {
                  status = tokenState.previousTokenStatus;
                  isStale = true;
                } else {
                  return const SizedBox(height: 36);
                }
                return TokenBalancePill(
                  label: status!.isPremium ? '∞' : '${status.totalTokens}',
                  isStale: isStale,
                  onTap: _navigateToTokenManagement,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(TranslationKeys.generateStudyHeadline),
          style: AppFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            height: 1.18,
            color: ink.text,
          ),
        ),
      ],
    );
  }

  /// "Choose depth" + "All N", then the horizontal row of depth cards.
  Widget _buildDepthSection() {
    final palette = ReaderPalette.of(context);
    final modes = _visibleStudyModes;
    final locked = _lockedStudyModes;
    // A saved/selected mode can become hidden after the plan loads.
    final selected = modes.contains(_selectedStudyMode)
        ? _selectedStudyMode
        : resolveInitialStudyMode(_savedStudyModePreference,
            available: modes, locked: locked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _padded(Row(
          children: [
            Expanded(
              child: Text(
                context.tr(TranslationKeys.generateStudyChooseDepth),
                style: AppFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
            TextButton(
              key: const Key('generate_depth_all'),
              onPressed: _openDepthChooser,
              style: TextButton.styleFrom(
                foregroundColor: palette.muted,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 36),
              ),
              child: Text(
                context.tr(TranslationKeys.generateStudyAllModes,
                    {'count': '${modes.length}'}),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: palette.muted,
                ),
              ),
            ),
          ],
        )),
        const SizedBox(height: 10),
        DepthModeCardRow(
          modes: modes,
          selected: selected,
          costs: _modeCosts,
          locked: locked,
          onSelected: _selectStudyMode,
          onLockedTap: _showUpgradeDialogForMode,
        ),
      ],
    );
  }

  /// Underlined Scripture / Topic / Question tabs.
  Widget _buildInputTypeTabs() {
    const modes = StudyInputMode.values;
    return InputTypeTabs(
      labels: [
        context.tr(TranslationKeys.generateStudyScriptureTab),
        context.tr(TranslationKeys.generateStudyTopicMode),
        context.tr(TranslationKeys.generateStudyQuestionMode),
      ],
      selectedIndex: modes.indexOf(_selectedMode),
      onChanged: (i) {
        if (modes[i] != _selectedMode) _switchMode(modes[i]);
      },
    );
  }

  // The search field is white in both themes (design), so its contents use
  // fixed light-surface colours rather than the theme's.
  static const Color _searchInk = SearchFieldColors.ink;
  static const Color _searchMuted = SearchFieldColors.muted;
  static const Color _searchHint = SearchFieldColors.hint;

  /// Compact "Talk to Discipler" (voice) row. The dock's Discipler tab is
  /// the text chat; this keeps the voice conversation entry and its
  /// walkthrough step on the Generate tab.
  Widget _buildCompactAiDisciplerButton(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(16);

    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.hairline),
      ),
      child: InkWell(
        onTap: () => _handleAiDisciplerTap(context),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.accentIcon.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_none_rounded,
                  size: 20,
                  color: palette.accentIcon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            context
                                .tr(TranslationKeys.generateStudyTalkToAiBuddy),
                            style: AppFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ReaderPalette.selectedFill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr(TranslationKeys
                                .generateStudyAiDisciplerBadgeNew),
                            style: AppFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                          TranslationKeys.generateStudyTalkToAiBuddySubtitle),
                      style: AppFonts.inter(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: palette.dim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    final isQuestion = _selectedMode == StudyInputMode.question;
    final radius = BorderRadius.circular(isQuestion ? 22 : 30);
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.fromLTRB(18, isQuestion ? 12 : 6, 8, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: _validationError != null
                  ? errorColor
                  : _inputFocusNode.hasFocus
                      ? ReaderPalette.selectedFill
                      : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: isQuestion
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: isQuestion ? 2 : 0),
                child: const Icon(
                  Icons.search_rounded,
                  size: 24,
                  color: _searchMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  maxLines: isQuestion ? 4 : 1,
                  minLines: isQuestion ? 3 : 1,
                  textInputAction: isQuestion
                      ? TextInputAction.newline
                      : TextInputAction.done,
                  cursorColor: ReaderPalette.selectedFill,
                  style: AppFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: _searchInk,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedMode == StudyInputMode.scripture
                        ? context.tr(TranslationKeys.generateStudyScriptureHint)
                        : _selectedMode == StudyInputMode.topic
                            ? context.tr(TranslationKeys.generateStudyTopicHint)
                            : context
                                .tr(TranslationKeys.generateStudyQuestionHint),
                    // Long hints wrap instead of being cut on narrow phones.
                    hintMaxLines: isQuestion ? 4 : 3,
                    hintStyle: AppFonts.inter(
                      fontSize: 15,
                      color: _searchHint,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_inputController.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _inputController.clear();
                    _inputFocusNode.requestFocus();
                  },
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: _searchHint,
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(top: isQuestion ? 4 : 0),
                child: LanguagePill(
                  selected: _selectedLanguage,
                  isDefault: _isLanguageDefault,
                  onSelected: _switchLanguage,
                ),
              ),
            ],
          ),
        ),
        if (_validationError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Text(
              _validationError!,
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: errorColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestions() {
    if (_selectedMode == StudyInputMode.question) {
      return _buildQuestionDropdown();
    }

    final ink = GenerateHeroInk.of(context);

    // Show book name autocomplete when user is typing a book name in scripture mode
    if (_selectedMode == StudyInputMode.scripture) {
      final bookSuggestions = _getBookNameSuggestions();
      if (bookSuggestions.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showBookTooltip)
              AnimatedOpacity(
                opacity: _showBookTooltip ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: ReaderPalette.selectedFill.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Tap the book name below to select it',
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              'Books of the Bible',
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ink.muted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: bookSuggestions
                  .map((s) => _SuggestionChip(
                        label: s.label,
                        badge: s.badge,
                        onTapDown: (_) => _inputFocusNode.requestFocus(),
                        onTap: () {
                          final newText = '${s.insertText} ';
                          _inputController.text = newText;
                          // Defer cursor placement to after the system's
                          // focus-gained auto-select has settled.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _inputController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: newText.length),
                            );
                          });
                        },
                      ))
                  .toList(),
            ),
          ],
        );
      }
    }

    final suggestions = _getFilteredSuggestions();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: context.tr(TranslationKeys.generateStudySuggestions),
      container: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions
            .map((suggestion) => _SuggestionChip(
                  label: suggestion,
                  onTap: () {
                    _inputController.text = suggestion;
                    _inputFocusNode.unfocus();
                  },
                ))
            .toList(),
      ),
    );
  }

  Widget _buildQuestionDropdown() {
    // Show dropdown when input is focused or empty
    final showDropdown =
        _isInputFocused || _inputController.text.trim().isEmpty;
    if (!showDropdown) return const SizedBox.shrink();

    final suggestions = _getFilteredSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final palette = ReaderPalette.of(context);
    final isDark = palette.isDark;

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: palette.accentIcon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Try asking...',
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.accentIcon,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.hairline),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: palette.hairline,
                ),
                itemBuilder: (context, index) {
                  final question = suggestions[index];
                  return InkWell(
                    onTap: () {
                      _inputController.text = question;
                      _inputFocusNode.unfocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: palette.dim,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              question,
                              style: AppFonts.inter(
                                fontSize: 14,
                                color: palette.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Walkthrough helpers
  // ---------------------------------------------------------------------------

  VoidCallback get _onNext => () => ShowCaseWidget.of(context).next();

  // Talk to Discipler lives in its own dock tab, not on Generate.
  int get _totalWalkthroughSteps => 3;

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.generate)) return;
      if (!mounted) return;
      final keys = [
        ShowcaseKeys.generateModeToggle,
        ShowcaseKeys.generateInput,
        ShowcaseKeys.generateButton,
      ];
      if (keys.isNotEmpty && mounted) {
        // Wait for a full frame after the async gap to ensure all Showcase
        // widgets are laid out before startShowCase accesses their RenderBox.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ShowCaseWidget.of(context).startShowCase(keys);
        });
      }
    });
  }

  // ---------------------------------------------------------------------------

  /// Checks if Talk to Discipler feature should be visible (respects display_mode)
  /// Returns true if feature should be shown (either with access or with lock overlay)
  bool _isAiDisciplerFeatureEnabled() {
    // Get user's current plan
    final userPlan = _currentTokenStatus?.userPlan.name ?? 'free';

    // Check if ai_discipler feature should be visible (respects display_mode='lock' vs 'hide')
    // shouldHideFeature returns true only if display_mode='hide' or feature is disabled
    final shouldShow =
        !_systemConfigService.shouldHideFeature('ai_discipler', userPlan);

    if (kDebugMode && !shouldShow) {
      Logger.debug('🚫 [AI DISCIPLER] Feature hidden for plan: $userPlan');
    }

    return shouldShow;
  }

  /// Handles tap on Talk to Discipler button
  /// Button is wrapped with LockedFeatureWrapper which handles access control
  void _handleAiDisciplerTap(BuildContext context) {
    // LockedFeatureWrapper handles access control and shows upgrade dialog if needed
    // If user reaches here, they have access - just navigate to voice conversation
    GoRouter.of(context).goToVoiceConversation();
  }

  Widget _buildGenerateButton(StudyState state, {bool isOffline = false}) {
    final palette = ReaderPalette.of(context);
    final isLoading =
        state is StudyGenerationInProgress || _isGeneratingStudyGuide;
    final tokenCost = _modeCosts[_selectedStudyMode];
    final isEnabled = _isInputValid && !isLoading && !isOffline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(palette.accentIcon),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.generateStudyGenerating),
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
                if (tokenCost != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr(TranslationKeys.generateStudyConsumingTokens,
                        {'tokens': tokenCost.toString()}),
                    style: AppFonts.inter(fontSize: 12, color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        GenerateStudyButton(
          label: isLoading
              ? context.tr(TranslationKeys.generateStudyButtonGenerating)
              : context.tr(TranslationKeys.generateStudyButtonGenerateShort),
          cost: tokenCost,
          enabled: isEnabled,
          loading: isLoading,
          onPressed: _generateStudyGuide,
          overlay: isOffline ? _buildOfflineGenerateOverlay(context) : null,
        ),
      ],
    );
  }

  Widget _buildOfflineGenerateOverlay(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(GenerateStudyButton.height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: palette.raised,
        child: InkWell(
          onTap: () => showAppSnackBar(
            context,
            context.tr(TranslationKeys.studyUiOfflineGenerate),
            tone: AppSnackTone.warning,
          ),
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: palette.outline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, color: palette.muted, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context
                        .tr(TranslationKeys.appChromeLockNotAvailableOffline),
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _switchMode(StudyInputMode mode) {
    setState(() {
      _selectedMode = mode;
      _inputController.clear();
      _validationError = null;
      _isInputValid = false;
    });
    _inputFocusNode.requestFocus();
  }

  Future<void> _switchLanguage(StudyLanguage? language) async {
    Logger.debug(
        '🔄 [GENERATE STUDY] User switching content language to: ${language?.code ?? "default"}');

    // If language is null, user selected "Default"
    if (language == null) {
      // Set to default (use app language)
      await _languagePreferenceService.saveStudyContentLanguage(null);

      // Load the app language to update UI
      final appLanguage =
          await _languagePreferenceService.getSelectedLanguage();
      final studyLanguage = appLanguage.toStudyLanguage();

      setState(() {
        _selectedLanguage = studyLanguage;
        _isLanguageDefault = true;
      });

      Logger.info(
          '✅ [GENERATE STUDY] Set to default - using app language: ${appLanguage.code}');
    } else {
      // User selected a specific language
      final appLanguage = language.toAppLanguage();
      await _languagePreferenceService.saveStudyContentLanguage(appLanguage);

      setState(() {
        _selectedLanguage = language;
        _isLanguageDefault = false;
      });

      Logger.info(
          '✅ [GENERATE STUDY] Content generation language saved: ${language.code}');
    }

    // Update token cost display for new language
    _loadModeCosts();

    Logger.debug(
        'ℹ️  [GENERATE STUDY] Note: This does not change the app UI language');
  }

  Future<void> _generateStudyGuide() async {
    if (!_isInputValid) return;

    // Prevent multiple clicks during navigation
    if (_isNavigating) return;

    // The depth is chosen inline (or via "All 5"), so generation starts
    // straight away with it — no mode sheet in between.
    final mode = _visibleStudyModes.contains(_selectedStudyMode)
        ? _selectedStudyMode
        : resolveInitialStudyMode(_savedStudyModePreference,
            available: _visibleStudyModes, locked: _lockedStudyModes);
    if (_lockedStudyModes.contains(mode)) {
      _showUpgradeDialogForMode(mode);
      return;
    }

    Logger.info('✅ [GENERATE_STUDY] Generating with mode: ${mode.name}');
    await _navigateToStudyGuide(mode);
  }

  /// Navigate to study guide with selected mode.
  Future<void> _navigateToStudyGuide(StudyMode mode) async {
    _isNavigating = true;

    final input = _inputController.text.trim();
    final inputType = _selectedMode == StudyInputMode.scripture
        ? 'scripture'
        : _selectedMode == StudyInputMode.topic
            ? 'topic'
            : 'question';
    final languageCode = _selectedLanguage.code;

    // Cost comes from the same source as the mode cards; only needed when
    // the plan is metered (a failed lookup counts as 0 — backend decides).
    final status = _currentTokenStatus;
    var requiredCost = 0;
    if (status != null && !status.isPremium && !status.unlimitedUsage) {
      final costResult =
          await _tokenCostRepository.getTokenCost(languageCode, mode.value);
      requiredCost = costResult.fold((f) => 0, (cost) => cost);
    }

    // Cached guides bypass the token check entirely.
    final launch = GetIt.instance<StudyLaunchService>();
    final decision = await launch.decide(
      input: input,
      type: inputType,
      language: languageCode,
      mode: mode,
      status: status,
      cost: requiredCost,
    );

    if (decision == LaunchDecision.needCredits && mounted) {
      setState(() => _isNavigating = false);
      await InsufficientTokensDialog.show(
        context,
        tokenStatus: status!,
        requiredTokens: requiredCost,
      );
      return;
    }

    // Backend will handle actual token consumption; token status is
    // refreshed after the backend processes the request.
    if (!mounted) {
      _isNavigating = false;
      return;
    }

    if (decision == LaunchDecision.openCached) {
      Logger.info('📦 [GENERATE_STUDY] Cache hit — bypassing token check');
    }

    // Set flag to indicate navigation away (will trigger token refresh on return)
    _hasNavigatedAway = true;

    Logger.debug(
        '🔍 [GENERATE_STUDY] Navigating to study guide V2 for $inputType with mode: ${mode.name}');

    context.go(launch.location(
      input: input,
      type: inputType,
      language: languageCode,
      mode: mode,
    ));

    // Reset navigation flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  void _showErrorDialog(
      BuildContext context, String message, bool isRetryable, Failure failure) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final palette = ReaderPalette.of(dialogContext);
        final isRateLimited = failure is RateLimitFailure;
        return PopupDialog(
          children: [
            PopupHeader(
              icon: PopupIconCircle(
                icon: isRateLimited
                    ? Icons.hourglass_bottom_rounded
                    : Icons.error_outline_rounded,
                tone: isRateLimited ? PopupTone.gold : PopupTone.indigo,
              ),
              title: dialogContext
                  .tr(TranslationKeys.generateStudyGenerationFailed),
              body: message,
            ),
            const SizedBox(height: 16),
            PopupPanel(
              child: Text(
                dialogContext
                    .tr(TranslationKeys.generateStudyGenerationFailedMessage),
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 13,
                  color: palette.muted,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 22),
            // Show different buttons based on failure type
            if (isRateLimited) ...[
              PopupPrimaryButton(
                key: const Key('generate_error_manage_tokens'),
                label:
                    dialogContext.tr(TranslationKeys.generateStudyManageTokens),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _navigateToTokenManagement();
                },
              ),
              const SizedBox(height: 4),
            ] else if (isRetryable) ...[
              PopupPrimaryButton(
                key: const Key('generate_error_try_again'),
                label:
                    dialogContext.tr(TranslationKeys.studyGuideErrorTryAgain),
                icon: Icons.refresh_rounded,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _generateStudyGuide();
                },
              ),
              const SizedBox(height: 4),
            ],
            PopupTextButton(
              key: const Key('generate_error_ok'),
              label: dialogContext.tr(TranslationKeys.guideFeedbackOk),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
}

/// Data class for a book name autocomplete suggestion.
class _BookSuggestion {
  final String label; // displayed on the chip
  final String insertText; // inserted into the text field on tap
  final String? badge; // optional language badge (e.g. 'हिं', 'മ')

  const _BookSuggestion({
    required this.label,
    required this.insertText,
    this.badge,
  });
}

/// Pill suggestion chip over the hero, with an optional language badge.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final GestureTapDownCallback? onTapDown;
  final String? badge;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
    this.onTapDown,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = GenerateHeroInk.of(context);
    // Dark: a translucent wash over the photo. Light: a translucent ink wash
    // read too faint over the pale sky, so chips are solid white with a
    // hairline and dark ink.
    final fill =
        palette.isDark ? Colors.white.withValues(alpha: 0.14) : palette.card;
    final textColor = palette.isDark ? ink.text : palette.text;

    return Material(
      color: fill,
      shape: palette.isDark
          ? const StadiumBorder()
          : StadiumBorder(side: BorderSide(color: palette.outline)),
      child: InkWell(
        onTapDown: onTapDown,
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: ReaderPalette.selectedFill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: AppFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
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

/// Enum for study input mode.
enum StudyInputMode {
  scripture,
  topic,
  question,
}

/// Enum for study language selection.
enum StudyLanguage {
  english('en'),
  hindi('hi'),
  malayalam('ml');

  const StudyLanguage(this.code);
  final String code;
}
