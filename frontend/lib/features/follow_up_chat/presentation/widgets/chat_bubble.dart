import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';
import '../bloc/follow_up_chat_state.dart';
import '../../../community/presentation/widgets/discipler_badges.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// A chat bubble widget for displaying messages in the follow-up chat
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  /// Asset for the assistant avatar: the white Discipler mark on a gold disc.
  static const String avatarAsset = 'assets/brand/discipler-mark-on-gold.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    // User questions sit on the right as a pill; Discipler replies on the
    // left beside its mark. Timestamp, credits and actions go under the
    // bubble rather than inside it.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(theme),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildMessageContainer(context, theme, isUser),
                _buildMessageFooter(context, theme, isUser),
              ],
            ),
          ),
          // Keeps a reply from running under the right edge's pill column.
          if (!isUser) const SizedBox(width: 24),
        ],
      ),
    );
  }

  /// The assistant avatar — the Discipler mark on gold.
  Widget _buildAvatar(ThemeData theme) {
    return ClipOval(
      child: Image.asset(
        avatarAsset,
        width: 32,
        height: 32,
        cacheWidth: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const DisciplerAvatar(radius: 16),
      ),
    );
  }

  /// Builds the main message container
  Widget _buildMessageContainer(
      BuildContext context, ThemeData theme, bool isUser) {
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.8 : 0.72),
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme, isUser),
        borderRadius: isUser
            ? const BorderRadius.only(
                topLeft: r, topRight: r, bottomLeft: r, bottomRight: tail)
            : const BorderRadius.only(
                topLeft: tail, topRight: r, bottomLeft: r, bottomRight: r),
        border: _getBorderColor(theme, isUser) == null
            ? null
            : Border.all(color: _getBorderColor(theme, isUser)!),
      ),
      child: _buildMessageContent(context, theme, isUser),
    );
  }

  /// Builds the message content
  Widget _buildMessageContent(
      BuildContext context, ThemeData theme, bool isUser) {
    return Padding(
      padding: isUser
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 11)
          : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageText(context, theme, isUser),
          if (_shouldShowStatusIndicator()) ...[
            const SizedBox(height: AppConstants.EXTRA_SMALL_PADDING),
            _buildStatusIndicator(context, theme),
          ],
        ],
      ),
    );
  }

  /// Builds the message text with streaming support and proper formatting
  Widget _buildMessageText(BuildContext context, ThemeData theme, bool isUser) {
    final content = message.content;
    final bodyStyle = AppFonts.inter(
      fontSize: 15,
      color: _getTextColor(theme, isUser),
      height: 1.5,
    );

    // During streaming, show plain text to avoid incomplete markdown parsing issues
    if (message.status == ChatMessageStatus.streaming) {
      return Container(
        key: ValueKey('${message.id}_streaming_container'),
        child: SelectableText(
          content.isEmpty ? '...' : content,
          style: bodyStyle,
        ),
      );
    }

    // For AI messages with complete content, use markdown rendering
    // Force widget rebuild by using unique key that includes status
    if (!isUser &&
        content.isNotEmpty &&
        message.status == ChatMessageStatus.sent) {
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
      return Container(
        key: ValueKey('${message.id}_sent_container'),
        child: MarkdownBody(
          key: ValueKey('${message.id}_${message.status}_markdown'),
          data: fixedContent,
          selectable: true,
          styleSheet:
              _markdownStyleSheet(context, _getTextColor(theme, isUser)),
          onTapLink: (text, href, title) {
            // Handle link taps if needed
          },
        ),
      );
    }

    // For user messages, use SelectableText
    return SelectableText(content, style: bodyStyle);
  }

  /// Markdown styles for a Discipler reply: Inter body, Poppins headings,
  /// lavender (dark) / indigo (light) accents, raised code and quote fills.
  MarkdownStyleSheet _markdownStyleSheet(BuildContext context, Color ink) {
    final palette = ReaderPalette.of(context);
    TextStyle body({FontWeight? weight, FontStyle? style, Color? color}) =>
        AppFonts.inter(
          fontSize: 15,
          fontWeight: weight,
          fontStyle: style,
          color: color ?? ink,
          height: 1.6,
        );
    TextStyle heading(double size, FontWeight weight) => AppFonts.poppins(
          fontSize: size,
          fontWeight: weight,
          color: ink,
          height: 1.3,
        );

    return MarkdownStyleSheet(
      p: body(),
      h1: heading(20, FontWeight.w700),
      h2: heading(18, FontWeight.w700),
      h3: heading(17, FontWeight.w600),
      h4: heading(16, FontWeight.w600),
      h5: heading(15, FontWeight.w600),
      h6: heading(15, FontWeight.w500),
      strong: body(weight: FontWeight.w700),
      em: body(style: FontStyle.italic),
      blockquote: body(style: FontStyle.italic, color: palette.muted),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      blockquoteDecoration: BoxDecoration(
        color: palette.raised,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        border: Border(
          left: BorderSide(color: palette.accentIcon, width: 3),
        ),
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: ink,
        backgroundColor: palette.raised,
      ),
      codeblockPadding: const EdgeInsets.all(AppConstants.SMALL_PADDING),
      codeblockDecoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.hairline),
      ),
      listBullet: body(color: palette.accentIcon),
      listIndent: AppConstants.DEFAULT_PADDING,
      tableHead: body(weight: FontWeight.w600),
      tableBody: body(),
      tableBorder: TableBorder.all(color: palette.outline),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.outline)),
      ),
      a: body(weight: FontWeight.w600, color: palette.accentIcon).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: palette.accentIcon.withValues(alpha: 0.6),
      ),
    );
  }

  /// Builds the status indicator for streaming/failed messages
  Widget _buildStatusIndicator(BuildContext context, ThemeData theme) {
    final palette = ReaderPalette.of(context);
    Widget pending(String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accentIcon,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _getTextColor(theme, message.isUser)
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );
    switch (message.status) {
      case ChatMessageStatus.streaming:
        return pending(context.tr(TranslationKeys.followUpChatResponding));
      case ChatMessageStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 16, color: context.appError),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.tr(TranslationKeys.followUpChatFailedToSend),
                style: AppFonts.inter(fontSize: 12, color: context.appError),
              ),
            ),
          ],
        );
      case ChatMessageStatus.sending:
        return pending(context.tr(TranslationKeys.followUpChatSending));
      default:
        return const SizedBox.shrink();
    }
  }

  /// Builds the footer under the bubble: timestamp, credits and actions.
  Widget _buildMessageFooter(
      BuildContext context, ThemeData theme, bool isUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _buildTimestamp(theme)),
          _buildActions(context, theme, isUser),
        ],
      ),
    );
  }

  /// Builds the timestamp
  Widget _buildTimestamp(ThemeData theme) {
    return Builder(
      builder: (context) {
        final palette = ReaderPalette.of(context);
        final timeString = _formatTimeWithContext(context, message.timestamp);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                timeString,
                style: AppFonts.inter(fontSize: 12, color: palette.dim),
              ),
            ),
            if (message.tokensConsumed != null &&
                message.tokensConsumed! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${message.tokensConsumed} ${context.tr(TranslationKeys.followUpChatTokens)}',
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: palette.accentIcon,
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
          Icons.copy_rounded,
          size: 16,
          color: ReaderPalette.of(context).muted,
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
          Icons.refresh_rounded,
          size: 16,
          color: context.appError,
        ),
      ),
    );
  }

  /// Gets the background color based on message type and status.
  /// User: white pill on dark, indigo pill on light. Reply: a card.
  Color _getBackgroundColor(ThemeData theme, bool isUser) {
    if (message.status == ChatMessageStatus.failed) {
      return AppColors.error.withValues(alpha: 0.1);
    }
    final isDark = theme.brightness == Brightness.dark;
    if (isUser) {
      return isDark ? Colors.white : ReaderPalette.selectedFill;
    }
    return isDark ? const Color(0xFF1A1A21) : Colors.white;
  }

  /// Border only where a fill alone would not separate from the page.
  Color? _getBorderColor(ThemeData theme, bool isUser) {
    if (message.status == ChatMessageStatus.failed) {
      return AppColors.error.withValues(alpha: 0.3);
    }
    if (isUser) return null;
    return theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFF16161D).withOpacity(0.08);
  }

  /// Gets the text color based on message type
  Color _getTextColor(ThemeData theme, bool isUser) {
    if (message.status == ChatMessageStatus.failed) {
      return AppColors.error;
    }
    final isDark = theme.brightness == Brightness.dark;
    if (isUser) return isDark ? AppColors.brandPrimaryInk : Colors.white;
    return isDark ? const Color(0xFFF2F2F4) : const Color(0xFF16161D);
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
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.followUpChatMessageCopied),
        tone: AppSnackTone.success,
      );
    }
  }
}
