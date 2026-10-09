import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/domain/entities/account_reason.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_link_panel.dart';

export 'package:disciplefy_bible_study/features/auth/domain/entities/account_reason.dart';

/// Whether the account-needed sheet applies right now.
class AccountGate {
  AccountGate._();

  /// True when the signed-in user is a guest. False when the service is not
  /// registered (tests, early startup) or cannot be read.
  ///
  /// Deliberately independent of the `guest_mode` flag: the flag only stops
  /// new guests. The router keeps blocking existing guests from account-only
  /// routes whatever the flag says, so the sheet must keep explaining why.
  static bool get isActive {
    try {
      if (!sl.isRegistered<GuestSessionService>()) return false;
      return sl<GuestSessionService>().isGuest;
    } catch (_) {
      return false;
    }
  }
}

/// Asks a guest to create an account before an account-only action.
///
/// Returns true straight away for a full account. For a guest it opens [AccountNeededSheet] and returns true only when
/// the guest has just become a full account; "Continue as guest" (or closing
/// the sheet) returns false and the caller does nothing.
Future<bool> requireAccount(BuildContext context, AccountReason reason) async {
  if (!AccountGate.isActive) return true;
  return AccountNeededSheet.show(context, reason);
}

/// Translation key of the sheet title for [reason].
String accountReasonTitleKey(AccountReason reason) => switch (reason) {
      AccountReason.community => TranslationKeys.accountGroupsTitle,
      AccountReason.discipler => TranslationKeys.accountDisciplerTitle,
      AccountReason.otherPath ||
      AccountReason.secondPath =>
        TranslationKeys.accountSecondPathTitle,
      AccountReason.generate => TranslationKeys.accountGenerateTitle,
      AccountReason.memoryVerses => TranslationKeys.accountMemoryVersesTitle,
      AccountReason.listen => TranslationKeys.accountListenTitle,
      AccountReason.saveProgress => TranslationKeys.accountSaveProgressTitle,
      AccountReason.other => TranslationKeys.accountGenericTitle,
    };

IconData _iconFor(AccountReason reason) => switch (reason) {
      AccountReason.community => Icons.groups_outlined,
      AccountReason.discipler => Icons.forum_outlined,
      AccountReason.otherPath ||
      AccountReason.secondPath =>
        Icons.route_outlined,
      AccountReason.generate => Icons.edit_note_rounded,
      AccountReason.memoryVerses => Icons.bookmark_border_rounded,
      AccountReason.listen => Icons.headphones_rounded,
      AccountReason.saveProgress ||
      AccountReason.other =>
        Icons.cloud_upload_outlined,
    };

/// "Groups need an account" bottom sheet: why, what moves over, and the
/// Google / Apple / email buttons, with "Continue as guest" to close it.
class AccountNeededSheet extends StatefulWidget {
  final AccountReason reason;

  const AccountNeededSheet({super.key, required this.reason});

  static Future<bool>? _open;

  /// Forgets [future] as the open sheet, unless a newer one replaced it.
  static void _release(Future<bool>? future) {
    if (identical(_open, future)) _open = null;
  }

  /// Shows the sheet over the current screen. Resolves true when the guest
  /// became a full account. While a sheet is already open, a second call
  /// returns the open sheet's result instead of stacking another.
  static Future<bool> show(BuildContext context, AccountReason reason) {
    final open = _open;
    if (open != null) return open;
    ActivationAnalytics.maybeTrack(
        NuxEvent.accountNeededShown, {'reason': reason.wireValue});
    late final Future<bool> future;
    future = showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: ReaderPalette.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AccountNeededSheet(reason: reason),
    ).then((linked) => linked ?? false).whenComplete(() => _release(future));
    _open = future;
    return future;
  }

  @override
  State<AccountNeededSheet> createState() => _AccountNeededSheetState();
}

class _AccountNeededSheetState extends State<AccountNeededSheet> {
  /// The open-sheet future this sheet was shown with.
  final Future<bool>? _shownWith = AccountNeededSheet._open;

  @override
  void dispose() {
    // The sheet can go without its route completing (the tree is torn
    // down); never leave a stale "already open" behind.
    AccountNeededSheet._release(_shownWith);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.reason;
    final palette = ReaderPalette.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: palette.selectedFill,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(_iconFor(reason),
                      color: palette.onSelected, size: 24),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                context.tr(accountReasonTitleKey(reason)),
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                context.tr(TranslationKeys.accountBody),
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                    fontSize: 14, color: palette.muted, height: 1.5),
              ),
              const SizedBox(height: 9),
              const AccountBenefits(),
              const SizedBox(height: 9),
              AccountLinkPanel(
                onLinked: (_) => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('account_continue_guest'),
                onPressed: () {
                  ActivationAnalytics.maybeTrack(NuxEvent.guestContinued, {
                    'source': 'account_sheet',
                    'reason': reason.wireValue,
                  });
                  Navigator.of(context).pop(false);
                },
                style: TextButton.styleFrom(
                  foregroundColor: palette.muted,
                  minimumSize: const Size.fromHeight(40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle:
                      AppFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                child: Text(context.tr(TranslationKeys.accountContinueGuest)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three check rows: progress moves over, every path unlocked, Discipler and
/// groups.
class AccountBenefits extends StatelessWidget {
  const AccountBenefits({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // The design's green ticks: deep on light, bright on dark.
    final tick =
        palette.isDark ? AppColors.successLighter : AppColors.successDark;
    Widget row(String key) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.check_rounded, size: 15, color: tick),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(key),
                  style: AppFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: palette.text),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row(TranslationKeys.accountBenefitMoves),
        row(TranslationKeys.accountBenefitPaths),
        row(TranslationKeys.accountBenefitGroups),
      ],
    );
  }
}
