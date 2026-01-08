import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/clickable_scripture_text.dart';
import '../../../../shared/widgets/scripture_verse_sheet.dart';
import '../../../../shared/widgets/markdown_with_scripture.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/token_failures.dart';
import '../../../../core/di/injection_container.dart';
import '../../../study_topics/domain/repositories/topic_progress_repository.dart';
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
import '../widgets/streaming_study_content.dart';
import '../widgets/tts_control_button.dart';
import '../widgets/tts_control_sheet.dart';
import '../../data/services/study_guide_tts_service.dart';
import '../../data/services/study_guide_pdf_service.dart';
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';
import '../../domain/entities/study_mode.dart';
import '../widgets/reflect_mode_view.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/repositories/reflections_repository.dart';
import '../widgets/reading_completion_card.dart';

/// Removes duplicate section title from content if present at the start
String _cleanDuplicateTitle(String content, String title) {
  final lines = content.split('\n');
  if (lines.isEmpty) return content;

  // Remove markdown formatting and normalize for comparison
  final normalizedTitle =
      title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  final firstLine =
      lines.first.toLowerCase().replaceAll(RegExp(r'[*_#]'), '').trim();

  // Check if first line matches the title (with some tolerance)
  if (firstLine.contains(normalizedTitle) ||
      normalizedTitle.contains(firstLine)) {
    // Remove first line and any empty lines that follow
    final cleanedLines =
        lines.skip(1).skipWhile((line) => line.trim().isEmpty).toList();
    final cleaned = cleanedLines.join('\n');

    // If removing the title left no content, return original
    // (the "title" might have been the entire content)
    if (cleaned.trim().isEmpty) {
      return content;
    }

    return cleaned;
  }

  return content;
}

/// Converts scripture references in text to markdown links for tap handling
/// Uses the same regex pattern as ClickableScriptureText to detect references
String _convertScriptureReferencesToLinks(String text) {
  // Use the same scripture pattern from ClickableScriptureText
  final scripturePattern = RegExp(
    r'('
    r'(?:\d\s?)?' // Optional number prefix
    r'(?:'
    // English book names
    r'[A-Z][a-z]{2,}(?:\s(?:of\s)?[A-Z][a-z]+)?'
    r'|'
    // Hindi multi-word book names
    r'भजन संहिता|प्रेरितों के काम|श्रेष्ठगीत'
    r'|'
    // Hindi single-word book names
    r'(?:उत्पत्ति|निर्गमन|लैव्यव्यवस्था|गिनती|व्यवस्थाविवरण|'
    r'यहोशू|न्यायियों|रूत|शमूएल|राजा|इतिहास|एज्रा|नहेम्याह|एस्तेर|अय्यूब|'
    r'भजन|नीतिवचन|सभोपदेशक|यशायाह|यिर्मयाह|विलापगीत|यहेजकेल|दानिय्येल|'
    r'होशे|योएल|आमोस|ओबद्याह|योना|मीका|नहूम|हबक्कूक|सपन्याह|हाग्गै|जकर्याह|मलाकी|'
    r'मत्ती|मरकुस|लूका|यूहन्ना|प्रेरितों|रोमियों|कुरिन्थियों|गलातियों|इफिसियों|'
    r'फिलिप्पियों|कुलुस्सियों|थिस्सलुनीकियों|तीमुथियुस|तीतुस|फिलेमोन|इब्रानियों|'
    r'याकूब|पतरस|यहूदा|प्रकाशितवाक्य)'
    r'|'
    // Malayalam multi-word book names
    r'അപ്പൊസ്തലന്മാരുടെ പ്രവൃത്തികൾ|ഉത്തമഗീതം'
    r'|'
    // Malayalam single-word book names
    r'(?:ഉല്പത്തി|പുറപ്പാട്|ലേവ്യപുസ്തകം|സംഖ്യ|ആവർത്തനം|'
    r'യോശുവ|ന്യായാധിപന്മാർ|രൂത്ത്|ശമൂവേൽ|രാജാക്കന്മാർ|ദിനവൃത്താന്തം|'
    r'എസ്രാ|നെഹെമ്യാവ്|എസ്ഥേർ|ഇയ്യോബ്|സങ്കീർത്തനങ്ങൾ|സദൃശ്യവാക്യങ്ങൾ|'
    r'സഭാപ്രസംഗി|യെശയ്യാവ്|യിരെമ്യാവ്|വിലാപങ്ങൾ|യെഹെസ്കേൽ|ദാനിയേൽ|'
    r'ഹോശേയ|യോവേൽ|ആമോസ്|ഓബദ്യാവ്|യോനാ|മീഖാ|നഹൂം|ഹബക്കൂക്ക്|സെഫന്യാവ്|'
    r'ഹഗ്ഗായി|സെഖര്യാവ്|മലാഖി|മത്തായി|മർക്കൊസ്|ലൂക്കൊസ്|യോഹന്നാൻ|'
    r'റോമർ|കൊരിന്ത്യർ|ഗലാത്യർ|എഫെസ്യർ|ഫിലിപ്പിയർ|കൊലൊസ്സ്യർ|'
    r'തെസ്സലൊനീക്യർ|തിമൊഥെയൊസ്|തീത്തൊസ്|ഫിലേമോൻ|എബ്രായർ|യാക്കോബ്|'
    r'പത്രൊസ്|യൂദാ|വെളിപ്പാട്)'
    r')'
    r')'
    r'\s+(\d+)(?::(\d+)(?:-(\d+))?)?', // Matches chapter:verse patterns
    unicode: true,
  );

  // Replace scripture references with markdown links
  return text.replaceAllMapped(scripturePattern, (match) {
    final reference = match.group(0)!;
    // Use a custom URL scheme to identify scripture references
    return '[$reference](scripture://$reference)';
  });
}

/// Lightens a color for better contrast in dark mode
Color _lightenColor(Color color, [double amount = 0.2]) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}

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
/// - With mode: `/study-guide-v2?input=Love&type=topic&mode=quick` (quick, standard, deep, lectio)
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

  /// Study mode (quick, standard, deep, lectio)
  final StudyMode studyMode;

  const StudyGuideScreenV2({
    super.key,
    this.topicId,
    this.input,
    this.type,
    this.description,
    this.language,
    this.navigationSource = StudyNavigationSource.home,
    this.studyMode = StudyMode.standard,
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
          studyMode: studyMode,
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
  final StudyMode studyMode;

  const _StudyGuideScreenV2Content({
    this.topicId,
    this.input,
    this.type,
    this.description,
    this.language,
    required this.navigationSource,
    required this.studyMode,
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
  bool _isInsufficientTokensError =
      false; // Track token error for special handling
  bool _isSaved = false;
  DateTime? _lastSaveAttempt;

  // View mode state for Read/Reflect toggle
  StudyViewMode _viewMode = StudyViewMode.read;

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
  final GlobalKey _followUpChatKey = GlobalKey();

  // Completion tracking state
  DateTime? _pageOpenedAt;
  int _timeSpentSeconds = 0;
  Timer? _timeTrackingTimer;
  bool _hasScrolledToBottom = false;
  bool _completionMarked = false;
  final GlobalKey _prayerPointsKey = GlobalKey();

  // Notification prompt state
  bool _hasTriggeredNotificationPrompt = false;
  bool _isCompletionTrackingStarted = false;

  // Reading completion card visibility
  bool _showCompletionCard = true;

  // PDF export state
  bool _isExportingPdf = false;

  // Reflection completion state
  bool _isCompletingReflection = false;

  // Scroll position preservation during streaming-to-complete transition
  double? _savedScrollPosition;
  bool _isTransitioningFromStreaming = false;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
    _initializeStudyGuide();
  }

  @override
  void dispose() {
    // Stop TTS when navigating away
    sl<StudyGuideTTSService>().stop();

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

    // Track topic progress start if we have a topic ID
    _startTopicProgress();

    // Dispatch streaming study guide generation event (V2 API)
    // This uses SSE for progressive section rendering
    context.read<StudyBloc>().add(GenerateStudyGuideStreamingRequested(
          input: widget.input!,
          inputType: widget.type!,
          topicDescription: widget
              .description, // Include topic description for richer context
          language: normalizedLanguageCode,
          studyMode: widget.studyMode,
        ));
  }

  /// Start tracking topic progress when user opens a study guide from a topic.
  ///
  /// This is called at the beginning of study guide generation when a topicId
  /// is present (e.g., from recommended topics or notifications).
  Future<void> _startTopicProgress() async {
    final topicId = widget.topicId;
    if (topicId == null || topicId.isEmpty) {
      return;
    }

    if (kDebugMode) {
      print('📊 [TOPIC_PROGRESS] Starting topic progress for: $topicId');
    }

    try {
      final repository = sl<TopicProgressRepository>();
      final result = await repository.startTopic(topicId);

      result.fold(
        (failure) {
          if (kDebugMode) {
            print(
                '❌ [TOPIC_PROGRESS] Failed to start topic: ${failure.message}');
          }
        },
        (_) {
          if (kDebugMode) {
            print('✅ [TOPIC_PROGRESS] Topic progress started successfully');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TOPIC_PROGRESS] Exception during start tracking: $e');
      }
    }
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
      } else if (_isSaved) {
        _loadPersonalNotesIfSaved();
      }
    });

    // Always setup auto-save for personal notes (independent of save status)
    _setupAutoSave();

    // Start completion tracking
    _startCompletionTracking();
  }

  /// Handle study guide generation failure
  void _handleGenerationFailure(Failure failure, {bool isRetryable = true}) {
    String errorKey = TranslationKeys.studyGuideErrorDefaultMessage;
    bool isTokenError = false;

    if (failure is NetworkFailure) {
      errorKey = TranslationKeys.studyGuideErrorNetwork;
    } else if (failure is ServerFailure) {
      errorKey = TranslationKeys.studyGuideErrorServer;
    } else if (failure is AuthenticationFailure) {
      errorKey = TranslationKeys.studyGuideErrorAuth;
    } else if (failure is InsufficientTokensFailure) {
      errorKey = TranslationKeys.studyGuideErrorInsufficientTokens;
      isTokenError = true;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = context.tr(errorKey);
      _isInsufficientTokensError = isTokenError;
    });
  }

  /// Handle streaming failure with partial content
  void _handleStreamingFailure(StudyGenerationStreamingFailed state) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = state.failure.message;
      // Check for token-related errors by type or error code
      _isInsufficientTokensError = state.failure is InsufficientTokensFailure ||
          state.failure is TokenFailure ||
          state.failure.code == 'INSUFFICIENT_TOKENS' ||
          state.failure.code == 'TOKEN_LIMIT_EXCEEDED';
    });
  }

  /// Retry study guide generation
  Future<void> _retryGeneration() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _isInsufficientTokensError = false;
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
  /// Notes are saved independently of whether the study guide is saved
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
          // Auto-save notes independently (no longer requires guide to be saved)
          if (_currentStudyGuide != null) {
            if (kDebugMode) {
              print(
                  '💾 [AUTO_SAVE] Saving personal notes (${currentText.length} chars)');
            }
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
    // Early return if already started to prevent duplicate timers/listeners
    if (_isCompletionTrackingStarted) return;

    _startTimeTrackingTimer();
    _startScrollListener();

    // Mark as started
    _isCompletionTrackingStarted = true;

    if (kDebugMode) {
      final guideId = _currentStudyGuide?.id ?? 'streaming';
      print('📊 [COMPLETION] Started tracking for guide: $guideId');
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

  /// Setup scroll listener to detect when user reaches prayer points section
  void _startScrollListener() {
    _scrollController.addListener(() {
      if (!_completionMarked &&
          !_hasScrolledToBottom &&
          _isPrayerPointsSectionVisible()) {
        setState(() {
          _hasScrolledToBottom = true;
        });
        _checkCompletionConditions();
      }
    });
  }

  /// Check if the prayer points section is visible on screen
  bool _isPrayerPointsSectionVisible() {
    final keyContext = _prayerPointsKey.currentContext;
    if (keyContext == null) return false;

    final RenderObject? renderObject = keyContext.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return false;

    final RenderBox box = renderObject;
    final Offset position = box.localToGlobal(Offset.zero);
    final Size screenSize = MediaQuery.of(context).size;

    // Check if the top of the prayer points section is visible on screen
    // Consider visible when the section enters the bottom 80% of the screen
    return position.dy < screenSize.height * 0.8;
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

  /// Complete topic progress tracking when study guide is finished.
  ///
  /// This is called after StudyCompletionSuccess to track the user's
  /// progress on the topic. Only executes if we have a valid topicId.
  Future<void> _completeTopicProgress() async {
    final topicId = widget.topicId;
    if (topicId == null || topicId.isEmpty) {
      if (kDebugMode) {
        print(
            '📊 [TOPIC_PROGRESS] No topicId provided, skipping progress tracking');
      }
      return;
    }

    if (kDebugMode) {
      print('📊 [TOPIC_PROGRESS] Completing topic progress:');
      print('   Topic ID: $topicId');
      print('   Study Mode: ${widget.studyMode.name}');
      print('   Time spent: $_timeSpentSeconds seconds');
    }

    try {
      final repository = sl<TopicProgressRepository>();
      final result = await repository.completeTopic(
        topicId,
        timeSpentSeconds: _timeSpentSeconds,
        generationMode: widget.studyMode.name,
      );

      result.fold(
        (failure) {
          if (kDebugMode) {
            print(
                '❌ [TOPIC_PROGRESS] Failed to complete topic: ${failure.message}');
          }
        },
        (completionResult) {
          if (kDebugMode) {
            print('✅ [TOPIC_PROGRESS] Topic completed successfully:');
            print('   XP earned: ${completionResult.xpEarned}');
            print('   First completion: ${completionResult.isFirstCompletion}');
          }

          // Show XP earned feedback if this is the first completion
          if (completionResult.isFirstCompletion &&
              completionResult.xpEarned > 0 &&
              mounted) {
            _showXpEarnedFeedback(completionResult.xpEarned);
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TOPIC_PROGRESS] Exception during progress tracking: $e');
      }
    }
  }

  /// Show feedback when user earns XP for completing a topic.
  void _showXpEarnedFeedback(int xpEarned) {
    _showSnackBar(
      '+$xpEarned XP earned!',
      Colors.green,
      icon: Icons.star,
    );
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
          } else if (state is StudyGenerationStreaming) {
            // Handle streaming state - UI will rebuild with BlocBuilder
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = false;
            });

            // Start completion tracking as soon as we have the first section
            if (state.content.sectionsLoaded > 0 &&
                !_isCompletionTrackingStarted) {
              _startCompletionTracking();
            }
          } else if (state is StudyGenerationStreamingFailed) {
            _handleStreamingFailure(state);
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
              // Check saved achievements when guide is saved
              sl<GamificationBloc>().add(const CheckSavedAchievements());
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
            // Always setup auto-save when notes are loaded
            _setupAutoSave();
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

            // Track topic progress completion if we have a topic ID
            _completeTopicProgress();

            // Update study streak and check achievements
            sl<GamificationBloc>().add(const UpdateStudyStreak());
            sl<GamificationBloc>().add(const CheckStudyAchievements());

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

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        onPressed: _handleBackNavigation,
        icon: Icon(
          Icons.arrow_back_ios,
          color: accentColor,
        ),
        tooltip: 'Go back',
      ),
      title: Text(
        context.tr('study_guide.page_title'),
        style: AppFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
      centerTitle: true,
      actions: _currentStudyGuide != null
          ? [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: accentColor,
                ),
                tooltip: 'More options',
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareStudyGuide();
                      break;
                    case 'pdf':
                      _exportToPdf();
                      break;
                    case 'save':
                      _saveStudyGuide();
                      break;
                    case 'complete':
                      _markStudyGuideComplete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(
                          Icons.share_outlined,
                          size: 20,
                          color: accentColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Share',
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    enabled: !_isExportingPdf,
                    child: Row(
                      children: [
                        _isExportingPdf
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accentColor,
                                ),
                              )
                            : Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 20,
                                color: accentColor,
                              ),
                        const SizedBox(width: 12),
                        Text(
                          'Download PDF',
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          size: 20,
                          color: _isSaved ? Colors.green : accentColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isSaved ? 'Saved' : 'Save Study',
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _isSaved ? Colors.green : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'complete',
                    enabled: !_completionMarked,
                    child: Row(
                      children: [
                        Icon(
                          _completionMarked
                              ? Icons.check_circle
                              : Icons.check_circle_outlined,
                          size: 20,
                          color: _completionMarked ? Colors.green : accentColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _completionMarked ? 'Completed' : 'Complete Study',
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _completionMarked ? Colors.green : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : null,
    );
  }

  Widget _buildBody() {
    // Use BlocBuilder to handle streaming states
    return BlocBuilder<StudyBloc, StudyState>(
      buildWhen: (previous, current) =>
          current is StudyGenerationStreaming ||
          current is StudyGenerationStreamingFailed ||
          current is StudyGenerationInProgress ||
          current is StudyGenerationSuccess ||
          current is StudyGenerationFailure ||
          current is StudyInitial,
      builder: (context, state) {
        // Handle streaming state - show progressive content
        if (state is StudyGenerationStreaming) {
          // If streaming is complete and we have the full study guide,
          // show the complete content view (with Follow-up Chat and Notes)
          if (state.content.isComplete && _currentStudyGuide != null) {
            // Save scroll position during transition from streaming to complete
            if (!_isTransitioningFromStreaming &&
                _scrollController.hasClients) {
              _savedScrollPosition = _scrollController.offset;
              _isTransitioningFromStreaming = true;

              // Restore scroll position after build completes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_savedScrollPosition != null &&
                    _scrollController.hasClients) {
                  _scrollController.jumpTo(_savedScrollPosition!);
                  _savedScrollPosition = null;
                  _isTransitioningFromStreaming = false;
                }
              });
            }
            return _buildStudyGuideContent();
          }

          // Reset transition flag if we're back to streaming
          _isTransitioningFromStreaming = false;

          // Otherwise show progressive streaming content
          return StreamingStudyContent(
            content: state.content,
            inputType: state.inputType,
            inputValue: state.inputValue,
            language: state.language,
            scrollController: _scrollController,
            studyMode: widget.studyMode,
            onComplete:
                state.content.isComplete && state.content.studyGuideId != null
                    ? () => _handleStreamingComplete(state)
                    : null,
          );
        }

        // Handle streaming failure with partial content
        if (state is StudyGenerationStreamingFailed) {
          if (state.hasPartialContent) {
            // Show partial content with error banner
            return _buildPartialContentWithError(state);
          }
          // No partial content, show error screen
          return _buildErrorScreen();
        }

        // Regular loading state
        if (_isLoading || state is StudyGenerationInProgress) {
          return _buildLoadingScreen();
        }

        // Error state
        if (_hasError) {
          return _buildErrorScreen();
        }

        // Success state with complete study guide
        if (_currentStudyGuide == null) {
          return _buildErrorScreen();
        }

        return _buildStudyGuideContent();
      },
    );
  }

  /// Handle streaming completion - convert to full study guide
  void _handleStreamingComplete(StudyGenerationStreaming state) {
    if (state.content.studyGuideId == null) return;

    // Create a StudyGuide from streaming content
    final studyGuide = StudyGuide(
      id: state.content.studyGuideId!,
      input: state.inputValue,
      inputType: state.inputType,
      language: state.language,
      summary: state.content.summary ?? '',
      interpretation: state.content.interpretation ?? '',
      context: state.content.context ?? '',
      relatedVerses: state.content.relatedVerses ?? [],
      reflectionQuestions: state.content.reflectionQuestions ?? [],
      prayerPoints: state.content.prayerPoints ?? [],
      interpretationInsights: state.content.interpretationInsights,
      summaryInsights: state.content.summaryInsights,
      reflectionAnswers: state.content.reflectionAnswers,
      contextQuestion: state.content.contextQuestion,
      summaryQuestion: state.content.summaryQuestion,
      relatedVersesQuestion: state.content.relatedVersesQuestion,
      reflectionQuestion: state.content.reflectionQuestion,
      prayerQuestion: state.content.prayerQuestion,
      createdAt: DateTime.now(),
      isSaved: false,
    );

    _handleGenerationSuccess(studyGuide);
  }

  /// Build partial content with error banner
  Widget _buildPartialContentWithError(StudyGenerationStreamingFailed state) {
    return Column(
      children: [
        // Error banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Generation interrupted. Partial content shown below.',
                  style: AppFonts.inter(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (state.canRetry)
                TextButton(
                  onPressed: _retryGeneration,
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
        // Partial content
        Expanded(
          child: StreamingStudyContent(
            content: state.partialContent!,
            inputType: state.inputType,
            inputValue: state.inputValue,
            language: state.language,
            scrollController: _scrollController,
            studyMode: widget.studyMode,
            isPartial: true,
          ),
        ),
      ],
    );
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
                _isInsufficientTokensError
                    ? context.tr(TranslationKeys.studyGuideErrorTitleNoTokens)
                    : context.tr(TranslationKeys.studyGuideErrorTitle),
                style: AppFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _isInsufficientTokensError
                    ? context
                        .tr(TranslationKeys.studyGuideErrorInsufficientTokens)
                    : (_errorMessage.isEmpty
                        ? context
                            .tr(TranslationKeys.studyGuideErrorDefaultMessage)
                        : _errorMessage),
                style: AppFonts.inter(
                  fontSize: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  final accentColor = isDark
                      ? _lightenColor(theme.colorScheme.primary, 0.10)
                      : theme.colorScheme.primary;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _handleBackNavigation,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          context.tr(TranslationKeys.studyGuideErrorGoBack),
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(
                            color: accentColor,
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
                      // Show different button based on error type
                      if (_isInsufficientTokensError)
                        ElevatedButton.icon(
                          onPressed: () => context.push('/token-management'),
                          icon: const Icon(Icons.token),
                          label: Text(
                            context.tr(TranslationKeys.studyGuideErrorMyPlan),
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
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
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _retryGeneration,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            context.tr(TranslationKeys.studyGuideErrorTryAgain),
                            style: AppFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
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
                  );
                },
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
          child: _viewMode == StudyViewMode.read
              ? _buildReadModeContent(isLargeScreen)
              : _buildReflectModeContent(),
        ),

        // Bottom Action Buttons (only show in read mode)
        if (_viewMode == StudyViewMode.read) _buildBottomActions(),
      ],
    );
  }

  /// Builds the Read Mode content (traditional scrollable view)
  Widget _buildReadModeContent(bool isLargeScreen) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isLargeScreen ? 24 : 16),

          // Topic Title
          _buildTopicTitle(),

          SizedBox(height: isLargeScreen ? 24 : 20),

          // Study Guide Content
          _buildStudyContent(),

          SizedBox(height: isLargeScreen ? 32 : 24),

          // Reading Completion Card (dismissible)
          if (_showCompletionCard)
            ReadingCompletionCard(
              onReflect: () {
                setState(() => _viewMode = StudyViewMode.reflect);
              },
              onMaybeLater: () {
                // Simply dismiss the card
                setState(() {
                  _showCompletionCard = false;
                });
              },
            ),

          SizedBox(height: isLargeScreen ? 32 : 24),

          // Follow-up Chat Section
          Container(
            key: _followUpChatKey,
            child: BlocProvider(
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
          ),

          SizedBox(height: isLargeScreen ? 32 : 24),

          // Notes Section
          _buildNotesSection(),

          SizedBox(height: isLargeScreen ? 32 : 24),
        ],
      ),
    );
  }

  /// Builds the Reflect Mode content (interactive card-by-card view)
  Widget _buildReflectModeContent() {
    return ReflectModeView(
      studyGuide: _currentStudyGuide!,
      onSwitchToRead: () {
        setState(() => _viewMode = StudyViewMode.read);
      },
      onComplete: _handleReflectionComplete,
      onExit: () => _handleBackNavigation(),
      isCompletingReflection: _isCompletingReflection,
    );
  }

  /// Handles reflection completion - saves responses and shows success message
  void _handleReflectionComplete(
    List<ReflectionResponse> responses,
    int timeSpent,
  ) async {
    if (_currentStudyGuide == null) {
      _showSnackBar(
        'Cannot save reflection: Study guide not loaded',
        Colors.red,
        icon: Icons.error,
      );
      return;
    }

    setState(() {
      _isCompletingReflection = true;
    });

    try {
      final reflectionsRepository = sl<ReflectionsRepository>();
      await reflectionsRepository.saveReflection(
        studyGuideId: _currentStudyGuide!.id,
        studyMode: widget.studyMode,
        responses: responses,
        timeSpentSeconds: timeSpent,
      );

      if (kDebugMode) {
        print(
            '✅ [REFLECTION] Saved reflection for guide: ${_currentStudyGuide!.id}');
        print('   Responses: ${responses.length}');
        print('   Time spent: ${timeSpent}s');
        print('   Study mode: ${widget.studyMode.displayName}');
      }

      setState(() {
        _isCompletingReflection = false;
        _viewMode = StudyViewMode.read;
      });

      _showSnackBar(
        'Reflection saved! Time spent: ${timeSpent ~/ 60} minutes',
        Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REFLECTION] Error saving reflection: $e');
      }

      setState(() {
        _isCompletingReflection = false;
      });

      _showSnackBar(
        'Failed to save reflection. Please try again.',
        Colors.red,
        icon: Icons.error,
      );
    }
  }

  /// Builds the topic title section displayed below the AppBar
  Widget _buildTopicTitle() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentStudyGuide?.inputType == 'scripture'
                ? context.tr('generate_study.scripture_mode')
                : context.tr('generate_study.topic_mode'),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getDisplayTitle(),
            style: AppFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyContent() {
    // Route to mode-specific layout
    return switch (widget.studyMode) {
      StudyMode.quick => _buildQuickModeStudyContent(),
      StudyMode.deep => _buildDeepModeStudyContent(),
      StudyMode.lectio => _buildLectioDivinaStudyContent(),
      StudyMode.sermon =>
        _buildStandardModeStudyContent(), // Sermon uses standard 6-section layout
      StudyMode.standard => _buildStandardModeStudyContent(),
    };
  }

  /// Standard mode - full 6-section layout (default)
  Widget _buildStandardModeStudyContent() {
    final ttsService = sl<StudyGuideTTSService>();

    return ValueListenableBuilder<StudyGuideTtsState>(
      valueListenable: ttsService.state,
      builder: (context, ttsState, child) {
        // Check if TTS is actively reading (playing status)
        final isReading = ttsState.status == TtsStatus.playing;
        final currentSection = ttsState.currentSectionIndex;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Section (index 0)
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideSummary),
              icon: Icons.summarize,
              content: _currentStudyGuide!.summary,
              isBeingRead: isReading && currentSection == 0,
            ),

            const SizedBox(height: 24),

            // Interpretation Section (index 1)
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideInterpretation),
              icon: Icons.lightbulb_outline,
              content: _currentStudyGuide!.interpretation,
              isBeingRead: isReading && currentSection == 1,
            ),

            const SizedBox(height: 24),

            // Context Section (index 2)
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideContext),
              icon: Icons.history_edu,
              content: _currentStudyGuide!.context,
              isBeingRead: isReading && currentSection == 2,
            ),

            const SizedBox(height: 24),

            // Related Verses Section (index 3)
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideRelatedVerses),
              icon: Icons.menu_book,
              content: _currentStudyGuide!.relatedVerses.join('\n\n'),
              isBeingRead: isReading && currentSection == 3,
            ),

            const SizedBox(height: 24),

            // Discussion Questions Section (index 4)
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideDiscussionQuestions),
              icon: Icons.quiz,
              content: _currentStudyGuide!.reflectionQuestions
                  .asMap()
                  .entries
                  .map((entry) => '${entry.key + 1}. ${entry.value}')
                  .join('\n\n'),
              isBeingRead: isReading && currentSection == 4,
            ),

            const SizedBox(height: 24),

            // Prayer Points Section (index 5)
            _StudySection(
              key: _prayerPointsKey,
              title: context.tr(TranslationKeys.studyGuidePrayerPoints),
              icon: Icons.favorite,
              content: _currentStudyGuide!.prayerPoints
                  .asMap()
                  .entries
                  .map((entry) => '• ${entry.value}')
                  .join('\n'),
              isBeingRead: isReading && currentSection == 5,
            ),
          ],
        );
      },
    );
  }

  /// Quick mode - compact card layout for 3-minute reads
  Widget _buildQuickModeStudyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Read badge
        _buildQuickReadBadge(),

        const SizedBox(height: 16),

        // Key Insight (summary)
        _QuickStudySection(
          title: context.tr(TranslationKeys.studyGuideKeyInsight),
          content: _currentStudyGuide!.summary,
          isHighlight: true,
        ),

        const SizedBox(height: 16),

        // Key Verse (interpretation)
        _QuickStudySection(
          title: context.tr(TranslationKeys.studyGuideKeyVerse),
          content: _currentStudyGuide!.interpretation,
        ),

        const SizedBox(height: 16),

        // Quick Reflection
        if (_currentStudyGuide!.reflectionQuestions.isNotEmpty)
          _QuickStudySection(
            title: context.tr(TranslationKeys.studyGuideQuickReflection),
            content: _currentStudyGuide!.reflectionQuestions.first,
          ),

        const SizedBox(height: 16),

        // Brief Prayer
        if (_currentStudyGuide!.prayerPoints.isNotEmpty)
          _QuickStudySection(
            title: context.tr(TranslationKeys.studyGuideBriefPrayer),
            content: _currentStudyGuide!.prayerPoints.first,
          ),
      ],
    );
  }

  /// Quick Read badge
  Widget _buildQuickReadBadge() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Text(
            context.tr(TranslationKeys.studyModeQuickDuration),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Deep Dive mode - extended scholarly content
  Widget _buildDeepModeStudyContent() {
    final ttsService = sl<StudyGuideTTSService>();

    return ValueListenableBuilder<StudyGuideTtsState>(
      valueListenable: ttsService.state,
      builder: (context, ttsState, child) {
        final isReading = ttsState.status == TtsStatus.playing;
        final currentSection = ttsState.currentSectionIndex;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deep Dive badge
            _buildDeepDiveBadge(),

            const SizedBox(height: 20),

            // Comprehensive Overview
            _StudySection(
              title:
                  context.tr(TranslationKeys.studyGuideComprehensiveOverview),
              icon: Icons.summarize,
              content: _currentStudyGuide!.summary,
              isBeingRead: isReading && currentSection == 0,
            ),

            const SizedBox(height: 28),

            // In-Depth Interpretation
            _StudySection(
              title:
                  context.tr(TranslationKeys.studyGuideInDepthInterpretation),
              icon: Icons.lightbulb_outline,
              content: _currentStudyGuide!.interpretation,
              isBeingRead: isReading && currentSection == 1,
            ),

            const SizedBox(height: 28),

            // Historical Context
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideHistoricalContext),
              icon: Icons.history_edu,
              content: _currentStudyGuide!.context,
              isBeingRead: isReading && currentSection == 2,
            ),

            const SizedBox(height: 28),

            // Scripture Connections
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideScriptureConnections),
              icon: Icons.menu_book,
              content: _currentStudyGuide!.relatedVerses.join('\n\n'),
              isBeingRead: isReading && currentSection == 3,
            ),

            const SizedBox(height: 28),

            // Deep Reflection
            _StudySection(
              title: context.tr(TranslationKeys.studyGuideDeepReflection),
              icon: Icons.edit_note,
              content: _currentStudyGuide!.reflectionQuestions
                  .asMap()
                  .entries
                  .map((entry) => '${entry.key + 1}. ${entry.value}')
                  .join('\n\n'),
              isBeingRead: isReading && currentSection == 4,
            ),

            const SizedBox(height: 28),

            // Prayer for Application
            _StudySection(
              key: _prayerPointsKey,
              title: context.tr(TranslationKeys.studyGuidePrayerForApplication),
              icon: Icons.favorite,
              content: _currentStudyGuide!.prayerPoints
                  .asMap()
                  .entries
                  .map((entry) => '• ${entry.value}')
                  .join('\n'),
              isBeingRead: isReading && currentSection == 5,
            ),
          ],
        );
      },
    );
  }

  /// Deep Dive badge
  Widget _buildDeepDiveBadge() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Text(
            context.tr(TranslationKeys.studyModeDeepDuration),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Lectio Divina mode - meditative 4-movement layout
  Widget _buildLectioDivinaStudyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lectio Divina badge
        _buildLectioDivinaBadge(),

        const SizedBox(height: 20),

        // Scripture for Meditation
        _LectioStudySection(
          title: context.tr(TranslationKeys.lectioScriptureForMeditation),
          content: _currentStudyGuide!.summary,
          icon: Icons.menu_book,
        ),

        const SizedBox(height: 24),

        // Lectio & Meditatio
        _LectioStudySection(
          title: context.tr(TranslationKeys.lectioLectioMeditatio),
          subtitle: context.tr(TranslationKeys.lectioReadMeditate),
          content: _currentStudyGuide!.interpretation,
          icon: Icons.auto_stories,
        ),

        const SizedBox(height: 24),

        // About This Practice
        _LectioStudySection(
          title: context.tr(TranslationKeys.lectioAboutPracticeEmoji),
          content: _currentStudyGuide!.context,
          icon: Icons.info_outline,
        ),

        const SizedBox(height: 24),

        // Focus Words
        if (_currentStudyGuide!.relatedVerses.isNotEmpty)
          _LectioStudySection(
            title: context.tr(TranslationKeys.lectioFocusWordsEmoji),
            content: _currentStudyGuide!.relatedVerses.join('\n• '),
            icon: Icons.highlight,
          ),

        const SizedBox(height: 24),

        // Oratio & Contemplatio
        _LectioStudySection(
          title: context.tr(TranslationKeys.lectioOratioContemplatio),
          subtitle: context.tr(TranslationKeys.lectioPrayRest),
          content: _currentStudyGuide!.reflectionQuestions.join('\n\n'),
          icon: Icons.self_improvement,
        ),

        const SizedBox(height: 24),

        // Closing Blessing
        if (_currentStudyGuide!.prayerPoints.isNotEmpty)
          _LectioStudySection(
            title: context.tr(TranslationKeys.lectioClosingBlessingEmoji),
            content: _currentStudyGuide!.prayerPoints.join('\n\n'),
            icon: Icons.wb_sunny_outlined,
          ),
      ],
    );
  }

  /// Lectio Divina badge
  Widget _buildLectioDivinaBadge() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Text(
            context.tr(TranslationKeys.lectioDurationLabel),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note,
              color: accentColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              context.tr(TranslationKeys.studyGuidePersonalNotes),
              style: AppFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withOpacity(0.2),
            ),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 6,
            style: AppFonts.inter(
              fontSize: 16,
              color: theme.colorScheme.onBackground,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: context
                  .tr(TranslationKeys.studyGuidePersonalNotesPlaceholder),
              hintStyle: AppFonts.inter(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;
    final ttsService = sl<StudyGuideTTSService>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Listen Button (Left) - Reactive to TTS state
          Expanded(
            child: SizedBox(
              height: 56,
              child: ValueListenableBuilder<StudyGuideTtsState>(
                valueListenable: ttsService.state,
                builder: (context, ttsState, child) {
                  final isPlaying = ttsState.status == TtsStatus.playing;
                  final isPaused = ttsState.status == TtsStatus.paused;
                  final isLoading = ttsState.status == TtsStatus.loading;
                  final showControls = isPlaying || isPaused;

                  if (showControls) {
                    // Show split button with pause/resume + settings
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: accentColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Main play/pause button
                          Expanded(
                            child: InkWell(
                              onTap: () => ttsService.togglePlayPause(),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(10),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: accentColor,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPlaying ? 'Pause' : 'Resume',
                                      style: AppFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 32,
                            color: accentColor.withOpacity(0.3),
                          ),
                          // Settings button
                          InkWell(
                            onTap: () => showTtsControlSheet(context),
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              child: Icon(
                                Icons.tune,
                                color: accentColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Show regular Listen button
                    return OutlinedButton.icon(
                      onPressed: () {
                        if (_currentStudyGuide != null) {
                          // Load and start reading the study guide if not already playing
                          final status = ttsService.state.value.status;
                          if (status == TtsStatus.idle ||
                              status == TtsStatus.error) {
                            ttsService.startReading(_currentStudyGuide!,
                                mode: widget.studyMode);
                          }
                          // Open the control sheet
                          showTtsControlSheet(context);
                        }
                      },
                      icon: isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            )
                          : const Icon(
                              Icons.headphones_rounded,
                              size: 22,
                            ),
                      label: Text(
                        isLoading
                            ? context.tr(TranslationKeys.studyGuideLoading)
                            : context.tr(TranslationKeys.studyGuideListen),
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(
                          color: accentColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Ask AI Button (Right) - Scroll to Follow-up Chat section
          Expanded(
            child: SizedBox(
              height: 56,
              child: Container(
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
                    onTap: () {
                      // Expand chat first if collapsed
                      if (!_isChatExpanded) {
                        setState(() {
                          _isChatExpanded = true;
                        });
                      }

                      // Then scroll to Follow-up Chat section after a brief delay
                      // to allow the expand animation to start
                      Future.delayed(const Duration(milliseconds: 100), () {
                        final chatContext = _followUpChatKey.currentContext;
                        if (chatContext != null && mounted) {
                          Scrollable.ensureVisible(
                            chatContext,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            alignment: 0.1, // Position near top of viewport
                          );
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr(TranslationKeys.studyGuideAskAi),
                          style: AppFonts.inter(
                            fontSize: 16,
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
          ),
        ],
      ),
    );
  }

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
          Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final accentColor = isDark
                  ? _lightenColor(theme.colorScheme.primary, 0.10)
                  : theme.colorScheme.primary;

              return ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  sl<StudyNavigator>().navigateToLogin(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              );
            },
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

  /// Exports the current study guide as a PDF and opens the system share sheet.
  ///
  /// For English, uses native PDF text rendering.
  /// For Hindi/Malayalam, uses image-based rendering to ensure proper
  /// ligature and character display.
  Future<void> _exportToPdf() async {
    if (_currentStudyGuide == null) return;

    // Show loading dialog for Hindi/Malayalam (image-based rendering takes time)
    final isComplexScript =
        _currentStudyGuide!.language.toLowerCase() == 'hi' ||
            _currentStudyGuide!.language.toLowerCase() == 'ml';

    setState(() {
      _isExportingPdf = true;
    });

    if (isComplexScript && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Use a static icon instead of animated spinner
                // since the main thread will be busy with rendering
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Theme.of(ctx).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('study_guide.actions.generating_pdf'),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('study_guide.actions.pdf_wait_message'),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
        ),
      );

      // Wait for dialog to fully render before starting heavy work
      await Future.delayed(const Duration(milliseconds: 150));
    }

    try {
      final pdfService = StudyGuidePdfService();
      // Pass context for image-based rendering (needed for Hindi/Malayalam)
      await pdfService.sharePdf(_currentStudyGuide!, context: context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // Close loading dialog if it was shown
      if (isComplexScript && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  /// Shows a dialog explaining PDF export limitation for non-English languages.
  /// This method is kept for potential future use but currently all languages
  /// are supported via image-based rendering.
  void _showPdfLanguageNotSupportedDialog() {
    final languageName = _currentStudyGuide!.language.toLowerCase() == 'hi'
        ? 'Hindi'
        : 'Malayalam';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('PDF Export'),
          ],
        ),
        content: Text(
          'PDF export is currently available only for English study guides. '
          '$languageName text requires special rendering that isn\'t supported yet.\n\n'
          'Would you like to share as text instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _shareStudyGuide();
            },
            child: const Text('Share as Text'),
          ),
        ],
      ),
    );
  }
}

/// Study section widget for displaying content with consistent styling.
class _StudySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool isBeingRead;

  const _StudySection({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.isBeingRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isBeingRead
            ? accentColor.withOpacity(0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBeingRead
              ? accentColor.withOpacity(0.5)
              : accentColor.withOpacity(0.1),
          width: isBeingRead ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isBeingRead
                ? accentColor.withOpacity(0.15)
                : accentColor.withOpacity(0.05),
            blurRadius: isBeingRead ? 16 : 10,
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isBeingRead ? accentColor : accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isBeingRead
                    ? const _PulsingIcon(icon: Icons.volume_up, size: 20)
                    : Icon(
                        icon,
                        color: accentColor,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isBeingRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.graphic_eq,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reading',
                              style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Copy button
              IconButton(
                onPressed: () => _copyToClipboard(context, content),
                icon: Icon(
                  Icons.copy,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  size: 18,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                tooltip: 'Copy $title',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Section Content with markdown formatting AND clickable scripture
          MarkdownWithScripture(
            data: _cleanDuplicateTitle(content, title),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

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

/// Animated pulsing icon for TTS reading indicator.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: widget.size,
          ),
        );
      },
    );
  }
}

/// Compact section widget for Quick Read mode (completed content)
class _QuickStudySection extends StatelessWidget {
  final String title;
  final String content;
  final bool isHighlight;

  const _QuickStudySection({
    required this.title,
    required this.content,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;
    final highlightColor = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight
            ? highlightColor.withOpacity(0.15)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight
              ? highlightColor.withOpacity(0.4)
              : accentColor.withOpacity(0.1),
          width: isHighlight ? 1.5 : 1,
        ),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: highlightColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with copy button
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isHighlight
                        ? accentColor
                        : theme.colorScheme.onBackground.withOpacity(0.8),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(context),
                icon: Icon(
                  Icons.copy,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  size: 16,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Content
          MarkdownWithScripture(
            data: _cleanDuplicateTitle(content, title),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isHighlight ? FontWeight.w500 : FontWeight.w400,
                  color: Theme.of(context).colorScheme.onBackground,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(TranslationKeys.studyGuideCopiedToClipboard),
          style: AppFonts.inter(color: Colors.white),
        ),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Meditative section widget for Lectio Divina mode (completed content)
class _LectioStudySection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String content;
  final IconData icon;

  const _LectioStudySection({
    required this.title,
    this.subtitle,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    // Softer, more meditative colors
    final backgroundColor =
        isDark ? accentColor.withOpacity(0.08) : accentColor.withOpacity(0.04);
    final borderColor =
        isDark ? accentColor.withOpacity(0.2) : accentColor.withOpacity(0.15);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: accentColor.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(context),
                icon: Icon(
                  Icons.copy,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  size: 16,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider for meditative feel
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.0),
                  accentColor.withOpacity(0.2),
                  accentColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Content with meditative typography
          MarkdownWithScripture(
            data: _cleanDuplicateTitle(content, title),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onBackground,
                  height: 1.7, // Extra line height for meditative reading
                ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? _lightenColor(theme.colorScheme.primary, 0.10)
        : theme.colorScheme.primary;

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(TranslationKeys.studyGuideCopiedToClipboard),
          style: AppFonts.inter(color: Colors.white),
        ),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
