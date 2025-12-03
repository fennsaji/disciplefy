import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../animations/app_animations.dart';

/// Shimmer loading widgets for placeholder states
///
/// Provides consistent loading placeholders throughout the app.

/// Base shimmer wrapper with theme-aware colors
class ShimmerWrapper extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerWrapper({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
      highlightColor:
          highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!),
      child: child,
    );
  }
}

/// Shimmer placeholder for text lines
class ShimmerText extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerText({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
}

/// Shimmer placeholder for circular elements (avatars, icons)
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({
    super.key,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Shimmer placeholder for rectangular cards
class ShimmerCard extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerCard({
    super.key,
    this.width,
    this.height = 100,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
    );
  }
}

/// Shimmer loading for a study guide card
class ShimmerStudyGuideCard extends StatelessWidget {
  const ShimmerStudyGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title line
            const ShimmerText(width: 200, height: 20),
            const SizedBox(height: 12),
            // Description lines
            const ShimmerText(height: 14),
            const SizedBox(height: 8),
            const ShimmerText(width: 250, height: 14),
            const SizedBox(height: 16),
            // Footer with icon and text
            const Row(
              children: [
                ShimmerCircle(size: 24),
                SizedBox(width: 8),
                ShimmerText(width: 100, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading for the daily verse card
class ShimmerDailyVerseCard extends StatelessWidget {
  const ShimmerDailyVerseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerText(width: 120, height: 18),
                const ShimmerCircle(size: 32),
              ],
            ),
            const SizedBox(height: 20),
            // Language tabs
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  const ShimmerText(width: 80, height: 32),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 20),
            // Verse reference
            const ShimmerText(width: 150),
            const SizedBox(height: 16),
            // Verse content
            const ShimmerText(height: 18),
            const SizedBox(height: 8),
            const ShimmerText(height: 18),
            const SizedBox(height: 8),
            const ShimmerText(width: 200, height: 18),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShimmerCircle(size: 44),
                const SizedBox(width: 16),
                const ShimmerCircle(size: 44),
                const SizedBox(width: 16),
                const ShimmerCircle(size: 44),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading for list items
class ShimmerListItem extends StatelessWidget {
  final bool showAvatar;
  final int descriptionLines;

  const ShimmerListItem({
    super.key,
    this.showAvatar = true,
    this.descriptionLines = 2,
  });

  // Note: Default values are used for clarity in API design

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            if (showAvatar) ...[
              const ShimmerCircle(size: 48),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerText(width: 180),
                  const SizedBox(height: 8),
                  for (int i = 0; i < descriptionLines; i++) ...[
                    ShimmerText(
                      width: i == descriptionLines - 1 ? 120 : double.infinity,
                      height: 12,
                    ),
                    if (i < descriptionLines - 1) const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading for a grid of cards
class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const ShimmerGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.2,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ShimmerCard(),
    );
  }
}

/// Animated content revealer that shows shimmer then fades to real content
class ShimmerToContent extends StatefulWidget {
  final Widget shimmer;
  final Widget child;
  final bool isLoading;
  final Duration animationDuration;

  const ShimmerToContent({
    super.key,
    required this.shimmer,
    required this.child,
    required this.isLoading,
    this.animationDuration = AppAnimations.medium,
  });

  @override
  State<ShimmerToContent> createState() => _ShimmerToContentState();
}

class _ShimmerToContentState extends State<ShimmerToContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    );

    if (!widget.isLoading) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ShimmerToContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      _controller.forward();
    } else if (!oldWidget.isLoading && widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        if (_fadeAnimation.value == 0) {
          return widget.shimmer;
        } else if (_fadeAnimation.value == 1) {
          return widget.child;
        }
        return Stack(
          children: [
            Opacity(
              opacity: 1 - _fadeAnimation.value,
              child: widget.shimmer,
            ),
            Opacity(
              opacity: _fadeAnimation.value,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}
