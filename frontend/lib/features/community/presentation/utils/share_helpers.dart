import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/share_links.dart';
import '../../domain/entities/fellowship_post_entity.dart';
import '../../domain/repositories/community_repository.dart';

/// Generates (or reuses) an invite link for [fellowshipId] and opens the
/// native share sheet with it.
///
/// Extracted from the invite link share action in `fellowship_invites_screen
/// .dart` so it can also be triggered from the fellowship home hero's Share
/// button.
Future<void> shareFellowshipInvite(
  BuildContext context,
  String fellowshipId,
  String? fellowshipName,
) async {
  final name = (fellowshipName != null && fellowshipName.isNotEmpty)
      ? fellowshipName
      : 'my fellowship';

  final result = await sl<CommunityRepository>().createInvite(fellowshipId);

  result.fold(
    (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.feedLoadError)));
    },
    (invite) {
      final token = invite['token'] as String? ?? '';
      final joinUrl = (invite['join_url'] as String?) ??
          'https://app.disciplefy.in/fellowship/join/$token';
      SharePlus.instance
          .share(ShareParams(text: 'Join $name on Disciplefy:\n$joinUrl'));
    },
  );
}

/// Builds the shareable text for [post]: a quoted excerpt (first 200 chars),
/// an attribution line, and the post's deep link.
///
/// The Discipler AI helper is attributed as `'Discipler'` rather than its
/// raw author display name.
String buildPostShareText({
  required FellowshipPostEntity post,
  required String fellowshipName,
  required String suffix,
}) {
  final body = post.content.length > 200
      ? '${post.content.substring(0, 200)}…'
      : post.content;
  final author = post.authorIsSystem ? 'Discipler' : post.authorDisplayName;
  return '"$body"\n— $author in $fellowshipName $suffix\n'
      '${ShareLinks.publicWebUrl}/fellowship/${post.fellowshipId}/post/${post.id}';
}

/// Shares [post] via the native share sheet using [buildPostShareText].
Future<void> sharePost(
  BuildContext context,
  FellowshipPostEntity post,
  String? fellowshipName,
) {
  final l10n = AppLocalizations.of(context)!;
  final name = (fellowshipName != null && fellowshipName.isNotEmpty)
      ? fellowshipName
      : 'Disciplefy Fellowship';
  final text = buildPostShareText(
    post: post,
    fellowshipName: name,
    suffix: l10n.sharePostSuffix,
  );
  return SharePlus.instance.share(ShareParams(text: text));
}
