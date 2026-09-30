import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// A 44x44 icon action for community top bars, always with a tooltip (the
/// tooltip doubles as the screen-reader label).
class CommunityIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Optional small badge drawn at the icon's bottom-right (e.g. a lock).
  final IconData? badge;

  /// Icon colour; defaults to the palette text colour.
  final Color? color;

  const CommunityIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = color ?? palette.text;
    Widget glyph = Icon(icon, size: 24, color: ink);
    if (badge != null) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          glyph,
          Positioned(
            right: -4,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: palette.page,
                shape: BoxShape.circle,
              ),
              child: Icon(badge, size: 11, color: palette.gold),
            ),
          ),
        ],
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: glyph,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}

/// Large Poppins page title ("Community", 26/700) with icon actions on the
/// right. Transparent, so it sits on a [PhotoWash].
class CommunityLargeTitleBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const CommunityLargeTitleBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 2,
                style: AppFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  height: 1.2,
                ),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Text tabs with a short gold underline under the selected one
/// ("My fellowships / Discover").
///
/// Labels never truncate: when they do not fit side by side at the current
/// width they scale down together.
class CommunityUnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const CommunityUnderlineTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                _UnderlineTab(
                  label: labels[i],
                  selected: i == selected,
                  onTap: () => onChanged(i),
                  palette: palette,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ReaderPalette palette;

  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selected ? palette.text : palette.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? palette.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back arrow + optional Poppins title + trailing actions, for inner
/// community screens (Post, Meetings, Settings…).
///
/// Transparent by default so it can sit on a [PhotoWash]; pass
/// [background] to paint it.
class CommunityBackBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Color? background;

  const CommunityBackBar({
    super.key,
    this.title,
    this.onBack,
    this.actions = const [],
    this.background,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: background ?? Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: preferredSize.height),
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(Icons.arrow_back, color: palette.text, size: 24),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: title == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        header: true,
                        child: Text(
                          title!,
                          maxLines: 2,
                          style: AppFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                            height: 1.25,
                          ),
                        ),
                      ),
              ),
              ...actions,
              SizedBox(width: actions.isEmpty ? 16 : 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold, tracked, uppercase label: section eyebrows ("STUDYING TOGETHER",
/// "THIS WEEK") and meta lines ("OFFICIAL · 3 MEMBERS · MENTOR: DISCIPLER").
///
/// Wraps rather than truncating.
class CommunitySectionLabel extends StatelessWidget {
  final String text;

  /// Defaults to the palette gold.
  final Color? color;
  final double fontSize;

  const CommunitySectionLabel(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: AppFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: fontSize * 0.14,
          height: 1.4,
          color: color ?? palette.gold,
        ),
      ),
    );
  }
}

/// Poppins section heading ("Recent activity") with an optional trailing
/// text action ("View all").
class CommunitySectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CommunitySectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.text,
                height: 1.3,
              ),
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: palette.muted,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
