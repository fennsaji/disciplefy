import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// The Topics tab body, top to bottom: the current path (strip and lesson
/// card), the streak and Leaderboard tiles, the path categories (each with
/// "See all") and a "Browse all paths" button that opens every path.
///
/// One vertical [ListView]: nothing inside it scrolls vertically or has an
/// unbounded height, so a drag anywhere below the header scrolls the tab,
/// and the bottom padding includes the floating dock so the last button
/// scrolls clear of it.
class TopicsLayout extends StatelessWidget {
  final Widget currentPath;
  final Widget statTiles;
  final Widget paths;
  final VoidCallback onBrowseAll;
  final ScrollController? controller;

  /// Called when the list is within [nearEndExtent] of its end: after a
  /// scroll, and also when the content changes size, so a first page that
  /// does not fill the screen still asks for more (it could never be
  /// scrolled to the end otherwise).
  final VoidCallback? onNearEnd;

  /// How close to the end [onNearEnd] fires.
  static const double nearEndExtent = 300;

  const TopicsLayout({
    super.key,
    required this.currentPath,
    required this.statTiles,
    required this.paths,
    required this.onBrowseAll,
    this.controller,
    this.onNearEnd,
  });

  /// Only the tab's own vertical list counts, not a nested horizontal row.
  bool _onNotification(Notification notification) {
    final onNearEnd = this.onNearEnd;
    if (onNearEnd == null) return false;
    final ScrollMetrics metrics;
    final int depth;
    if (notification is ScrollUpdateNotification) {
      metrics = notification.metrics;
      depth = notification.depth;
    } else if (notification is ScrollMetricsNotification) {
      metrics = notification.metrics;
      depth = notification.depth;
    } else {
      return false;
    }
    if (depth == 0 &&
        metrics.axis == Axis.vertical &&
        metrics.extentAfter < nearEndExtent) {
      onNearEnd();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: _list(context),
    );
  }

  Widget _list(BuildContext context) {
    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      // The floating dock overlaps the page; its height is in the bottom
      // inset, so the last card scrolls clear of it.
      padding: EdgeInsets.fromLTRB(
          0, 8, 0, 16 + MediaQuery.paddingOf(context).bottom),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: currentPath,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: statTiles,
        ),
        const SizedBox(height: 20),
        paths,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: BrowseAllPathsButton(onPressed: onBrowseAll),
        ),
      ],
    );
  }
}

/// Gold outlined "Browse all paths ›" pill, 40px tall.
class BrowseAllPathsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const BrowseAllPathsButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return OutlinedButton(
      key: const Key('topics_browse_all_paths'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.gold,
        backgroundColor: palette.gold.withValues(alpha: 0.08),
        side: BorderSide(color: palette.gold.withValues(alpha: 0.6)),
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              context.tr(TranslationKeys.topicsBrowseAll),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}
