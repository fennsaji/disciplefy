import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../../core/constants/app_colors.dart';
import '../../../gamification/domain/entities/achievement.dart';

/// Achievement Unlock Animation Widget.
///
/// Displays a celebratory animation when user unlocks an achievement:
/// - Badge zoom-in with bounce effect
/// - Particle explosion effect
/// - Confetti animation
/// - XP gain counter
/// - Sound effect (optional)
///
/// Auto-dismisses after 3 seconds or on tap.
class AchievementUnlockAnimation extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onDismiss;

  const AchievementUnlockAnimation({
    super.key,
    required this.achievement,
    this.onDismiss,
  });

  @override
  State<AchievementUnlockAnimation> createState() =>
      _AchievementUnlockAnimationState();
}

class _AchievementUnlockAnimationState extends State<AchievementUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _badgeController;
  late AnimationController _particleController;
  late AnimationController _xpController;

  late Animation<double> _badgeScale;
  late Animation<double> _badgeRotation;
  late Animation<double> _particleExplosion;
  late Animation<double> _xpCountUp;

  @override
  void initState() {
    super.initState();

    // Badge animation (zoom + bounce)
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _badgeScale = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    );

    _badgeRotation = Tween<double>(begin: 0, end: math.pi * 2).animate(
      CurvedAnimation(
        parent: _badgeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Particle explosion animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _particleExplosion = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    );

    // XP counter animation
    _xpController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _xpCountUp =
        Tween<double>(begin: 0, end: widget.achievement.xpReward.toDouble())
            .animate(
      CurvedAnimation(
        parent: _xpController,
        curve: Curves.easeOut,
      ),
    );

    // Start animations
    _badgeController.forward();
    _particleController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _xpController.forward();
      }
    });

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _particleController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: _dismiss,
        child: Stack(
          children: [
            // Particle explosion background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleExplosion,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ParticleExplosionPainter(
                      progress: _particleExplosion.value,
                      color: AppColors.primaryPurple,
                    ),
                  );
                },
              ),
            ),

            // Achievement badge
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge with animation
                  AnimatedBuilder(
                    animation: _badgeController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _badgeScale.value,
                        child: Transform.rotate(
                          angle: _badgeRotation.value,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.highlightGold,
                                  AppColors.highlightGold.withOpacity(0.7),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.highlightGold.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _getAchievementIcon(),
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Achievement unlocked text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🎉 Achievement Unlocked!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Achievement name
                  Text(
                    widget.achievement.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Achievement description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      widget.achievement.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // XP gained
                  AnimatedBuilder(
                    animation: _xpCountUp,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryPurple,
                              AppColors.primaryPurple.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+${_xpCountUp.value.toInt()} XP',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Tap to continue hint
                  const Text(
                    'Tap anywhere to continue',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon() {
    // Map achievement categories to icons
    switch (widget.achievement.category) {
      case AchievementCategory.study:
        return Icons.menu_book;
      case AchievementCategory.streak:
        return Icons.local_fire_department;
      case AchievementCategory.memory:
        return Icons.psychology;
      case AchievementCategory.voice:
        return Icons.mic;
      case AchievementCategory.saved:
        return Icons.bookmark;
    }
  }
}

/// Custom painter for particle explosion effect.
class ParticleExplosionPainter extends CustomPainter {
  final double progress;
  final Color color;

  ParticleExplosionPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    const particleCount = 30;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * math.pi * 2;
      final distance = progress * 200;
      final particleSize = (1 - progress) * 8;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      paint.color = color.withOpacity((1 - progress) * 0.8);

      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticleExplosionPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
