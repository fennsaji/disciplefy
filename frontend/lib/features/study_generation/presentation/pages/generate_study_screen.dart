import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/keyboard_aware_scaffold.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/device_keyboard_handler.dart';
import '../../../../core/services/language_preference_service.dart';
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

/// Generate Study Screen allowing users to input scripture reference or topic.
///
/// Features toggle between modes, input validation, suggestions, and loading states
/// following the UX specifications and brand guidelines.
class GenerateStudyScreen extends StatefulWidget {
  const GenerateStudyScreen({super.key});

  @override
  State<GenerateStudyScreen> createState() => _GenerateStudyScreenState();
}

class _GenerateStudyScreenState extends State<GenerateStudyScreen>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  StudyInputMode _selectedMode = StudyInputMode.scripture;
  StudyLanguage _selectedLanguage = StudyLanguage.english;
  bool _isInputValid = false;
  bool _isGeneratingStudyGuide = false;
  String? _validationError;

  // Token status for consumption calculation
  TokenStatus? _currentTokenStatus;

  // Track whether user has navigated away to prevent excessive token refreshes
  bool _hasNavigatedAway = false;

  // Track if we've already triggered a token refresh to prevent loops
  bool _isRefreshingTokens = false;

  // Timer to ensure loading state doesn't get stuck
  Timer? _generationTimeoutTimer;

  // Track if we're currently navigating to prevent multiple navigations
  bool _isNavigating = false;

  // Language preference service for database integration
  late final LanguagePreferenceService _languagePreferenceService;

  // Navigation service
  late final StudyNavigator _navigator;

  // Suggestions are now loaded from translations to support multiple languages
  // See _getFilteredSuggestions() method for implementation

  @override
  void initState() {
    super.initState();
    _languagePreferenceService = GetIt.instance<LanguagePreferenceService>();
    _navigator = GetIt.instance<StudyNavigator>();
    _inputController.addListener(_validateInput);
    _loadDefaultLanguage();

    // Register app lifecycle observer to detect when returning from study guide
    WidgetsBinding.instance.addObserver(this);

    // Load initial token status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // First, check if token status is already loaded in the bloc
        final currentState = context.read<TokenBloc>().state;
        if (kDebugMode) {
          print(
              '🔄 [GENERATE_STUDY] initState - current bloc state: ${currentState.runtimeType}');
        }

        if (currentState is TokenLoaded) {
          // Token already loaded - use it directly
          if (kDebugMode) {
            print(
                '✅ [GENERATE_STUDY] Token already loaded on init: ${currentState.tokenStatus.userPlan}');
          }
          setState(() {
            _currentTokenStatus = currentState.tokenStatus;
          });
        } else {
          // Token not loaded - request it
          if (kDebugMode) {
            print('🔄 [GENERATE_STUDY] Token not loaded - requesting...');
          }
          context.read<TokenBloc>().add(const GetTokenStatus());
        }
      }
    });
  }

  /// Load the default language from user preferences
  Future<void> _loadDefaultLanguage() async {
    try {
      final getDefaultStudyLanguage = GetIt.instance<GetDefaultStudyLanguage>();
      final result = await getDefaultStudyLanguage(NoParams());

      result.fold(
        (failure) {
          if (kDebugMode) {
            print(
                '❌ [GENERATE STUDY] Failed to load default language: ${failure.message}');
          }
        },
        (language) {
          if (mounted) {
            setState(() {
              _selectedLanguage = language;
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [GENERATE STUDY] Error loading default language: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kDebugMode) {
      print(
          '🔄 [DEBUG] didChangeDependencies called, _hasNavigatedAway: $_hasNavigatedAway, mounted: $mounted');
    }
    // Always refresh tokens when dependencies change and we don't have current status
    // This handles the case where user returns from navigation and token state is stale
    if (mounted &&
        (_hasNavigatedAway || _currentTokenStatus == null) &&
        !_isRefreshingTokens) {
      _hasNavigatedAway = false; // Reset the flag
      _isRefreshingTokens = true; // Prevent multiple simultaneous refreshes
      if (kDebugMode) {
        print(
            '✅ [DEBUG] Triggering token refresh from didChangeDependencies (hasNavigatedAway OR null status)');
      }
      // Use a short delay to ensure the context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (kDebugMode) {
            print(
                '🔄 [DEBUG] Executing GetTokenStatus from didChangeDependencies');
          }
          context.read<TokenBloc>().add(const GetTokenStatus());
        }
      });
    } else {
      if (kDebugMode) {
        print(
            '❌ [DEBUG] Not triggering token refresh - conditions not met (isRefreshing: $_isRefreshingTokens)');
      }
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
    _generationTimeoutTimer?.cancel();
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
        debugPrint(
            '⏱️ [GENERATE_STUDY] Study generation timeout - resetting loading state');
        _resetLoadingState();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Study generation is taking longer than expected. Please try again.'),
            backgroundColor: Colors.orange,
          ),
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
        _validationError = _isInputValid
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

  /// Calculate tokens required for study generation based on language
  int _getTokenCost() {
    switch (_selectedLanguage) {
      case StudyLanguage.english:
        return 10; // English: 10 tokens
      case StudyLanguage.hindi:
      case StudyLanguage.malayalam:
        return 20; // Hindi/Malayalam: 20 tokens
    }
  }

  /// Navigate to token management page
  void _navigateToTokenManagement() {
    // Set flag to indicate navigation away (will trigger token refresh on return)
    _hasNavigatedAway = true;
    if (kDebugMode) {
      print(
          '🚀 [DEBUG] Navigating to token management, _hasNavigatedAway set to true');
    }
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
      // Question mode - single suggestion
      final translatedList =
          context.trList(TranslationKeys.generateStudyQuestionSuggestions);
      suggestions =
          translatedList.isNotEmpty ? translatedList : ['How should we pray'];
    }

    final query = _inputController.text.trim().toLowerCase();

    // For Question mode, only show 1 suggestion
    if (query.isEmpty) {
      return _selectedMode == StudyInputMode.question
          ? suggestions.take(1).toList()
          : suggestions.take(3).toList();
    }

    return suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // Check if we need to refresh tokens on build (fallback for didChangeDependencies)
    if ((_hasNavigatedAway || _currentTokenStatus == null) &&
        !_isRefreshingTokens) {
      _hasNavigatedAway = false; // Reset the navigation flag
      _isRefreshingTokens = true; // Prevent multiple simultaneous refreshes
      if (kDebugMode) {
        print(
            '✅ [DEBUG] Triggering token refresh from build method (hasNavigatedAway OR null status)');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (kDebugMode) {
            print('🔄 [DEBUG] Executing GetTokenStatus from build method');
          }
          context.read<TokenBloc>().add(const GetTokenStatus());
        }
      });
    }

    // 🔧 Phase 2: Enhanced device-specific keyboard handling
    final useAdvancedKeyboardHandling =
        DeviceKeyboardHandler.needsCustomKeyboardHandling;

    if (kDebugMode && useAdvancedKeyboardHandling) {
      print(
          '🔧 [GENERATE STUDY] Using KeyboardAwareScaffold for: ${DeviceKeyboardHandler.deviceManufacturer}');
    }

    final appBar = AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        context.tr(TranslationKeys.generateStudyTitle),
        style: AppFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
      centerTitle: true,
      actions: [
        // Compact token balance display
        BlocBuilder<TokenBloc, TokenState>(
          builder: (context, tokenState) {
            if (tokenState is TokenLoaded) {
              return GestureDetector(
                onTap: _navigateToTokenManagement,
                child: Container(
                  margin: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.token,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tokenState.tokenStatus.isPremium
                            ? '∞'
                            : '${tokenState.tokenStatus.totalTokens}',
                        style: AppFonts.inter(
                          fontSize: tokenState.tokenStatus.isPremium ? 18 : 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (tokenState is TokenError &&
                tokenState.previousTokenStatus != null) {
              return GestureDetector(
                onTap: _navigateToTokenManagement,
                child: Container(
                  margin: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tokenState.previousTokenStatus!.isPremium
                            ? '∞'
                            : '${tokenState.previousTokenStatus!.totalTokens}',
                        style: AppFonts.inter(
                          fontSize: tokenState.previousTokenStatus!.isPremium
                              ? 18
                              : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    final body = MultiBlocListener(
      listeners: [
        BlocListener<StudyBloc, StudyState>(
          listener: (context, state) {
            // Handle success state first
            if (state is StudyGenerationSuccess) {
              // Study guide generated successfully - navigate and reset state
              if (!_isNavigating) {
                debugPrint(
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
              debugPrint(
                  '❌ [GENERATE_STUDY] Study guide generation failed: ${state.failure.message}');
              _resetLoadingState();

              // Refresh token status after failure
              context.read<TokenBloc>().add(const GetTokenStatus());

              final displayMessage = kDebugMode
                  ? state.failure.message
                  : 'Something went wrong. Please try again.';

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
                debugPrint(
                    '🔄 [GENERATE_STUDY] Returned to initial state - clearing loader');
                _resetLoadingState();
              }
            }
          },
        ),
        BlocListener<TokenBloc, TokenState>(
          listener: (context, state) {
            if (kDebugMode) {
              print(
                  '🎯 [GENERATE_STUDY] TokenBloc state changed: ${state.runtimeType}');
            }
            if (state is TokenLoaded) {
              if (kDebugMode) {
                print(
                    '💰 [GENERATE_STUDY] Token loaded - totalTokens: ${state.tokenStatus.totalTokens}, userPlan: ${state.tokenStatus.userPlan}, isPremium: ${state.tokenStatus.isPremium}');
              }
              setState(() {
                _currentTokenStatus = state.tokenStatus;
                _isRefreshingTokens =
                    false; // Reset refresh flag when tokens load
              });
            } else if (state is TokenLoading) {
              if (kDebugMode) {
                print('⏳ [GENERATE_STUDY] Token loading...');
              }
            } else if (state is TokenError) {
              if (kDebugMode) {
                print(
                    '❌ [GENERATE_STUDY] Token error: ${state.failure.message}');
              }
              if (state.previousTokenStatus != null) {
                if (kDebugMode) {
                  print(
                      '❌ [GENERATE_STUDY] Using previous status - totalTokens: ${state.previousTokenStatus!.totalTokens}');
                }
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
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom:
                      isKeyboardVisible ? 20 : 0, // 🔧 FIX: Keyboard padding
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top spacing
                    const SizedBox(height: 24),

                    // Mode Toggle - Compact design
                    _buildCompactModeToggle(),

                    const SizedBox(height: 32),

                    // Input Section with inline language selector
                    _buildInputSection(),

                    // Show 2-3 suggestions per category
                    const SizedBox(height: 16),
                    _buildSuggestions(),

                    const SizedBox(height: 32),

                    // Generate Button and Status
                    BlocBuilder<StudyBloc, StudyState>(
                      builder: (context, state) => _buildGenerateButton(state),
                    ),

                    // 🔧 FIX: Only show additional sections when keyboard is hidden
                    if (!isKeyboardVisible) ...[
                      const SizedBox(height: 24),

                      // Compact AI Discipler option
                      _buildCompactAiDisciplerButton(context),

                      const SizedBox(height: 32),

                      // Recent Studies (has "View All" link built-in)
                      const RecentGuidesSection(),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 🔧 Phase 2: Choose appropriate scaffold based on device requirements
    if (useAdvancedKeyboardHandling) {
      return KeyboardAwareScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: appBar,
        child: body,
      );
    } else {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true, // 🔧 FIX: Explicitly handle keyboard
        appBar: appBar,
        body: body,
      );
    }
  }

  /// Compact mode toggle with minimal design
  Widget _buildCompactModeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        _buildCompactModeChip(
          label: 'Scripture',
          icon: Icons.menu_book_rounded,
          isSelected: _selectedMode == StudyInputMode.scripture,
          onTap: () => _switchMode(StudyInputMode.scripture),
        ),
        const SizedBox(width: 8),
        _buildCompactModeChip(
          label: 'Topic',
          icon: Icons.lightbulb_outline_rounded,
          isSelected: _selectedMode == StudyInputMode.topic,
          onTap: () => _switchMode(StudyInputMode.topic),
        ),
        const SizedBox(width: 8),
        _buildCompactModeChip(
          label: 'Question',
          icon: Icons.help_outline_rounded,
          isSelected: _selectedMode == StudyInputMode.question,
          onTap: () => _switchMode(StudyInputMode.question),
        ),
      ],
    );
  }

  Widget _buildCompactModeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.6),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeToggleButton(
                  label: context.tr(TranslationKeys.generateStudyScriptureMode),
                  isSelected: _selectedMode == StudyInputMode.scripture,
                  onTap: () => _switchMode(StudyInputMode.scripture),
                ),
              ),
              Expanded(
                child: _ModeToggleButton(
                  label: context.tr(TranslationKeys.generateStudyTopicMode),
                  isSelected: _selectedMode == StudyInputMode.topic,
                  onTap: () => _switchMode(StudyInputMode.topic),
                ),
              ),
              Expanded(
                child: _ModeToggleButton(
                  label: context.tr(TranslationKeys.generateStudyQuestionMode),
                  isSelected: _selectedMode == StudyInputMode.question,
                  onTap: () => _switchMode(StudyInputMode.question),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact language selector as dropdown/chip
  Widget _buildCompactLanguageSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String getLanguageLabel(StudyLanguage lang) {
      switch (lang) {
        case StudyLanguage.english:
          return 'EN';
        case StudyLanguage.hindi:
          return 'हिं';
        case StudyLanguage.malayalam:
          return 'മ';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: PopupMenuButton<StudyLanguage>(
        initialValue: _selectedLanguage,
        onSelected: _switchLanguage,
        offset: const Offset(0, 40),
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        itemBuilder: (context) => [
          _buildLanguageMenuItem(StudyLanguage.english, 'English'),
          _buildLanguageMenuItem(StudyLanguage.hindi, 'हिन्दी'),
          _buildLanguageMenuItem(StudyLanguage.malayalam, 'മലയാളം'),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getLanguageLabel(_selectedLanguage),
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<StudyLanguage> _buildLanguageMenuItem(
    StudyLanguage language,
    String label,
  ) {
    final isSelected = _selectedLanguage == language;
    return PopupMenuItem<StudyLanguage>(
      value: language,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, color: AppTheme.primaryColor, size: 18),
        ],
      ),
    );
  }

  /// Compact AI Discipler button
  Widget _buildCompactAiDisciplerButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.go('/ai-discipler');
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: AppTheme.primaryColor,
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
                          'Talk to AI Discipler',
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NEW',
                            style: AppFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get personalized spiritual guidance',
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onBackground
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.generateStudyLanguage),
          style: AppFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withOpacity(0.9)
                : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _LanguageToggleButton(
                  label: context.tr(TranslationKeys.generateStudyEnglish),
                  isSelected: _selectedLanguage == StudyLanguage.english,
                  onTap: () async =>
                      await _switchLanguage(StudyLanguage.english),
                ),
              ),
              Expanded(
                child: _LanguageToggleButton(
                  label: context.tr(TranslationKeys.generateStudyHindi),
                  isSelected: _selectedLanguage == StudyLanguage.hindi,
                  onTap: () async => await _switchLanguage(StudyLanguage.hindi),
                ),
              ),
              Expanded(
                child: _LanguageToggleButton(
                  label: context.tr(TranslationKeys.generateStudyMalayalam),
                  isSelected: _selectedLanguage == StudyLanguage.malayalam,
                  onTap: () async =>
                      await _switchLanguage(StudyLanguage.malayalam),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with inline language selector
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedMode == StudyInputMode.scripture
                    ? context.tr(TranslationKeys.generateStudyEnterScripture)
                    : _selectedMode == StudyInputMode.topic
                        ? context.tr(TranslationKeys.generateStudyEnterTopic)
                        : context.tr(TranslationKeys.generateStudyAskQuestion),
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withOpacity(0.9)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildCompactLanguageSelector(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (_inputFocusNode.hasFocus)
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            maxLines: _selectedMode == StudyInputMode.question ? 4 : 1,
            minLines: _selectedMode == StudyInputMode.question ? 3 : 1,
            textInputAction: _selectedMode == StudyInputMode.question
                ? TextInputAction.newline
                : TextInputAction.done,
            style: AppFonts.inter(
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            decoration: InputDecoration(
              hintText: _selectedMode == StudyInputMode.scripture
                  ? context.tr(TranslationKeys.generateStudyScriptureHint)
                  : _selectedMode == StudyInputMode.topic
                      ? context.tr(TranslationKeys.generateStudyTopicHint)
                      : context.tr(TranslationKeys.generateStudyQuestionHint),
              hintStyle: AppFonts.inter(
                color: isDark
                    ? Colors.white.withOpacity(0.4)
                    : const Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 2,
                ),
              ),
              errorText: _validationError,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: _selectedMode == StudyInputMode.question ? 20 : 18,
              ),
              suffixIcon: _inputController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _inputController.clear();
                        _inputFocusNode.requestFocus();
                      },
                      icon: Icon(
                        Icons.clear_rounded,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : const Color(0xFF9CA3AF),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _getFilteredSuggestions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.generateStudySuggestions),
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
      ],
    );
  }

  /// Builds the AI Discipler button - a premium feature highlight
  Widget _buildAiStudyBuddyButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleVoiceBuddyTap(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated microphone icon with glow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              context.tr(
                                  TranslationKeys.generateStudyTalkToAiBuddy),
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // "NEW" badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEW',
                              style: AppFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                            TranslationKeys.generateStudyTalkToAiBuddySubtitle),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Arrow with circle background
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handles tap on Voice Buddy button - checks plan and shows upgrade dialog for free users
  void _handleVoiceBuddyTap(BuildContext context) {
    if (kDebugMode) {
      print('🎤 [VOICE BUDDY] Button tapped');
      print('🎤 [VOICE BUDDY] _currentTokenStatus: $_currentTokenStatus');
      if (_currentTokenStatus != null) {
        print('🎤 [VOICE BUDDY] userPlan: ${_currentTokenStatus!.userPlan}');
      }
    }

    // Block access until token status is loaded
    if (_currentTokenStatus == null) {
      // Token status not loaded yet - trigger refresh and wait
      if (kDebugMode) {
        print('🎤 [VOICE BUDDY] Token status is null - triggering refresh');
      }
      context.read<TokenBloc>().add(const GetTokenStatus());
      // Show a loading indicator or snackbar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading... Please try again.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Check if user is on free plan
    if (_currentTokenStatus!.userPlan == UserPlan.free) {
      if (kDebugMode) {
        print('🎤 [VOICE BUDDY] User is on FREE plan - showing upgrade dialog');
      }
      // Show upgrade required dialog
      UpgradeRequiredDialog.show(
        context,
        featureName: 'AI Voice Discipler',
        featureIcon: Icons.mic_rounded,
        featureDescription:
            'Have voice conversations with your AI Discipler to discuss scripture, ask questions, and deepen your understanding of the Bible.',
      );
      return;
    }

    // User is on Standard or Premium plan - proceed to Voice Buddy
    if (kDebugMode) {
      print(
          '🎤 [VOICE BUDDY] User is on ${_currentTokenStatus!.userPlan} plan - navigating to voice conversation');
    }
    GoRouter.of(context).goToVoiceConversation();
  }

  /// Builds the View Saved Guides button with modern styling
  Widget _buildViewSavedGuidesButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F0FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/saved'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_outline_rounded,
                    size: 20,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr(TranslationKeys.generateStudyViewSaved),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withOpacity(0.8)
                          : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(StudyState state) {
    final isLoading =
        state is StudyGenerationInProgress || _isGeneratingStudyGuide;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenCost = _getTokenCost();
    final isEnabled = _isInputValid && !isLoading;

    return Column(
      children: [
        if (isLoading) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryPurple.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.generateStudyGenerating),
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(TranslationKeys.generateStudyConsumingTokens,
                      {'tokens': tokenCost.toString()}),
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withOpacity(0.5)
                        : const Color(0xFF6B7280),
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
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: isEnabled ? AppTheme.primaryGradient : null,
                  color: isEnabled
                      ? null
                      : isDark
                          ? Colors.white.withOpacity(0.1)
                          : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isEnabled ? _generateStudyGuide : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLoading) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              isLoading
                                  ? context.tr(TranslationKeys
                                      .generateStudyButtonGenerating)
                                  : context.tr(TranslationKeys
                                      .generateStudyButtonGenerate),
                              style: AppFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isEnabled
                                    ? Colors.white
                                    : isDark
                                        ? Colors.white.withOpacity(0.4)
                                        : const Color(0xFF9CA3AF),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (!isLoading) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? Colors.white.withOpacity(0.2)
                                    : isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.token,
                                    size: 16,
                                    color: isEnabled
                                        ? Colors.white.withOpacity(0.9)
                                        : isDark
                                            ? Colors.white.withOpacity(0.4)
                                            : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$tokenCost',
                                    style: AppFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isEnabled
                                          ? Colors.white.withOpacity(0.9)
                                          : isDark
                                              ? Colors.white.withOpacity(0.4)
                                              : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Mode selector button
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showStudyModePreferenceSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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

  Future<void> _switchLanguage(StudyLanguage language) async {
    if (kDebugMode) {
      print(
          '🔄 [GENERATE STUDY] User switching content language to: ${language.code}');
    }

    // Update local state only - this affects content generation language, not UI language
    setState(() {
      _selectedLanguage = language;
    });

    if (kDebugMode) {
      print(
          '✅ [GENERATE STUDY] Content generation language updated: ${language.code}');
      print(
          'ℹ️  [GENERATE STUDY] Note: This does not change the app UI language');
    }
  }

  /// Show bottom sheet to change study mode preference
  Future<void> _showStudyModePreferenceSheet() async {
    final currentMode =
        await _languagePreferenceService.getStudyModePreference();

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
                  context.tr(TranslationKeys.studyModePreferenceTitle),
                  style: AppFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(TranslationKeys.studyModePreferenceSubtitle),
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Mode options
                _buildModeOption(
                  context: context,
                  mode: null,
                  title: context
                      .tr(TranslationKeys.studyModePreferenceAskEveryTime),
                  subtitle: context.tr(
                      TranslationKeys.studyModePreferenceAskEveryTimeSubtitle),
                  icon: Icons.touch_app_outlined,
                  currentMode: currentMode,
                  duration: null,
                ),
                const SizedBox(height: 12),
                _buildModeOption(
                  context: context,
                  mode: StudyMode.quick,
                  title: context.tr(TranslationKeys.studyModeQuickName),
                  subtitle:
                      context.tr(TranslationKeys.studyModeQuickDescription),
                  icon: Icons.bolt,
                  currentMode: currentMode,
                  duration: '3 min',
                ),
                const SizedBox(height: 12),
                _buildModeOption(
                  context: context,
                  mode: StudyMode.standard,
                  title: context.tr(TranslationKeys.studyModeStandardName),
                  subtitle:
                      context.tr(TranslationKeys.studyModeStandardDescription),
                  icon: Icons.library_books,
                  currentMode: currentMode,
                  duration: '10 min',
                ),
                const SizedBox(height: 12),
                _buildModeOption(
                  context: context,
                  mode: StudyMode.deep,
                  title: context.tr(TranslationKeys.studyModeDeepName),
                  subtitle:
                      context.tr(TranslationKeys.studyModeDeepDescription),
                  icon: Icons.search,
                  currentMode: currentMode,
                  duration: '25 min',
                ),
                const SizedBox(height: 12),
                _buildModeOption(
                  context: context,
                  mode: StudyMode.lectio,
                  title: context.tr(TranslationKeys.studyModeLectioName),
                  subtitle:
                      context.tr(TranslationKeys.studyModeLectioDescription),
                  icon: Icons.self_improvement,
                  currentMode: currentMode,
                  duration: '15 min',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required StudyMode? mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required StudyMode? currentMode,
    required String? duration,
  }) {
    final isSelected = mode == currentMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        Navigator.of(context).pop();

        // Update preference
        if (mode != null) {
          await _languagePreferenceService.saveStudyModePreference(mode);
        } else {
          // Clear preference - save null
          await _languagePreferenceService.clearStudyModePreference();
        }

        // Show confirmation
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mode != null
                  ? 'Default mode set to ${mode.displayName}'
                  : 'Will ask for mode every time',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
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
            color: isSelected
                ? AppTheme.primaryColor
                : isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
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
                icon,
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
                  Text(
                    title,
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : isDark
                              ? Colors.white
                              : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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

            // Duration badge (if provided)
            if (duration != null) ...[
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
                  duration,
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
              const SizedBox(width: 8),
            ],

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
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
    );
  }

  Future<void> _generateStudyGuide() async {
    if (!_isInputValid) return;

    // Prevent multiple clicks during navigation
    if (_isNavigating) {
      return;
    }

    // Check if user has a saved study mode preference
    final savedMode = await _languagePreferenceService.getStudyModePreference();

    if (savedMode != null) {
      // User has saved preference - use it directly without showing sheet
      if (kDebugMode) {
        print(
            '✅ [GENERATE_STUDY] Using saved study mode: ${savedMode.displayName}');
      }
      _navigateToStudyGuide(savedMode, false);
    } else {
      // No saved preference - show mode selection sheet
      if (kDebugMode) {
        print(
            '🔍 [GENERATE_STUDY] No saved preference - showing mode selection sheet');
      }
      ModeSelectionSheet.show(
        context: context,
        onModeSelected: (mode, rememberChoice) {
          _navigateToStudyGuide(mode, rememberChoice);
        },
      );
    }
  }

  /// Navigate to study guide with selected mode.
  void _navigateToStudyGuide(StudyMode mode, bool rememberChoice) {
    _isNavigating = true;

    final input = _inputController.text.trim();
    final inputType = _selectedMode == StudyInputMode.scripture
        ? 'scripture'
        : _selectedMode == StudyInputMode.topic
            ? 'topic'
            : 'question';
    final languageCode = _selectedLanguage.code;

    // Consume tokens immediately for UI feedback
    if (_currentTokenStatus != null && !_currentTokenStatus!.isPremium) {
      context.read<TokenBloc>().add(
            ConsumeTokens(
              tokensConsumed: _getTokenCost(),
              operationType: 'study_generation',
            ),
          );
    } else if (_currentTokenStatus == null) {
      // If token status is null, trigger a refresh to get current status
      context.read<TokenBloc>().add(const GetTokenStatus());
    }

    // Save user's mode preference if they chose to remember
    if (rememberChoice) {
      _languagePreferenceService.saveStudyModePreference(mode);
    }

    // Set flag to indicate navigation away (will trigger token refresh on return)
    _hasNavigatedAway = true;

    final encodedInput = Uri.encodeComponent(input);

    debugPrint(
        '🔍 [GENERATE_STUDY] Navigating to study guide V2 for $inputType: $input with mode: ${mode.name}');

    // Navigate to study guide V2 with mode parameter
    context.go(
        '/study-guide-v2?input=$encodedInput&type=$inputType&language=$languageCode&mode=${mode.name}&source=generate');

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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: theme.shadowColor.withOpacity(0.1),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              context.tr(TranslationKeys.generateStudyGenerationFailed),
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: AppFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context
                    .tr(TranslationKeys.generateStudyGenerationFailedMessage),
                style: AppFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Show different buttons based on failure type
          if (failure is RateLimitFailure) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToTokenManagement();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                context.tr(TranslationKeys.generateStudyManageTokens),
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (isRetryable) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _generateStudyGuide();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Try Again',
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mode toggle button widget with gradient styling.
class _ModeToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isDark
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.primaryColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Language toggle button widget with gradient styling.
class _LanguageToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isDark
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.primaryColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Suggestion chip widget with modern styling.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F0FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color:
                isDark ? Colors.white.withOpacity(0.8) : AppTheme.primaryColor,
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
