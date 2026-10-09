import 'dart:async';

import 'package:flutter/widgets.dart';

/// How long the verse has to stay on screen before it counts as read.
const Duration dailyVerseReadDelay = Duration(seconds: 5);

/// Calls [onRead] once the wrapped verse has been on screen for [delay].
///
/// "On screen" means the app is in the foreground (resumed), tickers are
/// enabled (an inactive bottom tab has them off) and the enclosing route is
/// the current one (no page pushed on top). Hiding the verse stops the
/// clock; showing it again starts a fresh [delay].
///
/// Fires at most once per local day: if the app stays open past midnight,
/// the new day can count after another [delay] on screen.
class DailyVerseReadTimer extends StatefulWidget {
  final VoidCallback onRead;
  final Duration delay;
  final Widget child;

  /// Current time; injectable for tests.
  final DateTime Function() now;

  const DailyVerseReadTimer({
    super.key,
    required this.onRead,
    required this.child,
    this.delay = dailyVerseReadDelay,
    this.now = DateTime.now,
  });

  @override
  State<DailyVerseReadTimer> createState() => _DailyVerseReadTimerState();
}

class _DailyVerseReadTimerState extends State<DailyVerseReadTimer>
    with WidgetsBindingObserver {
  Timer? _readTimer;
  Timer? _midnightTimer;

  /// Local day [DailyVerseReadTimer.onRead] last fired on.
  DateTime? _firedOn;
  bool _onScreen = false;
  bool _resumed = true;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Both lookups register a dependency, so this runs again whenever the
    // tab is switched or a route is pushed over / popped off this one.
    _onScreen =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_firedOn != null && _firedOn != _day(widget.now())) {
      // A new local day since the last read: it can count again.
      _firedOn = null;
    }
    if (_firedOn != null) return;
    if (!_onScreen || !_resumed) {
      _readTimer?.cancel();
      _readTimer = null;
      return;
    }
    _readTimer ??= Timer(widget.delay, _onDelayElapsed);
  }

  void _onDelayElapsed() {
    _readTimer = null;
    if (!mounted) return;
    final now = widget.now();
    _firedOn = _day(now);
    widget.onRead();
    _scheduleMidnight(now);
  }

  /// Re-arms just after the next local midnight, for an app left open.
  void _scheduleMidnight(DateTime now) {
    _midnightTimer?.cancel();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer =
        Timer(nextDay.difference(now) + const Duration(seconds: 1), () {
      _midnightTimer = null;
      if (!mounted) return;
      _sync();
      // Fired early (clock drift or change): try again at the real midnight.
      if (_firedOn != null) _scheduleMidnight(widget.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
