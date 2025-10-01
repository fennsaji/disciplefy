import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../bloc/follow_up_chat_bloc.dart';
import '../bloc/follow_up_chat_event.dart';
import '../bloc/follow_up_chat_state.dart';
import 'chat_bubble.dart';
import 'chat_input.dart';

/// Main widget for the follow-up chat interface
class FollowUpChatWidget extends StatefulWidget {
  final String studyGuideId;
  final String studyGuideTitle;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  const FollowUpChatWidget({
    super.key,
    required this.studyGuideId,
    required this.studyGuideTitle,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  State<FollowUpChatWidget> createState() => _FollowUpChatWidgetState();
}

class _FollowUpChatWidgetState extends State<FollowUpChatWidget>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

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
    print(
        '[FollowUpChatWidget] 🏠 Building widget for study guide: ${widget.studyGuideId}');
    print(
        '[FollowUpChatWidget] 📝 Study guide title: ${widget.studyGuideTitle}');

    // Check if there's already a FollowUpChatBloc in the context
    try {
      final existingBloc = context.read<FollowUpChatBloc>();
      print(
          '[FollowUpChatWidget] 🔍 Found existing FollowUpChatBloc in context');
      // If there's an existing bloc, dispatch the event to it
      existingBloc.add(StartConversationEvent(
        studyGuideId: widget.studyGuideId,
        studyGuideTitle: widget.studyGuideTitle,
      ));
      return _buildChatInterface();
    } catch (e) {
      print(
          '[FollowUpChatWidget] 🆕 No existing FollowUpChatBloc found, creating new one');
    }

    return BlocProvider(
      create: (context) {
        try {
          print('[FollowUpChatWidget] 🎨 Creating FollowUpChatBloc');
          final bloc = sl<FollowUpChatBloc>();
          print('[FollowUpChatWidget] ✅ Successfully created FollowUpChatBloc');
          print('[FollowUpChatWidget] 📨 Dispatching StartConversationEvent');
          bloc.add(StartConversationEvent(
            studyGuideId: widget.studyGuideId,
            studyGuideTitle: widget.studyGuideTitle,
          ));
          print(
              '[FollowUpChatWidget] ✅ Successfully dispatched StartConversationEvent');
          return bloc;
        } catch (e, stackTrace) {
          print('[FollowUpChatWidget] ❌ Error creating FollowUpChatBloc: $e');
          print('[FollowUpChatWidget] 📝 Stack trace: $stackTrace');
          rethrow;
        }
      },
      child: _buildChatInterface(),
    );
  }

  Widget _buildChatInterface() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.LARGE_BORDER_RADIUS),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: _buildChatContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.DEFAULT_PADDING,
        vertical: AppConstants.SMALL_PADDING,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.LARGE_BORDER_RADIUS),
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.EXTRA_SMALL_PADDING),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(AppConstants.SMALL_BORDER_RADIUS),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: AppConstants.ICON_SIZE_16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppConstants.SMALL_PADDING),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow-up Questions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  widget.studyGuideTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onToggleExpanded,
            icon: AnimatedRotation(
              turns: widget.isExpanded ? 0.5 : 0,
              duration: const Duration(
                  milliseconds: AppConstants.DEFAULT_ANIMATION_DURATION_MS),
              child: Icon(
                Icons.expand_more,
                color: theme.colorScheme.onSurface,
              ),
            ),
            tooltip: widget.isExpanded ? 'Collapse chat' : 'Expand chat',
          ),
        ],
      ),
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
      height: 300,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
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
              'Starting conversation...',
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
      height: 300,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
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
              'Chat Error',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
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
            ElevatedButton(
              onPressed: () {
                context.read<FollowUpChatBloc>().add(
                      StartConversationEvent(
                        studyGuideId: widget.studyGuideId,
                        studyGuideTitle: widget.studyGuideTitle,
                      ),
                    );
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsufficientTokensState(FollowUpChatInsufficientTokens state) {
    final theme = Theme.of(context);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
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
              'Insufficient Tokens',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              'You need ${state.required} tokens but only have ${state.available} available.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: AppConstants.SMALL_PADDING),
                ElevatedButton(
                  onPressed: () {
                    context.push(AppRoutes.tokenManagement);
                  },
                  child: const Text('Get More Tokens'),
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
      height: 300,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
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
              'Follow-up Questions Not Available',
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
              'Upgrade to Standard or Premium to ask follow-up questions',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: AppConstants.SMALL_PADDING),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to token management page for upgrade
                    context.push(AppRoutes.tokenManagement);
                  },
                  child: const Text('Upgrade Plan'),
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
      height: 300,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
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
              'Follow-up Limit Reached',
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
              'Generate a new study guide to continue asking questions',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: AppConstants.SMALL_PADDING),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to generate study guide page
                    context.go(AppRoutes.generateStudy);
                  },
                  child: const Text('Generate New Study'),
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
      height: 300,
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
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
              'Ask Follow-up Questions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              'Get deeper insights about this study guide by asking follow-up questions.',
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
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.6; // Use 60% of screen height
    const minHeight = 500.0; // Minimum height for readability
    final chatHeight = maxHeight.clamp(minHeight, maxHeight);

    return SizedBox(
      height: chatHeight,
      child: Column(
        children: [
          Expanded(
            child: _buildMessagesList(state),
          ),
          _buildChatInput(state),
        ],
      ),
    );
  }

  Widget _buildMessagesList(FollowUpChatLoaded state) {
    if (state.messages.isEmpty) {
      return _buildEmptyMessages();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppConstants.SMALL_PADDING),
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

  Widget _buildEmptyMessages() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.question_answer_outlined,
              size: AppConstants.ICON_SIZE_40,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: AppConstants.DEFAULT_PADDING),
            Text(
              'No messages yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppConstants.SMALL_PADDING),
            Text(
              'Start by asking a question about this study guide.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput(FollowUpChatLoaded state) {
    return ChatInput(
      onSendMessage: (message) {
        print(
            '[FollowUpChatWidget] 🎯 onSendMessage callback received: "$message"');
        print('[FollowUpChatWidget] 📨 Dispatching SendQuestionEvent to BLoC');
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
    );
  }
}
