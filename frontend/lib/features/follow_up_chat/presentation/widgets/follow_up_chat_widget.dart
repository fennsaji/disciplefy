import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/numbered_section_header.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../bloc/follow_up_chat_bloc.dart';
import '../bloc/follow_up_chat_event.dart';
import '../bloc/follow_up_chat_state.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../community/presentation/widgets/discipler_badges.dart';
import 'chat_bubble.dart';
import 'chat_input.dart';

/// Main widget for the follow-up chat interface
class FollowUpChatWidget extends StatefulWidget {
  final String studyGuideId;
  final String studyGuideTitle;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final bool enableVoiceInput;

  /// Position of this block in the guide, shown as a gold `08` before the
  /// heading so numbering runs on from the guide's sections. Null hides it.
  final int? sectionNumber;

  const FollowUpChatWidget({
    super.key,
    required this.studyGuideId,
    required this.studyGuideTitle,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.enableVoiceInput = true,
    this.sectionNumber,
  });

  @override
  State<FollowUpChatWidget> createState() => _FollowUpChatWidgetState();
}

class _FollowUpChatWidgetState extends State<FollowUpChatWidget>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _hasInitialized = false;

  // Builder context from ShowCaseWidget — use this for ShowCaseWidget.of() calls.
  BuildContext? _showcaseContext;

  /// Advances the showcase to the next step.
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(
          milliseconds: AppConstants.DEFAULT_ANIMATION_DURATION_MS),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    if (widget.isExpanded) {
      _expandController.value = 1.0;
    }

    _initializeConversation();
    _triggerWalkthroughIfNeeded();
  }

  /// Dispatches StartConversationEvent once on widget initialization.
  /// Called from initState to avoid infinite loop on widget rebuilds.
  void _initializeConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized && mounted) {
        _hasInitialized = true;
        try {
          context.read<FollowUpChatBloc>().add(StartConversationEvent(
                studyGuideId: widget.studyGuideId,
                studyGuideTitle: widget.studyGuideTitle,
              ));
        } catch (e) {
          // Silently handle BLoC access errors during initialization
        }
      }
    });
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.discipler)) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        ShowcaseKeys.disciplerInput,
        ShowcaseKeys.disciplerSend,
      ]);
    });
  }

  @override
  void didUpdateWidget(FollowUpChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: StartConversationEvent is dispatched in initState() to avoid infinite loop
    // DO NOT dispatch events in build() - it causes rebuilds on every state change!

    // Check if there's already a FollowUpChatBloc in the context
    Widget chatContent;
    try {
      context.read<FollowUpChatBloc>();
      chatContent = _buildChatInterface();
    } catch (e) {
      // No existing bloc, create a new one
      chatContent = BlocProvider(
        create: (context) => sl<FollowUpChatBloc>(),
        child: _buildChatInterface(),
      );
    }

    return ShowCaseWidget(
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.discipler),
      builder: (showcaseContext) {
        _showcaseContext = showcaseContext;
        return chatContent;
      },
    );
  }

  Widget _buildChatInterface() {
    final theme = Theme.of(context);

    // Flat on the page, like the guide's sections: numbered heading, credit
    // caption, then the conversation. The caller supplies side padding.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(theme),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: _buildChatContent(),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      button: true,
      label:
          '${context.tr(TranslationKeys.followUpChatTitle)}. ${widget.isExpanded ? context.tr(TranslationKeys.followUpChatExpanded) : context.tr(TranslationKeys.followUpChatCollapsed)}. ${context.tr(TranslationKeys.followUpChatDoubleTapTo)} ${widget.isExpanded ? context.tr(TranslationKeys.followUpChatCollapse) : context.tr(TranslationKeys.followUpChatExpand)}',
      onTap: widget.onToggleExpanded,
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onToggleExpanded,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NumberedSectionHeader(
                number: widget.sectionNumber,
                title: context.tr(TranslationKeys.followUpChatTitle),
                trailing: [_buildHeaderIndicator(palette)],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(TranslationKeys.followUpChatTokenCost),
                style: AppFonts.inter(fontSize: 13, color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIndicator(ReaderPalette palette) {
    return AnimatedRotation(
      turns: widget.isExpanded ? 0.5 : 0,
      duration: const Duration(
          milliseconds: AppConstants.DEFAULT_ANIMATION_DURATION_MS),
      child: Icon(Icons.expand_more_rounded, color: palette.muted),
    );
  }

  Widget _buildChatContent() {
    return BlocConsumer<FollowUpChatBloc, FollowUpChatState>(
      listener: (context, state) {
        if (state is FollowUpChatLoaded) {
          // Auto-scroll when new messages are added
          if (state.messages.isNotEmpty) {
            _scrollToBottom();
          }
        }
      },
      builder: (context, state) {
        if (state is FollowUpChatLoading) {
          return _buildLoadingState();
        } else if (state is FollowUpChatError) {
          return _buildErrorState(state);
        } else if (state is FollowUpChatInsufficientTokens) {
          return _buildInsufficientTokensState(state);
        } else if (state is FollowUpChatFeatureNotAvailable) {
          return _buildFeatureNotAvailableState(state);
        } else if (state is FollowUpChatLimitExceeded) {
          return _buildLimitExceededState(state);
        } else if (state is FollowUpChatLoaded) {
          return _buildLoadedState(state);
        }

        return _buildInitialState();
      },
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatStartingConversation),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(FollowUpChatError state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppConstants.ICON_SIZE_40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatError),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              context.tr(TranslationKeys.commonErrorTryAgain),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            ElevatedButton(
              onPressed: () {
                context.read<FollowUpChatBloc>().add(
                      StartConversationEvent(
                        studyGuideId: widget.studyGuideId,
                        studyGuideTitle: widget.studyGuideTitle,
                      ),
                    );
              },
              child: Text(context.tr(TranslationKeys.followUpChatTryAgain)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsufficientTokensState(FollowUpChatInsufficientTokens state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.token,
              size: AppConstants.ICON_SIZE_40,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatInsufficientTokens),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              context
                  .tr(TranslationKeys.followUpChatInsufficientTokensMessage, {
                'required': state.required,
                'available': state.available,
              }),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            // Wrap, not Row: the two buttons overflow a 320pt phone in the
            // longer languages.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppConstants.SMALL_PADDING,
              runSpacing: AppConstants.SMALL_PADDING,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Dismiss and reload conversation
                    context.read<FollowUpChatBloc>().add(
                          StartConversationEvent(
                            studyGuideId: widget.studyGuideId,
                            studyGuideTitle: widget.studyGuideTitle,
                          ),
                        );
                  },
                  child: Text(context.tr(TranslationKeys.followUpChatDismiss)),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push(AppRoutes.tokenManagement);
                  },
                  child: Text(
                      context.tr(TranslationKeys.followUpChatGetMoreTokens)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureNotAvailableState(FollowUpChatFeatureNotAvailable state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: AppConstants.ICON_SIZE_40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatNotAvailable),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              state.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatUpgradeMessage),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            // Wrap, not Row: the two buttons overflow a 320pt phone in the
            // longer languages.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppConstants.SMALL_PADDING,
              runSpacing: AppConstants.SMALL_PADDING,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Dismiss
                    context.read<FollowUpChatBloc>().add(
                          StartConversationEvent(
                            studyGuideId: widget.studyGuideId,
                            studyGuideTitle: widget.studyGuideTitle,
                          ),
                        );
                  },
                  child: Text(context.tr(TranslationKeys.followUpChatDismiss)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to token management page for upgrade
                    context.push(AppRoutes.tokenManagement);
                  },
                  child:
                      Text(context.tr(TranslationKeys.followUpChatUpgradePlan)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitExceededState(FollowUpChatLimitExceeded state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: AppConstants.ICON_SIZE_40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatLimitReached),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              state.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatLimitMessage),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            // Wrap, not Row: the two buttons overflow a 320pt phone in the
            // longer languages.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppConstants.SMALL_PADDING,
              runSpacing: AppConstants.SMALL_PADDING,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Dismiss and reload conversation
                    context.read<FollowUpChatBloc>().add(
                          StartConversationEvent(
                            studyGuideId: widget.studyGuideId,
                            studyGuideTitle: widget.studyGuideTitle,
                          ),
                        );
                  },
                  child: Text(context.tr(TranslationKeys.followUpChatDismiss)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to generate study guide page
                    context.go(AppRoutes.generateStudy);
                  },
                  child: Text(
                      context.tr(TranslationKeys.followUpChatGenerateNewStudy)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: AppConstants.ICON_SIZE_40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatInitialTitle),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatInitialMessage),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(FollowUpChatLoaded state) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // The conversation grows with its messages up to 60% of the screen
    // (300–600pt), then scrolls inside itself.
    final maxChatHeight = (screenHeight * 0.6).clamp(300.0, 600.0);
    final suggestions = _nextSuggestions(state);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.messages.isEmpty)
            _buildEmptyMessages()
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxChatHeight),
              child: _buildMessagesList(state),
            ),
          if (suggestions.isNotEmpty && !state.isProcessing) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestions)
                  _SuggestionChip(
                    text: suggestion,
                    onTap: () {
                      _inputController.text = suggestion;
                      _inputController.selection = TextSelection.collapsed(
                        offset: suggestion.length,
                      );
                    },
                  ),
              ],
            ),
          ],
          _buildChatInput(state),
        ],
      ),
    );
  }

  /// Questions the reader might ask Discipler, minus ones already asked.
  /// Shown only before the conversation gets going.
  List<String> _nextSuggestions(FollowUpChatLoaded state) {
    if (state.messages.where((m) => m.isUser).length >= 2) return const [];
    final asked = state.messages
        .where((m) => m.isUser)
        .map((m) => m.content.trim().toLowerCase())
        .toSet();
    final prompts = [
      context.tr(TranslationKeys.followUpChatPromptExplain),
      context.tr(TranslationKeys.followUpChatPromptApply),
      context.tr(TranslationKeys.followUpChatPromptVerses),
    ];
    return prompts
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty && !asked.contains(q.toLowerCase()))
        .toList();
  }

  Widget _buildMessagesList(FollowUpChatLoaded state) {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return ChatBubble(
          key: ValueKey('${message.id}_${message.status.toString()}'),
          message: message,
          onRetry: message.status == ChatMessageStatus.failed
              ? () => context
                  .read<FollowUpChatBloc>()
                  .add(RetryMessageEvent(message.id))
              : null,
        );
      },
    );
  }

  /// Discipler's greeting, drawn like one of its replies so the empty
  /// conversation already reads as a chat.
  Widget _buildEmptyMessages() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(
              ChatBubble.avatarAsset,
              width: 32,
              height: 32,
              cacheWidth: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DisciplerAvatar(radius: 16),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A21) : Colors.white,
                borderRadius: const BorderRadius.only(
                    topLeft: tail, topRight: r, bottomLeft: r, bottomRight: r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFF16161D).withOpacity(0.08),
                ),
              ),
              child: Text(
                context.tr(TranslationKeys.followUpChatGreeting),
                style: AppFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark
                      ? const Color(0xFFF2F2F4)
                      : const Color(0xFF16161D),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildChatInput(FollowUpChatLoaded state) {
    return ChatInput(
      controller: _inputController,
      onSendMessage: (message) {
        context.read<FollowUpChatBloc>().add(
              SendQuestionEvent(
                question: message,
                // language: 'en', // TODO: Get from user preferences
              ),
            );
      },
      isEnabled: !state.isProcessing,
      isProcessing: state.isProcessing,
      onCancel: state.isProcessing
          ? () =>
              context.read<FollowUpChatBloc>().add(const CancelRequestEvent())
          : null,
      enableVoiceInput: widget.enableVoiceInput,
      onNext: _showcaseContext != null ? _onNext : null,
    );
  }
}

/// Outlined pill offering a suggested follow-up question.
class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: palette.outline)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 16, color: palette.accentIcon),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
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
