import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../bloc/follow_up_chat_state.dart';

/// A chat bubble widget for displaying messages in the follow-up chat
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.DEFAULT_PADDING,
        vertical: AppConstants.EXTRA_SMALL_PADDING,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(theme),
          if (!isUser) const SizedBox(width: AppConstants.SMALL_PADDING),
          Flexible(
            child: _buildMessageContainer(context, theme, isUser),
          ),
          if (isUser) const SizedBox(width: AppConstants.SMALL_PADDING),
          if (isUser) _buildUserAvatar(theme),
        ],
      ),
    );
  }

  /// Builds the assistant avatar
  Widget _buildAvatar(ThemeData theme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.auto_awesome,
        color: theme.colorScheme.onPrimary,
        size: 18,
      ),
    );
  }

  /// Builds the user avatar
  Widget _buildUserAvatar(ThemeData theme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.person,
        color: theme.colorScheme.onSecondary,
        size: 18,
      ),
    );
  }

  /// Builds the main message container
  Widget _buildMessageContainer(
      BuildContext context, ThemeData theme, bool isUser) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme, isUser),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppConstants.BORDER_RADIUS),
          topRight: const Radius.circular(AppConstants.BORDER_RADIUS),
          bottomLeft: Radius.circular(isUser
              ? AppConstants.BORDER_RADIUS
              : AppConstants.EXTRA_SMALL_PADDING),
          bottomRight: Radius.circular(isUser
              ? AppConstants.EXTRA_SMALL_PADDING
              : AppConstants.BORDER_RADIUS),
        ),
        border: Border.all(
          color: _getBorderColor(theme, isUser),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageContent(context, theme, isUser),
          _buildMessageFooter(context, theme, isUser),
        ],
      ),
    );
  }

  /// Builds the message content
  Widget _buildMessageContent(
      BuildContext context, ThemeData theme, bool isUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.DEFAULT_PADDING,
        AppConstants.SMALL_PADDING,
        AppConstants.DEFAULT_PADDING,
        AppConstants.EXTRA_SMALL_PADDING,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageText(theme, isUser),
          if (_shouldShowStatusIndicator()) ...[
            const SizedBox(height: AppConstants.EXTRA_SMALL_PADDING),
            _buildStatusIndicator(context, theme),
          ],
        ],
      ),
    );
  }

  /// Builds the message text with streaming support and proper formatting
  Widget _buildMessageText(ThemeData theme, bool isUser) {
    final content = message.content;

    // Debug logging
    // During streaming, show plain text to avoid incomplete markdown parsing issues
    if (message.status == ChatMessageStatus.streaming) {
      return SelectableText(
        content.isEmpty ? '...' : content,
        key: ValueKey('${message.id}_streaming_text'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: _getTextColor(theme, isUser),
          height: 1.5,
        ),
      );
    }

    // For AI messages with complete content, use markdown rendering
    if (!isUser && content.isNotEmpty) {
      // Add blank lines before lists for proper markdown parsing
      final fixedContent = content
          // Fix: **bold**1. -> **bold**\n\n1.
          .replaceAllMapped(
            RegExp(r'(\*\*[^*]+\*\*)(\d+\.)', multiLine: true),
            (match) => '${match.group(1)}\n\n${match.group(2)}',
          )
          // Fix: *italic*1. -> *italic*\n\n1.
          .replaceAllMapped(
            RegExp(r'(\*[^*]+\*)(\d+\.)', multiLine: true),
            (match) => '${match.group(1)}\n\n${match.group(2)}',
          )
          // Fix: "text"1. -> "text"\n\n1.
          .replaceAllMapped(
            RegExp(r'("[^"]+")(\d+\.)', multiLine: true),
            (match) => '${match.group(1)}\n\n${match.group(2)}',
          );
      return MarkdownBody(
        key: ValueKey(
            '${message.id}_${message.status.toString()}_${content.hashCode}'),
        data: fixedContent,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          // Paragraph styling with proper line height
          p: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            height: 1.6,
          ),
          // Heading styles with proper spacing
          h1: theme.textTheme.headlineMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
          h2: theme.textTheme.headlineSmall?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
          h3: theme.textTheme.titleLarge?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          h4: theme.textTheme.titleMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          h5: theme.textTheme.titleSmall?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          h6: theme.textTheme.titleSmall?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          // Text formatting
          strong: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.bold,
          ),
          em: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            fontStyle: FontStyle.italic,
          ),
          // Blockquote with border and padding
          blockquote: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser).withOpacity(0.8),
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
          blockquotePadding: const EdgeInsets.all(AppConstants.SMALL_PADDING),
          blockquoteDecoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 3,
              ),
            ),
          ),
          // Inline code styling
          code: theme.textTheme.bodySmall?.copyWith(
            color: _getTextColor(theme, isUser),
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            fontFamily: 'Courier',
            fontSize: 14,
          ),
          // Code block styling
          codeblockPadding: const EdgeInsets.all(AppConstants.SMALL_PADDING),
          codeblockDecoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                BorderRadius.circular(AppConstants.SMALL_BORDER_RADIUS),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          // List styling
          listBullet: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            height: 1.5,
          ),
          listIndent: AppConstants.DEFAULT_PADDING,
          // Table styling
          tableHead: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser),
            fontWeight: FontWeight.w600,
          ),
          tableBody: theme.textTheme.bodyMedium?.copyWith(
            color: _getTextColor(theme, isUser),
          ),
          tableBorder: TableBorder.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          // Horizontal rule
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
          ),
          // Link styling
          a: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        onTapLink: (text, href, title) {
          // Handle link taps if needed
        },
      );
    }

    // For user messages, use SelectableText
    return SelectableText(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _getTextColor(theme, isUser),
        height: 1.5,
      ),
    );
  }

  /// Builds the status indicator for streaming/failed messages
  Widget _buildStatusIndicator(BuildContext context, ThemeData theme) {
    switch (message.status) {
      case ChatMessageStatus.streaming:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.EXTRA_SMALL_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatResponding),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      case ChatMessageStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: AppConstants.EXTRA_SMALL_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatFailedToSend),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        );
      case ChatMessageStatus.sending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.EXTRA_SMALL_PADDING),
            Text(
              context.tr(TranslationKeys.followUpChatSending),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Builds the message footer with timestamp and actions
  Widget _buildMessageFooter(
      BuildContext context, ThemeData theme, bool isUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.DEFAULT_PADDING,
        0,
        AppConstants.DEFAULT_PADDING,
        AppConstants.SMALL_PADDING,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimestamp(theme),
          _buildActions(context, theme, isUser),
        ],
      ),
    );
  }

  /// Builds the timestamp
  Widget _buildTimestamp(ThemeData theme) {
    return Builder(
      builder: (context) {
        final timeString = _formatTimeWithContext(context, message.timestamp);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: AppConstants.FONT_SIZE_14,
              ),
            ),
            if (message.tokensConsumed != null &&
                message.tokensConsumed! > 0) ...[
              const SizedBox(width: AppConstants.EXTRA_SMALL_PADDING),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.EXTRA_SMALL_PADDING,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${message.tokensConsumed} ${context.tr(TranslationKeys.followUpChatTokens)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: AppConstants.FONT_SIZE_14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Builds action buttons
  Widget _buildActions(BuildContext context, ThemeData theme, bool isUser) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isUser && message.content.isNotEmpty) ...[
          _buildCopyButton(context, theme),
        ],
        if (message.status == ChatMessageStatus.failed && onRetry != null) ...[
          const SizedBox(width: AppConstants.EXTRA_SMALL_PADDING),
          _buildRetryButton(context, theme),
        ],
      ],
    );
  }

  /// Builds the copy button
  Widget _buildCopyButton(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => _copyToClipboard(context),
      borderRadius: BorderRadius.circular(AppConstants.SMALL_BORDER_RADIUS),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.EXTRA_SMALL_PADDING),
        child: Icon(
          Icons.copy,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  /// Builds the retry button
  Widget _buildRetryButton(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(AppConstants.SMALL_BORDER_RADIUS),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.EXTRA_SMALL_PADDING),
        child: Icon(
          Icons.refresh,
          size: 16,
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  /// Gets the background color based on message type and status
  Color _getBackgroundColor(ThemeData theme, bool isUser) {
    if (message.status == ChatMessageStatus.failed) {
      return theme.colorScheme.error.withOpacity(0.1);
    }

    if (isUser) {
      return theme.colorScheme.primary.withOpacity(0.1);
    } else {
      return theme.colorScheme.surface;
    }
  }

  /// Gets the border color based on message type and status
  Color _getBorderColor(ThemeData theme, bool isUser) {
    if (message.status == ChatMessageStatus.failed) {
      return theme.colorScheme.error.withOpacity(0.3);
    }

    if (isUser) {
      return theme.colorScheme.primary.withOpacity(0.3);
    } else {
      return theme.colorScheme.outline.withOpacity(0.2);
    }
  }

  /// Gets the text color based on message type
  Color _getTextColor(ThemeData theme, bool isUser) {
    if (message.status == ChatMessageStatus.failed) {
      return theme.colorScheme.error;
    }

    return theme.colorScheme.onSurface;
  }

  /// Determines whether to show status indicator
  bool _shouldShowStatusIndicator() {
    return message.status == ChatMessageStatus.streaming ||
        message.status == ChatMessageStatus.sending ||
        message.status == ChatMessageStatus.failed;
  }

  /// Formats the timestamp
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // Need BuildContext for translation, this is handled in the build method
    return '';
  }

  /// Formats the timestamp with translation support
  String _formatTimeWithContext(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return context.tr(TranslationKeys.followUpChatDaysAgo,
          {'count': difference.inDays.toString()});
    } else if (difference.inHours > 0) {
      return context.tr(TranslationKeys.followUpChatHoursAgo,
          {'count': difference.inHours.toString()});
    } else if (difference.inMinutes > 0) {
      return context.tr(TranslationKeys.followUpChatMinutesAgo,
          {'count': difference.inMinutes.toString()});
    } else {
      return context.tr(TranslationKeys.followUpChatJustNow);
    }
  }

  /// Copies message content to clipboard
  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.content));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.followUpChatMessageCopied)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
