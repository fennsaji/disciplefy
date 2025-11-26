import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Animated waveform visualization for voice recording indicator.
///
/// Displays animated vertical bars that respond to simulate audio input
/// visualization during voice recording.
class VoiceWaveform extends StatefulWidget {
  /// Whether the waveform animation is active.
  final bool isActive;

  /// Number of bars in the waveform.
  final int barCount;

  /// Color of the waveform bars.
  final Color? barColor;

  /// Maximum height of the waveform container.
  final double height;

  /// Width of each bar.
  final double barWidth;

  /// Spacing between bars.
  final double barSpacing;

  const VoiceWaveform({
    super.key,
    required this.isActive,
    this.barCount = 30,
    this.barColor,
    this.height = 60.0,
    this.barWidth = 3.0,
    this.barSpacing = 2.0,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late List<double> _heights;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _heights = List.generate(widget.barCount, (_) => 0.2);

    if (widget.isActive) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimation();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          final now = DateTime.now().millisecondsSinceEpoch / 100.0;
          for (int i = 0; i < _heights.length; i++) {
            // Create a wave-like pattern with some randomness
            _heights[i] = 0.2 +
                (0.8 * (0.5 + 0.5 * sin(now + i * 0.3))) *
                    (0.7 + 0.3 * Random().nextDouble());
          }
        });
      }
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        for (int i = 0; i < _heights.length; i++) {
          _heights[i] = 0.2;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.barColor ?? theme.colorScheme.primary;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _heights.asMap().entries.map((entry) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: EdgeInsets.symmetric(horizontal: widget.barSpacing / 2),
            width: widget.barWidth,
            height: widget.height * entry.value,
            decoration: BoxDecoration(
              color: color.withAlpha((0.7 * 255).round()),
              borderRadius: BorderRadius.circular(widget.barWidth / 2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A simpler pulsing indicator for voice activity.
class VoicePulseIndicator extends StatefulWidget {
  /// Whether the pulse animation is active.
  final bool isActive;

  /// Size of the indicator.
  final double size;

  /// Color of the pulse rings.
  final Color? color;

  const VoicePulseIndicator({
    super.key,
    required this.isActive,
    this.size = 100.0,
    this.color,
  });

  @override
  State<VoicePulseIndicator> createState() => _VoicePulseIndicatorState();
}

class _VoicePulseIndicatorState extends State<VoicePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(VoicePulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _PulseRingPainter(
              progress: _animation.value,
              color: color,
              isActive: widget.isActive,
            ),
          );
        },
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  _PulseRingPainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw multiple rings with fading opacity
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.3) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.5;

      final paint = Paint()
        ..color = color.withAlpha((opacity * 255).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isActive != isActive;
  }
}
