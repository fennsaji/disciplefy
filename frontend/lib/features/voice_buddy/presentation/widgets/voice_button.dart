import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// The round microphone control of a voice session.
///
/// A solid pill-coloured disc (white with ink on dark, ink with
/// white on light). The big orb above it already says "listening", so the
/// button itself stays still: only the existing speaking bars move, and only
/// while a reply is being spoken.
///
/// Gestures:
/// - continuous mode: tap toggles listening;
/// - hold mode: press to start, release (or cancel) to send;
/// - while speaking: tap interrupts the reply.
class VoiceButton extends StatefulWidget {
  final VoiceButtonState state;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final VoidCallback? onTap;
  final bool isContinuousMode;
  final double size;

  /// Spoken by screen readers; the button has no visible label.
  final String? semanticLabel;

  const VoiceButton({
    super.key,
    this.state = VoiceButtonState.idle,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onTap,
    this.isContinuousMode = false,
    this.size = 80.0,
    this.semanticLabel,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _speakingController;

  @override
  void initState() {
    super.initState();
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.state == VoiceButtonState.speaking) {
      if (!_speakingController.isAnimating) {
        _speakingController.repeat(reverse: true);
      }
    } else if (_speakingController.isAnimating ||
        _speakingController.value != 0) {
      _speakingController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isListening = widget.state == VoiceButtonState.listening;
    final isProcessing = widget.state == VoiceButtonState.processing;
    final fill = isProcessing
        ? palette.ctaFill.withValues(alpha: 0.55)
        : palette.ctaFill;

    return VoiceMicGestures(
      state: widget.state,
      isContinuousMode: widget.isContinuousMode,
      semanticLabel: widget.semanticLabel,
      onTap: widget.onTap,
      onTapDown: widget.onTapDown,
      onTapUp: widget.onTapUp,
      onTapCancel: widget.onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          // A still ring marks "recording" without a pulse.
          border: isListening
              ? Border.all(
                  color: palette.accentIcon.withValues(alpha: 0.7),
                  width: 3,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: _buildIcon(palette.ctaInk),
      ),
    );
  }

  Widget _buildIcon(Color ink) {
    final iconSize = widget.size * 0.4;
    switch (widget.state) {
      case VoiceButtonState.listening:
        return Icon(Icons.mic, color: ink, size: iconSize);
      case VoiceButtonState.processing:
        return SizedBox(
          width: widget.size * 0.34,
          height: widget.size * 0.34,
          child: CircularProgressIndicator(color: ink, strokeWidth: 3),
        );
      case VoiceButtonState.speaking:
        return AnimatedBuilder(
          animation: _speakingController,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                // Staggered wave bars
                final value = (_speakingController.value + index * 0.3) % 1.0;
                final height = 8.0 + 20.0 * (0.3 + 0.7 * value);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            );
          },
        );
      case VoiceButtonState.idle:
        return Icon(Icons.mic_none_rounded, color: ink, size: iconSize);
    }
  }
}

/// The mic's gestures around any [child], so every surface that starts or
/// stops listening (the round mic button, the big orb above it) responds
/// the same way:
/// - continuous mode: tap toggles listening;
/// - hold mode: press to start, release (or cancel) to send;
/// - while speaking: tap interrupts the reply.
class VoiceMicGestures extends StatelessWidget {
  final VoiceButtonState state;
  final bool isContinuousMode;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;

  /// Spoken by screen readers in place of [child]'s own semantics.
  final String? semanticLabel;
  final Widget child;

  const VoiceMicGestures({
    super.key,
    required this.state,
    required this.isContinuousMode,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isListening = state == VoiceButtonState.listening;
    final tapToggles = isContinuousMode || state == VoiceButtonState.speaking;
    final pressStarts = !isContinuousMode && state == VoiceButtonState.idle;
    final releaseSends = !isContinuousMode && isListening;
    // Excluding the child's semantics also drops the detector's own tap
    // action, so a screen reader's double-tap is given the same meaning
    // here: toggle, start, or send, as the pointer would.
    final VoidCallback? semanticTap = tapToggles
        ? onTap
        : pressStarts
            ? onTapDown
            : releaseSends
                ? onTapUp
                : null;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: semanticTap,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tapToggles ? onTap : null,
        onTapDown: pressStarts ? (_) => onTapDown?.call() : null,
        onTapUp: releaseSends ? (_) => onTapUp?.call() : null,
        onTapCancel: !isContinuousMode ? onTapCancel : null,
        child: child,
      ),
    );
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
