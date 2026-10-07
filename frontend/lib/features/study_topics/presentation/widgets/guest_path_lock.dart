import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

/// True when [path] is closed to the current guest: guest mode is on, the
/// user is a guest, and the path is not one of the guest-accessible ones.
/// [guest] overrides [AccountGate.isActive] (tests).
bool isGuestLockedPath(LearningPath path, {bool? guest}) =>
    (guest ?? AccountGate.isActive) && !path.guestAccessible;

/// Opens [path] with [open], or, for a guest on a locked path, shows the
/// account-needed sheet (reason `other_path`) instead. When the guest signs
/// up from the sheet, the path opens.
Future<void> guestPathGate(
  BuildContext context,
  LearningPath path,
  Future<void> Function() open, {
  bool? guest,
}) async {
  if (!isGuestLockedPath(path, guest: guest)) return open();
  final linked =
      await AccountNeededSheet.show(context, AccountReason.otherPath);
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
    if (!isGuestLockedPath(path, guest: guest)) return child;
    final palette = ReaderPalette.of(context);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: badgeAlignment,
              child: Padding(
                padding: badgePadding,
                child: Container(
                  key: Key('guest_path_lock_${path.id}'),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: palette.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.outline),
                  ),
                  child:
                      Icon(Icons.lock_rounded, size: 12, color: palette.muted),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
