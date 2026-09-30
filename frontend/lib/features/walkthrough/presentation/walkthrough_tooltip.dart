// frontend/lib/features/walkthrough/presentation/walkthrough_tooltip.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/reader_palette.dart';
import '../domain/walkthrough_screen.dart';
import '../domain/walkthrough_video_config.dart';

/// Wraps a widget with a Showcase tooltip using Disciplefy's visual style.
///
/// Renders a palette card bubble (dark/light) with a gold step eyebrow, a
/// gold border highlight on the target, "Got it →" button,
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
  static const double _maxTooltipWidthPhone = 280;
  static const double _maxTooltipWidthDesktop = 380;
  static const double _tooltipHeight = 160; // includes arrow height
  static const double _tooltipHorizontalMargin = 48; // 24px each side

  @override
  Widget build(BuildContext context) {
    final videoUrl = WalkthroughVideoConfig.getVideoUrl(screen);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth =
        screenWidth > 600 ? _maxTooltipWidthDesktop : _maxTooltipWidthPhone;
    final tooltipWidth =
        math.min(maxWidth, screenWidth - _tooltipHorizontalMargin);

    return Showcase.withWidget(
      key: showcaseKey,
      width: tooltipWidth,
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
        maxWidth: tooltipWidth,
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

  /// Maximum width of the tooltip bubble, responsive to screen size.
  final double maxWidth;

  const _TooltipContent({
    required this.title,
    required this.description,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.gotItLabel,
    required this.watchVideoLabel,
    required this.maxWidth,
    this.videoUrl,
    this.arrowAtBottom = true,
    this.arrowAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final bubble = Container(
      width: maxWidth,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold step eyebrow
          Text(
            '$stepNumber / $totalSteps',
            style: AppFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: palette.text,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Description
          Text(
            description,
            style: AppFonts.inter(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons. Wrap, not Row: the Malayalam labels are too wide
          // to sit side by side and overflowed the bubble.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GotItButton(onTap: onNext, label: gotItLabel),
              if (videoUrl != null)
                _WatchVideoButton(videoUrl: videoUrl!, label: watchVideoLabel),
            ],
          ),
        ],
      ),
    );

    // Arrow pointing toward the target widget, in the bubble's own fill.
    final arrowShape = CustomPaint(
      size: const Size(20, 10),
      painter: _DownArrowPainter(color: palette.card),
    );

    // Wrap in Align so the arrow can be offset horizontally (e.g. right-aligned
    // when the target is a bottom-nav tab near the right edge of the screen).
    Widget positionedArrow(Widget a) =>
        Align(alignment: arrowAlignment, child: a);

    // IntrinsicWidth + stretch give the arrow row the bubble's width. Without
    // them the Align was only as wide as the arrow, so arrowAlignment had no
    // effect and the arrow always sat in the middle of the bubble.
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: arrowAtBottom
            ? [
                bubble,
                positionedArrow(arrowShape),
              ]
            : [
                positionedArrow(RotatedBox(quarterTurns: 2, child: arrowShape)),
                bubble,
              ],
      ),
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
    final palette = ReaderPalette.of(context);
    return _TooltipPill(
      label: label,
      fill: palette.ctaFill,
      ink: palette.ctaInk,
      onTap: onTap,
    );
  }
}

class _WatchVideoButton extends StatelessWidget {
  final String videoUrl;
  final String label;

  const _WatchVideoButton({required this.videoUrl, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return _TooltipPill(
      // The localized label already starts with a play glyph.
      label: label,
      fill: palette.raised,
      ink: palette.text,
      borderColor: palette.outline,
      onTap: () async {
        final uri = Uri.parse(videoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

/// Compact stadium button used inside the tooltip bubble.
class _TooltipPill extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;
  final Color? borderColor;
  final VoidCallback onTap;

  const _TooltipPill({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      shape: StadiumBorder(
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: AppFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}
