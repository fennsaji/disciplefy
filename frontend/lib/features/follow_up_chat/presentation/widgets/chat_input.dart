import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Input widget for sending follow-up questions
class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isEnabled;
  final bool isProcessing;
  final VoidCallback? onCancel;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.isEnabled = true,
    this.isProcessing = false,
    this.onCancel,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    setState(() {
      // Trigger rebuild when text changes to update send button state
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();

    if (text.isNotEmpty && widget.isEnabled && !widget.isProcessing) {
      widget.onSendMessage(text);
      _controller.clear();
      _focusNode.unfocus();
    }
  }

  void _cancelRequest() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.DEFAULT_PADDING),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isProcessing) _buildProcessingIndicator(theme),
            _buildInputRow(theme),
            _buildHelpText(theme),
          ],
        ),
      ),
    );
  }

  /// Builds the processing indicator when request is in progress
  Widget _buildProcessingIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.SMALL_PADDING),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.DEFAULT_PADDING,
        vertical: AppConstants.SMALL_PADDING,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: AppConstants.SMALL_PADDING),
          Expanded(
            child: Text(
              'Getting response...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _cancelRequest,
            child: Text(
              'Cancel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main input row
  Widget _buildInputRow(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _buildTextField(theme),
        ),
        const SizedBox(width: AppConstants.SMALL_PADDING),
        _buildSendButton(theme),
      ],
    );
  }

  /// Builds the text input field
  Widget _buildTextField(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 48,
        maxHeight: 120,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.LARGE_BORDER_RADIUS),
        border: Border.all(
          color: _isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.3),
          width: _isFocused ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.isEnabled && !widget.isProcessing,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendMessage(),
        decoration: InputDecoration(
          hintText: 'Ask a follow-up question...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.DEFAULT_PADDING,
            vertical: AppConstants.SMALL_PADDING,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  /// Builds the send button
  Widget _buildSendButton(ThemeData theme) {
    final canSend = _controller.text.trim().isNotEmpty &&
        widget.isEnabled &&
        !widget.isProcessing;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: canSend
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSend ? _sendMessage : null,
          borderRadius: BorderRadius.circular(24),
          child: Icon(
            Icons.send_rounded,
            color: canSend
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withOpacity(0.4),
            size: 20,
          ),
        ),
      ),
    );
  }

  /// Builds help text below the input
  Widget _buildHelpText(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.SMALL_PADDING),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: AppConstants.EXTRA_SMALL_PADDING),
          Expanded(
            child: Text(
              'Each follow-up question costs 5 tokens',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: AppConstants.FONT_SIZE_14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.SMALL_PADDING,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.secondary.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.token,
                  size: 12,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 2),
                Text(
                  '5',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontSize: AppConstants.FONT_SIZE_14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
