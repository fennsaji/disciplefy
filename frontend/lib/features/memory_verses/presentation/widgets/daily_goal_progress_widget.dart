import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/daily_goal_entity.dart';

/// Daily goal progress widget.
///
/// Displays memory verse daily goal progress with:
/// - Circular progress indicators for reviews and new verses
/// - Target/completion counts
/// - Goal achievement status
/// - Motivational messages
/// - Bonus XP display
class DailyGoalProgressWidget extends StatelessWidget {
  final DailyGoalEntity dailyGoal;
  final VoidCallback? onTap;
  final bool showDetailedStats;

  const DailyGoalProgressWidget({
    super.key,
    required this.dailyGoal,
    this.onTap,
    this.showDetailedStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = dailyGoal.isCompleted;

    return Card(
      elevation: isCompleted ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCompleted
            ? BorderSide(
                color: Colors.green,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Goal',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withAlpha((0.3 * 255).round()),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Complete',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress circles
              Row(
                children: [
                  // Reviews progress
                  Expanded(
                    child: _CircularProgressIndicator(
                      progress: dailyGoal.reviewsProgress,
                      completed: dailyGoal.completedReviews,
                      target: dailyGoal.targetReviews,
                      label: 'Reviews',
                      icon: Icons.replay,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // New verses progress
                  Expanded(
                    child: _CircularProgressIndicator(
                      progress: dailyGoal.newVersesProgress,
                      completed: dailyGoal.addedNewVerses,
                      target: dailyGoal.targetNewVerses,
                      label: 'New Verses',
                      icon: Icons.add_circle_outline,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),

              if (showDetailedStats) ...[
                const SizedBox(height: 20),

                // Overall progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Progress',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(dailyGoal.overallProgress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: dailyGoal.overallProgress,
                        backgroundColor: theme.colorScheme.primary
                            .withAlpha((0.2 * 255).round()),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted
                              ? Colors.green
                              : theme.colorScheme.primary,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Motivational message or bonus XP
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCompleted
                          ? [
                              Colors.green.withAlpha((0.1 * 255).round()),
                              Colors.lightGreen.withAlpha((0.1 * 255).round()),
                            ]
                          : [
                              theme.colorScheme.primaryContainer
                                  .withAlpha((0.3 * 255).round()),
                              theme.colorScheme.primaryContainer
                                  .withAlpha((0.1 * 255).round()),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted
                          ? Colors.green.withAlpha((0.3 * 255).round())
                          : theme.colorScheme.primary
                              .withAlpha((0.2 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.celebration : Icons.emoji_events,
                        color: isCompleted
                            ? Colors.green
                            : theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isCompleted) ...[
                              Text(
                                dailyGoal.motivationalMessage,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (dailyGoal.bonusXpAwarded > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${dailyGoal.bonusXpAwarded} XP Bonus',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.amber.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ] else ...[
                              Text(
                                dailyGoal.motivationalMessage,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular progress indicator widget for individual goals
class _CircularProgressIndicator extends StatelessWidget {
  final double progress;
  final int completed;
  final int target;
  final String label;
  final IconData icon;
  final Color color;

  const _CircularProgressIndicator({
    required this.progress,
    required this.completed,
    required this.target,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = progress >= 1.0;
    final displayProgress = progress.clamp(0.0, 1.0);

    return Column(
      children: [
        // Circular progress
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              CustomPaint(
                size: const Size(100, 100),
                painter: _CircularProgressPainter(
                  progress: displayProgress,
                  color: color,
                  backgroundColor: color.withAlpha((0.2 * 255).round()),
                ),
              ),
              // Center content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isComplete ? Colors.green : color,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed/$target',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isComplete ? Colors.green : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Completion checkmark overlay
              if (isComplete)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha((0.3 * 255).round()),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Label
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Custom painter for circular progress indicator
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    // Draw progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // Start from top
      const sweepAngleBase = 2 * math.pi;
      final sweepAngle = sweepAngleBase * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
