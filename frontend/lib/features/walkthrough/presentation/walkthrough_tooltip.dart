// frontend/lib/features/walkthrough/presentation/walkthrough_tooltip.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/reader_palette.dart';
import '../domain/walkthrough_repository.dart';
import '../domain/walkthrough_screen.dart';
import '../domain/walkthrough_video_config.dart';
import 'showcase_keys.dart';

/// Wraps a widget with a Showcase tooltip using Disciplefy's visual style.
///
/// Renders a palette card bubble (dark/light) with a gold step eyebrow,
/// "Got it →", optional "▶ Watch video" (omitted when no video URL exists)
/// and "Skip", which ends this page's walkthrough and marks it seen.
///
/// showcaseview positions custom tooltips with fixed guesses that ignore the
/// real bubble height and the safe area, so the bubble is placed here
/// instead: it is laid out in the overlay next to the spotlight, above or
/// below the target (whichever side fits), clamped inside the safe area, with
/// the arrow pointing at the target's centre. While its step is active the
/// target is re-measured every frame, so the spotlight follows it through
/// scrolls, tab transitions and late layout changes.
class WalkthroughTooltip extends StatefulWidget {
  /// A unique [GlobalKey] that identifies this showcase target.
  final GlobalKey showcaseKey;

  /// Short headline shown in bold at the top of the bubble.
  final String title;

  /// Body text describing the highlighted feature.
  final String description;

  /// The screen this tooltip belongs to; used to look up the video URL and
  /// marked seen when the user taps "Skip".
  final WalkthroughScreen screen;

  /// 1-based index of this step.
  final int stepNumber;

  /// Total number of steps in this walkthrough sequence.
  final int totalSteps;

  /// The widget to highlight.
  final Widget child;

  /// Called when the user taps "Got it →".
  ///
  /// Should call [ShowCaseWidget.of(capturedContext).next()] where
  /// [capturedContext] is a context that is a *descendant* of [ShowCaseWidget].
  final VoidCallback onNext;

  /// Extra work to run when the user taps "Skip", after the walkthrough has
  /// been dismissed and [screen] marked seen.
  final VoidCallback? onSkip;

  /// Preferred side for the bubble. It is only a preference: when the bubble
  /// does not fit on that side it goes to the other one.
  final TooltipPosition tooltipPosition;

  /// Corner radius of the spotlight cut-out around the target.
  ///
  /// Defaults to 8. Pass the widget's own corner radius so the cut-out hugs
  /// its shape (e.g. 20 for a 20-radius card).
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
    this.onSkip,
    this.tooltipPosition = TooltipPosition.top,
    this.highlightBorderRadius = 8,
  });

  /// Space kept between the target and the cut-out edge.
  static const double targetGap = 4;

  @override
  State<WalkthroughTooltip> createState() => _WalkthroughTooltipState();
}

class _WalkthroughTooltipState extends State<WalkthroughTooltip>
    with SingleTickerProviderStateMixin {
  /// Target bounds in global coordinates, refreshed every frame while active.
  final ValueNotifier<Rect?> _targetRect = ValueNotifier<Rect?>(null);
  late final Ticker _ticker;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _syncTargetRect());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _targetRect.dispose();
    super.dispose();
  }

  Rect? _measureTarget() {
    final box = widget.showcaseKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _syncTargetRect() {
    final rect = _measureTarget();
    if (rect == null || rect == _targetRect.value) return;
    _targetRect.value = rect;
    // Rebuilding the Showcase makes showcaseview re-measure the target, so
    // the cut-out follows it instead of keeping its first (stale) position.
    if (mounted) setState(() {});
  }

  void _onActiveChanged(bool active) {
    _active = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_active) {
        _scrollIntoViewIfNeeded();
        if (!_ticker.isActive) _ticker.start();
      } else if (_ticker.isActive) {
        _ticker.stop();
      }
    });
  }

  /// Brings a target that sits (partly) outside the safe viewport into view.
  void _scrollIntoViewIfNeeded() {
    final rect = _measureTarget();
    final targetContext = widget.showcaseKey.currentContext;
    if (rect == null || targetContext == null) return;
    final media = MediaQuery.of(context);
    final visibleTop = media.viewPadding.top;
    final visibleBottom = media.size.height - media.viewPadding.bottom;
    if (rect.top >= visibleTop && rect.bottom <= visibleBottom) return;
    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.4,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Ends this page's walkthrough and records it as seen.
  void _skip() {
    try {
      ShowCaseWidget.of(context).dismiss();
    } catch (_) {
      // No ShowCaseWidget above us any more; nothing to dismiss.
    }
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl<WalkthroughRepository>().markSeen(widget.screen);
    }
    widget.onSkip?.call();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        ShowCaseWidget.activeTargetWidget(context) == widget.showcaseKey;
    if (active != _active) _onActiveChanged(active);

    final l10n = AppLocalizations.of(context)!;
    final radius = BorderRadius.circular(widget.highlightBorderRadius);
    final tourStep = ShowcaseKeys.homeTourStepOf(widget.showcaseKey);

    return Showcase.withWidget(
      key: widget.showcaseKey,
      // The real bubble is placed by [_TooltipPortal]; showcaseview only
      // lays out an empty box, so these sizes are nominal.
      width: 1,
      height: 1,
      tooltipPosition: widget.tooltipPosition,
      disableMovingAnimation: true,
      targetShapeBorder: RoundedRectangleBorder(borderRadius: radius),
      targetBorderRadius: radius,
      targetPadding: const EdgeInsets.all(WalkthroughTooltip.targetGap),
      overlayColor: Colors.black,
      overlayOpacity: 0.6,
      container: _TooltipPortal(
        targetRect: _targetRect,
        measureTarget: _measureTarget,
        preferAbove: widget.tooltipPosition == TooltipPosition.top,
        bubble: _TooltipBubble(
          title: widget.title,
          description: widget.description,
          // The home tour spans two ShowCaseWidgets and skips hidden tabs,
          // so its numbering comes from the tour actually running.
          stepNumber: tourStep?.step ?? widget.stepNumber,
          totalSteps: tourStep?.total ?? widget.totalSteps,
          videoUrl: WalkthroughVideoConfig.getVideoUrl(widget.screen),
          onNext: widget.onNext,
          onSkip: _skip,
          gotItLabel: l10n.walkthroughGotIt,
          watchVideoLabel: l10n.walkthroughWatchVideo,
          skipLabel: l10n.walkthroughSkip,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Renders the bubble into the enclosing [Overlay] (the one holding the
/// showcase), positioned by [_TooltipLayoutDelegate].
class _TooltipPortal extends StatefulWidget {
  final ValueNotifier<Rect?> targetRect;
  final Rect? Function() measureTarget;
  final bool preferAbove;
  final Widget bubble;

  const _TooltipPortal({
    required this.targetRect,
    required this.measureTarget,
    required this.preferAbove,
    required this.bubble,
  });

  @override
  State<_TooltipPortal> createState() => _TooltipPortalState();
}

class _TooltipPortalState extends State<_TooltipPortal> {
  final OverlayPortalController _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _controller.show();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (overlayContext) => ValueListenableBuilder<Rect?>(
        valueListenable: widget.targetRect,
        builder: (context, rect, _) {
          final globalRect = rect ?? widget.measureTarget();
          if (globalRect == null) return const SizedBox.shrink();
          final overlayBox =
              Overlay.of(overlayContext).context.findRenderObject();
          final origin = overlayBox is RenderBox && overlayBox.hasSize
              ? overlayBox.localToGlobal(Offset.zero)
              : Offset.zero;
          final media = MediaQuery.of(context);
          return Material(
            type: MaterialType.transparency,
            child: CustomMultiChildLayout(
              delegate: _TooltipLayoutDelegate(
                target: globalRect
                    .shift(-origin)
                    .inflate(WalkthroughTooltip.targetGap),
                safeArea: EdgeInsets.only(
                  top: math.max(0, media.viewPadding.top - origin.dy),
                  bottom: media.viewPadding.bottom,
                ),
                preferAbove: widget.preferAbove,
                maxBubbleWidth: media.size.width > 600 ? 380 : 300,
              ),
              children: [
                LayoutId(id: _TooltipSlot.bubble, child: widget.bubble),
                LayoutId(
                  id: _TooltipSlot.arrowDown,
                  child: _Arrow(color: ReaderPalette.of(context).card),
                ),
                LayoutId(
                  id: _TooltipSlot.arrowUp,
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: _Arrow(color: ReaderPalette.of(context).card),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      child: const SizedBox.shrink(),
    );
  }
}

enum _TooltipSlot { bubble, arrowDown, arrowUp }

/// Places the bubble on the side of [target] that fits, clamped inside the
/// screen's safe area, and points the matching arrow at the target.
class _TooltipLayoutDelegate extends MultiChildLayoutDelegate {
  final Rect target;
  final EdgeInsets safeArea;
  final bool preferAbove;
  final double maxBubbleWidth;

  _TooltipLayoutDelegate({
    required this.target,
    required this.safeArea,
    required this.preferAbove,
    required this.maxBubbleWidth,
  });

  static const double sideMargin = 12;
  static const double edgeMargin = 8;
  static const double arrowHeight = 10;
  static const double arrowWidth = 20;
  static const double bubbleRadius = 16;

  @override
  void performLayout(Size size) {
    final minTop = safeArea.top + edgeMargin;
    final maxBottom = size.height - safeArea.bottom - edgeMargin;
    final width =
        math.max(0.0, math.min(maxBubbleWidth, size.width - 2 * sideMargin));
    final bubble = layoutChild(
      _TooltipSlot.bubble,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0.0, maxBottom - minTop),
      ),
    );
    final arrowConstraints = BoxConstraints.tight(
      const Size(arrowWidth, arrowHeight),
    );
    layoutChild(_TooltipSlot.arrowDown, arrowConstraints);
    layoutChild(_TooltipSlot.arrowUp, arrowConstraints);

    final h = bubble.height;
    final spaceAbove = target.top - arrowHeight - minTop;
    final spaceBelow = maxBottom - target.bottom - arrowHeight;
    final bool above;
    if (preferAbove) {
      above = h <= spaceAbove || (h > spaceBelow && spaceAbove >= spaceBelow);
    } else {
      above =
          !(h <= spaceBelow || (h > spaceAbove && spaceBelow >= spaceAbove));
    }

    final rawTop =
        above ? target.top - arrowHeight - h : target.bottom + arrowHeight;
    final top =
        rawTop.clamp(minTop, math.max(minTop, maxBottom - h)).toDouble();
    final left = (target.center.dx - width / 2)
        .clamp(
            sideMargin, math.max(sideMargin, size.width - sideMargin - width))
        .toDouble();
    positionChild(_TooltipSlot.bubble, Offset(left, top));

    // The arrow only makes sense when the bubble did not have to be pushed
    // over the target to stay on screen.
    final arrowFits =
        above ? top + h <= target.top + 0.5 : top >= target.bottom - 0.5;
    final arrowX = (target.center.dx - arrowWidth / 2)
        .clamp(
          left + bubbleRadius,
          math.max(
              left + bubbleRadius, left + width - bubbleRadius - arrowWidth),
        )
        .toDouble();
    const hidden = Offset(-1000, -1000);
    positionChild(
      _TooltipSlot.arrowDown,
      above && arrowFits ? Offset(arrowX, top + h) : hidden,
    );
    positionChild(
      _TooltipSlot.arrowUp,
      !above && arrowFits ? Offset(arrowX, top - arrowHeight) : hidden,
    );
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) =>
      target != oldDelegate.target ||
      safeArea != oldDelegate.safeArea ||
      preferAbove != oldDelegate.preferAbove ||
      maxBubbleWidth != oldDelegate.maxBubbleWidth;
}

class _Arrow extends StatelessWidget {
  final Color color;

  const _Arrow({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(20, 10),
        painter: _DownArrowPainter(color: color),
      );
}

class _TooltipBubble extends StatelessWidget {
  final String title;
  final String description;
  final int stepNumber;
  final int totalSteps;
  final String? videoUrl;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String gotItLabel;
  final String watchVideoLabel;
  final String skipLabel;

  const _TooltipBubble({
    required this.title,
    required this.description,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
    required this.gotItLabel,
    required this.watchVideoLabel,
    required this.skipLabel,
    this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      key: const Key('walkthrough_tooltip_bubble'),
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
      // Scrolls only in the unlikely case the text is taller than the screen.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              description,
              style: AppFonts.inter(
                fontSize: 12.5,
                color: palette.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Wrap, not Row: Hindi/Malayalam labels are too wide to sit side
            // by side at 320px, so buttons drop to the next line whole.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TooltipPill(
                  label: gotItLabel,
                  fill: palette.ctaFill,
                  ink: palette.ctaInk,
                  onTap: onNext,
                ),
                if (videoUrl != null)
                  _TooltipPill(
                    // The localized label already starts with a play glyph.
                    label: watchVideoLabel,
                    fill: palette.raised,
                    ink: palette.text,
                    borderColor: palette.outline,
                    onTap: () async {
                      final uri = Uri.parse(videoUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                _TooltipPill(
                  key: const Key('walkthrough_skip'),
                  label: skipLabel,
                  fill: Colors.transparent,
                  ink: palette.muted,
                  onTap: onSkip,
                ),
              ],
            ),
          ],
        ),
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

/// Compact stadium button used inside the tooltip bubble.
class _TooltipPill extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;
  final Color? borderColor;
  final VoidCallback onTap;

  const _TooltipPill({
    super.key,
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
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
      ),
    );
  }
}
