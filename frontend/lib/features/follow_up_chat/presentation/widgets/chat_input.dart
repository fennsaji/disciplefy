import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../voice_buddy/data/services/speech_service.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';

/// Input widget for sending follow-up questions with voice support
class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isEnabled;
  final bool isProcessing;
  final VoidCallback? onCancel;
  final bool enableVoiceInput;

  /// Called when the user taps "Got it →" on a walkthrough tooltip inside
  /// this input widget. Pass null to skip walkthrough entirely.
  final VoidCallback? onNext;

  /// Optional external controller, so a parent can prefill a question (e.g.
  /// from a suggestion chip). Owned and disposed by the caller.
  final TextEditingController? controller;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.isEnabled = true,
    this.isProcessing = false,
    this.onCancel,
    this.enableVoiceInput = false,
    this.onNext,
    this.controller,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
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

    // Resolve the service but do NOT initialize it here: the plugin's
    // initialize() raises the OS microphone (and, on iOS, speech recognition)
    // prompts, and this input is mounted by every study guide screen — asking
    // for the mic on page open, before the user has gone near the mic button,
    // is what that used to do. The first mic tap initializes instead.
    if (widget.enableVoiceInput) {
      _speechService = sl<SpeechService>();
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

  /// Prepares speech input on demand, prompting for the microphone only now.
  ///
  /// Returns false when the user declined or the recognizer is unavailable, in
  /// which case the caller has already told them why.
  Future<bool> _prepareSpeech() async {
    final permission = await _speechService.requestMicrophonePermission();
    if (permission != MicPermission.granted) {
      if (mounted) {
        _showMicPermissionSnackbar(
          permanentlyDenied: permission == MicPermission.permanentlyDenied,
        );
      }
      return false;
    }

    final available = await _speechService.initialize();
    if (mounted) {
      setState(() {
        _isSpeechAvailable = available;
      });
    }
    if (!available && mounted) {
      _showSpeechNotAvailableSnackbar();
    }
    return available;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    if (widget.controller == null) _controller.dispose();
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
    if (!_isSpeechAvailable && !await _prepareSpeech()) {
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
    showAppSnackBar(
      context,
      context.tr(TranslationKeys.followUpChatSpeechNotAvailable),
      tone: AppSnackTone.error,
    );
  }

  /// Tells the user what the declined microphone blocks, and how to undo it.
  /// Not styled as an error — typing still works.
  void _showMicPermissionSnackbar({required bool permanentlyDenied}) {
    showAppSnackBar(
      context,
      context.tr(permanentlyDenied
          ? TranslationKeys.micPermissionBlockedMessage
          : TranslationKeys.micPermissionMessage),
      actionLabel: permanentlyDenied
          ? context.tr(TranslationKeys.micPermissionOpenSettings)
          : null,
      onAction:
          permanentlyDenied ? _speechService.openPermissionSettings : null,
    );
  }

  void _showErrorSnackbar(String message) {
    showAppSnackBar(context, message, tone: AppSnackTone.error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sits inside the page's scroll view, so no bar chrome or safe-area inset:
    // just the indicators above one pill-shaped field. The credit cost is shown
    // once, under the section heading.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isProcessing) _buildProcessingIndicator(theme),
          if (_isListening) _buildListeningIndicator(theme),
          _buildInputRow(theme),
        ],
      ),
    );
  }

  /// Card shell shared by the processing and listening indicators.
  Widget _indicatorCard({required List<Widget> children}) {
    final palette = ReaderPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.SMALL_PADDING),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.card : palette.raised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(children: children),
    );
  }

  /// Small stadium text action inside an indicator (Cancel / Stop).
  Widget _indicatorAction(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(44, 40),
      ),
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.error,
        ),
      ),
    );
  }

  /// Builds the processing indicator when request is in progress
  Widget _buildProcessingIndicator(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    return _indicatorCard(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: palette.accentIcon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.tr(TranslationKeys.followUpChatGettingResponse),
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: palette.text,
            ),
          ),
        ),
        _indicatorAction(
          context.tr(TranslationKeys.followUpChatCancel),
          _cancelRequest,
        ),
      ],
    );
  }

  /// Builds the listening indicator with waveform visualization
  Widget _buildListeningIndicator(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    return _indicatorCard(
      children: [
        // Pulsing mic disc
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.ctaFill,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic, color: palette.ctaInk, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(TranslationKeys.followUpChatListening),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              if (_partialText.isNotEmpty)
                Text(
                  _partialText,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: palette.muted,
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
        const SizedBox(width: 4),
        _indicatorAction(
          context.tr(TranslationKeys.followUpChatStop),
          _stopListening,
        ),
      ],
    );
  }

  /// Simple sound level visualization
  Widget _buildSoundLevelIndicator(ThemeData theme) {
    final palette = ReaderPalette.of(context);
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
            color: isActive ? palette.accentIcon : palette.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Builds the main input row: one pill holding the field, the mic and a
  /// round send button.
  Widget _buildInputRow(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.card : palette.raised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isFocused ? palette.accentIcon : palette.outline,
          width: _isFocused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTextField(theme)),
          if (widget.enableVoiceInput) _buildVoiceButton(theme),
          const SizedBox(width: 4),
          _buildSendButton(theme),
        ],
      ),
    );
  }

  /// Builds the voice/mic button for inline speech-to-text
  Widget _buildVoiceButton(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    final isEnabled = widget.isEnabled && !widget.isProcessing;
    final isActive = _isListening;

    return IconButton(
      onPressed: isEnabled ? _toggleListening : null,
      tooltip: isActive
          ? context.tr(TranslationKeys.followUpChatStopListening)
          : context.tr(TranslationKeys.followUpChatTapToSpeak),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(
        isActive ? Icons.stop_rounded : Icons.mic_none_rounded,
        color: isActive
            ? AppColors.error
            : (isEnabled ? palette.muted : palette.dim.withValues(alpha: 0.5)),
        size: 22,
      ),
    );
  }

  /// Builds the text input field
  Widget _buildTextField(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.isEnabled && !widget.isProcessing && !_isListening,
      minLines: 1,
      maxLines: 5,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendMessage(),
      decoration: InputDecoration(
        // Override the global inputDecorationTheme (filled: true): the pill
        // around the row is the field.
        filled: false,
        isDense: true,
        hintText: _isListening
            ? context.tr(TranslationKeys.followUpChatListening)
            : context.tr(TranslationKeys.followUpChatInputHint),
        hintMaxLines: 1,
        hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
      style: AppFonts.inter(fontSize: 15, color: palette.text, height: 1.4),
    );
  }

  /// Builds the round send button (white on dark, ink on light).
  Widget _buildSendButton(ThemeData theme) {
    final palette = ReaderPalette.of(context);
    final canSend = _controller.text.trim().isNotEmpty &&
        widget.isEnabled &&
        !widget.isProcessing &&
        !_isListening;

    return Semantics(
      button: true,
      enabled: canSend,
      label: context.tr(TranslationKeys.followUpChatSend),
      child: Material(
        color: canSend
            ? palette.ctaFill
            : palette.ctaFill.withValues(alpha: palette.isDark ? 0.35 : 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: canSend ? _sendMessage : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.arrow_upward_rounded,
              color: palette.ctaInk,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
