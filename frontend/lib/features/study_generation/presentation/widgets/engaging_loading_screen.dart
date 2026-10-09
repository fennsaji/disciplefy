import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/photo_wash.dart';

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

  // Track whether initial random fact has been set
  bool _isFactInitialized = false;

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

    // Prevent screen from turning off during AI generation
    if (!kIsWeb) {
      WakelockPlus.enable();
    }

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
      // ✅ FIX: Check mounted BEFORE accessing context
      if (!mounted) return;

      // Compute safe count dynamically from actual facts list each tick
      // to handle race condition where timer fires before didChangeDependencies
      final actualFacts = _getFacts(context);
      final safeCount = actualFacts.isNotEmpty ? actualFacts.length : 1;

      setState(() {
        // Generate random index only if we have facts, otherwise use 0
        _currentFactIndex = safeCount > 0 ? _random.nextInt(safeCount) : 0;

        // Update cached count for consistency
        _factsCount = actualFacts.length;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Now we have context, get actual facts and initialize properly
    final facts = _getFacts(context);
    _factsCount = facts.length;

    // Set initial random fact index using actual facts length
    if (!_isFactInitialized && _factsCount > 0) {
      _currentFactIndex = _random.nextInt(_factsCount);
      _isFactInitialized = true;
    } else if (_currentFactIndex >= _factsCount) {
      // Clamp if somehow out of bounds
      _currentFactIndex = _factsCount > 0 ? _factsCount - 1 : 0;
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      WakelockPlus.disable();
    }
    _pulseController.dispose();
    _rotationController.dispose();
    _stageTimer?.cancel();
    _factTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = screenHeight * 0.12;

    // Same scenery wash as the guide header, tied to what is being studied.
    return PhotoWash.forKey(
      photoKey: widget.topic ?? '',
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

                const SizedBox(height: 36),

                // Topic being generated (if provided)
                if (widget.topic != null) ...[
                  _buildTopicDisplay(),
                  const SizedBox(height: 28),
                ],

                // Multi-stage progress indicator
                _buildStageIndicator(),

                const SizedBox(height: 40),

                // Rotating historical fact
                _buildRotatingFact(),

                const SizedBox(height: 28),

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
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring: hairline track with a gold arc.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) => Transform.rotate(
                angle: _rotationAnimation.value,
                child: child,
              ),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.hairline, width: 3),
                ),
                child: CustomPaint(
                  painter: _ArcPainter(color: palette.gold, progress: 0.25),
                ),
              ),
            ),
          ),

          // Gently pulsing centre: flat tinted disc, no glow.
          RepaintBoundary(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.card,
                  border: Border.all(color: palette.hairline),
                ),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.gold
                        .withValues(alpha: palette.isDark ? 0.24 : 0.1),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: palette.accentIcon,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicDisplay() {
    final palette = ReaderPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: palette.accentIcon,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.topic!,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.text,
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
    final palette = ReaderPalette.of(context);

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
                width: index == _currentStage ? 28 : 8,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color:
                      index == _currentStage ? palette.gold : palette.outline,
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
            style: AppFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.3,
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
    final palette = ReaderPalette.of(context);

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
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          children: [
            // Historical fact icon
            Icon(
              Icons.history_edu_rounded,
              color: palette.gold,
              size: 28,
            ),

            const SizedBox(height: 14),

            // Historical fact text
            Text(
              currentFact,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: palette.text,
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

    final palette = ReaderPalette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.access_time, size: 16, color: palette.muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            l10n.loadingTimeEstimate,
            textAlign: TextAlign.center,
            style: AppFonts.inter(fontSize: 13, color: palette.muted),
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
