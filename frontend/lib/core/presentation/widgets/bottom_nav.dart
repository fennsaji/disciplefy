import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as flutter_services;
import 'package:showcaseview/showcaseview.dart';
import '../../constants/app_fonts.dart';
import '../../animations/app_animations.dart';
import '../../localization/app_localizations.dart';
import '../../../features/walkthrough/domain/walkthrough_screen.dart';
import '../../../features/walkthrough/presentation/showcase_keys.dart';
import '../../../features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Navigation tab data model for bottom navigation
class NavTab {
  final IconData icon;
  final IconData? activeIcon;

  /// Stable identifier ('home', 'generate', 'topics', 'community').
  ///
  /// Layout code branches on which tabs are present; it used to compare the
  /// English [label], which meant localizing the label would silently change
  /// behaviour. Compare [id] instead — it never changes with locale.
  final String id;

  /// English fallback, used only when localization is unavailable.
  final String label;
  final String semanticLabel;

  const NavTab({
    required this.icon,
    this.activeIcon,
    required this.id,
    required this.label,
    required this.semanticLabel,
  });
}

/// Disciplefy bottom navigation: a floating dock.
///
/// A rounded bar floating above the page (74px, inset 14px from the sides,
/// just above the home indicator) with five labelled destinations: Home,
/// Generate, Discipler, Topics, Community. Selection is a state, so it is
/// shown lightly: a soft gold pill behind the icon and a gold label. The
/// Discipler button keeps one look — a gold circle with the white mark —
/// and gains only a gold ring when it is the selected tab.
class DisciplefyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavTab> tabs;

  const DisciplefyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  /// Dock label size: the readable minimum for secondary text.
  static const double labelFontSize = 12;

  /// Discipler as a tab. Kept out of [defaultTabs]: its label is the brand
  /// name, the same in every language, and the shell adds it only when the
  /// Talk to Discipler feature is available.
  static const NavTab disciplerTab = NavTab(
    icon: Icons.graphic_eq,
    id: 'discipler',
    label: 'Discipler',
    semanticLabel:
        'Navigate to Discipler. Talk with your Bible companion by voice or text.',
  );

  /// Default navigation tabs for Disciplefy app
  static const List<NavTab> defaultTabs = [
    NavTab(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      id: 'home',
      label: 'Home',
      semanticLabel:
          'Navigate to Home screen. Shows daily verse and study recommendations.',
    ),
    NavTab(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      id: 'generate',
      label: 'Generate',
      semanticLabel:
          'Navigate to Study Generation screen. Create new Bible study guides.',
    ),
    NavTab(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      id: 'topics',
      label: 'Topics',
      semanticLabel:
          'Navigate to Study Topics screen. Browse learning paths and continue your studies.',
    ),
    NavTab(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      id: 'community',
      label: 'Community',
      semanticLabel:
          'Navigate to Community screen. Join fellowships and connect with other believers.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _DockPalette.of(context);

    // Sit just above the home indicator, or 14px from the edge on phones
    // without one. SafeArea plus a fixed margin stacked to ~50px on iPhones.
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(14, 6, 14, systemBottom > 0 ? systemBottom : 14),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: palette.dock,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: _buildTabItems(context, constraints.maxWidth),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabItems(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context)!;
    // Dock tabs covered by the home tour, in dock order. Step numbers here
    // are fallbacks; the running tour numbers them (hidden tabs excluded).
    final tourSteps = <String, (GlobalKey, String, String)>{
      'generate': (
        ShowcaseKeys.homeGenerateTab,
        l10n.walkthroughHomeGenerateTitle,
        l10n.walkthroughHomeGenerateDesc,
      ),
      disciplerTab.id: (
        ShowcaseKeys.homeDisciplerTab,
        l10n.walkthroughHomeDisciplerTitle,
        l10n.walkthroughHomeDisciplerDesc,
      ),
      'topics': (
        ShowcaseKeys.homeTopicsTab,
        l10n.walkthroughHomeTopicsTitle,
        l10n.walkthroughHomeTopicsDesc,
      ),
      'community': (
        ShowcaseKeys.homeCommunityTab,
        l10n.walkthroughCommunityNavTitle,
        l10n.walkthroughCommunityNavDesc,
      ),
    };
    const bodySteps = 2;
    final tourTabIds = tabs.map((t) => t.id).where(tourSteps.containsKey);
    final totalSteps = bodySteps + tourTabIds.length;
    final flexes = _itemFlexes(context, l10n, width);

    return tabs.asMap().entries.map((entry) {
      final index = entry.key;
      final tab = entry.value;
      final isSelected = currentIndex == index;

      final Widget navItem = tab.id == disciplerTab.id
          ? _DisciplerNavItem(
              tab: tab,
              isSelected: isSelected,
              onTap: () => _handleTap(context, index),
            )
          : _BottomNavItem(
              tab: tab,
              isSelected: isSelected,
              onTap: () => _handleTap(context, index),
            );

      // Wrap the dock tabs with walkthrough tooltips so the home tour
      // highlights each of them.
      final step = tourSteps[tab.id];
      if (step != null) {
        final (key, title, description) = step;
        return Expanded(
          flex: flexes[index],
          child: WalkthroughTooltip(
            showcaseKey: key,
            title: title,
            description: description,
            screen: WalkthroughScreen.home,
            stepNumber: bodySteps + 1 + tourTabIds.toList().indexOf(tab.id),
            totalSteps: totalSteps,
            onNext: () => ShowCaseWidget.of(context).next(),
            child: _gapped(navItem),
          ),
        );
      }

      return Expanded(flex: flexes[index], child: _gapped(navItem));
    }).toList();
  }

  /// Space kept clear on each side of a slot, so neighbouring labels never
  /// touch (scripts whose glyphs ink slightly past their advance included).
  static const double slotGap = 3;

  /// Smallest size a label is scaled to before it is ellipsized instead.
  static const double minLabelFontSize = 11;

  /// Narrowest slot an item gets: room for its icon pill and a short label.
  static const double _minItemWidth = 56;

  static Widget _gapped(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: slotGap),
        child: child,
      );

  /// Width share of each item. Equal while every label fits an equal slot;
  /// otherwise a longer label ("Community") takes room from the items with
  /// short labels, so labels stay at full size where the dock allows it and
  /// shrink evenly where it does not.
  List<int> _itemFlexes(
      BuildContext context, AppLocalizations l10n, double available) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final needs = [
      for (final tab in tabs)
        () {
          final painter = TextPainter(
            text: TextSpan(
              text: tab.id == disciplerTab.id
                  ? l10n.navDiscipler
                  : l10n.navLabel(tab.id),
              style: AppFonts.inter(
                  fontSize: labelFontSize, fontWeight: FontWeight.w600),
            ),
            maxLines: 1,
            textDirection: direction,
            textScaler: scaler,
          )..layout();
          final width = painter.width + 2 * slotGap + 2;
          painter.dispose();
          return width < _minItemWidth ? _minItemWidth : width;
        }(),
    ];
    final equal = available / tabs.length;
    if (needs.every((w) => w <= equal)) {
      return List.filled(tabs.length, 1);
    }
    return [for (final w in needs) w.ceil()];
  }

  void _handleTap(BuildContext context, int index) {
    if (index != currentIndex) {
      // Provide haptic feedback for better UX
      flutter_services.HapticFeedback.lightImpact();
    }
    // Re-taps are reported too: the shell ignores them except on Home,
    // where tapping the current tab scrolls back to the top.
    onTap(index);
  }
}

/// Dock colours per theme. Gold on white is too faint for text, so the
/// light theme uses the deep gold for the selected icon, label and ring.
class _DockPalette {
  final Color dock;
  final Color border;
  final Color shadow;
  final Color inactive;
  final Color selected;
  final Color tint;
  final Color tintBorder;
  final Color ring;

  const _DockPalette({
    required this.dock,
    required this.border,
    required this.shadow,
    required this.inactive,
    required this.selected,
    required this.tint,
    required this.tintBorder,
    required this.ring,
  });

  static _DockPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const _DockPalette(
            dock: Color(0xFF1C1C24),
            border: Color(0x14FFFFFF),
            shadow: Color(0x80000000),
            inactive: Color(0xFF8A8A95),
            selected: AppColors.brandGold,
            tint: Color(0x26E3B154),
            tintBorder: Color(0x55E3B154),
            ring: AppColors.brandGold,
          )
        : const _DockPalette(
            dock: Colors.white,
            border: Color(0xFFE4E0D6),
            shadow: Color(0x1F1A1917),
            // The design's warm grey, darkened to 4.5:1 on the white dock.
            inactive: Color(0xFF7B766D),
            selected: AppColors.brandGoldDeep,
            tint: Color(0x33E3B154),
            tintBorder: Color(0x66C9973A),
            ring: Color(0xFFB98A2E),
          );
  }
}

/// Shared column for every dock item: a fixed 44px icon row with the visual
/// (pill or Discipler button) centred in it, then the label. Equal heights
/// keep every icon and label on the same line, centred in the dock.
class _DockItemLayout extends StatelessWidget {
  final Widget visual;
  final String label;
  final bool isSelected;
  final _DockPalette palette;

  const _DockItemLayout({
    required this.visual,
    required this.label,
    required this.isSelected,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    // At least 60px so Inter labels keep their place; Devanagari and
    // Malayalam lines are taller, so the item grows into the dock's spare
    // height instead of overflowing.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Every item gets the same 44px icon row (the Discipler ring's
          // size), so icons, the button and labels share one centre line and
          // the row sits centred in the dock.
          SizedBox(height: 44, child: Center(child: visual)),
          const SizedBox(height: 3),
          // Flexible so a very large text size shrinks the label to the dock
          // height rather than overflowing it.
          Flexible(
            child: _DockLabel(
              label: label,
              style: AppFonts.inter(
                fontSize: DisciplefyBottomNav.labelFontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? palette.selected : palette.inactive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dock label that always stays inside its slot: full size when it fits,
/// scaled down to no less than [DisciplefyBottomNav.minLabelFontSize] when
/// it nearly fits, and ellipsized at that size otherwise. The full label
/// stays in the semantics tree either way.
class _DockLabel extends StatelessWidget {
  final String label;
  final TextStyle style;

  const _DockLabel({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      final height = painter.height;
      painter.dispose();

      final scale = [
        1.0,
        if (constraints.hasBoundedWidth && width > 0)
          constraints.maxWidth / width,
        if (constraints.hasBoundedHeight && height > 0)
          constraints.maxHeight / height,
      ].reduce((a, b) => a < b ? a : b);
      final renderedSize =
          scaler.scale(DisciplefyBottomNav.labelFontSize) * scale;

      final Widget text;
      if (scale >= 1) {
        text = Text(label, maxLines: 1, softWrap: false);
      } else if (renderedSize >= DisciplefyBottomNav.minLabelFontSize) {
        text = FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, softWrap: false),
        );
      } else {
        // Too long even at the minimum size: keep the minimum and end with
        // an ellipsis rather than shrinking into unreadable text.
        text = FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: DisciplefyBottomNav.minLabelFontSize),
            ),
          ),
        );
      }
      return AnimatedDefaultTextStyle(
        duration: AppAnimations.fast,
        curve: AppAnimations.defaultCurve,
        style: style,
        textAlign: TextAlign.center,
        child: text,
      );
    });
  }
}

/// Discipler: the brand's Discipler mark on gold. Its look never
/// changes with selection except for a thin gold ring, so it always reads as
/// the same thing.
class _DisciplerNavItem extends StatelessWidget {
  final NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _DisciplerNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _DockPalette.of(context);
    final label = AppLocalizations.of(context)?.navDiscipler ?? tab.label;

    return Semantics(
      label: tab.semanticLabel,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _DockItemLayout(
          label: label,
          isSelected: isSelected,
          palette: palette,
          visual: AnimatedContainer(
            key: const Key('nav_discipler_ring'),
            duration: AppAnimations.fast,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? palette.ring : Colors.transparent,
                width: 2,
              ),
            ),
            // The brand's Discipler mark on gold (brand/discipler/
            // discipler-mark-on-gold.svg): symbol plus the two sparkles.
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGoldDeep.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/brand/discipler-mark-on-gold.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  cacheWidth: 128,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.brandGold,
                    child: Icon(Icons.graphic_eq, color: ReaderPalette.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A regular dock tab: icon in a pill (tinted gold when selected) and label.
class _BottomNavItem extends StatefulWidget {
  final NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(
            parent: _controller, curve: AppAnimations.defaultCurve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _DockPalette.of(context);
    final selected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Semantics(
          label: widget.tab.semanticLabel,
          button: true,
          selected: selected,
          enabled: true,
          focusable: true,
          child: _DockItemLayout(
            label: AppLocalizations.of(context)?.navLabel(widget.tab.id) ??
                widget.tab.label,
            isSelected: selected,
            palette: palette,
            visual: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.defaultCurve,
              width: 48,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? palette.tint : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: selected ? palette.tintBorder : Colors.transparent,
                ),
              ),
              child: Icon(
                selected && widget.tab.activeIcon != null
                    ? widget.tab.activeIcon!
                    : widget.tab.icon,
                size: 20,
                color: selected ? palette.selected : palette.inactive,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
