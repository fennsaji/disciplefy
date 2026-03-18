// frontend/lib/features/walkthrough/presentation/walkthrough_tooltip.dart

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/walkthrough_screen.dart';
import '../domain/walkthrough_video_config.dart';

/// Wraps a widget with a Showcase tooltip using Disciplefy's visual style.
///
/// Renders a white bubble with gold border highlight, "Got it →" button,
/// optional "▶ Watch video" button (omitted when no video URL exists), and
/// a step counter (e.g. "1 / 3").
///
/// Uses [Showcase.withWidget] so the tooltip container can carry a box shadow
/// and arbitrary layout not supported by the default [Showcase] constructor.
class WalkthroughTooltip extends StatelessWidget {
  /// A unique [GlobalKey] that identifies this showcase target.
  final GlobalKey showcaseKey;

  /// Short headline shown in bold at the top of the bubble.
  final String title;

  /// Body text describing the highlighted feature.
  final String description;

  /// The screen this tooltip belongs to; used to look up the video URL.
  final WalkthroughScreen screen;

  /// 1-based index of this step.
  final int stepNumber;

  /// Total number of steps in this walkthrough sequence.
  final int totalSteps;

  /// The widget to highlight with the gold border ring.
  final Widget child;

  /// Called when the user taps "Got it →".
  ///
  /// Should call [ShowCaseWidget.of(capturedContext).next()] where
  /// [capturedContext] is a context that is a *descendant* of [ShowCaseWidget].
  final VoidCallback onNext;

  /// Where to position the tooltip relative to the target widget.
  ///
  /// Use [TooltipPosition.top] (default) for elements in the middle/bottom of
  /// the screen so the tooltip appears above. Use [TooltipPosition.bottom] for
  /// elements near the top of the screen (e.g. header icons) so the tooltip
  /// appears below without being clipped.
  final TooltipPosition tooltipPosition;

  /// Horizontal alignment of the pointing arrow within the tooltip bubble.
  ///
  /// Defaults to [Alignment.center]. Use [Alignment.centerRight] when the
  /// target widget is near the right edge of the screen (e.g. a bottom-nav tab).
  final Alignment arrowAlignment;

  /// Border radius of the gold highlight ring around the target widget.
  ///
  /// Defaults to 8. Override with the widget's own corner radius so the ring
  /// hugs the widget shape (e.g. pass 20 for the DailyVerseCard).
  final double highlightBorderRadius;

  const WalkthroughTooltip({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.screen,
    required this.stepNumber,
    required this.totalSteps,
    required this.child,
    required this.onNext,
    this.tooltipPosition = TooltipPosition.top,
    this.arrowAlignment = Alignment.center,
    this.highlightBorderRadius = 8,
  });

  // Design tokens
  static const _gold = Color(0xFFFFEEC0);

  // Tooltip bubble dimensions
  static const double _tooltipWidth = 280;
  static const double _tooltipHeight = 160; // includes arrow height

  @override
  Widget build(BuildContext context) {
    final videoUrl = WalkthroughVideoConfig.getVideoUrl(screen);
    final l10n = AppLocalizations.of(context)!;

    return Showcase.withWidget(
      key: showcaseKey,
      width: _tooltipWidth,
      height: _tooltipHeight,
      tooltipPosition: tooltipPosition,
      // Gold border ring around the highlighted widget
      targetShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(highlightBorderRadius),
        side: const BorderSide(color: _gold, width: 3),
      ),
      targetBorderRadius: BorderRadius.circular(highlightBorderRadius),
      targetPadding: const EdgeInsets.all(4),
      overlayColor: Colors.black,
      overlayOpacity: 0.6,
      container: _TooltipContent(
        title: title,
        description: description,
        stepNumber: stepNumber,
        totalSteps: totalSteps,
        videoUrl: videoUrl,
        onNext: onNext,
        gotItLabel: l10n.walkthroughGotIt,
        watchVideoLabel: l10n.walkthroughWatchVideo,
        arrowAtBottom: tooltipPosition == TooltipPosition.top,
        arrowAlignment: arrowAlignment,
      ),
      child: child,
    );
  }
}

class _TooltipContent extends StatelessWidget {
  final String title;
  final String description;
  final int stepNumber;
  final int totalSteps;
  final String? videoUrl;

  /// Invoked when the user taps "Got it →". Advances the showcase.
  final VoidCallback onNext;

  /// Localized label for the "Got it" button.
  final String gotItLabel;

  /// Localized label for the "Watch video" button.
  final String watchVideoLabel;

  /// When true, the arrow appears at the bottom pointing down toward the target
  /// (tooltip is above target). When false, arrow appears at the top pointing
  /// up toward the target (tooltip is below target).
  final bool arrowAtBottom;

  /// Horizontal alignment of the arrow within the bubble width.
  /// Defaults to [Alignment.center].
  final Alignment arrowAlignment;

  const _TooltipContent({
    required this.title,
    required this.description,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.gotItLabel,
    required this.watchVideoLabel,
    this.videoUrl,
    this.arrowAtBottom = true,
    this.arrowAlignment = Alignment.center,
  });

  static const _mutedGrey = Color(0xFF9CA3AF);
  static const _arrowColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with step counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              Text(
                '$stepNumber / $totalSteps',
                style: const TextStyle(fontSize: 11, color: _mutedGrey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              _GotItButton(onTap: onNext, label: gotItLabel),
              if (videoUrl != null) ...[
                const SizedBox(width: 8),
                _WatchVideoButton(videoUrl: videoUrl!, label: watchVideoLabel),
              ],
            ],
          ),
        ],
      ),
    );

    // Arrow pointing toward the target widget
    final arrowShape = CustomPaint(
      size: const Size(20, 10),
      painter: const _DownArrowPainter(color: _arrowColor),
    );

    // Wrap in Align so the arrow can be offset horizontally (e.g. right-aligned
    // when the target is a bottom-nav tab near the right edge of the screen).
    Widget positionedArrow(Widget a) =>
        Align(alignment: arrowAlignment, child: a);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: arrowAtBottom
          ? [
              bubble,
              positionedArrow(arrowShape),
            ]
          : [
              positionedArrow(RotatedBox(quarterTurns: 2, child: arrowShape)),
              bubble,
            ],
    );
  }
}

/// Paints a downward-pointing triangle arrow.
class _DownArrowPainter extends CustomPainter {
  final Color color;

  const _DownArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DownArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GotItButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _GotItButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WatchVideoButton extends StatelessWidget {
  final String videoUrl;
  final String label;

  const _WatchVideoButton({required this.videoUrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(videoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E7FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4F46E5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
