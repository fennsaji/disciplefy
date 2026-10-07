import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';

/// Coin icon + credit amount, as used on depth cards, depth rows and the
/// Generate button.
class CreditCost extends StatelessWidget {
  final int cost;
  final Color color;
  final double size;

  const CreditCost({
    super.key,
    required this.cost,
    required this.color,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.toll_outlined, size: size + 2, color: color),
        const SizedBox(width: 4),
        Text(
          '$cost',
          style: AppFonts.inter(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Horizontal, scrollable row of compact depth cards (icon + cost, name +
/// duration) for the Generate tab. Selection is owned by the caller.
class DepthModeCardRow extends StatefulWidget {
  final List<StudyMode> modes;
  final StudyMode selected;

  /// Credit cost per mode; a missing entry hides that card's cost.
  final Map<StudyMode, int> costs;

  /// Modes shown with a lock; tapping them calls [onLockedTap].
  final Set<StudyMode> locked;
  final ValueChanged<StudyMode> onSelected;
  final ValueChanged<StudyMode>? onLockedTap;

  /// Horizontal inset of the first and last card, so the row can bleed to
  /// the screen edge while lining up with the page content.
  final double horizontalPadding;

  const DepthModeCardRow({
    super.key,
    required this.modes,
    required this.selected,
    required this.onSelected,
    this.costs = const {},
    this.locked = const {},
    this.onLockedTap,
    this.horizontalPadding = 20,
  });

  static const double cardWidth = 108;
  static const double cardHeight = 84;
  static const double gap = 10;

  @override
  State<DepthModeCardRow> createState() => _DepthModeCardRowState();
}

class _DepthModeCardRowState extends State<DepthModeCardRow> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(DepthModeCardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected(animate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls a selection made elsewhere (saved preference, the full chooser)
  /// into view — e.g. Sermon sits off-screen on a phone. Only this row
  /// scrolls; the page around it stays put.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final index = widget.modes.indexOf(widget.selected);
      if (index < 0) return;
      final position = _controller.position;
      const stride = DepthModeCardRow.cardWidth + DepthModeCardRow.gap;
      final cardStart = widget.horizontalPadding + index * stride;
      final cardEnd = cardStart + DepthModeCardRow.cardWidth;
      final viewStart = position.pixels;
      final viewEnd = viewStart + position.viewportDimension;

      double? target;
      if (cardStart - widget.horizontalPadding < viewStart) {
        target = cardStart - widget.horizontalPadding;
      } else if (cardEnd + widget.horizontalPadding > viewEnd) {
        target =
            cardEnd + widget.horizontalPadding - position.viewportDimension;
      }
      if (target == null) return;
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      if (animate) {
        _controller.animateTo(target,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _controller.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DepthModeCardRow.cardHeight,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
        itemCount: widget.modes.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DepthModeCardRow.gap),
        itemBuilder: (context, index) {
          final mode = widget.modes[index];
          final isLocked = widget.locked.contains(mode);
          return DepthModeCard(
            key: ValueKey('depth_card_${mode.name}'),
            mode: mode,
            isSelected: mode == widget.selected,
            isLocked: isLocked,
            cost: widget.costs[mode],
            onTap: () => isLocked
                ? widget.onLockedTap?.call(mode)
                : widget.onSelected(mode),
          );
        },
      ),
    );
  }
}

/// One compact depth card: icon + cost on top, name + duration below.
class DepthModeCard extends StatelessWidget {
  final StudyMode mode;
  final bool isSelected;
  final bool isLocked;
  final int? cost;
  final VoidCallback onTap;

  const DepthModeCard({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
    this.cost,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final fill = isSelected ? palette.selectedFill : palette.card;
    final onFill = palette.onSelected;
    final iconColor = isSelected ? onFill : palette.accentIcon;
    final nameColor = isSelected ? onFill : palette.text;
    final secondary =
        isSelected ? onFill.withValues(alpha: 0.8) : palette.muted;
    final costColor = isSelected ? onFill.withValues(alpha: 0.8) : palette.gold;
    final radius = BorderRadius.circular(18);

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${mode.localizedName(context)}, ${mode.localizedDuration(context)}',
      child: Opacity(
        opacity: isLocked ? 0.6 : 1,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: isSelected ? palette.selectedFill : palette.hairline,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: SizedBox(
              width: DepthModeCardRow.cardWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(mode.outlineIcon, size: 20, color: iconColor),
                        const Spacer(),
                        if (isLocked)
                          Icon(Icons.lock_rounded, size: 14, color: secondary)
                        else if (cost != null)
                          CreditCost(cost: cost!, color: costColor, size: 11),
                      ],
                    ),
                    // Hindi/Malayalam names can outgrow the card and the
                    // Devanagari/Malayalam fonts have taller lines than Inter:
                    // shrink the name + duration block to the space left
                    // rather than overflow the fixed-height card.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.localizedShortName(context),
                              maxLines: 1,
                              style: AppFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: nameColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mode.localizedDuration(context),
                              maxLines: 1,
                              style: AppFonts.inter(
                                  fontSize: 12, color: secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
