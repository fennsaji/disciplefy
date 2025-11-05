import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_event.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';

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

  // Scripture reference suggestions
  final List<String> _scriptureeSuggestions = [
    'John 3:16',
    'Psalm 23:1',
    'Romans 8:28',
    'Matthew 5:16',
    'Philippians 4:13',
    '1 Corinthians 13:4-7',
    'Isaiah 40:31',
    'Jeremiah 29:11',
    'Proverbs 3:5-6',
    'Ephesians 2:8-9',
  ];

  // Topic suggestions
  final List<String> _topicSuggestions = [
    'Forgiveness',
    'Love',
    'Faith',
    'Hope',
    'Prayer',
    'Salvation',
    'Grace',
    'Peace',
    'Wisdom',
    'Trust',
    'Courage',
    'Patience',
    'Joy',
    'Mercy',
    'Redemption',
  ];

  // Question suggestions
  final List<String> _questionSuggestions = [
    'What does the Bible say about anxiety?',
    'How can I strengthen my faith?',
    'What is the purpose of prayer?',
    'Why does God allow suffering?',
    'How do I know God\'s will for my life?',
    'What does it mean to have faith?',
    'How can I overcome fear?',
    'What is God\'s love like?',
    'How should I handle difficult relationships?',
    'What happens after we die?',
    'How can I find peace in troubled times?',
    'What does it mean to be saved?',
    'How do I pray effectively?',
    'What is the meaning of grace?',
    'How can I serve God better?',
  ];

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
        context.read<TokenBloc>().add(const GetTokenStatus());
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
    // Basic regex pattern for scripture references
    final scripturePattern =
        RegExp(r'^[1-3]?\s*[a-zA-Z]+\s+\d+(?::\d+(?:-\d+)?)?$');
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
    final suggestions = _selectedMode == StudyInputMode.scripture
        ? _scriptureeSuggestions
        : _selectedMode == StudyInputMode.topic
            ? _topicSuggestions
            : _questionSuggestions;

    final query = _inputController.text.trim().toLowerCase();
    if (query.isEmpty) return suggestions.take(5).toList();

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
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
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
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tokenState.tokenStatus.totalTokens}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
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
                        '${tokenState.previousTokenStatus!.totalTokens}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
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
              print('🎯 [DEBUG] TokenBloc state changed: ${state.runtimeType}');
            }
            if (state is TokenLoaded) {
              if (kDebugMode) {
                print(
                    '💰 [DEBUG] Token loaded - totalTokens: ${state.tokenStatus.totalTokens}, isPremium: ${state.tokenStatus.isPremium}');
              }
              setState(() {
                _currentTokenStatus = state.tokenStatus;
                _isRefreshingTokens =
                    false; // Reset refresh flag when tokens load
              });
            } else if (state is TokenError &&
                state.previousTokenStatus != null) {
              if (kDebugMode) {
                print(
                    '❌ [DEBUG] Token error with previous status - totalTokens: ${state.previousTokenStatus!.totalTokens}');
              }
              setState(() {
                _currentTokenStatus = state.previousTokenStatus;
                _isRefreshingTokens = false; // Reset refresh flag even on error
              });
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
                    SizedBox(height: isLargeScreen ? 32 : 24),

                    // Mode Toggle
                    _buildModeToggle(),

                    SizedBox(height: isLargeScreen ? 24 : 16),

                    // Language Selection
                    _buildLanguageSelection(),

                    SizedBox(height: isLargeScreen ? 32 : 24),

                    // Input Section
                    _buildInputSection(),

                    SizedBox(height: isLargeScreen ? 24 : 16),

                    // Suggestions
                    _buildSuggestions(),

                    SizedBox(height: isLargeScreen ? 32 : 24),

                    // Generate Button and Status
                    BlocBuilder<StudyBloc, StudyState>(
                      builder: (context, state) => _buildGenerateButton(state),
                    ),

                    // 🔧 FIX: Only show recent guides when keyboard is hidden
                    if (!isKeyboardVisible) ...[
                      const SizedBox(height: 32),

                      // View Saved Guides button
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/saved'),
                          icon: Icon(
                            Icons.bookmark_outline,
                            size: 18,
                          ),
                          label: Text(
                            context.tr(TranslationKeys.generateStudyViewSaved),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const RecentGuidesSection(),
                      SizedBox(height: isLargeScreen ? 40 : 24),
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

  Widget _buildModeToggle() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeToggleButton(
                    label:
                        context.tr(TranslationKeys.generateStudyScriptureMode),
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
                    label:
                        context.tr(TranslationKeys.generateStudyQuestionMode),
                    isSelected: _selectedMode == StudyInputMode.question,
                    onTap: () => _switchMode(StudyInputMode.question),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildLanguageSelection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.generateStudyLanguage),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
                    onTap: () async =>
                        await _switchLanguage(StudyLanguage.hindi),
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

  Color _getTokenCostColor() {
    return Colors.orange[600]!;
  }

  Widget _buildInputSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedMode == StudyInputMode.scripture
                ? context.tr(TranslationKeys.generateStudyEnterScripture)
                : _selectedMode == StudyInputMode.topic
                    ? context.tr(TranslationKeys.generateStudyEnterTopic)
                    : context.tr(TranslationKeys.generateStudyAskQuestion),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            maxLines: _selectedMode == StudyInputMode.question ? 4 : 1,
            minLines: _selectedMode == StudyInputMode.question ? 3 : 1,
            textInputAction: _selectedMode == StudyInputMode.question
                ? TextInputAction.newline
                : TextInputAction.done,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            decoration: InputDecoration(
              hintText: _selectedMode == StudyInputMode.scripture
                  ? context.tr(TranslationKeys.generateStudyScriptureHint)
                  : _selectedMode == StudyInputMode.topic
                      ? context.tr(TranslationKeys.generateStudyTopicHint)
                      : context.tr(TranslationKeys.generateStudyQuestionHint),
              hintStyle: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 2,
                ),
              ),
              errorText: _validationError,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _selectedMode == StudyInputMode.question ? 20 : 16,
              ),
              suffixIcon: _inputController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _inputController.clear();
                        _inputFocusNode.requestFocus();
                      },
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      );

  Widget _buildSuggestions() {
    final suggestions = _getFilteredSuggestions();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.generateStudySuggestions),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
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
      ],
    );
  }

  Widget _buildGenerateButton(StudyState state) {
    final isLoading =
        state is StudyGenerationInProgress || _isGeneratingStudyGuide;

    final tokenCost = _getTokenCost();

    return Column(
      children: [
        if (isLoading) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.generateStudyGenerating),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(TranslationKeys.generateStudyConsumingTokens,
                      {'tokens': tokenCost.toString()}),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isInputValid && !isLoading ? _generateStudyGuide : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isLoading
                        ? context
                            .tr(TranslationKeys.generateStudyButtonGenerating)
                        : context
                            .tr(TranslationKeys.generateStudyButtonGenerate),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!isLoading) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token,
                        size: 18,
                        color: _getTokenCostColor(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$tokenCost',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getTokenCostColor(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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

  void _generateStudyGuide() {
    if (!_isInputValid) return;

    // Prevent multiple clicks during generation
    if (_isGeneratingStudyGuide) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.generateStudyInProgress)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final input = _inputController.text.trim();
    final inputType = _selectedMode == StudyInputMode.scripture
        ? 'scripture'
        : _selectedMode == StudyInputMode.topic
            ? 'topic'
            : 'question';
    final languageCode = _selectedLanguage.code;

    // Set loading state immediately
    setState(() {
      _isGeneratingStudyGuide = true;
    });

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

    // Trigger BLoC event to generate study guide
    context.read<StudyBloc>().add(
          GenerateStudyGuideRequested(
            input: input,
            inputType: inputType,
            language: languageCode,
          ),
        );
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
              style: GoogleFonts.playfairDisplay(
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
              style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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

/// Mode toggle button widget.
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

/// Language toggle button widget.
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

/// Suggestion chip widget.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
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
