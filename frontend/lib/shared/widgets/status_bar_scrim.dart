import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// For a page whose scroll view runs under the status bar (so a hero photo
/// can reach the top of the screen): once [child] scrolls, a scrim in the
/// page colour fades in over the status-bar area, so text never slides
/// under the clock and icons. Unscrolled, the photo still shows there.
///
/// The status-bar icons follow the theme (dark icons on a light page, light
/// icons on a dark one), so they read on the scrim.
class StatusBarScrim extends StatefulWidget {
  /// The page's scroll view (its first scrollable drives the scrim).
  final Widget child;

  /// The scrim colour; the theme's scaffold background by default.
  final Color? color;

  /// Scroll distance over which the scrim becomes opaque.
  final double solidAfter;

  static const Key scrimKey = Key('status_bar_scrim');

  const StatusBarScrim({
    super.key,
    required this.child,
    this.color,
    this.solidAfter = 16,
  });

  @override
  State<StatusBarScrim> createState() => _StatusBarScrimState();
}

class _StatusBarScrimState extends State<StatusBarScrim> {
  final ValueNotifier<double> _offset = ValueNotifier(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _offset.value = n.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, offset, child) => Opacity(
                  opacity: (offset / widget.solidAfter).clamp(0.0, 1.0),
                  child: child,
                ),
                child: DecoratedBox(
                  key: StatusBarScrim.scrimKey,
                  decoration: BoxDecoration(
                    color: widget.color ?? theme.scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
