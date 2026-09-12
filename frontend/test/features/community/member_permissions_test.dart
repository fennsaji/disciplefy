@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Who may do what to a fellowship member.
///
/// The member menu merged "mentor" and "global admin" into one
/// `viewerCanManage`, so an admin — including an admin who is only an ordinary
/// member of the group they are looking at — was offered mute, transfer mentor
/// role and remove. The backend refuses all three for anyone but a mentor
/// (`is_fellowship_mentor` → 403), so those entries could only ever fail.
///
/// The invite button had no condition at all, and creating an invite is
/// likewise mentor-only server-side.
///
/// These read the source rather than pumping widgets: the conditions are what
/// regressed, and they are what is pinned here.
void main() {
  final members = File(
    'lib/features/community/presentation/screens/fellowship_members_tab_screen.dart',
  ).readAsStringSync();
  final home = File(
    'lib/features/community/presentation/screens/fellowship_home_screen.dart',
  ).readAsStringSync();

  test('member management is mentor-only, not admin', () {
    expect(members.contains('final canManageMembers = isMentor;'), true,
        reason: 'mute, transfer and remove are refused for an admin with 403');

    // The merged gate is gone from the code. (It is still named in the comment
    // that explains why, so match an assignment rather than the bare word.)
    expect(members.contains('final viewerCanManage'), false,
        reason: 'conflating admin with mentor is what showed the bad menu');
    expect(RegExp(r'viewerCanManage\s*&&').hasMatch(members), false,
        reason: 'no gate should still be computed from the merged value');
  });

  test('changing who mentors the group stays open to admins', () {
    // This one the backend does allow: handleChangeMentorRole accepts
    // `isMentor || profile.is_admin`.
    expect(members.contains('final canChangeMentorRole = isMentor || isAdmin;'),
        true);
  });

  test('mute and remove are gated on the mentor-only value', () {
    expect(
        members.contains('final canAct = canManageMembers && !isMemberMentor;'),
        true,
        reason: 'canAct drives mute, transfer and remove');
  });

  test('promote and demote are gated on the mentor-or-admin value', () {
    expect(
      members.contains(
          'final canPromote = canChangeMentorRole && !isMemberMentor;'),
      true,
    );
    expect(
      members.contains(
          'final canDemote = canChangeMentorRole && isMemberMentor && !member.isOwner;'),
      true,
    );
  });

  test('blocking stays available to every member', () {
    // A personal safety action, not moderation — it must not be gated on role.
    expect(
      members.contains(
          'final canBlock = currentUserId != null && member.userId != currentUserId;'),
      true,
    );
  });

  test('the mute menu entry names the action, not the outcome', () {
    // It used the success-toast strings, so the entry read "Member muted" on a
    // member who was not muted.
    expect(members.contains('l10n.muteMemberAction'), true);
    expect(members.contains('l10n.unmuteMemberAction'), true);
    expect(
        members.contains(
            'label: member.isMuted\n                          ? l10n.unmuteSuccess'),
        false);
  });

  test('only a mentor is offered the invite button', () {
    expect(home.contains('if (isMentor || membersState.isMentor)'), true,
        reason: 'creating an invite is mentor-only server-side');
  });
}
