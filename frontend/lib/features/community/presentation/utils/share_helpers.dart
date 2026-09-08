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
      // Built here rather than trusting the API's join_url: that still
      // points at the web app, which has no link preview and cannot hand the
      // URL to an installed app.
      final joinUrl = ShareLinks.fellowshipInvite(token);
      SharePlus.instance
          .share(ShareParams(text: 'Join $name on Disciplefy:\n$joinUrl'));
    },
  );
}

/// Upper bound on the shared body. Android caps an intent's extras at ~500KB
/// and iOS gets sluggish well before that; posts never approach this.
const int _maxShareBody = 5000;

/// Builds the shareable text for [post]: the full post, an attribution line,
/// and the post's deep link.
///
/// The body is sent whole — a study post carries its topic, reflection,
/// scripture and question, and an excerpt cut the reader off mid-thought.
/// [_maxShareBody] only guards against a pathological post breaking the
/// platform share sheet.
///
/// The Discipler AI helper is attributed as `'Discipler'` rather than its
/// raw author display name.
String buildPostShareText({
  required FellowshipPostEntity post,
  required String fellowshipName,
  required String suffix,
}) {
  final content = post.content.trim();
  final body = content.length > _maxShareBody
      ? '${content.substring(0, _maxShareBody)}…'
      : content;
  final author = post.authorIsSystem ? 'Discipler' : post.authorDisplayName;
  return '"$body"\n— $author in $fellowshipName $suffix\n'
      '${ShareLinks.fellowshipPost(post.fellowshipId, post.id)}';
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
