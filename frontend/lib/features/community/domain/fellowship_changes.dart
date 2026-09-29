import 'package:flutter/foundation.dart';

/// Ticks whenever the user's fellowships or their meetings change: a join
/// (invite, public, deep link), a leave, a newly created group, or a meeting
/// scheduled or cancelled.
///
/// Home keeps its fellowship-driven sections (recent activity, today's
/// meeting) mounted across navigation, so without this signal it keeps
/// inviting the user to join a group they just joined.
class FellowshipChanges extends ValueNotifier<int> {
  FellowshipChanges._() : super(0);

  static final FellowshipChanges instance = FellowshipChanges._();

  void notifyChanged() => value++;
}
