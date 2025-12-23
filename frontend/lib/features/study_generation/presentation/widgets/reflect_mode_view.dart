import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/entities/study_mode.dart';
import 'reflect_mode_card.dart';

/// Configuration for each reflection card
class ReflectCardConfig {
  final String sectionTitle;
  final String Function(StudyGuide) getContent;
  final ReflectionInteractionType interactionType;
  final String question;
  final List<InteractionOption>? options;
  final SliderLabels? sliderLabels;

  const ReflectCardConfig({
    required this.sectionTitle,
    required this.getContent,
    required this.interactionType,
    required this.question,
    this.options,
    this.sliderLabels,
  });
}

/// Widget for displaying Reflect Mode with card-by-card progression.
///
/// Shows one section at a time with interactive prompts for engagement.
class ReflectModeView extends StatefulWidget {
  /// The study guide to reflect upon.
  final StudyGuide studyGuide;

  /// Callback when switching back to Read mode.
  final VoidCallback onSwitchToRead;

  /// Callback when reflection is completed.
  final void Function(List<ReflectionResponse> responses, int timeSpent)
      onComplete;

  /// Callback when exiting reflect mode.
  final VoidCallback onExit;

  const ReflectModeView({
    super.key,
    required this.studyGuide,
    required this.onSwitchToRead,
    required this.onComplete,
    required this.onExit,
  });

  @override
  State<ReflectModeView> createState() => _ReflectModeViewState();
}

class _ReflectModeViewState extends State<ReflectModeView> {
  int _currentCardIndex = 0;
  final List<ReflectionResponse> _responses = [];
  late DateTime _startTime;
  Timer? _timeTracker;
  int _timeSpentSeconds = 0;

  /// Card configurations for each section
  late final List<ReflectCardConfig> _cardConfigs;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimeTracking();
    _initializeCardConfigs();
  }

  void _initializeCardConfigs() {
    _cardConfigs = [
      // Summary - Tap Selection
      ReflectCardConfig(
        sectionTitle: 'Summary',
        getContent: (guide) => guide.summary,
        interactionType: ReflectionInteractionType.tapSelection,
        question: 'What resonates most with you?',
        options: const [
          InteractionOption(label: 'Strength', icon: '💪'),
          InteractionOption(label: 'Comfort', icon: '🤗'),
          InteractionOption(label: 'Challenge', icon: '🎯'),
        ],
      ),

      // Interpretation - Slider
      ReflectCardConfig(
        sectionTitle: 'Interpretation',
        getContent: (guide) => guide.interpretation,
        interactionType: ReflectionInteractionType.slider,
        question: 'How much does this apply to your life right now?',
        sliderLabels: const SliderLabels(
          left: 'Not at all',
          right: 'Very much',
        ),
      ),

      // Context - Yes/No
      ReflectCardConfig(
        sectionTitle: 'Context',
        getContent: (guide) => guide.context,
        interactionType: ReflectionInteractionType.yesNo,
        question: 'Have you faced a similar situation before?',
      ),

      // Related Verses - Multi-select (verse selection)
      ReflectCardConfig(
        sectionTitle: 'Related Verses',
        getContent: (guide) => guide.relatedVerses.join('\n\n'),
        interactionType: ReflectionInteractionType.verseSelection,
        question: 'Tap verses to save for later:',
        options: [], // Will be populated dynamically
      ),

      // Reflection Questions - Multi-select (life areas)
      ReflectCardConfig(
        sectionTitle: 'Reflection',
        getContent: (guide) => guide.reflectionQuestions
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n\n'),
        interactionType: ReflectionInteractionType.multiSelect,
        question: 'Where do you need this today?',
        options: LifeAreas.all
            .map(
                (area) => InteractionOption(label: area.label, icon: area.icon))
            .toList(),
      ),

      // Prayer - Prayer mode selection
      ReflectCardConfig(
        sectionTitle: 'Prayer',
        getContent: (guide) => guide.prayerPoints.map((p) => '• $p').join('\n'),
        interactionType: ReflectionInteractionType.prayer,
        question: 'How would you like to pray?',
      ),
    ];
  }

  void _startTimeTracking() {
    _timeTracker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeSpentSeconds = DateTime.now().difference(_startTime).inSeconds;
      });
    });
  }

  @override
  void dispose() {
    _timeTracker?.cancel();
    super.dispose();
  }

  void _handleInteractionComplete(ReflectionResponse response) {
    // Remove any existing response for this card index
    _responses.removeWhere((r) => r.cardIndex == response.cardIndex);
    _responses.add(response);
  }

  void _handleContinue() {
    if (_currentCardIndex < _cardConfigs.length - 1) {
      setState(() {
        _currentCardIndex++;
      });
    } else {
      // Completed all cards
      widget.onComplete(_responses, _timeSpentSeconds);
    }
  }

  void _handleBack() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentConfig = _cardConfigs[_currentCardIndex];

    // Get dynamic options for verse selection
    List<InteractionOption>? options = currentConfig.options;
    if (currentConfig.interactionType ==
        ReflectionInteractionType.verseSelection) {
      options = widget.studyGuide.relatedVerses
          .map((verse) => InteractionOption(label: verse))
          .toList();
    }

    return Column(
      children: [
        // Header with back button and mode toggle
        _buildHeader(context),

        // Main card area
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            child: ReflectModeCard(
              key: ValueKey(_currentCardIndex),
              cardIndex: _currentCardIndex,
              totalCards: _cardConfigs.length,
              sectionTitle: currentConfig.sectionTitle,
              sectionContent: currentConfig.getContent(widget.studyGuide),
              interactionType: currentConfig.interactionType,
              interactionQuestion: currentConfig.question,
              options: options,
              sliderLabels: currentConfig.sliderLabels,
              onInteractionComplete: _handleInteractionComplete,
              onContinue: _handleContinue,
            ),
          ),
        ),

        // Back navigation (only shown after first card)
        if (_currentCardIndex > 0) _buildBackButton(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close/Exit button
          IconButton(
            onPressed: () => _showExitDialog(context),
            icon: const Icon(Icons.close),
            tooltip: 'Exit Reflect Mode',
          ),

          const SizedBox(width: 8),

          // Time spent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_timeSpentSeconds),
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Switch to Read mode button
          TextButton.icon(
            onPressed: widget.onSwitchToRead,
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text(
              'Read',
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextButton.icon(
        onPressed: _handleBack,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Previous'),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Reflect Mode?'),
        content: const Text(
          'Your progress will not be saved. You can return to Read mode instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSwitchToRead();
            },
            child: const Text('Switch to Read'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onExit();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
