import 'package:flutter/widgets.dart';

import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';

/// Whether a lesson shows the Discipler follow-up panel.
///
/// [planShowsChat] is the plan rule (the panel is shown, or shown locked
/// with "Tap to upgrade"). A guest never sees it: the chat needs an account,
/// the server refuses a guest's conversation-history and study-followup calls
/// with 403 ACCOUNT_REQUIRED, and an upgrade pill would be the wrong answer.
bool lessonShowsFollowUpChat({
  required bool planShowsChat,
  required bool isGuest,
}) =>
    planShowsChat && !isGuest;

/// Runs before a lesson opens the Discipler ("Ask Discipler").
///
/// A full account goes straight on (true). A guest gets the account-needed
/// sheet (reason `discipler`) and goes on only when they have just signed
/// up. [isGuest] overrides the session check (tests).
Future<bool> lessonDisciplerGate(BuildContext context, {bool? isGuest}) {
  final guest = isGuest ?? GuestRouteGate.currentUserIsGuest();
  if (!guest) return Future.value(true);
  return AccountNeededSheet.show(context, AccountReason.discipler);
}

/// Runs before a lesson's "Listen" for a guest.
///
/// Listening needs an account, not a plan, so a guest gets the
/// account-needed sheet (reason `listen`) rather than an upgrade prompt.
/// True when the user is a full account (or just became one). [isGuest]
/// overrides the session check (tests).
Future<bool> lessonListenGate(BuildContext context, {bool? isGuest}) {
  final guest = isGuest ?? GuestRouteGate.currentUserIsGuest();
  if (!guest) return Future.value(true);
  return AccountNeededSheet.show(context, AccountReason.listen);
}
