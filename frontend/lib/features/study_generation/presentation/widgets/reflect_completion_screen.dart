import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_mode.dart';

/// Completion screen shown after finishing Reflect Mode.
///
/// Displays a summary of the user's reflection session including:
/// - Selected themes and life areas
/// - Saved verses
/// - Time spent
/// - Prayer time
class ReflectCompletionScreen extends StatefulWidget {
  final String studyGuideId;
  final String? topicTitle;
  final StudyMode studyMode;
  final List<ReflectionResponse> responses;
  final int timeSpentSeconds;
  final VoidCallback onViewFullGuide;
  final VoidCallback onViewJournal;
  final VoidCallback onDone;

  const ReflectCompletionScreen({
    super.key,
    required this.studyGuideId,
    this.topicTitle,
    required this.studyMode,
    required this.responses,
    required this.timeSpentSeconds,
    required this.onViewFullGuide,
    required this.onViewJournal,
    required this.onDone,
  });

  @override
  State<ReflectCompletionScreen> createState() =>
      _ReflectCompletionScreenState();
}

class _ReflectCompletionScreenState extends State<ReflectCompletionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _celebrationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1, curve: Curves.easeOut),
      ),
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _animationController.forward();
      _celebrationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Success icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Reflection Complete',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (widget.topicTitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.topicTitle!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Summary card
                      _buildSummaryCard(theme),

                      const SizedBox(height: 24),

                      // Details sections
                      _buildDetailsSection(theme),

                      const SizedBox(height: 32),

                      // Action buttons
                      _buildActionButtons(theme),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Celebration particles
          AnimatedBuilder(
            animation: _celebrationController,
            builder: (context, child) {
              return CustomPaint(
                painter: _CelebrationPainter(
                  progress: _celebrationController.value,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                    Colors.pink,
                    Colors.orange,
                    Colors.green,
                  ],
                ),
                size: Size.infinite,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final minutes = widget.timeSpentSeconds ~/ 60;
    final savedVerses = _getSavedVerses();
    final lifeAreas = _getLifeAreas();
    final prayerTime = _getPrayerTime();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.08),
            AppTheme.secondaryColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Your Reflection Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                theme,
                icon: Icons.timer_outlined,
                value: '${minutes}m',
                label: 'Total Time',
              ),
              _buildStatItem(
                theme,
                icon: Icons.bookmark_outline,
                value: savedVerses.length.toString(),
                label: 'Verses Saved',
              ),
              if (prayerTime > 0)
                _buildStatItem(
                  theme,
                  icon: Icons.self_improvement,
                  value: '${(prayerTime / 60).round()}m',
                  label: 'Prayer Time',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(ThemeData theme) {
    final selectedTheme = _getSelectedTheme();
    final lifeAreas = _getLifeAreas();
    final savedVerses = _getSavedVerses();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected theme
        if (selectedTheme != null) ...[
          _buildDetailRow(
            theme,
            icon: Icons.lightbulb_outline,
            title: 'Theme Selected',
            content: selectedTheme,
          ),
          const SizedBox(height: 16),
        ],

        // Life areas
        if (lifeAreas.isNotEmpty) ...[
          _buildDetailRow(
            theme,
            icon: Icons.psychology_outlined,
            title: 'Areas for Focus',
            contentWidget: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: lifeAreas.map((area) {
                final lifeArea = LifeAreas.all.firstWhere(
                  (la) => la.id == area,
                  orElse: () =>
                      LifeAreaOption(id: area, label: area, icon: '•'),
                );
                return Chip(
                  avatar: Text(lifeArea.icon),
                  label: Text(lifeArea.label),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Saved verses
        if (savedVerses.isNotEmpty) ...[
          _buildDetailRow(
            theme,
            icon: Icons.bookmark_added,
            title: 'Verses Saved',
            contentWidget: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: savedVerses.map((verse) {
                return Chip(
                  label: Text(verse),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.3),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? content,
    Widget? contentWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (content != null) Text(content, style: theme.textTheme.bodyMedium),
          if (contentWidget != null) contentWidget,
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        // Primary action - Done
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onViewFullGuide,
                icon: const Icon(Icons.menu_book, size: 18),
                label: const Text('Read Full Guide'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onViewJournal,
                icon: const Icon(Icons.book, size: 18),
                label: const Text('View Journal'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods to extract data from responses
  String? _getSelectedTheme() {
    for (final response in widget.responses) {
      if (response.interactionType == ReflectionInteractionType.tapSelection) {
        return response.value as String?;
      }
    }
    return null;
  }

  List<String> _getLifeAreas() {
    for (final response in widget.responses) {
      if (response.interactionType == ReflectionInteractionType.multiSelect) {
        return List<String>.from(response.value as List? ?? []);
      }
    }
    return [];
  }

  List<String> _getSavedVerses() {
    for (final response in widget.responses) {
      if (response.interactionType ==
          ReflectionInteractionType.verseSelection) {
        return List<String>.from(response.value as List? ?? []);
      }
    }
    return [];
  }

  int _getPrayerTime() {
    for (final response in widget.responses) {
      if (response.interactionType == ReflectionInteractionType.prayer) {
        final data = response.value as Map<String, dynamic>?;
        return data?['duration'] as int? ?? 0;
      }
    }
    return 0;
  }
}

/// Custom painter for celebration particle animation.
class _CelebrationPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final List<_Particle> _particles;

  _CelebrationPainter({
    required this.progress,
    required this.colors,
  }) : _particles = _generateParticles(colors);

  static List<_Particle> _generateParticles(List<Color> colors) {
    final random = Random(42); // Fixed seed for consistent animation
    return List.generate(30, (index) {
      return _Particle(
        x: random.nextDouble(),
        y: random.nextDouble() * 0.3,
        size: random.nextDouble() * 8 + 4,
        color: colors[random.nextInt(colors.length)],
        speed: random.nextDouble() * 0.5 + 0.3,
        angle: random.nextDouble() * pi * 2,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    for (final particle in _particles) {
      final x = size.width * particle.x +
          cos(particle.angle) * progress * size.width * 0.3;
      final y =
          size.height * particle.y + progress * size.height * particle.speed;

      final opacity = (1 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1 - progress * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double speed;
  final double angle;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speed,
    required this.angle,
  });
}
