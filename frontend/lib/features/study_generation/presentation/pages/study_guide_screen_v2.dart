import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/daily_streak_activity.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/services/font_scale_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/navigation/route_observer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/clickable_scripture_text.dart';
import '../../../../shared/widgets/scripture_verse_sheet.dart';
import '../../../../shared/widgets/markdown_with_scripture.dart';
import '../../../../core/error/failures.dart';
import 'package:disciplefy_bible_study/core/error/account_required.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import '../../../../core/error/token_failures.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/datasources/study_local_data_source.dart';
import '../../../study_topics/domain/repositories/topic_progress_repository.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/widgets/locked_feature_wrapper.dart';
import '../../domain/entities/study_guide.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
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
import '../widgets/guide_share_prompts.dart';
import '../widgets/streaming_study_content.dart';
import '../widgets/study_guide_body.dart';
import '../widgets/guide_complete_sheet.dart';
import '../../../../shared/widgets/sign_in_required_dialog.dart';
import '../widgets/study_reading_tracker.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/lesson_discipler_gate.dart';
import '../../../study_topics/domain/entities/lesson_ref.dart';
import '../../../study_topics/presentation/pages/lesson_complete_page.dart';
import '../../../study_topics/presentation/widgets/lesson_mark_complete_bar.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/lesson_mode_switch.dart';
import '../../data/services/reading_progress_store.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/numbered_section_header.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/popup.dart';
import '../../../settings/presentation/widgets/settings_group.dart'
    show SettingsButton, SettingsButtonKind;
import '../widgets/tts_control_sheet.dart';
import '../../data/services/study_guide_tts_service.dart';
// Deferred: the pdf/printing packages load only when a PDF is exported (web).
import '../../data/services/study_guide_pdf_service.dart'
    deferred as pdf_export;
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/utils/achievement_popup_gate.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';
import '../../../gamification/presentation/bloc/gamification_state.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/repositories/reflections_repository.dart';
import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/utils/logger.dart';
import '../../../community/domain/entities/fellowship_entity.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../../community/presentation/screens/share_guide_sheet.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import '../../../../core/utils/share_links.dart';
import '../../../community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/lesson_completion_refresh.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/lesson_events.dart';

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
/// The interpretation's opening heading (if any) plus its first paragraph —
/// enough to give a reader the gist without the whole (often very long)
/// interpretation section, for the share-text preview.
String firstInterpretationParagraph(String interpretation) {
  final paragraphs = interpretation
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (paragraphs.isEmpty) return interpretation.trim();

  final first = paragraphs.first;
  // A heading-only first chunk (e.g. "**Creation Declares God's
  // Existence**") reads as an orphaned title without the paragraph under
  // it, so pull that paragraph in too when the split left it separate.
  final isHeadingOnly = first.startsWith('**') &&
      first.endsWith('**') &&
      !first.substring(2, first.length - 2).contains('**');
  if (isHeadingOnly && paragraphs.length > 1) {
    return '$first\n\n${paragraphs[1]}';
  }
  return first;
}

class StudyGuideScreenV2 extends StatelessWidget {
  /// Optional topic ID from database (used for tracking/future features)
  final String? topicId;

  /// Input text from query parameters (topic/verse/question)
  final String? input;

  /// Type of input: 'scripture', 'topic', or 'question'
  final String? type;

  /// Optional topic description for additional context (only for topics)
  final String? description;

  /// Optional learning path title for curriculum-aware generation.
  /// Only set when the study guide is generated from a learning path topic.
  final String? pathTitle;

  /// Optional learning path description for curriculum-aware generation.
  /// Only set when the study guide is generated from a learning path topic.
  final String? pathDescription;

  /// Optional disciple level from the learning path (seeker|believer|follower|disciple|leader).
  final String? pathDiscipleLevel;

  /// Optional language code for the study guide
  final String? language;

  /// Navigation source for proper back navigation
  final StudyNavigationSource navigationSource;

  /// Study mode (quick, standard, deep, lectio)
  final StudyMode studyMode;

  /// Existing guide data from saved/recent guides (skips generation if provided)
  final Map<String, dynamic>? existingGuideData;

  /// Set when opened as a lesson of a learning path.
  final LessonRef? lesson;

  /// Lesson 1 opened from the first run (`first_run=1`).
  final bool firstRun;

  const StudyGuideScreenV2({
    super.key,
    this.topicId,
    this.input,
    this.type,
    this.description,
    this.pathTitle,
    this.pathDescription,
    this.pathDiscipleLevel,
    this.language,
    this.navigationSource = StudyNavigationSource.home,
    this.studyMode = StudyMode.standard,
    this.existingGuideData,
    this.lesson,
    this.firstRun = false,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => sl<StudyBloc>(),
        child: _StudyGuideScreenV2Content(
          topicId: topicId,
          input: input,
          type: type,
          description: description,
          pathTitle: pathTitle,
          pathDescription: pathDescription,
          pathDiscipleLevel: pathDiscipleLevel,
          language: language,
          navigationSource: navigationSource,
          studyMode: studyMode,
          existingGuideData: existingGuideData,
          lesson: lesson,
          firstRun: firstRun,
        ),
      );
}

class _StudyGuideScreenV2Content extends StatefulWidget {
  final String? topicId;
  final String? input;
  final String? type;
  final String? description;
  final String? pathTitle;
  final String? pathDescription;
  final String? pathDiscipleLevel;
  final String? language;
  final StudyNavigationSource navigationSource;
  final StudyMode studyMode;
  final Map<String, dynamic>? existingGuideData;
  final LessonRef? lesson;
  final bool firstRun;

  const _StudyGuideScreenV2Content({
    this.topicId,
    this.input,
    this.type,
    this.description,
    this.pathTitle,
    this.pathDescription,
    this.pathDiscipleLevel,
    this.language,
    required this.navigationSource,
    required this.studyMode,
    this.existingGuideData,
    this.lesson,
    this.firstRun = false,
  });

  @override
  State<_StudyGuideScreenV2Content> createState() =>
      _StudyGuideScreenV2ContentState();
}

class _StudyGuideScreenV2ContentState extends State<_StudyGuideScreenV2Content>
    with RouteAware {
  /// Start and completion analytics of a path lesson; null for other guides.
  late final LessonEventTracker? _lessonEvents = widget.lesson == null
      ? null
      : LessonEventTracker(
          lesson: widget.lesson!,
          mode: widget.studyMode,
          firstRun: widget.firstRun,
        );

  final TextEditingController _notesController = TextEditingController();
  final FocusNode _notesFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Delayed completion-sheet timer (cancelled if user taps notes)
  Timer? _completionSheetTimer;

  // Walkthrough state
  WalkthroughScreen? _pendingMarkSeen;
  // Keys to show once read-mode content is rendered (set when keys not yet in tree)
  // Stores the builder context from ShowCaseWidget — required for ShowCaseWidget.of() calls.
  // State.context is an ancestor of ShowCaseWidget, so ShowCaseWidget.of(this.context) fails.
  // The builder context is a descendant and resolves correctly.
  BuildContext? _showcaseContext;

  StudyGuide? _currentStudyGuide;
  bool _isLoading = true;

  // Navigation and background generation tracking
  bool _isUserOnScreen = true;
  bool _isGenerationComplete = false;
  String? _pendingStudyId;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isInsufficientTokensError =
      false; // Track token error for special handling
  bool _isSaved = false;
  DateTime? _lastSaveAttempt;

  // Learning-path completion state
  bool _isTopicCompletedFromPath = false;

  // View mode state for Read/Reflect toggle

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

  // Follow-up chat state. Open by default: the redesigned guide shows the
  // conversation inline, and the header still collapses it.
  bool _isChatExpanded = true;
  final GlobalKey _followUpChatKey = GlobalKey();

  // Completion tracking state
  DateTime? _pageOpenedAt;
  int _timeSpentSeconds = 0;
  Timer? _timeTrackingTimer;
  // The guide counts as read once the end of the interpretation section has
  // been on screen; related verses, questions and prayer points are optional.
  final GlobalKey _interpretationKey = GlobalKey();
  bool _reachedInterpretation = false;
  bool _completionMarked = false;
  // Completion feedback (snackbars, achievement dialogs, notification prompt)
  // held back until the user reaches the bottom of the guide.
  final List<VoidCallback> _deferredCompletionFeedback = [];
  bool _achievementCheckDeferred = false;
  // Popups released at the bottom run one after another, never stacked:
  // achievement dialogs, then the notification prompt, then the completion
  // sheet. These complete when each earlier step has been dismissed.
  Future<void>? _achievementDialogsSettled;
  Future<void>? _completionPopupsDone;
  // Holds the in-flight topic-progress future so _handleBackNavigation can
  // await it before popping — prevents the race condition where the member
  // progress count in fellowship is still stale when the screen is dismissed.
  Future<void>? _topicProgressFuture;
  // True once Phase 2 walkthrough has been triggered. Prevents the completion
  // sheet from appearing after the walkthrough has already started.
  bool _phase2WalkthroughStarted = false;

  // Notification prompt state
  bool _hasTriggeredNotificationPrompt = false;
  bool _isCompletionTrackingStarted = false;

  // Reading completion card visibility

  // PDF export state
  bool _isExportingPdf = false;

  // Reflection completion state
  bool _isCompletingReflection = false;

  // Scroll position preservation during streaming-to-complete transition
  double? _savedScrollPosition;
  bool _isTransitioningFromStreaming = false;

  // Study guide content font size (persisted, overrides app-level setting)
  static const String _fontSizePrefsKey = 'study_guide_content_font_size';
  static const double _fontSizeMin = 14.0;
  static const double _fontSizeMax = 26.0;
  static const double _fontSizeStep = 2.0;
  double _contentFontSize = 18.0;

  // Fellowship data for optional "post to fellowship feed" toggle
  List<FellowshipEntity>? _userFellowships;

  // Screenshot detection
  StreamSubscription<dynamic>? _screenshotSubscription;

  // Reader chrome: segmented "sections read" header, and whether the page has
  // scrolled past the hero (the floating top bar then turns solid and shows
  // the title). Notifiers, so scrolling rebuilds only what they drive.
  final StudyReadingTracker _readingTracker = StudyReadingTracker();
  final ValueNotifier<bool> _topBarCollapsed = ValueNotifier<bool>(false);
  final ReadingProgressStore _readingProgressStore = ReadingProgressStore();
  int _lastSavedReadCount = 0;
  String? _readingProgressSeededFor;

  /// Scroll offset past which the hero is considered gone.
  static const double _heroCollapseOffset = 160;

  @override
  void initState() {
    super.initState();
    _pageOpenedAt = DateTime.now();
    _loadContentFontSize();
    _initializeStudyGuide();
    _loadUserFellowships();
    if (!kIsWeb) _setupScreenshotDetection();
    _triggerWalkthroughIfNeeded();
    _notesFocusNode.addListener(_onNotesFocusChanged);
    _scrollController.addListener(_onReaderScroll);
    _readingTracker.addListener(_persistReadingProgress);

    // Listen for TTS section completions to auto-mark the guide as completed
    // once the user has listened through the interpretation section.
    sl<StudyGuideTTSService>().state.addListener(_onTtsStateChanged);
  }

  /// Marks the study guide as completed when TTS finishes the interpretation
  /// section (or beyond).
  void _onTtsStateChanged() {
    final ttsState = sl<StudyGuideTTSService>().state.value;
    final completed = ttsState.lastCompletedSection;
    if (completed == null || _completionMarked) return;

    // These sections are at or past interpretation — trigger completion.
    const completionTriggers = {
      StudyGuideSection.interpretation,
      StudyGuideSection.relatedVerses,
      StudyGuideSection.discussionQuestions,
      StudyGuideSection.prayerPoints,
    };

    if (completionTriggers.contains(completed)) {
      Logger.debug(
          '🔊 [TTS→COMPLETION] Interpretation+ section completed via TTS — marking guide done');
      // Listening does not scroll, so the reading checks would reject it.
      _markStudyGuideComplete(isManual: true);
    }
  }

  void _onNotesFocusChanged() {
    if (_notesFocusNode.hasFocus) {
      // Typing in notes counts as user activity — reset inactivity countdown.
      _cancelInactivityCountdown();
    }
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      final seenHint = await repo.hasSeen(WalkthroughScreen.disciplerHint);
      // Only show disciplerHint after Phase 1 (menu+listen) has been seen,
      // so the walkthroughs don't compete on the first visit.
      final seenPhase1 = await repo.hasSeen(WalkthroughScreen.studyGuide);

      if (!seenHint && seenPhase1) {
        if (!mounted || _showcaseContext == null) return;
        // Wait for a full frame after the async gap to ensure Showcase widgets
        // are laid out before startShowCase accesses their RenderBox.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _showcaseContext == null) return;
          // Second+ visit: show Talk to Discipler cross-promo if button is in tree
          if (ShowcaseKeys.disciplerHintStudyGuide.currentContext != null) {
            _pendingMarkSeen = WalkthroughScreen.disciplerHint;
            ShowCaseWidget.of(_showcaseContext!)
                .startShowCase([ShowcaseKeys.disciplerHintStudyGuide]);
          }
          // If button absent (feature flag / plan restriction): skip silently
        });
      }
    });
  }

  /// Triggers the Phase 1 study guide walkthrough (menu + listen) the first
  /// time a guide loads for this user.
  Future<void> _triggerStudyGuideWalkthrough() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      final seen = await repo.hasSeen(WalkthroughScreen.studyGuide);
      if (seen || !mounted || _showcaseContext == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showcaseContext == null) return;
        if (ShowcaseKeys.studyGuideMenuButton.currentContext != null) {
          _pendingMarkSeen = WalkthroughScreen.studyGuide;
          ShowCaseWidget.of(_showcaseContext!).startShowCase([
            ShowcaseKeys.studyGuideMenuButton,
            ShowcaseKeys.studyGuideListen,
          ]);
        }
      });
    });
  }

  /// Triggers the Phase 2 study guide walkthrough (fellowship + chat + notes)
  /// the first time the user completes a study guide.
  Future<void> _triggerStudyGuideCompletionWalkthrough() async {
    // Mark as started synchronously so no new sheet timer can be created,
    // and cancel any timers that are already pending.
    _phase2WalkthroughStarted = true;
    _completionSheetTimer?.cancel();
    _completionSheetTimer = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      final seen = await repo.hasSeen(WalkthroughScreen.studyGuideCompletion);
      if (seen || !mounted || _showcaseContext == null) return;

      // Wait for any pending achievement popups to be dismissed before starting
      // the walkthrough — completing a study fires CheckStudyAchievements which
      // can trigger an achievement dialog that would overlap the tooltip.
      final gamificationBloc = sl<GamificationBloc>();
      if (gamificationBloc.state.hasPendingNotifications) {
        try {
          await gamificationBloc.stream
              .firstWhere((s) => !s.hasPendingNotifications)
              .timeout(const Duration(seconds: 30));
        } catch (_) {
          // Timeout — proceed anyway so the walkthrough is never blocked forever
        }
        if (!mounted || _showcaseContext == null) return;
        // Extra pause so the dialog dismiss animation fully completes
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted || _showcaseContext == null) return;
      }

      // Determine which keys are in the tree
      final keys = <GlobalKey>[];
      if (ShowcaseKeys.studyGuideFellowshipShare.currentContext != null) {
        keys.add(ShowcaseKeys.studyGuideFellowshipShare);
      }
      if (ShowcaseKeys.studyGuideFollowUpChat.currentContext != null) {
        keys.add(ShowcaseKeys.studyGuideFollowUpChat);
      }
      if (ShowcaseKeys.studyGuideNotes.currentContext != null) {
        keys.add(ShowcaseKeys.studyGuideNotes);
      }
      if (keys.isEmpty || !mounted) return;

      // Scroll so the first target sits at ~30% from the top of the screen.
      // We cannot use Scrollable.ensureVisible because it skips scrolling when
      // the widget is already visible — which is the common case here (the user
      // is already at the bottom).  Instead we compute the delta manually.
      final firstCtx = keys.first.currentContext;
      if (firstCtx != null && _scrollController.hasClients) {
        final renderObj = firstCtx.findRenderObject();
        if (renderObj is RenderBox) {
          final widgetScreenY = renderObj.localToGlobal(Offset.zero).dy;
          final screenHeight = MediaQuery.of(context).size.height;
          // Target: widget top at 30% from top (leaves room for tooltip above)
          final targetScreenY = screenHeight * 0.30;
          final delta = widgetScreenY - targetScreenY;
          final newOffset = (_scrollController.offset + delta)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
          await _scrollController.animateTo(
            newOffset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      }

      // One more frame after scroll settles, then start the showcase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showcaseContext == null) return;
        _pendingMarkSeen = WalkthroughScreen.studyGuideCompletion;
        ShowCaseWidget.of(_showcaseContext!).startShowCase(keys);
      });
    });
  }

  /// Loads the fellowships the current user belongs to so the
  /// [_FellowshipShareSection] can be shown.
  Future<void> _loadUserFellowships() async {
    // Content language, like every other getFellowships caller: the parameter
    // selects the translation of each fellowship's learning-path title, not
    // which fellowships come back (membership decides that).
    String language = 'en';
    try {
      final resolved =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      language = resolved.code;
    } catch (_) {
      // Keep the English default and still attempt the fetch.
    }

    final result = await sl<CommunityRepository>().getFellowships(language);
    if (!mounted) return;
    result.fold(
      // A failed lookup is not the same as belonging to no fellowship —
      // emptying the list here hides the share section entirely, so a
      // transient error looks like "you have no groups". Leave whatever we
      // already had instead.
      (_) => Logger.warning(
          '[STUDY_GUIDE] Could not load fellowships for the share section'),
      (fellowships) => setState(() => _userFellowships = fellowships),
    );
  }

  Future<void> _loadContentFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_fontSizePrefsKey);
    if (saved != null) {
      if (mounted) setState(() => _contentFontSize = saved);
    } else {
      // Default: base 18px scaled by the app-wide font scale setting
      final scale = sl<FontScaleService>().scaleFactor;
      final defaultSize = (18.0 * scale).clamp(_fontSizeMin, _fontSizeMax);
      if (mounted) setState(() => _contentFontSize = defaultSize);
    }
  }

  Future<void> _changeContentFontSize(double delta) async {
    final newSize =
        (_contentFontSize + delta).clamp(_fontSizeMin, _fontSizeMax);
    if (newSize == _contentFontSize) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizePrefsKey, newSize);
    if (mounted) setState(() => _contentFontSize = newSize);
  }

  void _showFontSizeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final palette = ReaderPalette.of(ctx);
          Future<void> step(double delta) async {
            await _changeContentFontSize(delta);
            setSheetState(() {});
          }

          Widget stepButton({
            required String semantics,
            required double glyphSize,
            required bool enabled,
            required VoidCallback onTap,
          }) {
            return Semantics(
              button: true,
              label: semantics,
              child: Material(
                color: Colors.transparent,
                shape: CircleBorder(
                  side: BorderSide(
                      color: enabled ? palette.outline : palette.hairline),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onTap : null,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: Text(
                        'A',
                        style: AppFonts.inter(
                          fontSize: glyphSize,
                          fontWeight: FontWeight.w600,
                          color: enabled ? palette.text : palette.dim,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: palette.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr(TranslationKeys.studyGuideTextSizeEyebrow),
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: palette.gold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(TranslationKeys.studyGuideMenuTextSize),
                      style: AppFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Live preview at the chosen size.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        context.tr(TranslationKeys.studyGuideTextSizePreview),
                        style: AppFonts.inter(
                          fontSize: _contentFontSize,
                          height: 1.55,
                          color: palette.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        stepButton(
                          semantics: 'Decrease font size',
                          glyphSize: 15,
                          enabled: _contentFontSize > _fontSizeMin,
                          onTap: () => step(-_fontSizeStep),
                        ),
                        SizedBox(
                          width: 88,
                          child: Text(
                            '${_contentFontSize.toInt()}',
                            textAlign: TextAlign.center,
                            style: AppFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                        ),
                        stepButton(
                          semantics: 'Increase font size',
                          glyphSize: 22,
                          enabled: _contentFontSize < _fontSizeMax,
                          onTap: () => step(_fontSizeStep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.ctaFill,
                          foregroundColor: palette.ctaInk,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          context.tr(TranslationKeys.studyGuideTextSizeDone),
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.ctaInk,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove(_fontSizePrefsKey);
                        final scale = sl<FontScaleService>().scaleFactor;
                        final defaultSize =
                            (18.0 * scale).clamp(_fontSizeMin, _fontSizeMax);
                        await step(defaultSize - _contentFontSize);
                      },
                      child: Text(
                        context.tr(TranslationKeys.studyGuideTextSizeReset),
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
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        appRouteObserver.subscribe(this, route);
      }
    });
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    appRouteObserver.unsubscribe(this);

    // Remove TTS state listener
    sl<StudyGuideTTSService>().state.removeListener(_onTtsStateChanged);

    // Stop TTS when navigating away
    sl<StudyGuideTTSService>().stop();

    _screenshotSubscription?.cancel();
    _autoSaveTimer?.cancel();
    _timeTrackingTimer?.cancel();
    _completionSheetTimer?.cancel();
    // Completed but left before reaching the bottom: still record the streak
    // and award achievements. Any dialog appears on the screen the user
    // returns to, not over the guide.
    if (_achievementCheckDeferred) {
      sl<GamificationBloc>().add(const UpdateStudyStreak());
      sl<GamificationBloc>().add(const CheckStudyAchievements());
    }
    // Pop-ups that waited while the guide was open show on the route the
    // user lands on (Lesson complete still holds them until it is shown).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AchievementPopupGate.flush());
    _isCompletionTrackingStarted = false;
    if (_autoSaveListener != null) {
      _notesController.removeListener(_autoSaveListener!);
    }
    _notesFocusNode.removeListener(_onNotesFocusChanged);
    _notesFocusNode.dispose();
    _notesController.dispose();
    _scrollController.removeListener(_onReaderScroll);
    _scrollController.dispose();
    _readingTracker.removeListener(_persistReadingProgress);
    _readingTracker.dispose();
    _topBarCollapsed.dispose();
    super.dispose();
  }

  // ============================================================================
  // ROUTE AWARENESS CALLBACKS
  // ============================================================================

  /// Called when user navigates to another screen (Study → Home)
  @override
  void didPushNext() {
    if (kDebugMode) {
      Logger.debug('🚪 [NAVIGATION] User navigated AWAY from study screen');
      Logger.debug('   Generation complete: $_isGenerationComplete');
      Logger.debug('   Pending study ID: $_pendingStudyId');
    }

    _isUserOnScreen = false;

    // DON'T cancel the stream - let it complete in background
    // The stream subscription will continue until completion

    if (!_isGenerationComplete && _pendingStudyId != null) {
      Logger.info('   ✅ Letting generation continue in background');
      // Schedule periodic checks for completion
      _scheduleCompletionCheck();
    }
  }

  /// Called when user comes back to this screen (Home → Study)
  @override
  void didPopNext() async {
    Logger.debug('👋 [NAVIGATION] User came BACK to study screen');

    _isUserOnScreen = true;

    // Check if generation completed while user was away
    if (_pendingStudyId != null && !_isGenerationComplete) {
      await _checkBackgroundGenerationStatus();
    }
  }

  /// Called when this screen is first opened
  @override
  void didPush() {
    Logger.debug('📱 [NAVIGATION] Study screen opened (fresh)');
    _isUserOnScreen = true;
  }

  /// Called when user explicitly closes this screen (back button)
  @override
  void didPop() {
    Logger.debug('🔙 [NAVIGATION] Study screen closed by user');
    _isUserOnScreen = false;
  }

  // ============================================================================
  // BACKGROUND GENERATION HELPERS
  // ============================================================================

  /// Schedule periodic checks for background generation completion
  void _scheduleCompletionCheck() {
    Future.delayed(const Duration(seconds: 10), () {
      if (!_isUserOnScreen && !_isGenerationComplete && mounted) {
        _checkBackgroundGenerationStatus();
        _scheduleCompletionCheck(); // Check again
      }
    });
  }

  /// Check if background generation completed
  Future<void> _checkBackgroundGenerationStatus() async {
    if (_pendingStudyId == null) return;

    try {
      // Check if study was saved to database
      final response = await Supabase.instance.client
          .from('study_guides')
          .select()
          .eq('id', _pendingStudyId!)
          .maybeSingle();

      if (response != null) {
        Logger.debug('✅ [NAVIGATION] Background generation completed!');

        _isGenerationComplete = true;

        // Load the completed study if user is back on screen
        if (_isUserOnScreen && mounted) {
          _loadExistingGuide(response);

          // Show snackbar notification
          if (mounted) {
            showAppSnackBar(
              context,
              context.tr(TranslationKeys.guideFeedbackCompletedWhileAway),
              tone: AppSnackTone.success,
            );
          }
        }
      } else {
        Logger.debug(
            '⏳ [NAVIGATION] Background generation still in progress...');
      }
    } catch (e) {
      Logger.debug('⚠️ [NAVIGATION] Error checking background status: $e');
    }
  }

  /// Initialize study guide generation from query parameters
  Future<void> _initializeStudyGuide() async {
    // If existing guide data is provided (from saved/recent guides), skip generation
    if (widget.existingGuideData != null) {
      _loadExistingGuide(widget.existingGuideData!);
      return;
    }

    // Note: widget.topicId is available for future features (tracking, analytics)
    // Currently, we use widget.input (topic_title) for study guide generation
    // since the API requires the actual topic text, not the database ID.

    if (kDebugMode && widget.topicId != null) {
      Logger.error(
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

    // Get study content language preference if not specified in URL
    // Uses study content language (not app UI language)
    String rawLanguageCode = widget.language ?? 'en';
    if (widget.language == null) {
      try {
        final languageService = sl<LanguagePreferenceService>();
        final appLanguage = await languageService.getStudyContentLanguage();
        rawLanguageCode = appLanguage.code;
      } catch (e) {
        Logger.warning(
            '⚠️ [STUDY_GUIDE_V2] Failed to get study content language preference: $e');
      }
    }

    // Normalize and validate language code
    final normalizedLanguageCode = _normalizeLanguageCode(rawLanguageCode);

    if (kDebugMode && rawLanguageCode != normalizedLanguageCode) {
      Logger.info(
          '🌐 [STUDY_GUIDE_V2] Language normalized: $rawLanguageCode → $normalizedLanguageCode');
    }

    // Guard against disposed widget after async operation
    if (!mounted) return;

    // Save selected language for loading screen localization
    setState(() {
      _selectedLanguage = normalizedLanguageCode;
    });

    // Check local cache before making any API call or token check
    final cached = await _findCachedStudyGuide(
      input: widget.input!,
      inputType: widget.type!,
      language: normalizedLanguageCode,
      studyMode: widget.studyMode.name,
    );
    if (cached != null && mounted) {
      // A cached guide with no passage was stored before the passage-reading
      // feature shipped. Treat it as stale so it is regenerated once and then
      // re-cached with the passage field populated.
      final lacksPassage = cached.passage == null || cached.passage!.isEmpty;
      final isPassageMode = cached.studyMode == StudyMode.standard.name ||
          cached.studyMode == StudyMode.deep.name ||
          cached.studyMode == null; // legacy entries without mode

      if (lacksPassage && isPassageMode) {
        // When offline, use the stale guide rather than failing to regenerate
        final isOffline = mounted &&
            context.read<ConnectivityBloc>().state is ConnectivityOffline;
        if (isOffline) {
          Logger.info(
              '📦 [STUDY_GUIDE_V2] Offline — using stale cache (no passage)');
          _startTopicProgress();
          _loadFromCachedStudyGuide(cached);
          return;
        }
        Logger.info(
            '♻️ [STUDY_GUIDE_V2] Stale cache (no passage) — regenerating');
      } else {
        Logger.info('📦 [STUDY_GUIDE_V2] Cache hit — skipping API call');
        _startTopicProgress();
        _loadFromCachedStudyGuide(cached);
        return;
      }
    }

    // Track topic progress start if we have a topic ID
    _startTopicProgress();

    // Generate a pending study ID BEFORE starting generation
    // This allows us to track background completion even if user navigates away
    _pendingStudyId = const Uuid().v4();

    Logger.info('🔄 [GENERATION] Starting with pending ID: $_pendingStudyId');

    // Dispatch streaming study guide generation event (V2 API)
    // This uses SSE for progressive section rendering
    context.read<StudyBloc>().add(GenerateStudyGuideStreamingRequested(
          input: widget.input!,
          inputType: widget.type!,
          topicDescription: widget.description,
          pathTitle: widget.pathTitle,
          pathDescription: widget.pathDescription,
          discipleLevel: widget.pathDiscipleLevel,
          language: normalizedLanguageCode,
          studyMode: widget.studyMode,
          pendingStudyId: _pendingStudyId,
          // TODO: Remove or update this when learning path token pricing is finalized.
          topicId: widget.topicId,
        ));
  }

  /// Load existing study guide from provided data (skips generation)
  void _loadExistingGuide(Map<String, dynamic> guideData) {
    try {
      // Extract data from the map
      final id = guideData['id'] as String;
      final inputType = guideData['type'] as String? ?? 'topic';
      final input = guideData['verse_reference'] ??
          guideData['topic_name'] ??
          guideData['title'] ??
          'Study Guide';
      final summary = guideData['summary'] as String?;
      final interpretation = guideData['interpretation'] as String?;
      final context = guideData['context'] as String?;
      final relatedVerses =
          (guideData['related_verses'] as List<dynamic>?)?.cast<String>();
      final reflectionQuestions =
          (guideData['reflection_questions'] as List<dynamic>?)?.cast<String>();
      final prayerPoints =
          (guideData['prayer_points'] as List<dynamic>?)?.cast<String>();
      final isSaved = guideData['is_saved'] as bool? ?? false;
      final personalNotes = guideData['personal_notes'] as String?;
      final passage = guideData['passage'] as String?;
      final language = widget.language ?? 'en';

      // Create StudyGuide entity
      final studyGuide = StudyGuide(
        id: id,
        input: input,
        inputType: inputType,
        language: language,
        summary: summary ?? '',
        interpretation: interpretation ?? '',
        context: context ?? '',
        relatedVerses: relatedVerses ?? [],
        reflectionQuestions: reflectionQuestions ?? [],
        prayerPoints: prayerPoints ?? [],
        personalNotes: personalNotes,
        isSaved: isSaved,
        passage: passage,
        createdAt: DateTime.now(),
      );

      Logger.info('✅ [STUDY_GUIDE_V2] Loaded existing guide: $input');

      setState(() {
        _currentStudyGuide = studyGuide;
        _isLoading = false;
        _isSaved = isSaved;
        if (personalNotes != null && personalNotes.isNotEmpty) {
          _notesController.text = personalNotes;
          _loadedNotes = personalNotes;
          _notesLoaded = true;
        }
      });

      // Like the other load paths: without this, guides opened from Saved,
      // Recent or a shared link could never complete by reading.
      _startCompletionTracking();
      // Header segments: resume from an earlier visit, then count what is
      // already on screen (previously only fresh generations did this, so
      // guides opened from Saved/Recent showed no segments filled).
      _seedReadingProgress(studyGuide.id);
    } catch (e) {
      Logger.error('❌ [STUDY_GUIDE_V2] Failed to load existing guide: $e');
      _showError('Failed to load study guide. Please try again.');
    }
  }

  /// Find a matching study guide in local Hive cache.
  ///
  /// Matches on input + inputType + language + studyMode so that different
  /// modes for the same topic each get their own cached guide.
  Future<StudyGuide?> _findCachedStudyGuide({
    required String input,
    required String inputType,
    required String language,
    required String studyMode,
  }) async {
    try {
      final cached = await sl<StudyLocalDataSource>().getCachedStudyGuides();
      final normalizedInput = input.trim().toLowerCase();
      // Filter by input+type+language first
      final matches = cached
          .where(
            (g) =>
                g.input.trim().toLowerCase() == normalizedInput &&
                g.inputType == inputType &&
                g.language == language,
          )
          .toList();

      if (matches.isEmpty) return null;

      // Prefer exact studyMode match; fall back to guides with no mode
      // (e.g. guides downloaded via the background download service which
      // uses the non-streaming V1 API and doesn't set studyMode).
      return matches.firstWhere(
        (g) => g.studyMode == studyMode,
        orElse: () => matches.firstWhere(
          (g) => g.studyMode == null,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Load a study guide from local cache and asynchronously fetch fresh notes.
  void _loadFromCachedStudyGuide(StudyGuide guide) {
    Logger.info('✅ [STUDY_GUIDE_V2] Loaded from local cache: ${guide.input}');

    setState(() {
      _currentStudyGuide = guide;
      _isLoading = false;
      _hasError = false;
      _isGenerationComplete = true;
      _isSaved = guide.isSaved ?? false;

      if (guide.personalNotes != null && guide.personalNotes!.isNotEmpty) {
        _notesController.text = guide.personalNotes!;
        _loadedNotes = guide.personalNotes;
        _notesLoaded = true;
      }
    });

    _setupAutoSave();
    _startCompletionTracking();
    _seedReadingProgress(guide.id);

    // Always fetch fresh notes from backend in case they've changed
    if (!_notesLoaded) {
      context
          .read<StudyBloc>()
          .add(LoadPersonalNotesRequested(guideId: guide.id));
    }
  }

  /// Start tracking topic progress when user opens a study guide from a topic.
  ///
  /// This is called at the beginning of study guide generation when a topicId
  /// is present (e.g., from recommended topics or notifications).
  Future<void> _startTopicProgress() async {
    _lessonEvents?.started();
    final topicId = widget.topicId;
    if (topicId == null || topicId.isEmpty) {
      return;
    }

    Logger.debug('📊 [TOPIC_PROGRESS] Starting topic progress for: $topicId');

    try {
      final repository = sl<TopicProgressRepository>();
      final result = await repository.startTopic(topicId);

      result.fold(
        (failure) {
          Logger.error(
              '❌ [TOPIC_PROGRESS] Failed to start topic: ${ErrorMessageSanitizer.sanitize(failure)}');
        },
        (_) {
          Logger.debug(
              '✅ [TOPIC_PROGRESS] Topic progress started successfully');
        },
      );
    } catch (e) {
      Logger.error('❌ [TOPIC_PROGRESS] Exception during start tracking: $e');
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

    // Mark generation as complete and clear pending study ID
    _isGenerationComplete = true;
    _pendingStudyId = null;

    Logger.info('✅ [GENERATION] Study generation completed successfully');

    // Attach study mode so the cache key includes it, preventing different
    // modes from returning each other's cached guide.
    final guideWithMode = studyGuide.copyWith(studyMode: widget.studyMode.name);

    setState(() {
      _currentStudyGuide = guideWithMode;
      _isLoading = false;
      _hasError = false;
      _errorMessage = '';

      // Check if guide is already saved
      if (guideWithMode.isSaved != null) {
        _isSaved = guideWithMode.isSaved!;
      }

      // Load personal notes if bundled with guide data
      if (guideWithMode.personalNotes != null) {
        _loadedNotes = guideWithMode.personalNotes;
        _notesController.text = guideWithMode.personalNotes!;
        _notesLoaded = true;
      }
    });

    // Always setup auto-save for personal notes (independent of save status)
    _setupAutoSave();

    // Start completion tracking
    _startCompletionTracking();

    // Header segments: resume from an earlier visit, then count what is
    // already on screen.
    _seedReadingProgress(guideWithMode.id);

    // Cache the generated guide for cache-first loading next time
    sl<StudyLocalDataSource>().cacheStudyGuide(guideWithMode);

    // Always load notes from backend — notes are saved independently of save status
    // Backend may return same guide ID on repeat generation (cache hit), so notes may exist
    if (!_notesLoaded) {
      context
          .read<StudyBloc>()
          .add(LoadPersonalNotesRequested(guideId: guideWithMode.id));
    }

    // Trigger Phase 1 walkthrough (first time only) now that guide is visible
    _triggerStudyGuideWalkthrough();
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
    if (isAccountRequired(state.failure)) {
      _offerAccount(state.failure);
      return;
    }
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = context.tr(TranslationKeys.commonErrorTryAgain);
      // Check for token-related errors by type or error code
      _isInsufficientTokensError = state.failure is InsufficientTokensFailure ||
          state.failure is TokenFailure ||
          state.failure.code == 'INSUFFICIENT_TOKENS' ||
          state.failure.code == 'TOKEN_LIMIT_EXCEEDED';
    });
  }

  /// A guest asked for a typed study or a paid mode (403 ACCOUNT_REQUIRED):
  /// offer an account, never "generation failed". With one, generate again;
  /// otherwise leave the page.
  Future<void> _offerAccount(Failure failure) async {
    final reason = (failure is AccountRequiredFailure
            ? AccountReason.fromWire(failure.reason)
            : null) ??
        AccountReason.generate;
    final linked = await AccountNeededSheet.show(context, reason);
    if (!mounted) return;
    if (linked) {
      await _retryGeneration();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
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

    Logger.info(
        '🔍 [STUDY_GUIDE_V2] Loading personal notes: isSaved=$_isSaved, notesLoaded=$_notesLoaded');

    if (_isSaved && !_notesLoaded) {
      Logger.debug(
          '📝 [STUDY_GUIDE_V2] Requesting personal notes for guide: ${_currentStudyGuide!.id}');
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
            Logger.info(
                '💾 [AUTO_SAVE] Saving personal notes (${currentText.length} chars)');
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
  // Reader chrome: top bar collapse + segmented reading progress
  // ============================================================================

  void _onReaderScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }
    final collapsed = _scrollController.offset > _heroCollapseOffset;
    if (_topBarCollapsed.value != collapsed) _topBarCollapsed.value = collapsed;
    _updateReadingProgress();
  }

  /// Line (as a fraction of the screen height) a section's top must scroll
  /// above to count as read. High enough that on open — hero on screen — no
  /// section below the first has reached it, whatever the section lengths.
  static const double _readThresholdFraction = 0.3;

  /// The first section is on screen as soon as the guide opens, so it counts
  /// as read; each further section counts once its top passes the upper
  /// third of the screen; at the very bottom every section does.
  ///
  /// The first-section floor keeps the header identical on every open (fresh
  /// generation, cache, Saved/Recent) instead of depending on how tall the
  /// first sections happen to be on this screen.
  void _updateReadingProgress() {
    if (!mounted) return;
    final height = MediaQuery.sizeOf(context).height;
    final hasScrollableContent = _scrollController.hasClients &&
        _scrollController.positions.length == 1 &&
        _scrollController.position.maxScrollExtent > 0;
    if (_readingTracker.total > 0) _readingTracker.seed(1);
    _readingTracker.update(
      thresholdY: height * _readThresholdFraction,
      atBottom: hasScrollableContent && _isScrolledToAbsoluteBottom(),
    );
  }

  Future<void> _seedReadingProgress(String guideId) async {
    if (_readingProgressSeededFor == guideId) return;
    _readingProgressSeededFor = guideId;
    final saved = await _readingProgressStore.get(guideId);
    if (!mounted) return;
    if (saved != null) {
      _lastSavedReadCount = saved.section;
      _readingTracker.seed(saved.section);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateReadingProgress();
    });
  }

  /// Remembers how far this guide has been read, for the library's Continue
  /// card. Only finished guides have an id to store it under.
  void _persistReadingProgress() {
    final guideId = _currentStudyGuide?.id;
    if (guideId == null || guideId.isEmpty) return;
    final total = _readingTracker.total;
    final read = _readingTracker.readCount;
    if (total <= 0 || read <= _lastSavedReadCount) return;
    _lastSavedReadCount = read;
    _readingProgressStore.save(guideId, read, total);
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
      Logger.debug('📊 [COMPLETION] Started tracking for guide: $guideId');
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

  /// Setup scroll listener to detect when user reaches bottom of content
  void _startScrollListener() {
    _scrollController.addListener(() {
      // Any scroll counts as user activity — reset the inactivity countdown.
      _onUserActivity();

      // Completion tracking: the guide counts as read once the end of the
      // interpretation section has been on screen.
      if (!_completionMarked &&
          !_reachedInterpretation &&
          _hasReachedInterpretationEnd()) {
        setState(() {
          _reachedInterpretation = true;
        });
        _checkCompletionConditions();
      }

      // Nothing pops up before the bottom: release held-back completion
      // feedback once the user gets there.
      if (_isScrolledToAbsoluteBottom()) {
        _releaseDeferredCompletionFeedback();
      }

      // Learning-path sheet: re-evaluate whether to start/cancel the inactivity
      // countdown whenever the scroll position changes.
      if (_completionMarked) {
        if (_isScrolledToAbsoluteBottom()) {
          _startInactivityCountdown();
        } else {
          // User scrolled away from bottom — cancel the pending countdown.
          _cancelInactivityCountdown();
        }
      }
    });
  }

  // ============================================================================
  // Inactivity-based completion sheet trigger
  // ============================================================================
  //
  // The completion sheet is shown only when:
  //   1. The guide is fully completed (_completionMarked == true).
  //   2. The user is at the absolute bottom of the page (97%+).
  //   3. The user has been inactive (no scroll, no tap) for [_inactivitySeconds].
  //
  // Any scroll or tap cancels the countdown and resets it from zero.

  static const int _inactivitySeconds = 3;

  /// Called whenever the user interacts (scroll or tap).
  /// Cancels any running inactivity countdown.  A new countdown is started by
  /// the scroll listener once the user settles at the bottom again.
  void _onUserActivity() {
    _cancelInactivityCountdown();
  }

  /// Starts (or ignores if already running) the inactivity countdown that will
  /// show the completion sheet after [_inactivitySeconds] of silence at the
  /// absolute bottom.
  void _startInactivityCountdown() {
    // Path lessons end with "Mark complete", not a timed sheet.
    if (widget.lesson != null) return;
    if (_isTopicCompletedFromPath) return;
    if (_phase2WalkthroughStarted) return;
    if (!_completionMarked) return;
    // Don't stack timers — one countdown at a time.
    if (_completionSheetTimer?.isActive ?? false) return;

    _completionSheetTimer =
        Timer(const Duration(seconds: _inactivitySeconds), () async {
      // Double-check all conditions at fire time (user may have scrolled away).
      if (!mounted) return;
      if (_isTopicCompletedFromPath || _phase2WalkthroughStarted) return;
      if (!_completionMarked) return;
      if (!_isScrolledToAbsoluteBottom()) return;

      // Wait for any pending achievement popups to be dismissed before showing
      // the sheet — completing a study fires CheckStudyAchievements which can
      // trigger an achievement dialog that would overlap the bottom sheet.
      final gamificationBloc = sl<GamificationBloc>();

      // Popups released on reaching the bottom (achievement dialog, then the
      // notification prompt) go first; the sheet waits until they are closed.
      final popupsDone = _completionPopupsDone;
      if (popupsDone != null) {
        await popupsDone;
        if (!mounted ||
            _isTopicCompletedFromPath ||
            _phase2WalkthroughStarted ||
            !_isScrolledToAbsoluteBottom()) {
          return;
        }
      }
      if (gamificationBloc.state.hasPendingNotifications) {
        // No timeout: an achievement dialog stays up until the user dismisses
        // it, and a timeout here opened the sheet on top of it. The checks
        // below still stop the sheet if the user has left or scrolled away.
        await gamificationBloc.stream
            .firstWhere((s) => !s.hasPendingNotifications);
        if (!mounted ||
            _isTopicCompletedFromPath ||
            _phase2WalkthroughStarted) {
          return;
        }
        // Extra pause so the dialog dismiss animation fully completes.
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted ||
            _isTopicCompletedFromPath ||
            _phase2WalkthroughStarted) {
          return;
        }
      }

      // Final position check after all the async waits above.
      if (!_isScrolledToAbsoluteBottom()) return;

      _showLearningPathCompletionSheet(
        onDismissed: _triggerStudyGuideCompletionWalkthrough,
      );
    });
  }

  /// Cancels the inactivity countdown without showing the sheet.
  void _cancelInactivityCountdown() {
    _completionSheetTimer?.cancel();
    _completionSheetTimer = null;
  }

  /// Whether the end of the interpretation section has been scrolled into view.
  ///
  /// Asks the viewport for the scroll offset at which the section's bottom
  /// edge meets the bottom of the screen; once the scroll position is past
  /// it, the whole interpretation has been on screen.
  bool _hasReachedInterpretationEnd() {
    if (!_scrollController.hasClients) return false;
    final box = _interpretationKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return false;
    final bottomAtScreenBottom = viewport.getOffsetToReveal(box, 1.0).offset;
    return _scrollController.position.pixels >= bottomAtScreenBottom - 1;
  }

  /// Runs [show] now if the user is at the bottom of the guide, otherwise
  /// holds it until they get there, so no completion popup interrupts reading.
  void _whenAtBottom(VoidCallback show) {
    if (!mounted) return;
    if (_isScrolledToAbsoluteBottom()) {
      show();
    } else {
      _deferredCompletionFeedback.add(show);
    }
  }

  void _releaseDeferredCompletionFeedback() {
    if (_deferredCompletionFeedback.isEmpty || !mounted) return;
    final pending = List<VoidCallback>.of(_deferredCompletionFeedback);
    _deferredCompletionFeedback.clear();
    for (final show in pending) {
      show();
    }
  }

  /// Completes once any achievement dialog from the check just dispatched has
  /// been dismissed, or after a short wait if the check unlocks nothing.
  Future<void> _settleAchievementDialogs() async {
    final gamificationBloc = sl<GamificationBloc>();
    if (!gamificationBloc.state.hasPendingNotifications) {
      try {
        await gamificationBloc.stream
            .firstWhere((s) => s.hasPendingNotifications)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        return; // Nothing unlocked.
      }
    }
    // A dialog stays up until the user dismisses it, so no timeout here.
    await gamificationBloc.stream.firstWhere((s) => !s.hasPendingNotifications);
  }

  /// Check if user has scrolled to the absolute bottom of the content.
  /// Returns true when scroll position is at 97% or more of max scroll extent.
  bool _isScrolledToAbsoluteBottom() {
    if (!_scrollController.hasClients) return false;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll <= 0) return true;

    return (currentScroll / maxScroll) >= 0.97;
  }

  /// Checks if Talk to Discipler feature is enabled based on feature flags and user's plan
  bool _isAiDisciplerFeatureEnabled() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    final userPlan = tokenState.knownPlanName ?? 'free';

    final systemConfigService = sl<SystemConfigService>();
    return systemConfigService.isFeatureEnabled('ai_discipler', userPlan);
  }

  /// Checks if Voice Buddy (Listen/TTS) feature is enabled based on feature flags and user's plan
  bool _isVoiceBuddyFeatureEnabled() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    final userPlan = tokenState.knownPlanName ?? 'free';

    final systemConfigService = sl<SystemConfigService>();
    return systemConfigService.isFeatureEnabled('voice_buddy', userPlan);
  }

  /// Checks if Study Chat (text follow-up) feature is enabled based on feature flags and user's plan
  bool _isStudyChatFeatureEnabled() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    final userPlan = tokenState.knownPlanName ?? 'free';

    final systemConfigService = sl<SystemConfigService>();
    return systemConfigService.isFeatureEnabled('study_chat', userPlan);
  }

  /// Whether the Discipler follow-up panel is in the page. Never for a
  /// guest: it needs an account, so no conversation-history call is made.
  bool _showFollowUpChat() => lessonShowsFollowUpChat(
        planShowsChat: _shouldShowStudyChat(),
        isGuest: GuestRouteGate.currentUserIsGuest(),
      );

  /// Checks if Study Chat feature should be visible (not hidden)
  bool _shouldShowStudyChat() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    final userPlan = tokenState.knownPlanName ?? 'free';

    final systemConfigService = sl<SystemConfigService>();
    return !systemConfigService.shouldHideFeature('study_chat', userPlan);
  }

  /// Check if both completion conditions are met and mark complete if so
  void _checkCompletionConditions() {
    if (_completionMarked || _currentStudyGuide == null) return;

    final minTimeSeconds = widget.studyMode.minCompletionSeconds;
    final timeConditionMet = _timeSpentSeconds >= minTimeSeconds;

    // Also checked on every timer tick: a short guide can show the end of the
    // interpretation without any scrolling.
    if (!_reachedInterpretation && _hasReachedInterpretationEnd()) {
      _reachedInterpretation = true;
    }
    final scrollConditionMet = _reachedInterpretation;

    if (kDebugMode) {
      Logger.debug('📊 [COMPLETION] Conditions check:');
      Logger.debug(
          '   Time: $_timeSpentSeconds/${minTimeSeconds}s (${timeConditionMet ? "✓" : "✗"})');
      Logger.debug('   Scroll: ${scrollConditionMet ? "✓" : "✗"}');
    }

    if (timeConditionMet && scrollConditionMet) {
      _markStudyGuideComplete();
    }
  }

  /// Call the API to mark the study guide as completed.
  ///
  /// [isManual] bypasses the server's time and reading checks. Use it for
  /// completions that are not about reading progress: tapping "Complete Study",
  /// listening through the interpretation, or downloading the PDF.
  /// Auto-completion from reading uses the default false.
  void _markStudyGuideComplete({bool isManual = false}) {
    if (_completionMarked || _currentStudyGuide == null) return;

    setState(() {
      _completionMarked = true;
    });
    _readingTracker.markComplete();

    // If the user is already sitting at the absolute bottom when completion
    // triggers, begin the inactivity countdown immediately so the sheet appears
    // after the user has been idle for a moment (without waiting for a scroll).
    if (_isScrolledToAbsoluteBottom()) {
      _startInactivityCountdown();
    }

    if (kDebugMode) {
      Logger.info('✅ [COMPLETION] Marking guide as complete:');
      Logger.debug('   Guide ID: ${_currentStudyGuide!.id}');
      Logger.debug('   Time spent: $_timeSpentSeconds seconds');
      Logger.debug('   Reached interpretation: $_reachedInterpretation');
      Logger.debug('   Manual: $isManual');
    }

    // Dispatch BLoC event to mark completion
    context.read<StudyBloc>().add(MarkStudyGuideCompleteRequested(
          guideId: _currentStudyGuide!.id,
          timeSpentSeconds: _timeSpentSeconds,
          // The API field predates the interpretation rule; it now means the
          // user reached the point where the guide counts as read.
          scrolledToBottom: _reachedInterpretation,
          isManual: isManual,
        ));

    // Cancel the tracking timer since completion is marked
    _timeTrackingTimer?.cancel();

    // The completion sheet (and the walkthrough after it) only appears once
    // the user reaches the absolute bottom — never mid-read.
  }

  /// "Mark complete" on a path lesson: record completion, then open the
  /// Lesson complete page in place of this guide.
  Future<void> _completeLessonNow() async {
    final lesson = widget.lesson;
    if (lesson == null) return;
    _markStudyGuideComplete(isManual: true);
    await (_topicProgressFuture ??= _completeTopicProgress());
    if (!mounted) return;
    context.pushReplacement(
      AppRoutes.lessonComplete,
      extra: LessonCompleteArgs(
        lesson: lesson,
        lessonTitle: _getDisplayTitle(),
        mode: widget.studyMode,
        language: widget.language ?? _currentStudyGuide?.language ?? 'en',
        firstRun: widget.firstRun,
      ),
    );
  }

  /// Share and follow-up buttons under "Mark complete".
  Widget? _buildLessonSecondaryActions(BuildContext context) {
    final guide = _currentStudyGuide;
    final palette = ReaderPalette.of(context);
    final canShare = guide != null && _userFellowships?.isNotEmpty == true;
    final canChat = _shouldShowStudyChat();
    if (!canShare && !canChat) return null;
    ButtonStyle style() => OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.outline),
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canShare)
          OutlinedButton.icon(
            style: style(),
            icon: const Icon(Icons.people_outline_rounded, size: 14),
            label: Text(context.tr(TranslationKeys.popupShareFellowship)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ShareGuideSheet(
                studyGuideId: guide.id,
                guideTitle: _getDisplayTitle(),
                guideInputType: guide.inputType,
                guideLanguage: guide.language,
                guideStudyMode: guide.studyMode ?? widget.studyMode.name,
                guideSummary: guide.summary,
                fellowships: _userFellowships!,
              ),
            ),
          ),
        if (canChat)
          OutlinedButton.icon(
            style: style(),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
            label: Text(context.tr(TranslationKeys.popupAskDiscipler)),
            onPressed: _openDisciplerChat,
          ),
      ],
    );
  }

  /// Complete topic progress tracking when study guide is finished.
  ///
  /// This is called after StudyCompletionSuccess to track the user's
  /// progress on the topic. Only executes if we have a valid topicId.
  Future<void> _completeTopicProgress() async {
    final topicId = widget.topicId;
    if (topicId == null || topicId.isEmpty) {
      Logger.debug(
          '📊 [TOPIC_PROGRESS] No topicId provided, skipping progress tracking');
      return;
    }

    if (kDebugMode) {
      Logger.debug('📊 [TOPIC_PROGRESS] Completing topic progress:');
      Logger.debug('   Topic ID: $topicId');
      Logger.debug('   Study Mode: ${widget.studyMode.name}');
      Logger.debug('   Time spent: $_timeSpentSeconds seconds');
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
          Logger.error(
              '❌ [TOPIC_PROGRESS] Failed to complete topic: ${ErrorMessageSanitizer.sanitize(failure)}');
        },
        (completionResult) {
          // Path progress and XP totals changed: drop the cached path
          // progress (a path just advanced still read "0/4 Topics") and
          // reload the gamification stats so XP agrees everywhere.
          // GamificationBloc is a GetIt singleton, not provided on every
          // route, so it is reached through sl rather than context.read.
          refreshAfterLessonCompletion(
            learningPaths: sl<LearningPathsRepository>(),
            gamification: sl<GamificationBloc>(),
          );

          // A finished lesson counts toward the daily streak, like reading
          // the verse of the day (once per day either way).
          if (mounted) unawaited(countLessonTowardStreak(context));
          _lessonEvents?.completed();

          if (kDebugMode) {
            Logger.debug('✅ [TOPIC_PROGRESS] Topic completed successfully:');
            Logger.debug('   XP earned: ${completionResult.xpEarned}');
            Logger.debug(
                '   First completion: ${completionResult.isFirstCompletion}');
          }

          // XP is not announced here (it lives in My progress and the
          // Leaderboard); only a fellowship moving on is.
          if (completionResult.fellowshipAdvanced) {
            _whenAtBottom(() {
              if (!mounted) return;
              showAppSnackBar(
                context,
                context.tr(completionResult.studyCompleted
                    ? TranslationKeys.guideFeedbackFellowshipPathComplete
                    : TranslationKeys.guideFeedbackFellowshipNextGuide),
                tone: AppSnackTone.success,
              );
            });
          }
        },
      );
    } catch (e) {
      Logger.error('❌ [TOPIC_PROGRESS] Exception during progress tracking: $e');
    }
  }

  // _maybeShowLearningPathSheet() has been replaced by _startInactivityCountdown()
  // and _cancelInactivityCountdown() above.  The new approach verifies both the
  // "at bottom" and "inactive for N seconds" conditions together.

  /// Shows a bottom sheet prompting the user after the guide is completed and
  /// the user has scrolled to the very bottom.
  ///
  /// [onDismissed] is called after the sheet closes so callers can chain
  /// follow-up actions (e.g. Phase 2 walkthrough) without visual overlap.
  void _showLearningPathCompletionSheet({VoidCallback? onDismissed}) {
    if (!mounted) return;
    if (widget.lesson != null) return;
    // Guard: only show once
    if (_isTopicCompletedFromPath) return;
    setState(() => _isTopicCompletedFromPath = true);

    final isFromLearningPath =
        widget.navigationSource == StudyNavigationSource.learningPath;
    final hasFellowship =
        _userFellowships != null && _userFellowships!.isNotEmpty;
    final hasGuide = _currentStudyGuide != null;
    final hasDiscipler =
        _isAiDisciplerFeatureEnabled() && _shouldShowStudyChat();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Build the list of next-step rows dynamically.
        final actions = <GuideCompleteAction>[
          GuideCompleteAction(
            icon: Icons.edit_note_rounded,
            label: context.tr(TranslationKeys.popupAddNotes),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _scrollToNotesAndFocus();
            },
          ),
          if (hasFellowship && hasGuide)
            GuideCompleteAction(
              icon: Icons.people_outline_rounded,
              label: context.tr(TranslationKeys.popupShareFellowship),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ShareGuideSheet(
                    studyGuideId: _currentStudyGuide!.id,
                    guideTitle: _getDisplayTitle(),
                    guideInputType: _currentStudyGuide!.inputType,
                    guideLanguage: _currentStudyGuide!.language,
                    guideStudyMode:
                        _currentStudyGuide!.studyMode ?? widget.studyMode.name,
                    guideSummary: _currentStudyGuide!.summary,
                    fellowships: _userFellowships!,
                  ),
                );
              },
            ),
          if (hasDiscipler)
            GuideCompleteAction(
              icon: Icons.psychology_rounded,
              // The Discipler glyph on the soft gold circle: white on
              // dark, ink on light — no gold disc.
              leading: DisciplerGlyph(
                size: 20,
                variant: isDark
                    ? DisciplerGlyphVariant.white
                    : DisciplerGlyphVariant.ink,
              ),
              label: context.tr(TranslationKeys.popupAskDiscipler),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDisciplerChat();
              },
            ),
        ];

        return GuideCompleteSheet(
          guideTitle: _getDisplayTitle(),
          isFromLearningPath: isFromLearningPath,
          actions: actions,
          onPrimary: () {
            Navigator.of(sheetContext).pop();
            _handleBackNavigation();
          },
          onNotNow: () => Navigator.of(sheetContext).pop(),
        );
      },
    ).then((_) => onDismissed?.call());
  }

  /// Scrolls to the personal notes section and focuses the text field.
  void _scrollToNotesAndFocus() {
    // The notes field is near the bottom of the page. Animate to the end and
    // then request focus so the keyboard opens and positions the view correctly.
    if (_scrollController.hasClients) {
      _scrollController
          .animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      )
          .then((_) {
        if (mounted) _notesFocusNode.requestFocus();
      });
    } else {
      _notesFocusNode.requestFocus();
    }
  }

  /// Scrolls to the Talk to Discipler / follow-up chat section and opens it.
  /// A guest gets the account-needed sheet instead.
  Future<void> _openDisciplerChat() async {
    if (!await _disciplerAllowed()) return;
    if (!mounted) return;
    setState(() => _isChatExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // Scroll the chat section into view by scrolling to bottom.
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () {
        if (_pendingMarkSeen != null) {
          sl<WalkthroughRepository>().markSeen(_pendingMarkSeen!);
          _pendingMarkSeen = null;
        }
      },
      builder: (showcaseContext) {
        _showcaseContext = showcaseContext; // capture for use in trigger
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
                // Start deferred walkthrough once read-mode content is visible
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
                _showSnackBar(state.message, AppSnackTone.success);
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
                // Update Hive cache with loaded notes
                if (_currentStudyGuide != null && state.notes != null) {
                  sl<StudyLocalDataSource>().cacheStudyGuide(
                    _currentStudyGuide!.copyWith(personalNotes: state.notes),
                  );
                }
              } else if (state is StudyPersonalNotesSuccess) {
                _showSnackBar(
                  state.isAutoSave
                      ? context.tr(TranslationKeys.guideFeedbackNotesSaved)
                      : (state.message ??
                          context.tr(TranslationKeys.guideFeedbackNotesSaved)),
                  AppSnackTone.success,
                );
                if (!mounted) return;
                setState(() {
                  _loadedNotes = state.savedNotes;
                });
                // Update Hive cache with saved notes
                if (_currentStudyGuide != null) {
                  sl<StudyLocalDataSource>().cacheStudyGuide(
                    _currentStudyGuide!
                        .copyWith(personalNotes: state.savedNotes),
                  );
                }
              } else if (state is StudyPersonalNotesFailure) {
                if (!state.isAutoSave) {
                  _showSnackBar(
                    context.tr(TranslationKeys.commonErrorTryAgain),
                    AppSnackTone.error,
                  );
                }
              }
              // Handle study completion - show notification prompt and invalidate cache
              else if (state is StudyCompletionSuccess) {
                // Invalidate the "For You" cache so completed topics don't show again
                sl<RecommendedGuidesService>().clearForYouCache();

                // Track topic progress completion (XP, first-completion badge, etc.)
                // Store the future so _handleBackNavigation can await it.
                _topicProgressFuture ??= _completeTopicProgress();

                // Anything that pops up waits until the user has reached the
                // bottom of the guide. That includes the streak update: it
                // checks achievements itself, and its dialog showed mid-read.
                _achievementCheckDeferred = true;
                _whenAtBottom(() {
                  _achievementCheckDeferred = false;
                  // Start listening before dispatching so the dialog that the
                  // check produces cannot be missed.
                  _achievementDialogsSettled = _settleAchievementDialogs();
                  sl<GamificationBloc>().add(const UpdateStudyStreak());
                  sl<GamificationBloc>().add(const CheckStudyAchievements());
                  _completionPopupsDone =
                      _showRecommendedTopicNotificationPrompt();
                });
              }
            },
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              // No AppBar sets the status bar any more: the page runs under
              // it, over the hero photo.
              value: Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: _buildBody(),
              ),
            ),
          ),
        ); // end PopScope
      }, // end ShowCaseWidget builder
    ); // end ShowCaseWidget
  }

  /// Floating top bar: back, title and the more-options menu.
  ///
  /// [overPhoto]: drawn over the hero, transparent with the title hidden until
  /// the page scrolls past the photo; otherwise solid with the title shown.
  Widget _buildTopBar({required bool overPhoto}) {
    final palette = ReaderPalette.of(context);
    final foreground = palette.isDark ? Colors.white : palette.text;
    final title = (_currentStudyGuide != null || overPhoto)
        ? _getDisplayTitle()
        : context.tr('study_guide.page_title');

    Widget bar(bool solid) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: solid ? palette.page : palette.page.withValues(alpha: 0),
            border: Border(
              bottom: BorderSide(
                color: solid && overPhoto
                    ? palette.hairline
                    : palette.hairline.withValues(alpha: 0),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: StudyGuideLayout.topBarHeight,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _handleBackNavigation,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: Icon(Icons.arrow_back_rounded, color: foreground),
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: solid ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ),
                  _buildMenuButton(foreground) ?? const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        );

    if (!overPhoto) return bar(true);
    return ValueListenableBuilder<bool>(
      valueListenable: _topBarCollapsed,
      builder: (_, collapsed, __) => bar(collapsed),
    );
  }

  /// Places the top bar over [child] (hero pages) or above it (loading and
  /// error screens, which have no photo).
  Widget _withTopBar(Widget child, {required bool overPhoto}) {
    if (overPhoto) {
      return Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(overPhoto: true),
          ),
        ],
      );
    }
    return Column(
      children: [
        _buildTopBar(overPhoto: false),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }

  /// The more-options menu (text size, share, PDF, save, complete), or null
  /// before a guide has finished loading.
  Widget? _buildMenuButton(Color iconColor) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final menuPalette = ReaderPalette.of(context);
    return _currentStudyGuide != null
        ? WalkthroughTooltip(
            showcaseKey: ShowcaseKeys.studyGuideMenuButton,
            title: context.tr(TranslationKeys.studyGuideWalkthroughMenuTitle),
            description:
                context.tr(TranslationKeys.studyGuideWalkthroughMenuDesc),
            screen: WalkthroughScreen.studyGuide,
            stepNumber: 1,
            totalSteps: 2,
            tooltipPosition: TooltipPosition.bottom,
            onNext: () => ShowCaseWidget.of(_showcaseContext!).next(),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: iconColor,
              ),
              tooltip: context.tr(TranslationKeys.studyGuideMenuMore),
              position: PopupMenuPosition.under,
              offset: const Offset(0, 6),
              color: menuPalette.card,
              surfaceTintColor: Colors.transparent,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              constraints: const BoxConstraints(minWidth: 232),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: menuPalette.hairline),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'font_size':
                    _showFontSizeSheet();
                    break;
                  case 'share':
                    _shareStudyGuide();
                    break;
                  case 'share_fellowship':
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ShareGuideSheet(
                        studyGuideId: _currentStudyGuide!.id,
                        guideTitle: _getDisplayTitle(),
                        guideInputType: _currentStudyGuide!.inputType,
                        guideLanguage: _currentStudyGuide!.language,
                        guideStudyMode: _currentStudyGuide!.studyMode ??
                            widget.studyMode.name,
                        guideSummary: _currentStudyGuide!.summary,
                        fellowships: _userFellowships!,
                      ),
                    );
                    break;
                  case 'pdf':
                    _exportToPdf();
                    break;
                  case 'save':
                    _saveStudyGuide();
                    break;
                  case 'complete':
                    _markStudyGuideComplete(isManual: true);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'font_size',
                  child: _menuRow(
                    menuPalette,
                    icon: Icons.text_fields_rounded,
                    label: context.tr(TranslationKeys.studyGuideMenuTextSize),
                    trailing: Text(
                      '${_contentFontSize.toInt()}',
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: menuPalette.muted,
                      ),
                    ),
                  ),
                ),
                PopupMenuDivider(height: 9, color: menuPalette.hairline),
                PopupMenuItem(
                  value: 'share',
                  child: _menuRow(
                    menuPalette,
                    icon: Icons.ios_share_rounded,
                    label: context.tr(TranslationKeys.studyGuideMenuShare),
                  ),
                ),
                if (_userFellowships?.isNotEmpty == true)
                  PopupMenuItem(
                    value: 'share_fellowship',
                    child: _menuRow(
                      menuPalette,
                      icon: Icons.groups_2_outlined,
                      label: context
                          .tr(TranslationKeys.studyGuideMenuShareFellowship),
                    ),
                  ),
                PopupMenuItem(
                  value: 'pdf',
                  enabled: !_isExportingPdf,
                  child: _menuRow(
                    menuPalette,
                    icon: Icons.picture_as_pdf_outlined,
                    label:
                        context.tr(TranslationKeys.studyGuideMenuDownloadPdf),
                    busy: _isExportingPdf,
                  ),
                ),
                PopupMenuItem(
                  value: 'save',
                  child: _menuRow(
                    menuPalette,
                    icon: _isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: context.tr(_isSaved
                        ? TranslationKeys.studyGuideMenuSaved
                        : TranslationKeys.studyGuideMenuSave),
                    done: _isSaved,
                  ),
                ),
                PopupMenuItem(
                  value: 'complete',
                  enabled: !_completionMarked,
                  child: _menuRow(
                    menuPalette,
                    icon: _completionMarked
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    label: context.tr(_completionMarked
                        ? TranslationKeys.studyGuideMenuCompleted
                        : TranslationKeys.studyGuideMenuComplete),
                    done: _completionMarked,
                  ),
                ),
              ],
            ),
          ) // WalkthroughTooltip
        : null;
  }

  /// One row of the guide's "more" menu: icon, label and an optional value
  /// on the right. Done states (saved, completed) turn gold.
  Widget _menuRow(
    ReaderPalette palette, {
    required IconData icon,
    required String label,
    Widget? trailing,
    bool done = false,
    bool busy = false,
  }) {
    final tint = done ? palette.gold : palette.accentIcon;
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: busy
              ? CircularProgressIndicator(strokeWidth: 2, color: tint)
              : Icon(icon, size: 20, color: tint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: AppFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: done ? palette.gold : palette.text,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _buildBody() {
    // Wrap with Listener so any pointer-down event (tap, long-press) is treated
    // as user activity and resets the inactivity countdown.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserActivity(),
      child: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
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
            return _withTopBar(_buildStudyGuideContent(), overPhoto: true);
          }

          // Reset transition flag if we're back to streaming
          _isTransitioningFromStreaming = false;

          // Otherwise show progressive streaming content
          return _withTopBar(
            StreamingStudyContent(
              content: state.content,
              inputType: state.inputType,
              inputValue: state.inputValue,
              language: state.language,
              scrollController: _scrollController,
              studyMode: widget.studyMode,
              contentFontSize: _contentFontSize,
              tracker: _readingTracker,
              lesson: widget.lesson,
              headerAccessory: _buildLessonModeSwitch(),
              onComplete:
                  state.content.isComplete && state.content.studyGuideId != null
                      ? () => _handleStreamingComplete(state)
                      : null,
            ),
            overPhoto: true,
          );
        }

        // Handle streaming failure with partial content
        if (state is StudyGenerationStreamingFailed) {
          if (state.hasPartialContent) {
            // Show partial content with error banner
            return _withTopBar(
              _buildPartialContentWithError(state),
              overPhoto: false,
            );
          }
          // No partial content, show error screen
          return _withTopBar(_buildErrorScreen(), overPhoto: false);
        }

        // Regular loading state
        if (_isLoading || state is StudyGenerationInProgress) {
          return _withTopBar(_buildLoadingScreen(), overPhoto: false);
        }

        // Error state
        if (_hasError) {
          return _withTopBar(_buildErrorScreen(), overPhoto: false);
        }

        // Success state with complete study guide
        if (_currentStudyGuide == null) {
          return _withTopBar(_buildErrorScreen(), overPhoto: false);
        }

        return _withTopBar(_buildStudyGuideContent(), overPhoto: true);
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
      passage: state.content.passage,
      relatedVerses: state.content.relatedVerses ?? [],
      reflectionQuestions: state.content.reflectionQuestions ?? [],
      prayerPoints: state.content.prayerPoints ?? [],
      createdAt: DateTime.now(),
      isSaved: false,
    );

    _handleGenerationSuccess(studyGuide);
  }

  /// Build partial content with error banner
  Widget _buildPartialContentWithError(StudyGenerationStreamingFailed state) {
    return Column(
      children: [
        GenerationInterruptedBanner(
          onRetry: state.canRetry ? _retryGeneration : null,
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
            contentFontSize: _contentFontSize,
            isPartial: true,
            tracker: _readingTracker,
            lesson: widget.lesson,
            headerAccessory: _buildLessonModeSwitch(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    final isSermon = widget.studyMode == StudyMode.sermon;
    return Stack(
      children: [
        EngagingLoadingScreen(
          topic: widget.input,
          language: _selectedLanguage,
        ),
        if (isSermon)
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Material orange here was hardcoded light: shade50 stayed a
                // near-white box on the dark loading screen, and shade800 on
                // it measured 2.81:1. Theme tokens fix both.
                color: context.appWarning.withValues(alpha: 0.12),
                border: Border.all(
                    color: context.appWarning.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: context.appWarning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context
                          .tr(TranslationKeys.generateStudySermonOutlineNotice),
                      style: AppFonts.inter(
                        fontSize: 13,
                        // Amber on an amber wash cannot clear AA on light, so
                        // the icon and border carry the warning colour.
                        color: context.appTextPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Quick/Full switch under a lesson's title; null outside lessons.
  Widget? _buildLessonModeSwitch() {
    if (widget.lesson == null) return null;
    return LessonModeSwitch(
      current: widget.studyMode,
      onChanged: _switchLessonMode,
    );
  }

  /// Reopens this lesson in [mode], keeping its other query parameters.
  /// Cancels a stream still in flight first.
  void _switchLessonMode(StudyMode mode) {
    if (mode == widget.studyMode) return;
    final bloc = context.read<StudyBloc>();
    if (bloc.state is StudyGenerationStreaming) {
      bloc.add(const CancelStudyStreamingRequested());
    }
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    context.pushReplacement(uri.replace(queryParameters: {
      ...uri.queryParameters,
      'mode': mode.name,
    }).toString());
  }

  Widget _buildErrorScreen() {
    final palette = ReaderPalette.of(context);
    final noTokens = _isInsufficientTokensError;
    return ColoredBox(
      color: palette.page,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupIconCircle(
                  icon: noTokens ? Icons.token_outlined : Icons.error_outline,
                  tone: noTokens ? PopupTone.gold : PopupTone.accent,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  noTokens
                      ? context.tr(TranslationKeys.studyGuideErrorTitleNoTokens)
                      : context.tr(TranslationKeys.studyGuideErrorTitle),
                  style: AppFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  noTokens
                      ? context
                          .tr(TranslationKeys.studyGuideErrorInsufficientTokens)
                      : (_errorMessage.isEmpty
                          ? context
                              .tr(TranslationKeys.studyGuideErrorDefaultMessage)
                          : _errorMessage),
                  style: AppFonts.inter(
                    fontSize: 15,
                    color: palette.muted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Primary action first, going back as the quieter pill below.
                if (noTokens)
                  PopupPrimaryButton(
                    key: const Key('study_error_get_credits'),
                    label: context.tr(TranslationKeys.studyGuideErrorMyPlan),
                    icon: Icons.token_outlined,
                    onPressed: () => context.push('/token-management'),
                  )
                else
                  PopupPrimaryButton(
                    key: const Key('study_error_try_again'),
                    label: context.tr(TranslationKeys.studyGuideErrorTryAgain),
                    icon: Icons.refresh,
                    onPressed: _retryGeneration,
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SettingsButton(
                    key: const Key('study_error_go_back'),
                    label: context.tr(TranslationKeys.studyGuideErrorGoBack),
                    icon: Icons.arrow_back,
                    kind: SettingsButtonKind.neutral,
                    onPressed: _handleBackNavigation,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudyGuideContent() {
    if (_currentStudyGuide == null) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return Column(
      children: [
        // Main content
        Expanded(
          child: _buildReadModeContent(isLargeScreen),
        ),

        _buildBottomActions(),
      ],
    );
  }

  /// Builds the Read Mode content: the full-bleed hero and numbered sections,
  /// then the end-of-guide blocks (share, follow-up chat, notes) numbered on
  /// from the last section.
  Widget _buildReadModeContent(bool isLargeScreen) {
    const sidePadding = StudyGuideLayout.sidePadding;
    final ttsService = sl<StudyGuideTTSService>();
    final guide = _currentStudyGuide!;
    final sections = StudyGuideSections.fromStudyGuide(guide);

    // End-of-guide blocks continue the sections' numbering.
    var nextNumber = StudyGuideBody.visibleSectionCount(
          context,
          studyMode: widget.studyMode,
          sections: sections,
        ) +
        1;
    final showShare = _userFellowships?.isNotEmpty == true;
    final shareNumber = showShare ? nextNumber++ : null;
    final chatNumber = _showFollowUpChat() ? nextNumber++ : null;
    final notesNumber = nextNumber;

    const blockTop = SizedBox(height: 26);
    const blockBottom = SizedBox(height: 26);

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero, title and sections: the same widget the streaming view
          // renders while the guide loads.
          ValueListenableBuilder<StudyGuideTtsState>(
            valueListenable: ttsService.state,
            builder: (context, ttsState, _) => StudyGuideBody(
              studyMode: widget.studyMode,
              sections: sections,
              inputType: guide.inputType,
              title: _getDisplayTitle(),
              contentFontSize: _contentFontSize,
              readingSectionIndex: ttsState.status == TtsStatus.playing
                  ? ttsState.currentSectionIndex
                  : null,
              interpretationKey: _interpretationKey,
              tracker: _readingTracker,
              lesson: widget.lesson,
              headerAccessory: _buildLessonModeSwitch(),
            ),
          ),

          if (widget.lesson != null && widget.studyMode == StudyMode.quick)
            Padding(
              padding: sidePadding.add(const EdgeInsets.only(top: 20)),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('lesson_read_full_guide'),
                  onPressed: () => _switchLessonMode(StudyMode.standard),
                  style: TextButton.styleFrom(
                    foregroundColor: ReaderPalette.of(context).gold,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 40),
                    textStyle: AppFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text(
                    '${context.tr(TranslationKeys.lessonFullGuideLink)} →',
                  ),
                ),
              ),
            ),

          if (widget.lesson != null)
            Padding(
              padding: sidePadding.add(EdgeInsets.only(
                  top: widget.studyMode == StudyMode.quick ? 4 : 20)),
              child: LessonMarkCompleteBar(
                lesson: widget.lesson!,
                onComplete: _completeLessonNow,
                secondary: _buildLessonSecondaryActions(context),
              ),
            ),

          // Share with fellowship — a reflection, question, or insight
          if (showShare)
            Padding(
              padding: sidePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  blockTop,
                  WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.studyGuideFellowshipShare,
                    title: context
                        .tr(TranslationKeys.studyGuideFellowshipShareTitle),
                    description: context.tr(
                        TranslationKeys.studyGuideFellowshipWalkthroughDesc),
                    screen: WalkthroughScreen.studyGuideCompletion,
                    stepNumber: 1,
                    totalSteps: 3,
                    onNext: () => ShowCaseWidget.of(_showcaseContext!).next(),
                    child: _FellowshipShareSection(
                      number: shareNumber,
                      studyGuideId: guide.id,
                      guideTitle: _getDisplayTitle(),
                      guideInputType: guide.inputType,
                      guideLanguage: guide.language,
                      guideStudyMode: guide.studyMode ?? widget.studyMode.name,
                      guideSummary: guide.summary,
                      userFellowships: _userFellowships!,
                    ),
                  ),
                  blockBottom,
                  const ReaderHairline(),
                ],
              ),
            ),

          // Follow-up Chat Section, with lock support for study_chat feature.
          // Not built for a guest (no panel, no history call).
          if (chatNumber != null)
            LockedFeatureWrapper(
              featureKey: 'study_chat',
              child: Padding(
                padding: sidePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    blockTop,
                    WalkthroughTooltip(
                      showcaseKey: ShowcaseKeys.studyGuideFollowUpChat,
                      title: context
                          .tr(TranslationKeys.studyGuideWalkthroughChatTitle),
                      description: context
                          .tr(TranslationKeys.studyGuideWalkthroughChatDesc),
                      screen: WalkthroughScreen.studyGuideCompletion,
                      stepNumber: 2,
                      totalSteps: 3,
                      onNext: () => ShowCaseWidget.of(_showcaseContext!).next(),
                      child: Container(
                        key: _followUpChatKey,
                        child: BlocProvider(
                          create: (context) {
                            final bloc = sl<FollowUpChatBloc>();
                            bloc.add(StartConversationEvent(
                              studyGuideId: guide.id,
                              studyGuideTitle: _getDisplayTitle(),
                            ));
                            return bloc;
                          },
                          child: FollowUpChatWidget(
                            studyGuideId: guide.id,
                            studyGuideTitle: _getDisplayTitle(),
                            sectionNumber: chatNumber,
                            isExpanded: _isChatExpanded,
                            onToggleExpanded: () {
                              setState(() {
                                _isChatExpanded = !_isChatExpanded;
                              });
                            },
                          ),
                        ),
                      ),
                    ), // WalkthroughTooltip
                    blockBottom,
                    const ReaderHairline(),
                  ],
                ),
              ),
            ),

          // Personal notes
          Padding(
            padding: sidePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                blockTop,
                WalkthroughTooltip(
                  showcaseKey: ShowcaseKeys.studyGuideNotes,
                  title: context
                      .tr(TranslationKeys.studyGuideWalkthroughNotesTitle),
                  description: context
                      .tr(TranslationKeys.studyGuideWalkthroughNotesDesc),
                  screen: WalkthroughScreen.studyGuideCompletion,
                  stepNumber: 3,
                  totalSteps: 3,
                  onNext: () => ShowCaseWidget.of(_showcaseContext!).next(),
                  child: _buildNotesSection(notesNumber),
                ),
                SizedBox(height: isLargeScreen ? 32 : 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Handles reflection completion - saves responses and shows success message
  void _handleReflectionComplete(
    List<ReflectionResponse> responses,
    int timeSpent,
  ) async {
    if (_currentStudyGuide == null) {
      _showSnackBar(
        context.tr(TranslationKeys.guideFeedbackReflectionNotLoaded),
        AppSnackTone.error,
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
        Logger.info(
            '✅ [REFLECTION] Saved reflection for guide: ${_currentStudyGuide!.id}');
        Logger.debug('   Responses: ${responses.length}');
        Logger.debug('   Time spent: ${timeSpent}s');
        Logger.debug('   Study mode: ${widget.studyMode.displayName}');
      }

      // Check if widget is still mounted before updating UI
      if (!mounted) return;

      setState(() {
        _isCompletingReflection = false;
      });

      _showSnackBar(
        context
            .tr(TranslationKeys.guideFeedbackReflectionSaved)
            .replaceAll('{minutes}', '${timeSpent ~/ 60}'),
        AppSnackTone.success,
      );
    } catch (e) {
      Logger.error('❌ [REFLECTION] Error saving reflection: $e');

      // Check if widget is still mounted before updating UI
      if (!mounted) return;

      setState(() {
        _isCompletingReflection = false;
      });

      _showSnackBar(
        context.tr(TranslationKeys.guideFeedbackReflectionFailed),
        AppSnackTone.error,
      );
    }
  }

  Widget _buildNotesSection(int number) {
    final palette = ReaderPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NumberedSectionHeader(
          number: number,
          title: context.tr(TranslationKeys.studyGuidePersonalNotes),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _notesController,
          focusNode: _notesFocusNode,
          minLines: 3,
          maxLines: 6,
          style: AppFonts.inter(
            fontSize: 16,
            color: palette.text,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText:
                context.tr(TranslationKeys.studyGuidePersonalNotesPlaceholder),
            hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
            filled: true,
            fillColor: palette.isDark ? palette.card : palette.raised,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: palette.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: palette.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: palette.accentIcon, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    final palette = ReaderPalette.of(context);
    final foreground = palette.text;
    final ttsService = sl<StudyGuideTTSService>();
    const pillHeight = 52.0;
    final pillBorder = BorderSide(color: palette.outline, width: 1.2);

    return Container(
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // Listen (left) - with lock support for voice_buddy feature
              Expanded(
                child: WalkthroughTooltip(
                  showcaseKey: ShowcaseKeys.studyGuideListen,
                  title:
                      context.tr(TranslationKeys.studyGuideWalkthroughTtsTitle),
                  description:
                      context.tr(TranslationKeys.studyGuideWalkthroughTtsDesc),
                  screen: WalkthroughScreen.studyGuide,
                  stepNumber: 2,
                  totalSteps: 2,
                  highlightBorderRadius: pillHeight / 2,
                  onNext: () => ShowCaseWidget.of(_showcaseContext!).next(),
                  child: LockedFeatureWrapper(
                    featureKey: 'voice_buddy',
                    child: SizedBox(
                      height: pillHeight,
                      child: ValueListenableBuilder<StudyGuideTtsState>(
                        valueListenable: ttsService.state,
                        builder: (context, ttsState, child) {
                          final isPlaying =
                              ttsState.status == TtsStatus.playing;
                          final isPaused = ttsState.status == TtsStatus.paused;
                          final isLoading =
                              ttsState.status == TtsStatus.loading;

                          if (isPlaying || isPaused) {
                            // Split pill: pause/resume + listen settings. The
                            // settings (tune) only ever appear while playing.
                            return DecoratedBox(
                              decoration: ShapeDecoration(
                                shape: StadiumBorder(side: pillBorder),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            ttsService.togglePlayPause(),
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                          left: Radius.circular(pillHeight / 2),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: foreground,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  isPlaying
                                                      ? 'Pause'
                                                      : 'Resume',
                                                  maxLines: 1,
                                                  style: AppFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: foreground,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 26,
                                      color: palette.outline,
                                    ),
                                    InkWell(
                                      onTap: () => showTtsControlSheet(context),
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                        right: Radius.circular(pillHeight / 2),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        child: SizedBox(
                                          height: pillHeight,
                                          child: Icon(
                                            Icons.tune,
                                            color: foreground,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // At rest: outlined Listen pill.
                          return OutlinedButton.icon(
                            onPressed: () {
                              if (_currentStudyGuide != null) {
                                // Load and start reading the study guide if
                                // not already playing
                                final status = ttsService.state.value.status;
                                if (status == TtsStatus.idle ||
                                    status == TtsStatus.error ||
                                    status == TtsStatus.completed) {
                                  ttsService.startReading(_currentStudyGuide!,
                                      mode: widget.studyMode);
                                }
                                // Open the control sheet
                                showTtsControlSheet(context);
                              }
                            },
                            icon: isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: foreground,
                                    ),
                                  )
                                : const Icon(Icons.headphones_rounded,
                                    size: 22),
                            // Shrinks rather than cutting on narrow phones.
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isLoading
                                    ? context
                                        .tr(TranslationKeys.studyGuideLoading)
                                    : context
                                        .tr(TranslationKeys.studyGuideListen),
                                maxLines: 1,
                                style: AppFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: foreground,
                              side: pillBorder,
                              shape: const StadiumBorder(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ), // WalkthroughTooltip
              ),
              // Ask Discipler (right) - only if ai_discipler is enabled and
              // study_chat is not hidden
              if (_isAiDisciplerFeatureEnabled() && _shouldShowStudyChat()) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.disciplerHintStudyGuide,
                    title: context
                        .tr(TranslationKeys.studyGuideWalkthroughDeeperTitle),
                    description: context
                        .tr(TranslationKeys.studyGuideWalkthroughDeeperDesc),
                    screen: WalkthroughScreen.disciplerHint,
                    stepNumber: 1,
                    totalSteps: 1,
                    highlightBorderRadius: pillHeight / 2,
                    onNext: () => ShowCaseWidget.of(_showcaseContext!).next(),
                    child: SizedBox(
                      height: pillHeight,
                      child: Material(
                        color: palette.ctaFill,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: _askDiscipler,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Flat glyph, no disc: ink on the white
                                // dark-theme pill, white on the ink one.
                                DisciplerGlyph.onCta(
                                  size: 24,
                                  isDark: palette.isDark,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      context
                                          .tr(TranslationKeys.studyGuideAskAi),
                                      maxLines: 1,
                                      style: AppFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: palette.ctaInk,
                                      ),
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
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// True when the Discipler may open: a full account, or a guest who has
  /// just signed up from the account-needed sheet (reason `discipler`).
  Future<bool> _disciplerAllowed() async {
    final allowed = await lessonDisciplerGate(context);
    // A guest who signed up now gets the follow-up panel.
    if (allowed && mounted) setState(() {});
    return allowed && mounted;
  }

  /// Opens the follow-up chat (if collapsed) and scrolls it into view.
  /// A guest gets the account-needed sheet instead.
  Future<void> _askDiscipler() async {
    if (!await _disciplerAllowed()) return;
    if (!_isChatExpanded) {
      setState(() {
        _isChatExpanded = true;
      });
    }

    // Scroll after a brief delay so the expand animation has started.
    Future.delayed(const Duration(milliseconds: 100), () {
      final chatContext = _followUpChatKey.currentContext;
      if (chatContext != null && mounted) {
        Scrollable.ensureVisible(
          chatContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.15, // Near the top, below the floating top bar
        );
      }
    });
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

  Future<void> _handleBackNavigation() async {
    // Ensure topic progress is written before navigating back so that the
    // fellowship member-progress query sees up-to-date data.
    //
    // Two cases:
    // 1. StudyCompletionSuccess already fired → _topicProgressFuture is set.
    //    Await it so the DB write finishes before we leave.
    // 2. Guide is marked complete (_completionMarked=true) but
    //    mark-study-guide-complete is still in-flight, so StudyCompletionSuccess
    //    hasn't fired yet → start _completeTopicProgress() and await it. It is
    //    stored in _topicProgressFuture so a StudyCompletionSuccess arriving
    //    meanwhile does not record (and refresh stats for) the lesson twice.
    if (_topicProgressFuture != null || _completionMarked) {
      await (_topicProgressFuture ??= _completeTopicProgress());
    }
    if (!mounted) return;
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
    AppSnackTone tone = AppSnackTone.error;

    if (state.guideSaveSuccess && !state.notesSaveSuccess) {
      message = context.tr(TranslationKeys.guideFeedbackSavedNotesFailed);
      tone = AppSnackTone.warning;
      if (mounted) {
        setState(() {
          _isSaved = true;
        });
      }
      _setupAutoSave();
    } else {
      if (state.primaryFailure.code == 'UNAUTHORIZED') {
        message = context.tr(TranslationKeys.guideFeedbackAuthExpired);
      } else if (state.primaryFailure.code == 'NETWORK_ERROR') {
        message = context.tr(TranslationKeys.guideFeedbackNetworkError);
      } else if (state.primaryFailure.code == 'ALREADY_SAVED') {
        message = context.tr(TranslationKeys.guideFeedbackAlreadySaved);
        tone = AppSnackTone.neutral;
        if (mounted) {
          setState(() {
            _isSaved = true;
          });
        }
        _setupAutoSave();
      } else {
        message = context.tr(TranslationKeys.commonErrorTryAgain);
      }
    }

    _showSnackBar(message, tone);
  }

  /// Show enhanced authentication required dialog
  void _showEnhancedAuthenticationRequiredDialog(
      StudyEnhancedAuthenticationRequired state) {
    SignInRequiredDialog.show(
      context,
      title: context.tr(TranslationKeys.studyGuideAuthRequired),
      message: context.tr(TranslationKeys.studyGuideAuthRequiredMessage),
      signInLabel: context.tr(TranslationKeys.studyGuideSignIn),
      cancelLabel: context.tr(TranslationKeys.commonCancel),
      onSignIn: () {
        if (mounted) sl<StudyNavigator>().navigateToLogin(context);
      },
    );
  }

  /// Show the app-wide snackbar with the given [tone].
  void _showSnackBar(String message, AppSnackTone tone) {
    if (!mounted) return;
    showAppSnackBar(context, message, tone: tone);
  }

  /// Shows recommended topic notification prompt after completing a study guide
  Future<void> _showRecommendedTopicNotificationPrompt() async {
    if (_hasTriggeredNotificationPrompt) return;
    _hasTriggeredNotificationPrompt = true;

    // Delay to show after the completion is processed
    await Future.delayed(const Duration(milliseconds: 1500));

    // Never over an achievement dialog: wait for it to be dismissed first.
    await _achievementDialogsSettled;

    if (!mounted) return;

    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.recommendedTopic,
      languageCode: _selectedLanguage,
    );
  }

  // ============================================================================
  // SCREENSHOT DETECTION
  // ============================================================================

  void _setupScreenshotDetection() {
    try {
      const channel = EventChannel('com.disciplefy/screenshot');
      _screenshotSubscription = channel.receiveBroadcastStream().listen((_) {
        if (mounted && _currentStudyGuide != null) {
          _showShareOnScreenshotPrompt();
        }
      });
    } catch (_) {
      // Platform does not support screenshot detection — no-op
    }
  }

  void _showShareOnScreenshotPrompt() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScreenshotShareSheet(
        onShareText: () {
          Navigator.of(ctx).pop();
          _shareStudyGuide();
        },
        onShareFellowship: (_userFellowships?.isNotEmpty == true)
            ? () {
                Navigator.of(ctx).pop();
                showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ShareGuideSheet(
                    studyGuideId: _currentStudyGuide!.id,
                    guideTitle: _getDisplayTitle(),
                    guideInputType: _currentStudyGuide!.inputType,
                    guideLanguage: _currentStudyGuide!.language,
                    guideStudyMode:
                        _currentStudyGuide!.studyMode ?? widget.studyMode.name,
                    guideSummary: _currentStudyGuide!.summary,
                    fellowships: _userFellowships!,
                  ),
                );
              }
            : null,
      ),
    );
  }

  Future<void> _shareStudyGuide() async {
    if (_currentStudyGuide == null) return;

    final appLink = '📱 ${ShareLinks.studyGuide(_currentStudyGuide!.id)}';
    final passage = _currentStudyGuide!.passage;
    final preview = firstInterpretationParagraph(
      _currentStudyGuide!.interpretation,
    );

    // A short preview, not the whole guide: the full guide (summary, every
    // interpretation section, context, related verses, discussion questions,
    // prayer points) routinely ran past WhatsApp's ~65 536-code-point paste
    // limit and arrived cropped mid-sentence with no way to read the rest.
    // Summary + passage + the interpretation's first paragraph fits easily,
    // and the link is where the whole guide actually lives.
    final shareText = '''
${context.tr(TranslationKeys.studyGuideSummary)}:
${_currentStudyGuide!.summary}
${passage != null && passage.isNotEmpty ? '\n${context.tr(TranslationKeys.studyGuidePassageReading)}:\n$passage' : ''}
${context.tr(TranslationKeys.studyGuideInterpretation)}:
$preview

${context.tr(TranslationKeys.studyGuideShareReadMore)}
— Shared from Disciplefy: Bible Study App
$appLink
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

    setState(() => _isExportingPdf = true);

    // Mutable progress state; updated via StatefulBuilder's setState.
    int pdfStep = 0;
    int pdfTotal = 0;
    String? savedPdfMessage;
    StateSetter? updateDialog;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            updateDialog = setDialogState;
            final fraction = pdfTotal > 0 ? pdfStep / pdfTotal : 0.0;
            final palette = ReaderPalette.of(ctx);
            return PopupDialog(
              children: [
                // Static icon — no animation (main thread is busy rendering)
                const PopupIconCircle(icon: Icons.picture_as_pdf_outlined),
                const SizedBox(height: 16),
                PopupEyebrow(
                    context.tr(TranslationKeys.studyGuideMenuDownloadPdf)),
                const SizedBox(height: 8),
                Text(
                  context.tr(TranslationKeys.studyGuideGeneratingPdf),
                  style: AppFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                // Determinate bar — snaps between sections (no animation needed)
                LinearProgressIndicator(
                  value: pdfTotal > 0 ? fraction.clamp(0.0, 1.0) : null,
                  backgroundColor: palette.raised,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.gold),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 10),
                Text(
                  pdfTotal > 0 && pdfStep < pdfTotal
                      ? '$pdfStep / $pdfTotal'
                      : pdfTotal > 0 && pdfStep == pdfTotal
                          ? context.tr(TranslationKeys.studyGuidePdfFinalizing)
                          : context
                              .tr(TranslationKeys.studyGuidePdfWaitMessage),
                  style: AppFonts.inter(fontSize: 13, color: palette.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );

    // Wait for the dialog to fully render before starting heavy work.
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      await pdf_export.loadLibrary();
      final pdfService = pdf_export.StudyGuidePdfService();
      final savedPath = await pdfService.sharePdf(
        _currentStudyGuide!,
        context: context,
        onProgress: (step, total) {
          pdfStep = step;
          pdfTotal = total;
          updateDialog?.call(() {}); // Trigger StatefulBuilder rebuild
        },
      );
      // Downloading the PDF counts as studying the guide.
      if (mounted) _markStudyGuideComplete(isManual: true);
      // Only when it was actually kept: elsewhere it was shared and nothing
      // was written to the device.
      if (mounted && savedPath != null) {
        savedPdfMessage = context.tr(TranslationKeys.studyGuidePdfSavedTo);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.commonErrorTryAgain),
          tone: AppSnackTone.error,
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isExportingPdf = false);
        // After the progress dialog is gone, so the snackbar is visible.
        final message = savedPdfMessage;
        if (message != null) {
          showAppSnackBar(context, message, tone: AppSnackTone.success);
        }
      }
    }
  }
}

// =============================================================================
// Reflection Comment Section
// =============================================================================

/// A combined card that lets users share a reflection, question, or insight
/// directly to their fellowship feed.
class _FellowshipShareSection extends StatefulWidget {
  /// Position in the guide, shown as a gold `07`.
  final int? number;
  final String studyGuideId;
  final String guideTitle;
  final String guideInputType;
  final String guideLanguage;
  final String? guideStudyMode;
  final String? guideSummary;
  final List<FellowshipEntity> userFellowships;

  const _FellowshipShareSection({
    this.number,
    required this.studyGuideId,
    required this.guideTitle,
    required this.guideInputType,
    required this.guideLanguage,
    this.guideStudyMode,
    this.guideSummary,
    required this.userFellowships,
  });

  @override
  State<_FellowshipShareSection> createState() =>
      _FellowshipShareSectionState();
}

class _FellowshipShareSectionState extends State<_FellowshipShareSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isPosting = false;

  /// Fellowships the post goes to. All of them until the user changes it.
  late final Set<String> _selectedIds =
      widget.userFellowships.map((f) => f.id).toSet();

  List<FellowshipEntity> get _selectedFellowships =>
      widget.userFellowships.where((f) => _selectedIds.contains(f.id)).toList();

  /// Lets the user pick which fellowships the post goes to.
  Future<void> _pickFellowships() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final palette = ReaderPalette.of(sheetContext);
          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      sheetContext.tr(TranslationKeys.communityPagesShareTo),
                      style: AppFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final fellowship in widget.userFellowships)
                          CheckboxListTile(
                            key: ValueKey('share-pick-${fellowship.id}'),
                            value: _selectedIds.contains(fellowship.id),
                            activeColor: palette.accentIcon,
                            controlAffinity: ListTileControlAffinity.trailing,
                            title: Text(
                              fellowship.name,
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                              ),
                            ),
                            onChanged: (checked) {
                              setSheetState(() {});
                              setState(() {
                                if (checked == true) {
                                  _selectedIds.add(fellowship.id);
                                } else {
                                  _selectedIds.remove(fellowship.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ShareGuideSheet paints its own palette surface, matching the other
      // call sites that open it on a transparent sheet.
      builder: (_) => ShareGuideSheet(
        studyGuideId: widget.studyGuideId,
        guideTitle: widget.guideTitle,
        guideInputType: widget.guideInputType,
        guideLanguage: widget.guideLanguage,
        guideStudyMode: widget.guideStudyMode,
        guideSummary: widget.guideSummary,
        fellowships: widget.userFellowships,
        content: text,
        initialSelectedIds: _selectedIds,
      ),
    );

    if (!mounted) return;
    setState(() => _isPosting = false);
    if (result == true) {
      _controller.clear();
      setState(() {});
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.guideFeedbackSharedToFellowship),
        tone: AppSnackTone.success,
      );
    }
  }

  /// "Name" for one fellowship, "Name +2" for several.
  String _fellowshipLabel() {
    final fellowships = _selectedFellowships;
    if (fellowships.isEmpty) {
      return context.tr(TranslationKeys.communityPagesShareSelect);
    }
    final first = fellowships.first.name;
    return fellowships.length == 1
        ? first
        : '$first +${fellowships.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final hasText = _controller.text.trim().isNotEmpty;
    final canPost = hasText && !_isPosting && _selectedIds.isNotEmpty;
    final label = _fellowshipLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NumberedSectionHeader(
          number: widget.number,
          title: context.tr(TranslationKeys.studyGuideFellowshipCardTitle),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(TranslationKeys.studyGuideFellowshipCardSubtitle),
          style: AppFonts.inter(
            fontSize: 13.5,
            color: palette.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          style: AppFonts.inter(fontSize: 15, color: palette.text, height: 1.4),
          // The 500 limit only shows once it is close.
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              currentLength > 400
                  ? Text(
                      '$currentLength/$maxLength',
                      style: AppFonts.inter(fontSize: 12, color: palette.dim),
                    )
                  : null,
          decoration: InputDecoration(
            hintText: context.tr(TranslationKeys.studyGuideFellowshipInputHint),
            hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
            filled: true,
            fillColor: palette.isDark ? palette.card : palette.raised,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: palette.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: palette.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: palette.accentIcon, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Where the post goes; tap to change the fellowships.
            Flexible(
              child: Material(
                color: palette.raised,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  key: const ValueKey('share-fellowship-picker'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.userFellowships.length > 1
                      ? _pickFellowships
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: palette.gold.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.group_rounded,
                              size: 14, color: palette.gold),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                        ),
                        if (widget.userFellowships.length > 1) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more_rounded,
                              size: 18, color: palette.muted),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: Material(
                color: canPost
                    ? palette.ctaFill
                    : palette.ctaFill
                        .withValues(alpha: palette.isDark ? 0.3 : 0.35),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: canPost ? _handleShare : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Center(
                      widthFactor: 1,
                      child: _isPosting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.ctaInk,
                              ),
                            )
                          : Text(
                              AppLocalizations.of(context)!.feedCreatePost,
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: palette.ctaInk,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
