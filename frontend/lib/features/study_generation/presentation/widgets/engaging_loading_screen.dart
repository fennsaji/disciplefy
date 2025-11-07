import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Engaging loading screen with multi-stage progress, rotating Bible verses,
/// and smooth animations to keep users engaged during 30+ second AI generation.
class EngagingLoadingScreen extends StatefulWidget {
  /// Optional custom message to display
  final String? message;

  /// Optional topic/verse being generated (for context)
  final String? topic;

  const EngagingLoadingScreen({
    super.key,
    this.message,
    this.topic,
  });

  @override
  State<EngagingLoadingScreen> createState() => _EngagingLoadingScreenState();
}

class _EngagingLoadingScreenState extends State<EngagingLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  int _currentStage = 0;
  int _currentVerseIndex = 0;
  Timer? _stageTimer;
  Timer? _verseTimer;

  // Multi-stage progress messages
  final List<String> _stages = [
    'Preparing your study guide...',
    'Analyzing scripture context...',
    'Gathering insights...',
    'Crafting reflections...',
    'Finalizing your guide...',
  ];

  // Rotating Bible verses to keep users engaged
  final List<Map<String, String>> _verses = [
    {
      'text': 'Your word is a lamp to my feet and a light to my path.',
      'reference': 'Psalm 119:105',
    },
    {
      'text': 'All Scripture is God-breathed and is useful for teaching.',
      'reference': '2 Timothy 3:16',
    },
    {
      'text':
          'Faith comes from hearing, and hearing through the word of Christ.',
      'reference': 'Romans 10:17',
    },
    {
      'text': 'The word of God is living and active, sharper than any sword.',
      'reference': 'Hebrews 4:12',
    },
    {
      'text': 'Be doers of the word, and not hearers only.',
      'reference': 'James 1:22',
    },
    {
      'text': 'Man shall not live by bread alone, but by every word from God.',
      'reference': 'Matthew 4:4',
    },
  ];

  @override
  void initState() {
    super.initState();

    // Pulse animation for the main circle
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotation animation for the outer ring
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // Stage progression timer (every 6 seconds)
    _stageTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentStage = (_currentStage + 1) % _stages.length;
        });
      }
    });

    // Verse rotation timer (every 5 seconds)
    _verseTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentVerseIndex = (_currentVerseIndex + 1) % _verses.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _stageTimer?.cancel();
    _verseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = screenHeight * 0.15;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D2D2D),
                ]
              : [
                  AppTheme.primaryColor.withOpacity(0.03),
                  Colors.white,
                ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              top: topPadding,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            child: Column(
              children: [
                // Animated loading circle with pulse effect
                _buildAnimatedLoadingCircle(),

                const SizedBox(height: 40),

                // Topic being generated (if provided)
                if (widget.topic != null) ...[
                  _buildTopicDisplay(),
                  const SizedBox(height: 32),
                ],

                // Multi-stage progress indicator
                _buildStageIndicator(),

                const SizedBox(height: 48),

                // Rotating Bible verse
                _buildRotatingVerse(),

                const SizedBox(height: 32),

                // Time estimate
                _buildTimeEstimate(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLoadingCircle() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      width: 3,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _ArcPainter(
                      color: AppTheme.primaryColor,
                      progress: 0.25,
                    ),
                  ),
                ),
              );
            },
          ),

          // Pulsing center circle
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.8),
                        AppTheme.primaryColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopicDisplay() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.primaryColor.withOpacity(0.2)
            : AppTheme.highlightColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppTheme.primaryColor.withOpacity(0.5)
              : AppTheme.highlightColor,
          width: isDarkMode ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: isDarkMode ? Colors.white : AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.topic!,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageIndicator() {
    return Column(
      children: [
        // Progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _stages.length,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: index == _currentStage ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: index == _currentStage
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Current stage message
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _stages[_currentStage],
            key: ValueKey<int>(_currentStage),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildRotatingVerse() {
    final currentVerse = _verses[_currentVerseIndex];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Container(
        key: ValueKey<int>(_currentVerseIndex),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(
                  0xFF4A4A4A) // Much lighter gray for maximum contrast
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(isDarkMode ? 0.5 : 0.1),
            width: isDarkMode ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Decorative quote icon
            Icon(
              Icons.format_quote,
              color: AppTheme.primaryColor.withOpacity(isDarkMode ? 0.6 : 0.3),
              size: 32,
            ),

            const SizedBox(height: 12),

            // Verse text
            Text(
              currentVerse['text']!,
              style: GoogleFonts.playfairDisplay(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: isDarkMode
                    ? Colors.white
                        .withOpacity(0.95) // Bright white for dark mode
                    : Theme.of(context).colorScheme.onSurface,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Verse reference
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    AppTheme.primaryColor.withOpacity(isDarkMode ? 0.3 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentVerse['reference']!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white // Bright white for dark mode
                      : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEstimate() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.access_time,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          'This usually takes 20-30 seconds',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for drawing arc segments in the loading circle
class _ArcPainter extends CustomPainter {
  final Color color;
  final double progress;

  _ArcPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
