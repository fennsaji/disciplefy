import 'dart:async';

/// Ignores repeat taps for a short window after one is accepted.
///
/// Use this instead of a "navigating" flag held across
/// `await context.push(...)`: go_router drops pushed routes on `go` /
/// `pushReplacement` (Lesson complete → Back home) without completing their
/// futures, so such a flag would stay set and the button would do nothing
/// for the rest of the session. The window here always ends on its own.
class TapGuard {
  TapGuard({this.window = const Duration(seconds: 1)});

  final Duration window;
  Timer? _timer;

  /// Whether a tap was accepted less than [window] ago.
  bool get isLocked => _timer?.isActive ?? false;

  /// Returns true and starts the window when no tap is in it; false (ignore
  /// the tap) otherwise.
  bool tryAcquire() {
    if (isLocked) return false;
    _timer = Timer(window, () {});
    return true;
  }

  /// Ends the window early (e.g. the action was cancelled before navigating).
  void release() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call from the owner's `dispose`.
  void dispose() => release();
}
