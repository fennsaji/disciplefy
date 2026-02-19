import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../voice_buddy/data/services/speech_service.dart';

/// Input widget for sending follow-up questions with voice support
class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isEnabled;
  final bool isProcessing;
  final VoidCallback? onCancel;
  final bool enableVoiceInput;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.isEnabled = true,
    this.isProcessing = false,
    this.onCancel,
    this.enableVoiceInput = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  // Voice input state
  late SpeechService _speechService;
  bool _isListening = false;
  bool _isSpeechAvailable = false;
  final String _currentLanguage = SupportedLanguages.english;
  double _soundLevel = 0.0;
  String _partialText = '';

  // Animation for listening indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);

    // Initialize speech service if voice input is enabled
    if (widget.enableVoiceInput) {
      _speechService = sl<SpeechService>();
      _initializeSpeech();
    }

    // Setup pulse animation for listening indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechService.initialize();
    if (mounted) {
      setState(() {
        _isSpeechAvailable = available;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _controller.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    if (widget.enableVoiceInput && _isListening) {
      _speechService.stopListening();
    }
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

  /// Toggle voice listening
  Future<void> _toggleListening() async {
    if (!_isSpeechAvailable) {
      _showSpeechNotAvailableSnackbar();
      return;
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _partialText = '';
    });
    _pulseController.repeat(reverse: true);

    try {
      await _speechService.startListening(
        languageCode: _currentLanguage,
        onResult: _onSpeechResult,
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        _pulseController.stop();
        _showErrorSnackbar('Failed to start listening: $e');
      }
    }
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    _pulseController.stop();
    _pulseController.reset();

    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _partialText = result.recognizedWords;
    });

    if (result.finalResult) {
      // Final result - add to text field
      final currentText = _controller.text;
      final newText = currentText.isEmpty
          ? result.recognizedWords
          : '$currentText ${result.recognizedWords}';
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );

      setState(() {
        _isListening = false;
        _partialText = '';
        _soundLevel = 0.0;
      });
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _showSpeechNotAvailableSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(context.tr(TranslationKeys.followUpChatSpeechNotAvailable)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
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
            if (_isListening) _buildListeningIndicator(theme),
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
              context.tr(TranslationKeys.followUpChatGettingResponse),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _cancelRequest,
            child: Text(
              context.tr(TranslationKeys.followUpChatCancel),
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

  /// Builds the listening indicator with waveform visualization
  Widget _buildListeningIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.SMALL_PADDING),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.DEFAULT_PADDING,
        vertical: AppConstants.SMALL_PADDING,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.BORDER_RADIUS),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Animated mic icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppConstants.SMALL_PADDING),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.followUpChatListening),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_partialText.isNotEmpty)
                  Text(
                    _partialText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Sound level indicator
          _buildSoundLevelIndicator(theme),
          const SizedBox(width: AppConstants.SMALL_PADDING),
          // Stop button
          TextButton(
            onPressed: _stopListening,
            child: Text(
              context.tr(TranslationKeys.followUpChatStop),
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

  /// Simple sound level visualization
  Widget _buildSoundLevelIndicator(ThemeData theme) {
    final normalizedLevel = (_soundLevel / 10).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final threshold = index / 5;
        final isActive = normalizedLevel > threshold;
        return Container(
          width: 3,
          height: 8 + (index * 3),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Builds the main input row
  Widget _buildInputRow(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.enableVoiceInput) ...[
          _buildVoiceButton(theme),
          const SizedBox(width: AppConstants.SMALL_PADDING),
        ],
        Expanded(
          child: _buildTextField(theme),
        ),
        const SizedBox(width: AppConstants.SMALL_PADDING),
        _buildSendButton(theme),
      ],
    );
  }

  /// Builds the voice/mic button for inline speech-to-text
  Widget _buildVoiceButton(ThemeData theme) {
    final isEnabled = widget.isEnabled && !widget.isProcessing;
    final isActive = _isListening;

    return GestureDetector(
      onTap: isEnabled ? _toggleListening : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(
                  colors: isActive
                      ? [AppColors.error, AppColors.errorDark]
                      : [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color:
              isEnabled ? null : theme.colorScheme.onSurface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color:
                        (isActive ? AppColors.error : theme.colorScheme.primary)
                            .withOpacity(0.3),
                    blurRadius: isActive ? 12 : 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? _toggleListening : null,
            borderRadius: BorderRadius.circular(24),
            child: Tooltip(
              message: isActive
                  ? context.tr(TranslationKeys.followUpChatStopListening)
                  : context.tr(TranslationKeys.followUpChatTapToSpeak),
              child: Icon(
                isActive ? Icons.stop_rounded : Icons.mic_rounded,
                color: isEnabled
                    ? Colors.white
                    : theme.colorScheme.onSurface.withOpacity(0.4),
                size: 22,
              ),
            ),
          ),
        ),
      ),
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
        enabled: widget.isEnabled && !widget.isProcessing && !_isListening,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendMessage(),
        decoration: InputDecoration(
          hintText: _isListening
              ? context.tr(TranslationKeys.followUpChatListening)
              : context.tr(TranslationKeys.followUpChatInputHint),
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
        !widget.isProcessing &&
        !_isListening;

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
              context.tr(TranslationKeys.followUpChatTokenCost),
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
