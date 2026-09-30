import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/data/services/speech_service.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_conversation_state.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/conversation_bubble.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_session_widgets.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/discipler_start_view.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/end_conversation_sheet.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/language_selector.dart'
    show VoiceLanguage, VoiceLanguageSheet;
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/mic_permission_dialog.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/voice_button.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/voice_session_view.dart';
import 'package:disciplefy_bible_study/shared/widgets/scripture_verse_sheet.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// Main page for conversations with Discipler, by voice or by text.
class VoiceConversationPage extends StatelessWidget {
  /// Optional study guide ID for contextual conversations.
  final String? studyGuideId;

  /// Optional scripture reference for focused discussions.
  final String? relatedScripture;

  /// Conversation type.
  final ConversationType conversationType;

  /// Shown as the Discipler tab in the bottom bar rather than as a pushed
  /// full-screen page: no back arrow, and back is handled by the tab bar.
  final bool asTab;

  const VoiceConversationPage({
    super.key,
    this.studyGuideId,
    this.relatedScripture,
    this.conversationType = ConversationType.general,
    this.asTab = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<VoiceConversationBloc>(),
      child: _VoiceConversationView(
        studyGuideId: studyGuideId,
        relatedScripture: relatedScripture,
        conversationType: conversationType,
        asTab: asTab,
      ),
    );
  }
}

class _VoiceConversationView extends StatefulWidget {
  final String? studyGuideId;
  final String? relatedScripture;
  final ConversationType conversationType;
  final bool asTab;

  const _VoiceConversationView({
    this.studyGuideId,
    this.relatedScripture,
    required this.conversationType,
    this.asTab = false,
  });

  @override
  State<_VoiceConversationView> createState() => _VoiceConversationViewState();
}

class _VoiceConversationViewState extends State<_VoiceConversationView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  /// Chat (typing) view instead of the hands-free voice view.
  bool _isTextInputMode = false;

  /// Continuous mode is paused while typing and restored on return to voice.
  bool _continuousBeforeTyping = false;

  /// Guards against a second mic-permission dialog stacking on the first when
  /// the bloc re-emits the denied state.
  bool _micPermissionSheetOpen = false;

  /// A suggested question to send as soon as the conversation it started is
  /// ready.
  String? _pendingFirstMessage;

  /// Focus the text field once the conversation started by "Type" is ready.
  bool _focusTextWhenReady = false;

  /// Start listening once the conversation started by "Start talking" is
  /// ready, so the user can speak straight away instead of tapping again.
  bool _listenWhenReady = false;

  /// Whether the previous state had a conversation, to notice it ending.
  bool _hadConversation = false;

  @override
  void initState() {
    super.initState();
    // Load preferences to get default language, then check quota
    context.read<VoiceConversationBloc>().add(const LoadPreferences());
    context.read<VoiceConversationBloc>().add(const CheckQuota());
  }

  /// As a tab, this page stays alive (offstage) while another tab is shown.
  /// The shell turns tickers off for hidden branches; use that as the cue to
  /// stop the microphone and any spoken reply, so Discipler never keeps
  /// listening or talking from a tab the user has left.
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.asTab) return;
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible && !visible) {
      final bloc = context.read<VoiceConversationBloc>();
      bloc.add(const StopListening());
      bloc.add(const StopPlayback());
    }
    _visible = visible;
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
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _endConversation() {
    // Capture the bloc from the widget context before showing the sheet:
    // the sheet's context doesn't have access to the BlocProvider.
    final bloc = context.read<VoiceConversationBloc>();

    EndConversationSheet.show(
      context,
      onEnd: (rating, feedback, helpful) {
        bloc.add(EndConversation(
          rating: rating,
          feedbackText: feedback,
          wasHelpful: helpful,
        ));
        // Check voice achievements when session ends
        sl<GamificationBloc>().add(const CheckVoiceAchievements());
      },
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

  void _switchToTyping() {
    final bloc = context.read<VoiceConversationBloc>();
    // Typing means the mic should be off: drop any half-spoken sentence and
    // stop continuous mode from reopening the mic after the next reply.
    if (bloc.state.isListening) bloc.add(const CancelListening());
    if (bloc.state.isContinuousMode) {
      _continuousBeforeTyping = true;
      bloc.add(const ToggleContinuousMode(false));
    }
    setState(() => _isTextInputMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocusNode.requestFocus();
    });
  }

  void _switchToVoice() {
    if (_continuousBeforeTyping) {
      _continuousBeforeTyping = false;
      context
          .read<VoiceConversationBloc>()
          .add(const ToggleContinuousMode(true));
    }
    _textFocusNode.unfocus();
    setState(() => _isTextInputMode = false);
  }

  Future<void> _openSettings() async {
    await context.push(AppRoutes.voicePreferences);
    // Reload preferences when returning from settings
    if (mounted) {
      context.read<VoiceConversationBloc>().add(const LoadPreferences());
    }
  }

  /// Opens the language sheet. "Default" resolves to the study content
  /// language here, as preferences do, because a conversation needs a
  /// concrete language code.
  Future<void> _openLanguageSheet(VoiceConversationState state) async {
    final bloc = context.read<VoiceConversationBloc>();
    final chosen = await VoiceLanguageSheet.show(
      context,
      selectedLanguage: VoiceLanguage.fromCode(state.languageCode),
    );
    if (chosen == null) return;
    final code = chosen.isDefault ? await _defaultVoiceCode() : chosen.code;
    if (!mounted) return;
    bloc.add(ChangeLanguage(code));
  }

  Future<String> _defaultVoiceCode() async {
    try {
      final language =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      final voice = VoiceLanguage.fromCode(language.code);
      return voice.isDefault ? VoiceLanguage.english.code : voice.code;
    } catch (e) {
      Logger.warning('Voice language: could not resolve default: $e');
      return VoiceLanguage.english.code;
    }
  }

  String _languageName(VoiceConversationState state) {
    final language = VoiceLanguage.fromCode(state.languageCode);
    return language.isDefault
        ? context.tr('voice_buddy.settings.default_language')
        : language.displayName;
  }

  QuotaDisplay? _quotaDisplay(VoiceConversationState state) =>
      state.quota == null
          ? null
          : QuotaDisplay(
              state.quota!,
              notifyQuota: state.notifyDailyQuotaReached,
            );

  void _onStateChanged(BuildContext context, VoiceConversationState state) {
    final bloc = context.read<VoiceConversationBloc>();

    // Show monthly limit exceeded dialog (mid-conversation server rejection)
    if (state is VoiceConversationMonthlyLimitExceeded) {
      _showVoiceUpsell(state.tier);
    }

    // Show limit dialog when server rejects start (quota was unknown or stale)
    if (state.status == VoiceConversationStatus.quotaExceeded) {
      _showVoiceUpsell(state.quota?.tier ?? 'free');
    }

    // A declined microphone is a choice, not a failure — explain what
    // it blocks and offer the way back instead of a red error.
    if (state.status == VoiceConversationStatus.micPermissionDenied) {
      _showMicPermissionSheet(
        context,
        permanentlyDenied: state.micPermissionPermanentlyDenied,
      );
    }

    // Show error snackbar
    if (state.status == VoiceConversationStatus.error &&
        state.errorMessage != null) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.commonError),
        tone: AppSnackTone.error,
      );
    }

    if (state.hasActiveConversation &&
        state.status == VoiceConversationStatus.ready) {
      // A suggested question or "Type" started this conversation.
      final pending = _pendingFirstMessage;
      if (pending != null) {
        _pendingFirstMessage = null;
        bloc.add(SendTextMessage(pending));
      }
      if (_focusTextWhenReady) {
        _focusTextWhenReady = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _textFocusNode.requestFocus();
        });
      }
      // Same event as the mic button; a declined microphone still comes
      // back as the permission dialog.
      if (_listenWhenReady) {
        _listenWhenReady = false;
        bloc.add(const StartListening());
      }
    } else if (state.conversation == null &&
        state.status != VoiceConversationStatus.loading) {
      // The start failed or was refused: nothing to send into.
      _pendingFirstMessage = null;
      _focusTextWhenReady = false;
      _listenWhenReady = false;
    }

    // Ending a conversation resets the bloc to a blank state, which also
    // drops the loaded preferences and allowance; reload them for the
    // start screen and go back to the voice view for the next one.
    if (_hadConversation &&
        state.conversation == null &&
        state.status == VoiceConversationStatus.initial) {
      bloc.add(const LoadPreferences());
      bloc.add(const CheckQuota());
      _textController.clear();
      if (_isTextInputMode) setState(() => _isTextInputMode = false);
    }
    _hadConversation = state.conversation != null;

    // Scroll to bottom when new messages arrive
    if (state.messages.isNotEmpty) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopScope(
      // As a tab, back belongs to the tab bar (AppShell returns to Home).
      canPop: widget.asTab,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || widget.asTab) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: palette.page,
        body: BlocConsumer<VoiceConversationBloc, VoiceConversationState>(
          listener: _onStateChanged,
          builder: (context, state) => _buildContent(state),
        ),
      ),
    );
  }

  Widget _buildContent(VoiceConversationState state) {
    if (state.status == VoiceConversationStatus.loading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // No conversation to show (not started, refused, failed to start, or
    // ended): the start screen, so a new one can always be started.
    if (state.conversation == null && state.messages.isEmpty) {
      return DisciplerStartView(
        quota: _quotaDisplay(state),
        languageName: _languageName(state),
        onBack: widget.asTab ? null : _handleBackNavigation,
        onSettings: _openSettings,
        onLanguageTap: () => _openLanguageSheet(state),
        onStartTalking: () => _startConversationWithState(state),
        onType: () => _startConversationWithState(state, typing: true),
        onSuggestion: (text) => _startConversationWithState(
          state,
          typing: true,
          firstMessage: text,
        ),
      );
    }

    if (_isTextInputMode || !state.hasActiveConversation) {
      return _buildConversationView(state);
    }
    return _buildVoiceView(state);
  }

  /// Explains what a declined microphone blocks, and offers the way back.
  ///
  /// Deliberately not an error dialog: typing still works, so this only asks
  /// again (or points at settings when the OS will no longer prompt).
  void _showMicPermissionSheet(
    BuildContext context, {
    required bool permanentlyDenied,
  }) {
    if (_micPermissionSheetOpen) return;
    _micPermissionSheetOpen = true;
    final bloc = context.read<VoiceConversationBloc>();

    showDialog<void>(
      context: context,
      builder: (_) => MicPermissionDialog(
        permanentlyDenied: permanentlyDenied,
        onPrimary: () {
          if (permanentlyDenied) {
            sl<SpeechService>().openPermissionSettings();
          } else {
            // The OS will prompt again; re-running the flow is the retry.
            bloc.add(const StartListening());
          }
        },
        onTypeInstead: () {
          if (mounted && bloc.state.hasActiveConversation) _switchToTyping();
        },
      ),
    ).whenComplete(() => _micPermissionSheetOpen = false);
  }

  /// The single upgrade sheet for every case where Talk to Discipler is
  /// unavailable — no allowance on this plan, allowance spent, or the server
  /// rejecting a start. The user's next step is the same in all of them.
  void _showVoiceUpsell(String tier) {
    showModalBottomSheet(
      // Above the floating dock, not under it.
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UpgradeDialog(
        featureKey: 'ai_discipler',
        currentPlan: tier,
        requiredPlans: const ['standard', 'plus', 'premium'],
      ),
    );
  }

  /// Starts a conversation, in the voice view or — with [typing] — the chat
  /// view, optionally sending [firstMessage] once it is ready.
  void _startConversationWithState(
    VoiceConversationState state, {
    bool typing = false,
    String? firstMessage,
  }) {
    final quota = state.quota;
    // Anyone who cannot start gets the same upgrade sheet, whether their plan
    // never included Talk to Discipler (free is 0/month) or they used up this
    // month's allowance. Two different dialogs for "you cannot start" was a
    // distinction that mattered to the code, not to the person reading it.
    if (quota != null && !quota.canStart) {
      _showVoiceUpsell(quota.tier);
      return;
    }
    setState(() => _isTextInputMode = typing);
    _pendingFirstMessage = firstMessage;
    _focusTextWhenReady = typing && firstMessage == null;
    _listenWhenReady = !typing && firstMessage == null;
    context.read<VoiceConversationBloc>().add(StartConversation(
          languageCode: state.languageCode,
          conversationType: widget.conversationType,
          relatedStudyGuideId: widget.studyGuideId,
          relatedScripture: widget.relatedScripture,
        ));
  }

  // ---------------------------------------------------------------------------
  // Chat view
  // ---------------------------------------------------------------------------

  Widget _buildConversationView(VoiceConversationState state) {
    final quota = _quotaDisplay(state);
    return Column(
      children: [
        _buildChatHeader(state),
        if (quota != null && quota.isVisible)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DisciplerQuotaChip(display: quota),
            ),
          ),
        Expanded(
          child: state.messages.isEmpty
              ? _buildEmptyConversation()
              : _buildMessageList(state),
        ),

        // Current transcription display (only if showTranscription is enabled)
        if (state.showTranscription &&
            state.isListening &&
            state.currentTranscription != null)
          _buildTranscriptionDisplay(state.currentTranscription!),

        if (state.hasActiveConversation) _buildInputArea(state),
      ],
    );
  }

  Widget _buildChatHeader(VoiceConversationState state) {
    final palette = ReaderPalette.of(context);
    final buttonState = chatStatusFor(state);
    final dotColor = switch (buttonState) {
      VoiceButtonState.idle => AppColors.success,
      VoiceButtonState.listening => palette.accentIcon,
      VoiceButtonState.processing || VoiceButtonState.speaking => palette.gold,
    };

    return Container(
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(widget.asTab ? 16 : 4, 8, 12, 10),
          child: Row(
            children: [
              if (!widget.asTab)
                IconButton(
                  onPressed: _handleBackNavigation,
                  icon: const Icon(Icons.arrow_back),
                  color: palette.text,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              const DisciplerAvatar(radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('voice_buddy.title'),
                      style: AppFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${sessionStatusLabel(context, buttonState)} · '
                            '${_languageName(state)}',
                            style: AppFonts.inter(
                              fontSize: 13,
                              color: palette.muted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (state.hasActiveConversation) ...[
                IconButton(
                  onPressed: _switchToVoice,
                  icon: const Icon(Icons.graphic_eq_rounded),
                  color: palette.accentIcon,
                  tooltip: context.tr(TranslationKeys.voiceSessionVoiceMode),
                ),
                const SizedBox(width: 2),
                SessionEndPill(onPressed: _endConversation),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(VoiceConversationState state) {
    final showPending = state.status == VoiceConversationStatus.streaming ||
        state.status == VoiceConversationStatus.processing;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      // Extra item for the reply being streamed (visible even while TTS
      // plays) or the typing indicator.
      itemCount: state.messages.length + (showPending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.messages.length) {
          if (state.streamingResponse.isNotEmpty) {
            return ConversationBubble(
              content: state.streamingResponse,
              isUser: false,
            );
          }
          return const ThinkingBubble();
        }

        final message = state.messages[index];
        return ConversationBubble(
          content: message.contentText,
          isUser: message.role == MessageRole.user,
          scriptureReferences: message.scriptureReferences,
          timestamp: message.createdAt,
          onScriptureReferenceTap: (ref) {
            ScriptureVerseSheet.show(context, reference: ref);
          },
        );
      },
    );
  }

  Widget _buildEmptyConversation() {
    final palette = ReaderPalette.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DisciplerAvatar(radius: 28),
            const SizedBox(height: 16),
            Text(
              context.tr('voice_buddy.conversation.empty_hint'),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 15,
                color: palette.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionDisplay(String transcription) {
    final palette = ReaderPalette.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: userBubbleFill(palette),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mic, size: 16, color: palette.accentIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transcription,
              style: AppFonts.inter(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: palette.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(VoiceConversationState state) {
    final palette = ReaderPalette.of(context);
    final isProcessing = state.status == VoiceConversationStatus.processing ||
        state.status == VoiceConversationStatus.streaming;

    return Container(
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocusNode,
                  enabled: !isProcessing,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: AppFonts.inter(fontSize: 15, color: palette.text),
                  decoration: InputDecoration(
                    hintText: context.tr('voice_buddy.conversation.type_hint'),
                    hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
                    filled: true,
                    fillColor: palette.raised,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide(color: palette.outline),
                    ),
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
              const SizedBox(width: 8),
              SessionRoundButton(
                icon: Icons.mic_none_rounded,
                tooltip: context.tr(TranslationKeys.voiceSessionVoiceMode),
                onPressed: _switchToVoice,
                fill: palette.raised,
                ink: palette.accentIcon,
              ),
              const SizedBox(width: 8),
              SessionRoundButton(
                icon: Icons.arrow_upward_rounded,
                tooltip: context.tr(TranslationKeys.voiceSessionSend),
                onPressed: isProcessing ? null : _sendTextMessage,
                fill: AppColors.brandPrimary,
                ink: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Voice view
  // ---------------------------------------------------------------------------

  Widget _buildVoiceView(VoiceConversationState state) {
    final bloc = context.read<VoiceConversationBloc>();
    final buttonState = voiceButtonStateFor(state);

    return VoiceSessionView(
      state: state,
      languageName: _languageName(state),
      hint: _getVoiceHint(buttonState, state.isContinuousMode),
      quota: _quotaDisplay(state),
      onBack: widget.asTab ? null : _handleBackNavigation,
      onSettings: _openSettings,
      onKeyboard: _switchToTyping,
      onEnd: _endConversation,
      // Interrupt the spoken reply and start listening.
      onInterrupt: () {
        bloc.add(const StopPlayback());
        bloc.add(const StartListening());
      },
      // Continuous mode: tap to toggle. Speaking: tap to interrupt.
      onVoiceTap: () {
        final current = bloc.state;
        if (current.isPlaying) {
          bloc.add(const StopPlayback());
          bloc.add(const StartListening());
        } else if (current.isListening) {
          bloc.add(const StopListening());
        } else {
          bloc.add(const StartListening());
        }
      },
      // Hold mode: press to speak, release to send.
      onVoiceTapDown: () => bloc.add(const StartListening()),
      onVoiceTapUp: () => bloc.add(const StopListening()),
      onVoiceTapCancel: () => bloc.add(const StopListening()),
      onScriptureReferenceTap: (ref) =>
          ScriptureVerseSheet.show(context, reference: ref),
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
