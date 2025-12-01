import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/study_guide.dart';
import '../../../../core/navigation/study_navigator.dart';
import '../../../home/data/services/recommended_guides_service.dart';
import '../bloc/study_bloc.dart';
import '../bloc/study_event.dart';
import '../bloc/study_state.dart';
import '../../../saved_guides/data/models/saved_guide_model.dart';
import '../../../follow_up_chat/presentation/widgets/follow_up_chat_widget.dart';
import '../../../follow_up_chat/presentation/bloc/follow_up_chat_bloc.dart';
import '../../../follow_up_chat/presentation/bloc/follow_up_chat_event.dart';

/// Study Guide Screen displaying generated content with sections and user interactions.
///
/// Features scrollable content, note-taking, save/share functionality, and error handling
/// following the UX specifications and brand guidelines.
///
/// Enhanced Integration: Utilizes personal notes and save status from StudyGuide entity
/// when available (from enhanced API response) to eliminate redundant API calls and
/// provide immediate access to user data. Supports navigation from both generate screen
/// and saved guides screen with proper state management and auto-save functionality.
class StudyGuideScreen extends StatelessWidget {
  final StudyGuide? studyGuide;
  final Map<String, dynamic>? routeExtra;
  final StudyNavigationSource navigationSource;

  const StudyGuideScreen({
    super.key,
    this.studyGuide,
    this.routeExtra,
    this.navigationSource = StudyNavigationSource.saved,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => sl<StudyBloc>(),
        child: _StudyGuideScreenContent(
          studyGuide: studyGuide,
          routeExtra: routeExtra,
          navigationSource: navigationSource,
        ),
      );
}

class _StudyGuideScreenContent extends StatefulWidget {
  final StudyGuide? studyGuide;
  final Map<String, dynamic>? routeExtra;
  final StudyNavigationSource navigationSource;

  const _StudyGuideScreenContent({
    this.studyGuide,
    this.routeExtra,
    required this.navigationSource,
  });

  @override
  State<_StudyGuideScreenContent> createState() =>
      _StudyGuideScreenContentState();
}

class _StudyGuideScreenContentState extends State<_StudyGuideScreenContent> {
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late StudyGuide _currentStudyGuide;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSaved = false;
  DateTime? _lastSaveAttempt;

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

  void _initializeStudyGuide() {
    _resetNotesState();

    if (widget.studyGuide != null) {
      _handleGeneratedStudyGuide();
    } else if (widget.routeExtra != null &&
        widget.routeExtra!['study_guide'] != null) {
      _handleSavedStudyGuide();
    } else {
      _handleMissingStudyGuide();
    }
  }

  void _resetNotesState() {
    _notesLoaded = false;
    _loadedNotes = null;
    _notesController.clear();
  }

  void _handleGeneratedStudyGuide() {
    _currentStudyGuide = widget.studyGuide!;

    if (_currentStudyGuide.isSaved != null) {
      _isSaved = _currentStudyGuide.isSaved!;
    }

    _processGeneratedGuideNotes();
    _startCompletionTracking();
  }

  void _processGeneratedGuideNotes() {
    if (_currentStudyGuide.personalNotes != null) {
      _loadedNotes = _currentStudyGuide.personalNotes;
      _notesController.text = _currentStudyGuide.personalNotes!;
      _notesLoaded = true;

      if (_isSaved) {
        _setupAutoSave();
      }
    } else {
      _loadPersonalNotesIfSaved();
    }
  }

  void _handleSavedStudyGuide() {
    try {
      final guideData =
          widget.routeExtra!['study_guide'] as Map<String, dynamic>;

      final savedGuideModel = _createSavedGuideModel(guideData);
      _currentStudyGuide = savedGuideModel.toStudyGuide();

      _isSaved = guideData['is_saved'] as bool? ?? true;

      _loadPersonalNotesIfSaved();
      _startCompletionTracking();
    } catch (e) {
      _showError('Invalid study guide data. Please try again.');
    }
  }

  SavedGuideModel _createSavedGuideModel(Map<String, dynamic> guideData) {
    return SavedGuideModel(
      id: guideData['id'] ?? '',
      title: guideData['title'] ?? '',
      content: guideData['content'] ?? '',
      typeString: guideData['type'] ?? 'topic',
      createdAt:
          DateTime.tryParse(guideData['created_at'] ?? '') ?? DateTime.now(),
      lastAccessedAt: DateTime.tryParse(guideData['last_accessed_at'] ?? '') ??
          DateTime.now(),
      isSaved: guideData['is_saved'] as bool? ?? false,
      verseReference: guideData['verse_reference'],
      topicName: guideData['topic_name'],
      summary: guideData['summary'] as String?,
      interpretation: guideData['interpretation'] as String?,
      context: guideData['context'] as String?,
      relatedVerses:
          (guideData['related_verses'] as List<dynamic>?)?.cast<String>(),
      reflectionQuestions:
          (guideData['reflection_questions'] as List<dynamic>?)?.cast<String>(),
      prayerPoints:
          (guideData['prayer_points'] as List<dynamic>?)?.cast<String>(),
    );
  }

  void _handleMissingStudyGuide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        sl<StudyNavigator>().navigateToSaved(context);
      }
    });
    _showError('Redirecting to saved guides...');
  }

  void _showError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
  }

  /// Load personal notes if the guide is saved and notes not already available
  void _loadPersonalNotesIfSaved() {
    if (kDebugMode) {
      print(
          '🔍 [STUDY_GUIDE] Loading personal notes: isSaved=$_isSaved, notesLoaded=$_notesLoaded, hasEntityNotes=${_currentStudyGuide.personalNotes != null}');
    }

    // Load notes if guide is saved and we haven't loaded them yet
    // Simplified logic: if saved and not loaded, try to load
    if (_isSaved && !_notesLoaded) {
      if (kDebugMode) {
        print(
            '📝 [STUDY_GUIDE] Requesting personal notes for guide: ${_currentStudyGuide.id}');
      }
      context.read<StudyBloc>().add(LoadPersonalNotesRequested(
            guideId: _currentStudyGuide.id,
          ));
    } else {
      if (kDebugMode) {
        print(
            '⏭️ [STUDY_GUIDE] Skipping notes load: isSaved=$_isSaved, notesLoaded=$_notesLoaded');
      }
    }
  }

  /// Setup auto-save for personal notes
  void _setupAutoSave() {
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
          if (_isSaved) {
            context.read<StudyBloc>().add(UpdatePersonalNotesRequested(
                  guideId: _currentStudyGuide.id,
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
      print(
          '📊 [COMPLETION] Started tracking for guide: ${_currentStudyGuide.id}');
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
    // This accounts for different screen sizes and scroll behavior
    return currentScroll >= (maxScroll - 100);
  }

  /// Check if both completion conditions are met and mark complete if so
  void _checkCompletionConditions() {
    if (_completionMarked) return;

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
    if (_completionMarked) return;

    setState(() {
      _completionMarked = true;
    });

    if (kDebugMode) {
      print('✅ [COMPLETION] Marking guide as complete:');
      print('   Guide ID: ${_currentStudyGuide.id}');
      print('   Time spent: $_timeSpentSeconds seconds');
      print('   Scrolled to bottom: $_hasScrolledToBottom');
    }

    // Dispatch BLoC event to mark completion
    context.read<StudyBloc>().add(MarkStudyGuideCompleteRequested(
          guideId: _currentStudyGuide.id,
          timeSpentSeconds: _timeSpentSeconds,
          scrolledToBottom: _hasScrolledToBottom,
        ));

    // Cancel the tracking timer since completion is marked
    _timeTrackingTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    if (_hasError) {
      return _buildErrorScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Handle Android back button - use StudyNavigator for proper back navigation
        sl<StudyNavigator>().navigateBack(
          context,
          source: widget.navigationSource,
        );
      },
      child: BlocListener<StudyBloc, StudyState>(
        listener: (context, state) {
          // Handle legacy save operations
          if (state is StudySaveSuccess) {
            setState(() {
              _isSaved = state.saved;
            });
            _showSnackBar(
              state.message,
              state.saved
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              icon: state.saved ? Icons.check_circle : Icons.bookmark_remove,
            );
          } else if (state is StudySaveFailure) {
            _handleSaveError(state.failure);
          } else if (state is StudyAuthenticationRequired) {
            _showAuthenticationRequiredDialog();
          }
          // Handle enhanced save operations
          else if (state is StudyEnhancedSaveSuccess) {
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
            // Setup auto-save if guide was saved
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
            if (kDebugMode) {
              print(
                  '📝 [STUDY_GUIDE] Personal notes loaded: ${state.notes?.length ?? 0} characters');
            }
            setState(() {
              _notesLoaded = true;
              _loadedNotes = state.notes;
              if (state.notes != null) {
                _notesController.text = state.notes!;
              }
            });
            // Setup auto-save for saved guides
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
            setState(() {
              _loadedNotes = state.savedNotes;
            });
          } else if (state is StudyPersonalNotesFailure) {
            if (kDebugMode) {
              print(
                  '❌ [STUDY_GUIDE] Personal notes operation failed: ${state.failure.message}, isAutoSave: ${state.isAutoSave}');
            }
            if (!state.isAutoSave) {
              _showSnackBar(
                'Failed to save personal notes: ${state.failure.message}',
                Theme.of(context).colorScheme.error,
                icon: Icons.error_outline,
              );
            }
          }
          // Handle study completion - invalidate cache
          else if (state is StudyCompletionSuccess) {
            // Invalidate the "For You" cache so completed topics don't show again
            sl<RecommendedGuidesService>().clearForYouCache();
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                // Navigate back using the navigation service
                sl<StudyNavigator>().navigateBack(
                  context,
                  source: widget.navigationSource,
                );
              },
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
            actions: [
              IconButton(
                onPressed: _shareStudyGuide,
                icon: Icon(
                  Icons.share_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'Share study guide',
              ),
            ],
          ),
          body: Column(
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
                            studyGuideId: _currentStudyGuide.id,
                            studyGuideTitle: _getDisplayTitle(),
                          ));
                          return bloc;
                        },
                        child: FollowUpChatWidget(
                          studyGuideId: _currentStudyGuide.id,
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
          ),
        ), // Scaffold
      ), // BlocListener
    ); // PopScope
  }

  Widget _buildErrorScreen() => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          // Handle Android back button - use StudyNavigator for proper back navigation
          sl<StudyNavigator>().navigateBack(
            context,
            source: widget.navigationSource,
          );
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                // Navigate back using the navigation service
                sl<StudyNavigator>().navigateBack(
                  context,
                  source: widget.navigationSource,
                );
              },
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.primary,
              ),
              tooltip: 'Go back',
            ),
            title: Text(
              'Study Guide',
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
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
                    'We couldn\'t generate a study guide',
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
                        ? 'Something went wrong. Please try again later.'
                        : _errorMessage,
                    style: AppFonts.inter(
                      fontSize: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () =>
                        sl<StudyNavigator>().navigateToSaved(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'View Saved Guides',
                      style: AppFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ), // body: Center
        ), // Scaffold
      ); // PopScope

  Widget _buildStudyContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideSummary),
            icon: Icons.summarize,
            content: _currentStudyGuide.summary,
          ),

          const SizedBox(height: 24),

          // Interpretation Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideInterpretation),
            icon: Icons.lightbulb_outline,
            content: _currentStudyGuide.interpretation,
          ),

          const SizedBox(height: 24),

          // Context Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideContext),
            icon: Icons.history_edu,
            content: _currentStudyGuide.context,
          ),

          const SizedBox(height: 24),

          // Related Verses Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideRelatedVerses),
            icon: Icons.menu_book,
            content: _currentStudyGuide.relatedVerses.join('\n\n'),
          ),

          const SizedBox(height: 24),

          // Discussion Questions Section
          _StudySection(
            title: context.tr(TranslationKeys.studyGuideDiscussionQuestions),
            icon: Icons.quiz,
            content: _currentStudyGuide.reflectionQuestions
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
            content: _currentStudyGuide.prayerPoints
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
                  final isSaving = (state is StudySaveInProgress &&
                          state.guideId == _currentStudyGuide.id) ||
                      (state is StudyEnhancedSaveInProgress &&
                          state.guideId == _currentStudyGuide.id);

                  // Get current step for enhanced save progress
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
          ],
        ),
      );

  String _getDisplayTitle() {
    if (_currentStudyGuide.inputType == 'scripture') {
      return _currentStudyGuide.input;
    } else {
      return _currentStudyGuide.input.substring(0, 1).toUpperCase() +
          _currentStudyGuide.input.substring(1);
    }
  }

  /// Toggle save/unsave status of the current study guide with personal notes via BLoC
  void _saveStudyGuide() {
    // Debounce rapid taps - prevent multiple requests within 2 seconds
    final now = DateTime.now();
    if (_lastSaveAttempt != null &&
        now.difference(_lastSaveAttempt!).inSeconds < 2) {
      return;
    }
    _lastSaveAttempt = now;

    // Determine action based on current save status
    final shouldSave = !_isSaved;
    final personalNotes = _notesController.text.trim();

    // Use enhanced save functionality that combines guide saving with personal notes
    context.read<StudyBloc>().add(CheckEnhancedAuthenticationRequested(
          guideId: _currentStudyGuide.id,
          save: shouldSave,
          personalNotes: personalNotes.isEmpty ? null : personalNotes,
        ));
  }

  /// Show authentication required dialog
  void _showAuthenticationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFA), // Light background
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Text(
          context.tr(TranslationKeys.studyGuideAuthRequired),
          style: AppFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333), // Primary gray text
          ),
        ),
        content: Text(
          context.tr(TranslationKeys.studyGuideAuthRequiredMessage),
          style: AppFonts.inter(
            fontSize: 18,
            color: const Color(0xFF333333), // Primary gray text
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF888888), // Light gray for cancel
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
                color: const Color(0xFF888888), // Light gray text
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

  /// Show enhanced authentication required dialog with personal notes info
  void _showEnhancedAuthenticationRequiredDialog(
      StudyEnhancedAuthenticationRequired state) {
    final hasNotes = state.personalNotes?.isNotEmpty == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFA), // Light background
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
            color: const Color(0xFF333333), // Primary gray text
          ),
        ),
        content: Text(
          context.tr(TranslationKeys.studyGuideAuthRequiredMessage),
          style: AppFonts.inter(
            fontSize: 18,
            color: const Color(0xFF333333), // Primary gray text
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF888888), // Light gray for cancel
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
                color: const Color(0xFF888888), // Light gray text
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

  /// Handle save operation errors from BLoC
  void _handleSaveError(Failure failure) {
    String message = 'Failed to save study guide. Please try again.';
    Color backgroundColor = Theme.of(context).colorScheme.error;

    if (failure.code == 'UNAUTHORIZED') {
      message = 'Authentication expired. Please sign in again.';
    } else if (failure.code == 'NETWORK_ERROR') {
      message = 'Network error. Please check your connection.';
    } else if (failure.code == 'NOT_FOUND') {
      message = 'Study guide not found. It may have been deleted.';
    } else if (failure.code == 'ALREADY_SAVED') {
      message = 'This study guide is already saved!';
      backgroundColor = Theme.of(context).colorScheme.primary;
      setState(() {
        _isSaved = true;
      });
    } else {
      message = failure.message;
    }

    _showSnackBar(message, backgroundColor, icon: Icons.error_outline);
  }

  /// Handle enhanced save operation errors from BLoC
  void _handleEnhancedSaveError(StudyEnhancedSaveFailure state) {
    String message;
    Color backgroundColor = Theme.of(context).colorScheme.error;
    IconData icon = Icons.error_outline;

    if (state.guideSaveSuccess && !state.notesSaveSuccess) {
      // Guide saved but notes failed
      message = 'Study guide saved, but failed to save personal notes.';
      setState(() {
        _isSaved = true;
      });
      _setupAutoSave(); // Setup auto-save since guide is now saved
    } else if (!state.guideSaveSuccess && state.notesSaveSuccess) {
      // Notes saved but guide failed (shouldn't happen in normal flow)
      message = 'Failed to save study guide: ${state.primaryFailure.message}';
    } else {
      // Both failed or primary failure
      if (state.primaryFailure.code == 'UNAUTHORIZED') {
        message = 'Authentication expired. Please sign in again.';
      } else if (state.primaryFailure.code == 'NETWORK_ERROR') {
        message = 'Network error. Please check your connection.';
      } else if (state.primaryFailure.code == 'ALREADY_SAVED') {
        message = 'This study guide is already saved!';
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.check_circle;
        setState(() {
          _isSaved = true;
        });
        _setupAutoSave();
      } else {
        message = state.primaryFailure.message;
      }
    }

    _showSnackBar(message, backgroundColor, icon: icon);
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

  void _shareStudyGuide() {
    final shareText = '''
${_getDisplayTitle()}

${context.tr(TranslationKeys.studyGuideSummary)}:
${_currentStudyGuide.summary}

${context.tr(TranslationKeys.studyGuideInterpretation)}:
${_currentStudyGuide.interpretation}

${context.tr(TranslationKeys.studyGuideContext)}:
${_currentStudyGuide.context}

${context.tr(TranslationKeys.studyGuideRelatedVerses)}:
${_currentStudyGuide.relatedVerses.join('\n')}

${context.tr(TranslationKeys.studyGuideDiscussionQuestions)}:
${_currentStudyGuide.reflectionQuestions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

${context.tr(TranslationKeys.studyGuidePrayerPoints)}:
${_currentStudyGuide.prayerPoints.map((p) => '• $p').join('\n')}

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
