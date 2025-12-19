import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../domain/entities/voice_conversation_entity.dart';
import '../bloc/voice_conversation_bloc.dart';
import '../bloc/voice_conversation_event.dart';
import '../bloc/voice_conversation_state.dart';
import '../widgets/conversation_bubble.dart';
import '../../../../shared/widgets/scripture_verse_sheet.dart';
import '../widgets/language_selector.dart' show VoiceLanguage;
import '../widgets/voice_button.dart';
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';

/// Main page for voice conversations with the AI Discipler.
class VoiceConversationPage extends StatelessWidget {
  /// Optional study guide ID for contextual conversations.
  final String? studyGuideId;

  /// Optional scripture reference for focused discussions.
  final String? relatedScripture;

  /// Conversation type.
  final ConversationType conversationType;

  const VoiceConversationPage({
    super.key,
    this.studyGuideId,
    this.relatedScripture,
    this.conversationType = ConversationType.general,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<VoiceConversationBloc>(),
      child: _VoiceConversationView(
        studyGuideId: studyGuideId,
        relatedScripture: relatedScripture,
        conversationType: conversationType,
      ),
    );
  }
}

class _VoiceConversationView extends StatefulWidget {
  final String? studyGuideId;
  final String? relatedScripture;
  final ConversationType conversationType;

  const _VoiceConversationView({
    this.studyGuideId,
    this.relatedScripture,
    required this.conversationType,
  });

  @override
  State<_VoiceConversationView> createState() => _VoiceConversationViewState();
}

class _VoiceConversationViewState extends State<_VoiceConversationView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  bool _isTextInputMode = false;

  @override
  void initState() {
    super.initState();
    // Load preferences to get default language, then check quota
    context.read<VoiceConversationBloc>().add(const LoadPreferences());
    context.read<VoiceConversationBloc>().add(const CheckQuota());
  }

  VoiceLanguage get _selectedLanguage {
    final state = context.read<VoiceConversationBloc>().state;
    return VoiceLanguage.fromCode(state.languageCode);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _startConversation() {
    context.read<VoiceConversationBloc>().add(StartConversation(
          languageCode: _selectedLanguage.code,
          conversationType: widget.conversationType,
          relatedStudyGuideId: widget.studyGuideId,
          relatedScripture: widget.relatedScripture,
        ));
  }

  void _endConversation() {
    // Capture the bloc from the widget context before showing the dialog
    // The dialog's context doesn't have access to the BlocProvider
    final bloc = context.read<VoiceConversationBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => _EndConversationDialog(
        onEnd: (rating, feedback, helpful) {
          bloc.add(EndConversation(
            rating: rating,
            feedbackText: feedback,
            wasHelpful: helpful,
          ));
          // Check voice achievements when session ends
          sl<GamificationBloc>().add(const CheckVoiceAchievements());
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      context.read<VoiceConversationBloc>().add(SendTextMessage(text));
      _textController.clear();
      _scrollToBottom();
    }
  }

  void _onLanguageChanged(VoiceLanguage language) {
    context.read<VoiceConversationBloc>().add(ChangeLanguage(language.code));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: BlocConsumer<VoiceConversationBloc, VoiceConversationState>(
          listener: (context, state) {
            // Show error snackbar
            if (state.status == VoiceConversationStatus.error &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            }

            // Scroll to bottom when new messages arrive
            if (state.messages.isNotEmpty) {
              _scrollToBottom();
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // Quota indicator
                if (state.quota != null) _buildQuotaIndicator(state),

                // Main content
                Expanded(
                  child: _buildContent(state),
                ),

                // Input area
                if (state.hasActiveConversation) _buildInputArea(state),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _handleBackNavigation,
      ),
      title: Text(context.tr('voice_buddy.title')),
      actions: [
        // Settings/preferences
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await context.push(AppRoutes.voicePreferences);
            // Reload preferences when returning from settings
            if (mounted) {
              context
                  .read<VoiceConversationBloc>()
                  .add(const LoadPreferences());
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuotaIndicator(VoiceConversationState state) {
    final theme = Theme.of(context);
    final quota = state.quota!;

    // Check if premium user (unlimited quota)
    final isPremium = quota.tier == 'premium' || quota.quotaRemaining < 0;
    final isLow = !isPremium && quota.quotaRemaining <= 1;

    // If notifications are disabled and quota is not critically low, don't show
    if (!state.notifyDailyQuotaReached && !isLow) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isLow
          ? theme.colorScheme.error.withAlpha((0.1 * 255).round())
          : theme.colorScheme.primary.withAlpha((0.1 * 255).round()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLow ? Icons.warning_amber : Icons.info_outline,
            size: 16,
            color: isLow ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '${context.tr('voice_buddy.conversations_remaining')}: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  isLow ? theme.colorScheme.error : theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isPremium)
            Icon(
              Icons.all_inclusive,
              size: 16,
              color: theme.colorScheme.primary,
            )
          else
            Text(
              '${quota.quotaRemaining}/${quota.quotaLimit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    isLow ? theme.colorScheme.error : theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(VoiceConversationState state) {
    switch (state.status) {
      case VoiceConversationStatus.initial:
        return _buildStartScreen(state);

      case VoiceConversationStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case VoiceConversationStatus.quotaExceeded:
        return _buildQuotaExceededScreen();

      default:
        return _buildConversationView(state);
    }
  }

  Widget _buildStartScreen(VoiceConversationState state) {
    final theme = Theme.of(context);

    // Get current language from state (supports both 'hi' and 'hi-IN' formats)
    final currentLanguage = VoiceLanguage.fromCode(state.languageCode);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFAF8F5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/AIDiscipler.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            context.tr('voice_buddy.title'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            context.tr('voice_buddy.description'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            ),
          ),
          const SizedBox(height: 16),

          // Current language indicator
          Text(
            '${context.tr('voice_buddy.language_label')}: ${currentLanguage.displayName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          const SizedBox(height: 32),

          // Start button
          FilledButton.icon(
            onPressed: state.canStartConversation
                ? () => _startConversationWithState(state)
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(context.tr('voice_buddy.start_conversation')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startConversationWithState(VoiceConversationState state) {
    context.read<VoiceConversationBloc>().add(StartConversation(
          languageCode: state.languageCode,
          conversationType: widget.conversationType,
          relatedStudyGuideId: widget.studyGuideId,
          relatedScripture: widget.relatedScripture,
        ));
  }

  Widget _buildQuotaExceededScreen() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 80,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('voice_buddy.quota_exceeded.title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('voice_buddy.quota_exceeded.message'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              Navigator.pushNamed(context, '/subscription');
            },
            child:
                Text(context.tr('voice_buddy.quota_exceeded.upgrade_button')),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationView(VoiceConversationState state) {
    // Fetch user profile picture URL once to avoid repeated getter calls
    final userProfilePictureUrl = sl<AuthStateProvider>().profilePictureUrl;

    return Column(
      children: [
        // Messages list
        Expanded(
          child: state.messages.isEmpty
              ? _buildEmptyConversation()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length +
                      // Show extra item for streaming/processing
                      // Allow streaming text to be visible even while TTS plays
                      ((state.status == VoiceConversationStatus.streaming ||
                              state.status ==
                                  VoiceConversationStatus.processing)
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.messages.length) {
                      // Show streaming response or thinking indicator
                      if (state.streamingResponse.isNotEmpty) {
                        return ConversationBubble(
                          content: state.streamingResponse,
                          isUser: false,
                        );
                      }
                      return const ThinkingBubble();
                    }

                    final message = state.messages[index];
                    final isUserMessage = message.role == MessageRole.user;

                    return ConversationBubble(
                      content: message.contentText,
                      isUser: isUserMessage,
                      scriptureReferences: message.scriptureReferences,
                      timestamp: message.createdAt,
                      onScriptureReferenceTap: (ref) {
                        ScriptureVerseSheet.show(context, reference: ref);
                      },
                      userProfilePictureUrl:
                          isUserMessage ? userProfilePictureUrl : null,
                    );
                  },
                ),
        ),

        // Current transcription display (only if showTranscription is enabled)
        if (state.showTranscription &&
            state.isListening &&
            state.currentTranscription != null)
          _buildTranscriptionDisplay(state.currentTranscription!),
      ],
    );
  }

  Widget _buildEmptyConversation() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.primary.withAlpha((0.3 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('voice_buddy.conversation.empty_hint'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color:
                    theme.colorScheme.onSurface.withAlpha((0.5 * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionDisplay(String transcription) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primary.withAlpha((0.1 * 255).round()),
      child: Row(
        children: [
          const Icon(Icons.mic, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transcription,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(VoiceConversationState state) {
    final theme = Theme.of(context);
    final isProcessing = state.status == VoiceConversationStatus.processing ||
        state.status == VoiceConversationStatus.streaming;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle between voice and text input
            Row(
              children: [
                // Text input toggle
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isTextInputMode = !_isTextInputMode;
                    });
                    if (_isTextInputMode) {
                      _textFocusNode.requestFocus();
                    }
                  },
                  icon: Icon(
                    _isTextInputMode ? Icons.mic : Icons.keyboard,
                    color: theme.colorScheme.primary,
                  ),
                ),

                // Text input field
                if (_isTextInputMode)
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      enabled: !isProcessing,
                      decoration: InputDecoration(
                        hintText:
                            context.tr('voice_buddy.conversation.type_hint'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        suffixIcon: IconButton(
                          onPressed: isProcessing ? null : _sendTextMessage,
                          icon: const Icon(Icons.send),
                        ),
                      ),
                      onSubmitted: (_) => _sendTextMessage(),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: _buildVoiceControls(state),
                    ),
                  ),

                // End conversation button
                IconButton(
                  onPressed: _endConversation,
                  icon: const Icon(Icons.stop_circle_outlined),
                  color: theme.colorScheme.error,
                  tooltip: context.tr('voice_buddy.voice_controls.end_tooltip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceControls(VoiceConversationState state) {
    VoiceButtonState buttonState;

    // Priority: isPlaying > isListening > processing > idle
    // isPlaying takes priority because we want to show speaking animation
    // during TTS playback even if continuous mode has listening enabled
    if (state.isPlaying) {
      // TTS is playing - show speaking state (highest priority)
      buttonState = VoiceButtonState.speaking;
    } else if (state.isListening) {
      buttonState = VoiceButtonState.listening;
    } else if (state.status == VoiceConversationStatus.processing ||
        state.status == VoiceConversationStatus.streaming) {
      buttonState = VoiceButtonState.processing;
    } else {
      buttonState = VoiceButtonState.idle;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VoiceButton(
          state: buttonState,
          isContinuousMode: state.isContinuousMode,
          // Continuous mode: tap to toggle
          // Speaking state: tap to interrupt and start listening
          onTap: () {
            if (state.isPlaying) {
              // Interrupt TTS and start listening
              context.read<VoiceConversationBloc>().add(const StopPlayback());
              context.read<VoiceConversationBloc>().add(const StartListening());
            } else if (state.isListening) {
              context.read<VoiceConversationBloc>().add(const StopListening());
            } else {
              context.read<VoiceConversationBloc>().add(const StartListening());
            }
          },
          // Normal mode: hold to speak
          onTapDown: () {
            context.read<VoiceConversationBloc>().add(const StartListening());
          },
          onTapUp: () {
            context.read<VoiceConversationBloc>().add(const StopListening());
          },
          onTapCancel: () {
            context.read<VoiceConversationBloc>().add(const StopListening());
          },
        ),
        const SizedBox(height: 8),
        Text(
          _getVoiceHint(buttonState, state.isContinuousMode),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.5 * 255).round()),
              ),
        ),
      ],
    );
  }

  String _getVoiceHint(VoiceButtonState buttonState, bool isContinuousMode) {
    switch (buttonState) {
      case VoiceButtonState.listening:
        return isContinuousMode
            ? context.tr('voice_buddy.voice_controls.listening_continuous')
            : context.tr('voice_buddy.voice_controls.listening_hold');
      case VoiceButtonState.processing:
        return context.tr('voice_buddy.voice_controls.processing');
      case VoiceButtonState.speaking:
        return context.tr('voice_buddy.voice_controls.tap_to_interrupt');
      case VoiceButtonState.idle:
        return isContinuousMode
            ? context.tr('voice_buddy.voice_controls.tap_to_speak')
            : context.tr('voice_buddy.voice_controls.hold_to_speak');
    }
  }

  /// Handle back navigation - go to generate study screen when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.generateStudy);
    }
  }
}

/// Dialog for ending conversation with optional feedback.
class _EndConversationDialog extends StatefulWidget {
  final void Function(int? rating, String? feedback, bool? helpful) onEnd;

  const _EndConversationDialog({required this.onEnd});

  @override
  State<_EndConversationDialog> createState() => _EndConversationDialogState();
}

class _EndConversationDialogState extends State<_EndConversationDialog> {
  int? _rating;
  bool? _wasHelpful;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.tr('voice_buddy.conversation.end_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('voice_buddy.conversation.end_experience')),
            const SizedBox(height: 12),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  icon: Icon(
                    index < (_rating ?? 0) ? Icons.star : Icons.star_border,
                    color: theme.colorScheme.secondary,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Was it helpful?
            Text(context.tr('voice_buddy.conversation.end_helpful')),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(context.tr('voice_buddy.conversation.yes')),
                  selected: _wasHelpful == true,
                  onSelected: (selected) {
                    setState(() {
                      _wasHelpful = selected ? true : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(context.tr('voice_buddy.conversation.no')),
                  selected: _wasHelpful == false,
                  onSelected: (selected) {
                    setState(() {
                      _wasHelpful = selected ? false : null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Feedback text
            TextField(
              controller: _feedbackController,
              decoration: InputDecoration(
                labelText: context.tr('voice_buddy.conversation.end_feedback'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('voice_buddy.conversation.cancel')),
        ),
        FilledButton(
          onPressed: () {
            widget.onEnd(
              _rating,
              _feedbackController.text.trim().isEmpty
                  ? null
                  : _feedbackController.text.trim(),
              _wasHelpful,
            );
          },
          child: Text(context.tr('voice_buddy.conversation.end_button')),
        ),
      ],
    );
  }
}
