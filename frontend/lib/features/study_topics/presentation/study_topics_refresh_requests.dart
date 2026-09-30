import 'package:flutter/foundation.dart';

/// Asks the Study Topics tab to refresh its learning paths in the background.
///
/// The tab is kept alive by the shell's IndexedStack, so its initial load
/// runs once; the shell fires this when the user switches back to the tab so
/// progress made elsewhere (a topic completed from Home, a path enrolled in)
/// shows up. The screen keeps what it shows and swaps in the fresh data when
/// it lands — no loading spinner.
class StudyTopicsRefreshRequests extends ChangeNotifier {
  StudyTopicsRefreshRequests._();

  static final StudyTopicsRefreshRequests instance =
      StudyTopicsRefreshRequests._();

  void request() => notifyListeners();
}
