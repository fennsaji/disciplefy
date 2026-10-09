import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/style.dart';

/// Page top bar: back arrow (or close) + Poppins title 22/700 and a small
/// gold subtitle ("1 due today", "Philippians 4:13"), with optional actions.
///
/// For practice screens use [MemoryPracticeTopBar] instead.
class MemoryTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Trailing icon buttons (use [MemoryBarAction]).
  final List<Widget> actions;

  /// Close (x) instead of a back arrow, for modal steps (add verse, results).
  final bool useCloseIcon;

  /// Hide the leading button entirely (e.g. a root tab).
  final bool showLeading;

  /// Subtitle colour; gold by default.
  final Color? subtitleColor;

  /// Title size; 22 by default (the deck list uses 24).
  final double titleFontSize;

  const MemoryTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.useCloseIcon = false,
    this.showLeading = true,
    this.subtitleColor,
    this.titleFontSize = 22,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Material(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Row(
            children: [
              if (showLeading) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: useCloseIcon
                      ? localizations.closeButtonTooltip
                      : localizations.backButtonTooltip,
                  icon: Icon(
                    useCloseIcon ? Icons.close_rounded : Icons.arrow_back,
                    color: palette.text,
                    size: 22,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 2),
              ] else
                const SizedBox(width: kMemoryGutter),
              Expanded(
                child: MemoryTitleBlock(
                  title: title,
                  subtitle: subtitle,
                  titleStyle: AppFonts.poppins(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.2,
                  ),
                  compactTitleSize: 17,
                  subtitleStyle: AppFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor ?? palette.gold,
                    height: 1.25,
                  ),
                  maxHeight: preferredSize.height - 6,
                ),
              ),
              ...actions,
              SizedBox(width: actions.isEmpty ? kMemoryGutter : 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain icon action for [MemoryTopBar] / [MemoryPracticeTopBar].
class MemoryBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const MemoryBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: ReaderPalette.of(context).text),
      );
}

/// Practice top bar: close (x) + Poppins 16/600 title, a muted subtitle
/// ("Philippians 4:13 · Easy") and, on the right, an optional timer pill
/// and/or extra actions.
class MemoryPracticeTopBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final String? subtitle;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onClose;

  /// Seconds for the timer pill; `null` hides the pill.
  final int? elapsedSeconds;

  /// Extra trailing widgets placed before the timer pill (e.g. a help icon).
  final List<Widget> actions;

  /// Leading icon; close by default, set to [Icons.arrow_back] if needed.
  final IconData leadingIcon;

  const MemoryPracticeTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.elapsedSeconds,
    this.actions = const [],
    this.leadingIcon = Icons.close_rounded,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Material(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: leadingIcon == Icons.close_rounded
                    ? localizations.closeButtonTooltip
                    : localizations.backButtonTooltip,
                icon: Icon(leadingIcon, color: palette.text, size: 22),
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: MemoryTitleBlock(
                  title: title,
                  subtitle: subtitle,
                  titleStyle: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.25,
                  ),
                  compactTitleSize: 14,
                  subtitleStyle: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
                    height: 1.25,
                  ),
                  maxHeight: preferredSize.height - 6,
                ),
              ),
              ...actions,
              if (elapsedSeconds != null) ...[
                const SizedBox(width: 6),
                MemoryTimerPill(elapsedSeconds: elapsedSeconds!),
              ],
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raised stadium with a gold timer icon and `m:ss` elapsed time.
class MemoryTimerPill extends StatelessWidget {
  final int elapsedSeconds;

  const MemoryTimerPill({super.key, required this.elapsedSeconds});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final text = formatPracticeDuration(elapsedSeconds);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: palette.gold),
            const SizedBox(width: 6),
            Text(
              text,
              style: AppFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.text,
                fontFeatures: kMemoryTabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title + optional subtitle of a fixed-height top bar that never cuts text
/// off with an ellipsis.
///
/// The title stays on one line at its full size when it fits; otherwise it
/// drops to [compactTitleSize] and wraps onto two lines. The subtitle takes
/// one line, or two when the title is on one line. Whatever still does not
/// fit in [maxHeight] (very large text scale) is scaled down as a whole
/// instead of being clipped.
class MemoryTitleBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextStyle titleStyle;
  final double compactTitleSize;
  final TextStyle subtitleStyle;
  final double maxHeight;

  const MemoryTitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleStyle,
    required this.compactTitleSize,
    required this.subtitleStyle,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final sub = subtitle;
    final hasSubtitle = sub != null && sub.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Text merges with the ambient DefaultTextStyle (letter spacing
        // etc.), so measure with the same merged style.
        final ambient = DefaultTextStyle.of(context).style;
        TextPainter measure(String text, TextStyle style, int? lines) =>
            TextPainter(
              text: TextSpan(text: text, style: ambient.merge(style)),
              maxLines: lines,
              textScaler: scaler,
              textDirection: direction,
            )..layout(maxWidth: width);

        var style = titleStyle;
        var titleLines = 1;
        if (measure(title, style, 1).didExceedMaxLines) {
          style = titleStyle.copyWith(fontSize: compactTitleSize);
          titleLines = 2;
        }
        final titlePainter = measure(title, style, null);
        var subtitleLines = 0;
        var height = titlePainter.height;
        if (hasSubtitle) {
          final subPainter = measure(sub, subtitleStyle, null);
          subtitleLines = subPainter.computeLineMetrics().length;
          if (titleLines == 2 && subtitleLines > 1) subtitleLines = 1;
          if (subtitleLines > 2) subtitleLines = 2;
          height += subtitleLines == 1
              ? measure(sub, subtitleStyle, 1).height
              : subPainter.height;
        }
        final block = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: style),
            ),
            if (hasSubtitle) Text(sub, style: subtitleStyle),
          ],
        );
        final wraps = titlePainter.computeLineMetrics().length > 2 ||
            (hasSubtitle &&
                measure(sub, subtitleStyle, null).computeLineMetrics().length >
                    subtitleLines);
        final limit = constraints.maxHeight < maxHeight
            ? constraints.maxHeight
            : maxHeight;
        if (!wraps && height <= limit) return block;
        // Too long even when wrapped: lay the text out on as few lines as
        // allowed and shrink it to fit, rather than cutting it off.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: width,
            child: block,
          ),
        );
      },
    );
  }
}
