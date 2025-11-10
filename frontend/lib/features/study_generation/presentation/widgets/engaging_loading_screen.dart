import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';

/// Engaging loading screen with multi-stage progress, rotating historical facts,
/// and smooth animations to keep users engaged during 30+ second AI generation.
class EngagingLoadingScreen extends StatefulWidget {
  /// Optional custom message to display
  final String? message;

  /// Optional topic/verse being generated (for context)
  final String? topic;

  /// Language code for localized content (e.g., 'en', 'hi', 'ml')
  /// If not provided, uses app's current locale
  final String? language;

  const EngagingLoadingScreen({
    super.key,
    this.message,
    this.topic,
    this.language,
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
  int _currentFactIndex = 0;
  Timer? _stageTimer;
  Timer? _factTimer;

  // Random instance for fact selection
  final math.Random _random = math.Random();

  // Expected number of historical facts (used as safe fallback)
  static const int _defaultFactsCount = 60;

  // Actual facts count (updated once we have context)
  int _factsCount = _defaultFactsCount;

  /// Resolves a language string to a valid supported Locale.
  ///
  /// Validates against supported locales, matches by language code,
  /// and falls back to context's current locale if not found.
  ///
  /// @returns A valid [Locale] that is guaranteed to be supported.
  Locale _resolveLocale(BuildContext context, String? languageCode) {
    if (languageCode == null || languageCode.isEmpty) {
      // No language specified, use context's locale
      return Localizations.localeOf(context);
    }

    // Parse the language code (e.g., 'en', 'en-US', 'hi-IN')
    // Extract base language code (first segment before '-')
    final baseLang = languageCode.split('-').first.toLowerCase();

    // Try to match against supported locales
    for (final supportedLocale in AppLocalizations.supportedLocales) {
      // Try exact match first (e.g., 'en' == 'en')
      if (supportedLocale.languageCode.toLowerCase() == baseLang) {
        return supportedLocale;
      }
    }

    // No match found, fall back to context's current locale
    return Localizations.localeOf(context);
  }

  // Get localized stages
  List<String> _getStages(BuildContext context) {
    // Resolve the locale safely
    final locale = _resolveLocale(context, widget.language);
    final l10n = AppLocalizations(locale);

    return [
      l10n.loadingStagePreparing,
      l10n.loadingStageAnalyzing,
      l10n.loadingStageGathering,
      l10n.loadingStageCrafting,
      l10n.loadingStageFinalizing,
    ];
  }

  // Get all 60 localized historical facts
  List<String> _getFacts(BuildContext context) {
    // Resolve the locale safely
    final locale = _resolveLocale(context, widget.language);
    final l10n = AppLocalizations(locale);

    return l10n.allLoadingFacts;
  }

  @override
  void initState() {
    super.initState();

    // Initialize with safe default (will be properly bounded in didChangeDependencies)
    // Use 0 as safe default since we don't have context yet to get actual facts
    _currentFactIndex = 0;

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

    // Stage progression timer (every 6 seconds, 5 stages)
    _stageTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _currentStage = (_currentStage + 1) % 5; // 5 stages
        });
      }
    });

    // Historical fact rotation timer (every 5 seconds, random fact)
    _factTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          // Use actual facts count to ensure we stay in bounds
          _currentFactIndex =
              _factsCount > 0 ? _random.nextInt(_factsCount) : 0;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Now we have context, get actual facts and initialize properly
    final facts = _getFacts(context);
    _factsCount = facts.length;

    // Set initial random fact index using actual facts length
    if (_currentFactIndex == 0 && _factsCount > 0) {
      // Only set random on first time (when it's still 0 from initState)
      _currentFactIndex = _random.nextInt(_factsCount);
    } else if (_currentFactIndex >= _factsCount) {
      // Clamp if somehow out of bounds
      _currentFactIndex = _factsCount > 0 ? _factsCount - 1 : 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _stageTimer?.cancel();
    _factTimer?.cancel();
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

                // Rotating historical fact
                _buildRotatingFact(),

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
    final stages = _getStages(context);

    return Column(
      children: [
        // Progress dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5, // 5 stages
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
            stages[_currentStage],
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

  Widget _buildRotatingFact() {
    final facts = _getFacts(context);

    // Guard against out-of-bounds access: clamp or reset index if needed
    if (_currentFactIndex >= facts.length) {
      _currentFactIndex = facts.isNotEmpty ? facts.length - 1 : 0;
    }

    // Additional safety: ensure facts list is not empty
    if (facts.isEmpty) {
      // Return empty container if no facts available
      return const SizedBox.shrink();
    }

    final currentFact = facts[_currentFactIndex];
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
        key: ValueKey<int>(_currentFactIndex),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF4A4A4A) // Lighter gray for dark mode contrast
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
            // Historical fact icon
            Icon(
              Icons.history_edu_rounded,
              color: AppTheme.primaryColor.withOpacity(isDarkMode ? 0.7 : 0.4),
              size: 32,
            ),

            const SizedBox(height: 16),

            // Historical fact text
            Text(
              currentFact,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.95)
                    : Theme.of(context).colorScheme.onSurface,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEstimate() {
    // Resolve the locale safely
    final locale = _resolveLocale(context, widget.language);
    final l10n = AppLocalizations(locale);

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
          l10n.loadingTimeEstimate,
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
