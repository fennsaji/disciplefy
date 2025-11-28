import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/token_failures.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../domain/entities/study_guide.dart';
import '../../../../core/navigation/study_navigator.dart';
import '../../../home/data/services/recommended_guides_service.dart';
import '../bloc/study_bloc.dart';
import '../bloc/study_event.dart';
import '../bloc/study_state.dart';
import '../../../follow_up_chat/presentation/widgets/follow_up_chat_widget.dart';
import '../../../follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import '../../../follow_up_chat/presentation/bloc/follow_up_chat_event.dart';
import '../../../notifications/presentation/widgets/notification_enable_prompt.dart';
import '../widgets/engaging_loading_screen.dart';

/// Study Guide Screen V2 - Dynamically generates study guides from query parameters
///
/// This screen accepts topic/verse/question as query parameters and generates
/// the study guide content via API. Perfect for push notification deep links.
///
/// **URL Structure:**
/// - Topic: `/study-guide-v2?input=Love&type=topic`
/// - Scripture: `/study-guide-v2?input=John 3:16&type=scripture`
/// - With language: `/study-guide-v2?input=Love&type=topic&language=en`
/// - With topic_id (from notification): `/study-guide-v2?topic_id=abc123&input=Love&type=topic`
///
/// **Features:**
/// - Dynamic content loading based on URL parameters
/// - Loading states with progress indication
/// - Error handling with retry functionality
/// - Same UI/UX as original study guide screen
/// - Auto-save and personal notes support
class StudyGuideScreenV2 extends StatelessWidget {
  /// Optional topic ID from database (used for tracking/future features)
  final String? topicId;

  /// Input text from query parameters (topic/verse/question)
  final String? input;

  /// Type of input: 'scripture', 'topic', or 'question'
  final String? type;

  /// Optional topic description for additional context (only for topics)
  final String? description;

  /// Optional language code for the study guide
  final String? language;

  /// Navigation source for proper back navigation
  final StudyNavigationSource navigationSource;

  const StudyGuideScreenV2({
    super.key,
    this.topicId,
    this.input,
    this.type,
    this.description,
    this.language,
    this.navigationSource = StudyNavigationSource.home,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => sl<StudyBloc>(),
        child: _StudyGuideScreenV2Content(
          topicId: topicId,
          input: input,
          type: type,
          description: description,
          language: language,
          navigationSource: navigationSource,
        ),
      );
}

class _StudyGuideScreenV2Content extends StatefulWidget {
  final String? topicId;
  final String? input;
  final String? type;
  final String? description;
  final String? language;
  final StudyNavigationSource navigationSource;

  const _StudyGuideScreenV2Content({
    this.topicId,
    this.input,
    this.type,
    this.description,
    this.language,
    required this.navigationSource,
  });

  @override
  State<_StudyGuideScreenV2Content> createState() =>
      _StudyGuideScreenV2ContentState();
}

class _StudyGuideScreenV2ContentState
    extends State<_StudyGuideScreenV2Content> {
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StudyGuide? _currentStudyGuide;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSaved = false;
  DateTime? _lastSaveAttempt;

  // Language state for loading screen localization
  String _selectedLanguage = 'en';

  // Supported languages for the app
  static const Set<String> _supportedLanguages = {'en', 'hi', 'ml'};

  /// Normalizes and validates a language code.
  ///
  /// Extracts the base language code (e.g., 'en' from 'en-US'),
  /// validates it against supported languages, and falls back to 'en'.
  ///
  /// @returns A normalized two-letter language code ('en', 'hi', or 'ml').
  String _normalizeLanguageCode(String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) {
      return 'en';
    }

    // Extract base language code (split on '-' and take first segment)
    final baseLang = languageCode.split('-').first.toLowerCase();

    // Validate against supported languages
    if (_supportedLanguages.contains(baseLang)) {
      return baseLang;
    }

    // Fall back to default
    return 'en';
  }

  // Personal notes state
  String? _loadedNotes;
  bool _notesLoaded = false;
  Timer? _autoSaveTimer;
  VoidCallback? _autoSaveListener;

  // Follow-up chat state
  bool _isChatExpanded = false;

  // Completion tracking state
  DateTime? _pageOpenedAt;
  int _timeSpentSeconds = 0;
  Timer? _timeTrackingTimer;
  bool _hasScrolledToBottom = false;
  bool _completionMarked = false;

  // Notification prompt state
  bool _hasTriggeredNotificationPrompt = false;
  bool _isCompletionTrackingStarted = false;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
    _initializeStudyGuide();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _timeTrackingTimer?.cancel();
    _isCompletionTrackingStarted = false;
    if (_autoSaveListener != null) {
      _notesController.removeListener(_autoSaveListener!);
    }
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize study guide generation from query parameters
  Future<void> _initializeStudyGuide() async {
    // Note: widget.topicId is available for future features (tracking, analytics)
    // Currently, we use widget.input (topic_title) for study guide generation
    // since the API requires the actual topic text, not the database ID.

    if (kDebugMode && widget.topicId != null) {
      print(
          '🔍 [STUDY_GUIDE_V2] Topic ID from notification: ${widget.topicId}');
    }

    // Validate required parameters
    if (widget.input == null || widget.input!.trim().isEmpty) {
      _showError('Missing study topic or verse. Please provide a valid input.');
      return;
    }

    if (widget.type == null ||
        !['scripture', 'topic', 'question'].contains(widget.type)) {
      _showError(
          'Invalid input type. Expected: scripture, topic, or question.');
      return;
    }

    // Get user's language preference if not specified in URL
    String rawLanguageCode = widget.language ?? 'en';
    if (widget.language == null) {
      try {
        final languageService = sl<LanguagePreferenceService>();
        final appLanguage = await languageService.getSelectedLanguage();
        rawLanguageCode = appLanguage.code;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [STUDY_GUIDE_V2] Failed to get language preference: $e');
        }
      }
    }

    // Normalize and validate language code
    final normalizedLanguageCode = _normalizeLanguageCode(rawLanguageCode);

    if (kDebugMode && rawLanguageCode != normalizedLanguageCode) {
      print(
          '🌐 [STUDY_GUIDE_V2] Language normalized: $rawLanguageCode → $normalizedLanguageCode');
    }

    // Guard against disposed widget after async operation
    if (!mounted) return;

    // Save selected language for loading screen localization
    setState(() {
      _selectedLanguage = normalizedLanguageCode;
    });

    // Dispatch study guide generation event
    context.read<StudyBloc>().add(GenerateStudyGuideRequested(
          input: widget.input!,
          inputType: widget.type!,
          topicDescription: widget
              .description, // Include topic description for richer context
          language: normalizedLanguageCode,
        ));
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = message;
    });
  }

  /// Handle successful study guide generation
  void _handleGenerationSuccess(StudyGuide studyGuide) {
    if (!mounted) return;
    setState(() {
      _currentStudyGuide = studyGuide;
      _isLoading = false;
      _hasError = false;
      _errorMessage = '';

      // Check if guide is already saved
      if (studyGuide.isSaved != null) {
        _isSaved = studyGuide.isSaved!;
      }

      // Load personal notes if available
      if (studyGuide.personalNotes != null) {
        _loadedNotes = studyGuide.personalNotes;
        _notesController.text = studyGuide.personalNotes!;
        _notesLoaded = true;

        if (_isSaved) {
          _setupAutoSave();
        }
      } else if (_isSaved) {
        _loadPersonalNotesIfSaved();
      }
    });

    // Start completion tracking
    _startCompletionTracking();
  }

  /// Handle study guide generation failure
  void _handleGenerationFailure(Failure failure, {bool isRetryable = true}) {
    String errorMessage = 'Failed to generate study guide.';

    if (failure is NetworkFailure) {
      errorMessage =
          'Network error. Please check your connection and try again.';
    } else if (failure is ServerFailure) {
      errorMessage = 'Server error. Please try again later.';
    } else if (failure is AuthenticationFailure) {
      errorMessage = 'Authentication error. Please sign in and try again.';
    } else if (failure is InsufficientTokensFailure) {
      errorMessage =
          'You have run out of AI tokens. Please purchase more tokens or upgrade to premium.';
    } else {
      errorMessage = failure.message;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = errorMessage;
    });
  }

  /// Retry study guide generation
  Future<void> _retryGeneration() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    await _initializeStudyGuide();
  }

  /// Load personal notes if the guide is saved and notes not already available
  void _loadPersonalNotesIfSaved() {
    if (_currentStudyGuide == null) return;

    if (kDebugMode) {
      print(
          '🔍 [STUDY_GUIDE_V2] Loading personal notes: isSaved=$_isSaved, notesLoaded=$_notesLoaded');
    }

    if (_isSaved && !_notesLoaded) {
      if (kDebugMode) {
        print(
            '📝 [STUDY_GUIDE_V2] Requesting personal notes for guide: ${_currentStudyGuide!.id}');
      }
      context.read<StudyBloc>().add(LoadPersonalNotesRequested(
            guideId: _currentStudyGuide!.id,
          ));
    }
  }

  /// Setup auto-save for personal notes
  void _setupAutoSave() {
    if (_currentStudyGuide == null) return;

    // Remove existing listener to prevent duplicates
    if (_autoSaveListener != null) {
      _notesController.removeListener(_autoSaveListener!);
    }

    // Create new listener callback
    _autoSaveListener = () {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(milliseconds: 2000), () {
        final currentText = _notesController.text.trim();
        if (currentText != (_loadedNotes ?? '').trim()) {
          // Only auto-save if notes have changed and guide is saved
          if (_isSaved && _currentStudyGuide != null) {
            context.read<StudyBloc>().add(UpdatePersonalNotesRequested(
                  guideId: _currentStudyGuide!.id,
                  personalNotes: currentText.isEmpty ? null : currentText,
                  isAutoSave: true,
                ));
          }
        }
      });
    };

    // Add the listener
    _notesController.addListener(_autoSaveListener!);
  }

  // ============================================================================
  // Completion Tracking Methods
  // ============================================================================

  /// Start tracking completion conditions (time spent + scroll to bottom)
  void _startCompletionTracking() {
    if (_currentStudyGuide == null) return;

    // Early return if already started to prevent duplicate timers/listeners
    if (_isCompletionTrackingStarted) return;

    _startTimeTrackingTimer();
    _startScrollListener();

    // Mark as started
    _isCompletionTrackingStarted = true;

    if (kDebugMode) {
      print(
          '📊 [COMPLETION] Started tracking for guide: ${_currentStudyGuide!.id}');
    }
  }

  /// Setup timer to track time spent on the page
  void _startTimeTrackingTimer() {
    _timeTrackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_completionMarked) {
        setState(() {
          _timeSpentSeconds++;
        });
        _checkCompletionConditions();
      }
    });
  }

  /// Setup scroll listener to detect when user reaches bottom
  void _startScrollListener() {
    _scrollController.addListener(() {
      if (!_completionMarked &&
          !_hasScrolledToBottom &&
          _isScrolledToBottom()) {
        setState(() {
          _hasScrolledToBottom = true;
        });
        _checkCompletionConditions();
      }
    });
  }

  /// Check if user has scrolled to the bottom of the page
  bool _isScrolledToBottom() {
    if (!_scrollController.hasClients) return false;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Consider "bottom" as within 100px of the actual bottom
    return currentScroll >= (maxScroll - 100);
  }

  /// Check if both completion conditions are met and mark complete if so
  void _checkCompletionConditions() {
    if (_completionMarked || _currentStudyGuide == null) return;

    const minTimeSeconds = 60; // 1 minute
    final timeConditionMet = _timeSpentSeconds >= minTimeSeconds;
    final scrollConditionMet = _hasScrolledToBottom;

    if (kDebugMode) {
      print('📊 [COMPLETION] Conditions check:');
      print(
          '   Time: $_timeSpentSeconds/${minTimeSeconds}s (${timeConditionMet ? "✓" : "✗"})');
      print('   Scroll: ${scrollConditionMet ? "✓" : "✗"}');
    }

    if (timeConditionMet && scrollConditionMet) {
      _markStudyGuideComplete();
    }
  }

  /// Call the API to mark the study guide as completed
  void _markStudyGuideComplete() {
    if (_completionMarked || _currentStudyGuide == null) return;

    setState(() {
      _completionMarked = true;
    });

    if (kDebugMode) {
      print('✅ [COMPLETION] Marking guide as complete:');
      print('   Guide ID: ${_currentStudyGuide!.id}');
      print('   Time spent: $_timeSpentSeconds seconds');
      print('   Scrolled to bottom: $_hasScrolledToBottom');
    }

    // Dispatch BLoC event to mark completion
    context.read<StudyBloc>().add(MarkStudyGuideCompleteRequested(
          guideId: _currentStudyGuide!.id,
          timeSpentSeconds: _timeSpentSeconds,
          scrolledToBottom: _hasScrolledToBottom,
        ));

    // Cancel the tracking timer since completion is marked
    _timeTrackingTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: BlocListener<StudyBloc, StudyState>(
        listener: (context, state) {
          // Handle study guide generation states
          if (state is StudyGenerationInProgress) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          } else if (state is StudyGenerationSuccess) {
            _handleGenerationSuccess(state.studyGuide);
          } else if (state is StudyGenerationFailure) {
            _handleGenerationFailure(state.failure,
                isRetryable: state.isRetryable);
          }
          // Handle save operations
          else if (state is StudyEnhancedSaveSuccess) {
            if (!mounted) return;
            setState(() {
              _isSaved = state.guideSaved;
              if (state.notesSaved && state.savedNotes != null) {
                _loadedNotes = state.savedNotes;
              }
            });
            _showSnackBar(
              state.message,
              Colors.green,
              icon: Icons.check_circle,
            );
            if (state.guideSaved) {
              _setupAutoSave();
            }
          } else if (state is StudyEnhancedSaveFailure) {
            _handleEnhancedSaveError(state);
          } else if (state is StudyEnhancedAuthenticationRequired) {
            _showEnhancedAuthenticationRequiredDialog(state);
          }
          // Handle personal notes operations
          else if (state is StudyPersonalNotesLoaded) {
            if (!mounted) return;
            setState(() {
              _notesLoaded = true;
              _loadedNotes = state.notes;
              if (state.notes != null) {
                _notesController.text = state.notes!;
              }
            });
            if (_isSaved) {
              _setupAutoSave();
            }
          } else if (state is StudyPersonalNotesSuccess) {
            if (!state.isAutoSave) {
              _showSnackBar(
                state.message ?? 'Personal notes saved!',
                Colors.green,
                icon: Icons.note_add,
              );
            }
            if (!mounted) return;
            setState(() {
              _loadedNotes = state.savedNotes;
            });
          } else if (state is StudyPersonalNotesFailure) {
            if (!state.isAutoSave) {
              _showSnackBar(
                'Failed to save personal notes: ${state.failure.message}',
                Theme.of(context).colorScheme.error,
                icon: Icons.error_outline,
              );
            }
          }
          // Handle study completion - show notification prompt and invalidate cache
          else if (state is StudyCompletionSuccess) {
            // Invalidate the "For You" cache so completed topics don't show again
            sl<RecommendedGuidesService>().clearForYouCache();
            _showRecommendedTopicNotificationPrompt();
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(),
          body: _buildBody(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: _handleBackNavigation,
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Go back',
        ),
        title: Text(
          _getDisplayTitle(),
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
        actions: _currentStudyGuide != null
            ? [
                IconButton(
                  onPressed: _shareStudyGuide,
                  icon: Icon(
                    Icons.share_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Share study guide',
                ),
              ]
            : null,
      );

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_hasError) {
      return _buildErrorScreen();
    }

    if (_currentStudyGuide == null) {
      return _buildErrorScreen();
    }

    return _buildStudyGuideContent();
  }

  Widget _buildLoadingScreen() => EngagingLoadingScreen(
        topic: widget.input,
        language: _selectedLanguage,
      );

  Widget _buildErrorScreen() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: AppFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage.isEmpty
                    ? 'We couldn\'t generate your study guide. Please try again.'
                    : _errorMessage,
                style: AppFonts.inter(
                  fontSize: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _handleBackNavigation,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      'Go Back',
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _retryGeneration,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      'Try Again',
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildStudyGuideContent() {
    if (_currentStudyGuide == null) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return Column(
      children: [
        // Main content
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isLargeScreen ? 24 : 16),

                // Study Guide Content
                _buildStudyContent(),

                SizedBox(height: isLargeScreen ? 32 : 24),

                // Follow-up Chat Section
                BlocProvider(
                  create: (context) {
                    final bloc = sl<FollowUpChatBloc>();
                    bloc.add(StartConversationEvent(
                      studyGuideId: _currentStudyGuide!.id,
                      studyGuideTitle: _getDisplayTitle(),
                    ));
                    return bloc;
                  },
                  child: FollowUpChatWidget(
                    studyGuideId: _currentStudyGuide!.id,
                    studyGuideTitle: _getDisplayTitle(),
                    isExpanded: _isChatExpanded,
                    onToggleExpanded: () {
                      setState(() {
                        _isChatExpanded = !_isChatExpanded;
                      });
                    },
                  ),
                ),

                SizedBox(height: isLargeScreen ? 32 : 24),

                // Notes Section
                _buildNotesSection(),

                SizedBox(height: isLargeScreen ? 32 : 24),
              ],
            ),
          ),
        ),

        // Bottom Action Buttons
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildStudyContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideSummary),
            icon: Icons.summarize,
            content: _currentStudyGuide!.summary,
          ),

          const SizedBox(height: 24),

          // Interpretation Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideInterpretation),
            icon: Icons.lightbulb_outline,
            content: _currentStudyGuide!.interpretation,
          ),

          const SizedBox(height: 24),

          // Context Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideContext),
            icon: Icons.history_edu,
            content: _currentStudyGuide!.context,
          ),

          const SizedBox(height: 24),

          // Related Verses Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideRelatedVerses),
            icon: Icons.menu_book,
            content: _currentStudyGuide!.relatedVerses.join('\n\n'),
          ),

          const SizedBox(height: 24),

          // Discussion Questions Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideDiscussionQuestions),
            icon: Icons.quiz,
            content: _currentStudyGuide!.reflectionQuestions
                .asMap()
                .entries
                .map((entry) => '${entry.key + 1}. ${entry.value}')
                .join('\n\n'),
          ),

          const SizedBox(height: 24),

          // Prayer Points Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuidePrayerPoints),
            icon: Icons.favorite,
            content: _currentStudyGuide!.prayerPoints
                .asMap()
                .entries
                .map((entry) => '• ${entry.value}')
                .join('\n'),
          ),
        ],
      );

  Widget _buildNotesSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(TranslationKeys.studyGuidePersonalNotes),
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 6,
              style: AppFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: context
                    .tr(TranslationKeys.studyGuidePersonalNotesPlaceholder),
                hintStyle: AppFonts.inter(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      );

  Widget _buildBottomActions() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: BlocBuilder<StudyBloc, StudyState>(
                builder: (context, state) {
                  final isSaving = (state is StudyEnhancedSaveInProgress &&
                      _currentStudyGuide != null &&
                      state.guideId == _currentStudyGuide!.id);

                  String? currentStep;
                  if (state is StudyEnhancedSaveInProgress) {
                    currentStep = state.currentStep;
                  }

                  return isSaving
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          label: Text(
                            currentStep ?? 'Saving...',
                            style: AppFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.6),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.6),
                              width: 2,
                            ),
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _saveStudyGuide,
                          icon: Icon(_isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border),
                          label: Text(
                            _isSaved
                                ? context.tr(TranslationKeys.studyGuideSaved)
                                : context
                                    .tr(TranslationKeys.studyGuideSaveStudy),
                            style: AppFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isSaved
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: _isSaved
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
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
                    onTap: _shareStudyGuide,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          context.tr(TranslationKeys.studyGuideShare),
                          style: AppFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      );

  String _getDisplayTitle() {
    if (_currentStudyGuide == null) {
      return widget.input ?? 'Study Guide';
    }

    if (_currentStudyGuide!.inputType == 'scripture') {
      return _currentStudyGuide!.input;
    } else {
      final input = _currentStudyGuide!.input;
      return input.substring(0, 1).toUpperCase() + input.substring(1);
    }
  }

  void _handleBackNavigation() {
    sl<StudyNavigator>().navigateBack(
      context,
      source: widget.navigationSource,
    );
  }

  /// Toggle save/unsave status of the current study guide
  void _saveStudyGuide() {
    if (_currentStudyGuide == null) return;

    // Debounce rapid taps
    final now = DateTime.now();
    if (_lastSaveAttempt != null &&
        now.difference(_lastSaveAttempt!).inSeconds < 2) {
      return;
    }
    _lastSaveAttempt = now;

    final shouldSave = !_isSaved;
    final personalNotes = _notesController.text.trim();

    context.read<StudyBloc>().add(CheckEnhancedAuthenticationRequested(
          guideId: _currentStudyGuide!.id,
          save: shouldSave,
          personalNotes: personalNotes.isEmpty ? null : personalNotes,
        ));
  }

  /// Handle enhanced save operation errors from BLoC
  void _handleEnhancedSaveError(StudyEnhancedSaveFailure state) {
    String message;
    Color backgroundColor = Theme.of(context).colorScheme.error;
    IconData icon = Icons.error_outline;

    if (state.guideSaveSuccess && !state.notesSaveSuccess) {
      message = 'Study guide saved, but failed to save personal notes.';
      if (mounted) {
        setState(() {
          _isSaved = true;
        });
      }
      _setupAutoSave();
    } else {
      if (state.primaryFailure.code == 'UNAUTHORIZED') {
        message = 'Authentication expired. Please sign in again.';
      } else if (state.primaryFailure.code == 'NETWORK_ERROR') {
        message = 'Network error. Please check your connection.';
      } else if (state.primaryFailure.code == 'ALREADY_SAVED') {
        message = 'This study guide is already saved!';
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.check_circle;
        if (mounted) {
          setState(() {
            _isSaved = true;
          });
        }
        _setupAutoSave();
      } else {
        message = state.primaryFailure.message;
      }
    }

    _showSnackBar(message, backgroundColor, icon: icon);
  }

  /// Show enhanced authentication required dialog
  void _showEnhancedAuthenticationRequiredDialog(
      StudyEnhancedAuthenticationRequired state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFA),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Text(
          context.tr(TranslationKeys.studyGuideAuthRequired),
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        content: Text(
          context.tr(TranslationKeys.studyGuideAuthRequiredMessage),
          style: AppFonts.inter(
            fontSize: 18,
            color: const Color(0xFF333333),
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF888888),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              context.tr(TranslationKeys.commonCancel),
              style: AppFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              sl<StudyNavigator>().navigateToLogin(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              context.tr(TranslationKeys.studyGuideSignIn),
              style: AppFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show snackbar with consistent styling
  void _showSnackBar(String message, Color backgroundColor, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: AppFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Shows recommended topic notification prompt after completing a study guide
  Future<void> _showRecommendedTopicNotificationPrompt() async {
    if (_hasTriggeredNotificationPrompt) return;
    _hasTriggeredNotificationPrompt = true;

    // Delay to show after the completion is processed
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.recommendedTopic,
      languageCode: _selectedLanguage,
    );
  }

  void _shareStudyGuide() {
    if (_currentStudyGuide == null) return;

    final shareText = '''
${_getDisplayTitle()}

${context.tr(TranslationKeys.studyGuideSummary)}:
${_currentStudyGuide!.summary}

${context.tr(TranslationKeys.studyGuideInterpretation)}:
${_currentStudyGuide!.interpretation}

${context.tr(TranslationKeys.studyGuideContext)}:
${_currentStudyGuide!.context}

${context.tr(TranslationKeys.studyGuideRelatedVerses)}:
${_currentStudyGuide!.relatedVerses.join('\n')}

${context.tr(TranslationKeys.studyGuideDiscussionQuestions)}:
${_currentStudyGuide!.reflectionQuestions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

${context.tr(TranslationKeys.studyGuidePrayerPoints)}:
${_currentStudyGuide!.prayerPoints.map((p) => '• $p').join('\n')}

Generated by Disciplefy - Bible Study App
''';

    Share.share(
      shareText,
      subject: 'Bible Study: ${_getDisplayTitle()}',
    );
  }
}

/// Study section widget for displaying content with consistent styling.
class _StudySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _StudySection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),
                // Copy button
                IconButton(
                  onPressed: () => _copyToClipboard(context, content),
                  icon: Icon(
                    Icons.copy,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    size: 18,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: 'Copy $title',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Section Content
            SelectableText(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      );

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(TranslationKeys.studyGuideCopiedToClipboard),
          style: AppFonts.inter(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
