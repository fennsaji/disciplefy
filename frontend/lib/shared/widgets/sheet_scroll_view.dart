import 'package:flutter/material.dart';

/// Scroll view for modal bottom sheet content that keeps pull-down-to-dismiss
/// working.
///
/// A sheet's dismiss gesture is a plain [VerticalDragGestureRecognizer] on the
/// sheet itself (`BottomSheet` in the framework). Flutter hands that drag to a
/// scrollable child whenever the child can scroll, and only
/// [DraggableScrollableSheet] coordinates the two. So content long enough to
/// overflow — which is exactly the content that needs a scroll view — swallows
/// the pull and the sheet can no longer be closed by dragging.
///
/// This restores it: once the content is scrolled to the top, further downward
/// drag arrives as overscroll, and enough of it pops the sheet. Content that
/// fits does not scroll at all, which hands the drag straight back to the
/// sheet.
class SheetScrollView extends StatefulWidget {
  final Widget child;

  /// Padding around [child], as [SingleChildScrollView.padding].
  final EdgeInsetsGeometry? padding;

  /// Downward overscroll, in logical pixels, that dismisses the sheet.
  static const double dismissThreshold = 60;

  const SheetScrollView({super.key, required this.child, this.padding});

  @override
  State<SheetScrollView> createState() => _SheetScrollViewState();
}

class _SheetScrollViewState extends State<SheetScrollView> {
  bool _overflows = false;
  double _pulled = 0;

  bool _onNotification(Notification notification) {
    if (notification is ScrollMetricsNotification) {
      final overflows = notification.metrics.maxScrollExtent > 0;
      if (overflows != _overflows) {
        // The notification arrives during layout, so the rebuild waits for the
        // frame to finish.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _overflows = overflows);
          }
        });
      }
    } else if (notification is OverscrollNotification) {
      // Negative overscroll is a drag past the top of the list.
      if (notification.overscroll < 0) {
        _pulled -= notification.overscroll;
        if (_pulled >= SheetScrollView.dismissThreshold) {
          _pulled = 0;
          Navigator.of(context).maybePop();
        }
      }
    } else if (notification is ScrollEndNotification) {
      _pulled = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: SingleChildScrollView(
        padding: widget.padding,
        physics: _overflows
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}
