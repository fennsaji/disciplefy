import 'package:flutter/material.dart';

/// A circular voice button widget for initiating voice conversations.
///
/// Supports four states:
/// - Idle: Ready to start recording
/// - Listening: Currently recording user speech
/// - Processing: Processing the recorded audio
/// - Speaking: TTS is playing the AI response
class VoiceButton extends StatefulWidget {
  final VoiceButtonState state;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final VoidCallback? onTap;
  final bool isContinuousMode;
  final double size;

  const VoiceButton({
    super.key,
    this.state = VoiceButtonState.idle,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onTap,
    this.isContinuousMode = false,
    this.size = 80.0,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _speakingController;

  @override
  void initState() {
    super.initState();
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.state == VoiceButtonState.speaking) {
      _speakingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == VoiceButtonState.speaking) {
      if (!_speakingController.isAnimating) {
        _speakingController.repeat(reverse: true);
      }
    } else {
      _speakingController.stop();
      _speakingController.reset();
    }
  }

  @override
  void dispose() {
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return GestureDetector(
      // In continuous mode: tap to toggle listening
      // In normal mode: hold to speak (tap down to start, tap up to stop)
      // When speaking: tap to interrupt and start listening
      onTap:
          widget.isContinuousMode || widget.state == VoiceButtonState.speaking
              ? widget.onTap
              : null,
      onTapDown:
          !widget.isContinuousMode && widget.state == VoiceButtonState.idle
              ? (_) => widget.onTapDown?.call()
              : null,
      onTapUp:
          !widget.isContinuousMode && widget.state == VoiceButtonState.listening
              ? (_) => widget.onTapUp?.call()
              : null,
      onTapCancel: !widget.isContinuousMode ? widget.onTapCancel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getGradientColors(primaryColor, secondaryColor),
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withAlpha((0.3 * 255).round()),
              blurRadius: 20,
              spreadRadius: widget.state == VoiceButtonState.listening ||
                      widget.state == VoiceButtonState.speaking
                  ? 10
                  : 0,
            ),
          ],
        ),
        child: Center(
          child: _buildIcon(),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(Color primary, Color secondary) {
    switch (widget.state) {
      case VoiceButtonState.listening:
        return [primary, primary.withAlpha((0.7 * 255).round())];
      case VoiceButtonState.processing:
        return [
          primary.withAlpha((0.5 * 255).round()),
          secondary.withAlpha((0.5 * 255).round())
        ];
      case VoiceButtonState.speaking:
        // Same indigo/purple as idle state when AI is speaking
        return [primary, secondary];
      case VoiceButtonState.idle:
        return [primary, secondary];
    }
  }

  Widget _buildIcon() {
    switch (widget.state) {
      case VoiceButtonState.listening:
        return const Icon(
          Icons.mic,
          color: Colors.white,
          size: 36,
        );
      case VoiceButtonState.processing:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        );
      case VoiceButtonState.speaking:
        // Animated speaker icon when AI is speaking
        return AnimatedBuilder(
          animation: _speakingController,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                // Create staggered wave bars
                final delay = index * 0.3;
                final value = (_speakingController.value + delay) % 1.0;
                final height = 8.0 + 20.0 * (0.3 + 0.7 * value);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            );
          },
        );
      case VoiceButtonState.idle:
        return const Icon(
          Icons.mic_none,
          color: Colors.white,
          size: 36,
        );
    }
  }
}

/// Represents the current state of the voice button.
enum VoiceButtonState {
  /// Ready to start recording
  idle,

  /// Currently recording user speech
  listening,

  /// Processing the recorded audio
  processing,

  /// TTS is playing the AI response
  speaking,
}
