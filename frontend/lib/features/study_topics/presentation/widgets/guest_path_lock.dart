import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// Why [path] is closed to the current guest, or null when it is open.
///
/// A guest gets one path only:
/// - their enrolled path is always open;
/// - a path that is not guest-accessible is locked (`other_path`);
/// - once they are enrolled in a path, every other path is locked too,
///   guest-accessible or not (`second_path`);
/// - before any enrolment, the guest-accessible paths are open.
///
/// The enrolled path comes from [GuestPathEnrollment] (Home's active path
/// and the Topics listing) or from [path] itself. [guest] overrides
/// [AccountGate.isActive] and [enrolledPathId] the recorded path (tests).
AccountReason? guestPathLockReason(
  LearningPath path, {
  bool? guest,
  String? enrolledPathId,
}) {
  if (!(guest ?? AccountGate.isActive)) return null;
  final own = enrolledPathId ?? GuestPathEnrollment.pathId;
  if (path.isEnrolled || path.id == own) return null;
  if (!path.guestAccessible) return AccountReason.otherPath;
  if (own != null) return AccountReason.secondPath;
  return null;
}

/// True when [path] is closed to the current guest ([guestPathLockReason]).
bool isGuestLockedPath(LearningPath path, {bool? guest}) =>
    guestPathLockReason(path, guest: guest) != null;

/// Opens [path] with [open], or, for a guest on a locked path, shows the
/// account-needed sheet with the lock reason (`other_path` or
/// `second_path`) instead. When the guest signs up from the sheet, the path
/// opens.
Future<void> guestPathGate(
  BuildContext context,
  LearningPath path,
  Future<void> Function() open, {
  bool? guest,
}) async {
  final reason = guestPathLockReason(path, guest: guest);
  if (reason == null) return open();
  final linked = await AccountNeededSheet.show(context, reason);
  if (linked) await open();
}

/// Adds a small lock badge over [child] when [path] is locked for the guest.
/// The tile itself is unchanged.
class GuestLockedPathTile extends StatelessWidget {
  final LearningPath path;
  final Widget child;

  /// Where the badge sits over [child].
  final AlignmentGeometry badgeAlignment;
  final EdgeInsetsGeometry badgePadding;

  /// Overrides [AccountGate.isActive] (tests).
  final bool? guest;

  const GuestLockedPathTile({
    super.key,
    required this.path,
    required this.child,
    this.badgeAlignment = Alignment.topRight,
    this.badgePadding = const EdgeInsets.all(8),
    this.guest,
  });

  @override
  Widget build(BuildContext context) {
    // Repaints when the guest's enrolled path becomes known.
    return ValueListenableBuilder<String?>(
      valueListenable: GuestPathEnrollment.changes,
      builder: (context, _, __) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    if (!isGuestLockedPath(path, guest: guest)) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: badgeAlignment,
              child: Padding(
                padding: badgePadding,
                child: GuestPathLockBadge(path: path),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The round lock badge shown on a path tile that is locked for the guest.
/// Keyed `guest_path_lock_<path id>`.
class GuestPathLockBadge extends StatelessWidget {
  final LearningPath path;

  const GuestPathLockBadge({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      key: Key('guest_path_lock_${path.id}'),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: palette.card,
        shape: BoxShape.circle,
        border: Border.all(color: palette.outline),
      ),
      child: Icon(Icons.lock_rounded, size: 12, color: palette.muted),
    );
  }
}
