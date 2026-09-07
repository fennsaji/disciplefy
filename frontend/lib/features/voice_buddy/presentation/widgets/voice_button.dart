import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _speakingController;
  late AnimationController _listeningController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _listeningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _listeningController, curve: Curves.easeInOut),
    );

    _updateAnimations();
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimations();
  }

  void _updateAnimations() {
    // Speaking animation
    if (widget.state == VoiceButtonState.speaking) {
      if (!_speakingController.isAnimating) {
        _speakingController.repeat(reverse: true);
      }
    } else {
      _speakingController.stop();
      _speakingController.reset();
    }

    // Listening pulse animation
    if (widget.state == VoiceButtonState.listening) {
      if (!_listeningController.isAnimating) {
        _listeningController.repeat(reverse: true);
      }
    } else {
      _listeningController.stop();
      _listeningController.reset();
    }
  }

  @override
  void dispose() {
    _speakingController.dispose();
    _listeningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isListening = widget.state == VoiceButtonState.listening;

    // Listening color - bright blue/cyan for clear distinction
    const listeningColor = AppColors.brandPrimaryDeep;

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
      child: SizedBox(
        // Fixed size to prevent layout shifts during animation
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ring when listening
                if (isListening)
                  AnimatedBuilder(
                    animation: _listeningController,
                    builder: (context, _) {
                      return Container(
                        width: widget.size *
                            (1.3 + 0.2 * _listeningController.value),
                        height: widget.size *
                            (1.3 + 0.2 * _listeningController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: listeningColor.withAlpha(
                              ((0.6 - 0.4 * _listeningController.value) * 255)
                                  .round(),
                            ),
                            width: 3,
                          ),
                        ),
                      );
                    },
                  ),
                // Second pulsing ring (delayed) when listening
                if (isListening)
                  AnimatedBuilder(
                    animation: _listeningController,
                    builder: (context, _) {
                      final delayedValue =
                          (_listeningController.value + 0.5) % 1.0;
                      return Container(
                        width: widget.size * (1.15 + 0.25 * delayedValue),
                        height: widget.size * (1.15 + 0.25 * delayedValue),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: listeningColor.withAlpha(
                              ((0.4 - 0.3 * delayedValue) * 255).round(),
                            ),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                // Main button
                Transform.scale(
                  scale: isListening ? _pulseAnimation.value : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _getGradientColors(),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isListening
                              ? listeningColor.withAlpha((0.5 * 255).round())
                              : primaryColor.withAlpha((0.3 * 255).round()),
                          blurRadius: isListening ? 25 : 20,
                          spreadRadius: isListening ||
                                  widget.state == VoiceButtonState.speaking
                              ? 8
                              : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildIcon(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Single-hue brand indigo ramp.
  ///
  /// This used to blend `colorScheme.primary` into `colorScheme.secondary` —
  /// indigo into the brand's pale gold — which read as an off-palette purple
  /// -to-peach wash. Staying inside the indigo family keeps the control on
  /// brand; state is conveyed by depth and the pulse, not by a second hue.
  List<Color> _getGradientColors() {
    switch (widget.state) {
      case VoiceButtonState.listening:
        // Deepest ramp while recording — reads as "hot" without a new hue.
        return [AppColors.brandPrimaryDeep, AppColors.brandPrimary];
      case VoiceButtonState.processing:
        return [
          AppColors.brandPrimary.withAlpha((0.5 * 255).round()),
          AppColors.brandPrimaryDeep.withAlpha((0.5 * 255).round())
        ];
      case VoiceButtonState.speaking:
      case VoiceButtonState.idle:
        return [AppColors.brandPrimary, AppColors.brandPrimaryDeep];
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
