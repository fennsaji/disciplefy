import 'dart:async';

import 'package:flutter/widgets.dart';

/// How long the verse has to stay on screen before it counts as read.
const Duration dailyVerseReadDelay = Duration(seconds: 5);

/// Calls [onRead] once the wrapped verse has been on screen for [delay].
///
/// "On screen" means tickers are enabled (an inactive bottom tab has them
/// off) and the enclosing route is the current one (no page pushed on top).
/// Hiding the verse stops the clock; showing it again starts a fresh
/// [delay]. Fires at most once per widget lifetime.
class DailyVerseReadTimer extends StatefulWidget {
  final VoidCallback onRead;
  final Duration delay;
  final Widget child;

  const DailyVerseReadTimer({
    super.key,
    required this.onRead,
    required this.child,
    this.delay = dailyVerseReadDelay,
  });

  @override
  State<DailyVerseReadTimer> createState() => _DailyVerseReadTimerState();
}

class _DailyVerseReadTimerState extends State<DailyVerseReadTimer> {
  Timer? _timer;
  bool _fired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Both lookups register a dependency, so this runs again whenever the
    // tab is switched or a route is pushed over / popped off this one.
    final visible =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    _sync(visible);
  }

  void _sync(bool visible) {
    if (_fired) return;
    if (!visible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(widget.delay, () {
      _timer = null;
      if (!mounted) return;
      _fired = true;
      widget.onRead();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
