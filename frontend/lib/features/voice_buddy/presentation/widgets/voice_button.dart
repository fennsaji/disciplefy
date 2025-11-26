import 'package:flutter/material.dart';

/// A circular voice button widget for initiating voice conversations.
///
/// Supports three states:
/// - Idle: Ready to start recording
/// - Listening: Currently recording user speech
/// - Processing: Processing the recorded audio
class VoiceButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return GestureDetector(
      // In continuous mode: tap to toggle listening
      // In normal mode: hold to speak (tap down to start, tap up to stop)
      onTap: isContinuousMode ? onTap : null,
      onTapDown: !isContinuousMode && state == VoiceButtonState.idle
          ? (_) => onTapDown?.call()
          : null,
      onTapUp: !isContinuousMode && state == VoiceButtonState.listening
          ? (_) => onTapUp?.call()
          : null,
      onTapCancel: !isContinuousMode ? onTapCancel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
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
              spreadRadius: state == VoiceButtonState.listening ? 10 : 0,
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
    switch (state) {
      case VoiceButtonState.listening:
        return [primary, primary.withAlpha((0.7 * 255).round())];
      case VoiceButtonState.processing:
        return [
          primary.withAlpha((0.5 * 255).round()),
          secondary.withAlpha((0.5 * 255).round())
        ];
      case VoiceButtonState.idle:
      default:
        return [primary, secondary];
    }
  }

  Widget _buildIcon() {
    switch (state) {
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
      case VoiceButtonState.idle:
      default:
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
}
