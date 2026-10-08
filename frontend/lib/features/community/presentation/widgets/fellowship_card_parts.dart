import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/current_study_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/group_study_progress.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';

/// Card surface of a fellowship (My fellowships, Discover): card fill,
/// 22 radius, 1px hairline and a faint gold glow in the top-left corner.
class FellowshipCardShell extends StatelessWidget {
  final Widget child;

  /// Makes the whole card tappable when set.
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const FellowshipCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(14, 16, 14, 14),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(22);
    return Material(
      color: palette.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.3,
              colors: [
                palette.gold.withValues(alpha: palette.isDark ? 0.18 : 0.07),
                palette.gold.withValues(alpha: 0),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Gold "Official" chip.
class FellowshipOfficialChip extends StatelessWidget {
  const FellowshipOfficialChip({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: palette.isDark ? 0.20 : 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        AppLocalizations.of(context)!.officialBadge,
        maxLines: 1,
        softWrap: false,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.goldOnTint,
        ),
      ),
    );
  }
}

/// Fellowship name (Poppins 18/600) followed inline by the "Official" chip
/// when [isOfficial]. Long names wrap; the chip flows after the last word.
class FellowshipCardTitle extends StatelessWidget {
  final String name;
  final bool isOfficial;

  const FellowshipCardTitle({
    super.key,
    required this.name,
    this.isOfficial = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          if (isOfficial) ...[
            const TextSpan(text: '  '),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: FellowshipOfficialChip(),
            ),
          ],
        ],
      ),
      style: AppFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.text,
        height: 1.35,
      ),
    );
  }
}

/// Who mentors a fellowship, resolved from the data the card already has.
class FellowshipMentorInfo {
  /// Mentor display name, or null when unknown.
  final String? name;
  final String? avatarUrl;

  /// Official and Discipler-mentored fellowships show the Discipler mark.
  final bool isDiscipler;

  /// The viewer is this mentor ("Fenn (you)").
  final bool isCurrentUser;

  const FellowshipMentorInfo({
    this.name,
    this.avatarUrl,
    this.isDiscipler = false,
    this.isCurrentUser = false,
  });

  /// First listed mentor (the same one the backend reports as `mentor_name`),
  /// falling back to [FellowshipEntity.mentorName].
  factory FellowshipMentorInfo.forFellowship(
    FellowshipEntity fellowship, {
    String? currentUserId,
  }) {
    final first =
        fellowship.mentors.isNotEmpty ? fellowship.mentors.first : null;
    final isDiscipler =
        fellowship.isOfficial || first?.userId == kDisciplerUserId;
    if (isDiscipler) return const FellowshipMentorInfo(isDiscipler: true);
    return FellowshipMentorInfo(
      name: realMentorName(first?.displayName) ??
          realMentorName(fellowship.mentorName),
      avatarUrl: first?.avatarUrl,
      isCurrentUser: currentUserId != null && first?.userId == currentUserId,
    );
  }

  factory FellowshipMentorInfo.forPublicFellowship(
      PublicFellowshipEntity fellowship) {
    if (fellowship.isOfficial) {
      return const FellowshipMentorInfo(isDiscipler: true);
    }
    return FellowshipMentorInfo(name: realMentorName(fellowship.mentorName));
  }
}

/// [name] when it is a real person's name, otherwise null.
///
/// The backend sends no name when the person never set one, and the data
/// layer fills that gap with the placeholders "Mentor" / "Unknown Member";
/// showing "Mentor: Mentor" says nothing, so those count as unknown.
String? realMentorName(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  const placeholders = {'mentor', 'unknown member'};
  if (placeholders.contains(trimmed.toLowerCase())) return null;
  return trimmed;
}

/// One mentor avatar + "Mentor: {name} · {N} members" (or "Guided by
/// Discipler · {N} members").
///
/// [leading] goes before the avatar (Discover's language chip). The text
/// wraps rather than truncating.
class FellowshipMentorRow extends StatelessWidget {
  final FellowshipMentorInfo mentor;
  final int memberCount;
  final Widget? leading;

  /// Avatar radius.
  final double avatarRadius;

  const FellowshipMentorRow({
    super.key,
    required this.mentor,
    required this.memberCount,
    this.leading,
    this.avatarRadius = 13,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final text = fellowshipMentorLine(context, mentor, memberCount);
    final displayName = mentor.isDiscipler ? l10n.disciplerName : mentor.name;

    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        if (mentor.isDiscipler)
          DisciplerAvatar(radius: avatarRadius)
        else if (displayName != null && displayName.trim().isNotEmpty)
          MemberAvatar(
            displayName: displayName,
            avatarUrl: mentor.avatarUrl,
            radius: avatarRadius,
          )
        else
          Icon(Icons.people_outline_rounded,
              size: avatarRadius * 1.4, color: palette.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppFonts.inter(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Mentor: {name} · {N} members", "Guided by Discipler · {N} members" for
/// Discipler-led groups, or just the member count when the mentor is unknown.
/// Shared by [FellowshipMentorRow] and the fellowship home meta.
String fellowshipMentorLine(
  BuildContext context,
  FellowshipMentorInfo mentor,
  int memberCount,
) {
  final l10n = AppLocalizations.of(context)!;
  final members = '$memberCount ${l10n.communityMembersCount(memberCount)}';
  if (mentor.isDiscipler) {
    return '${context.tr(TranslationKeys.communityGuidedByDiscipler)} · $members';
  }
  var name = mentor.name;
  if (name == null || name.trim().isEmpty) return members;
  if (mentor.isCurrentUser) {
    name = context.tr(TranslationKeys.communitySharedMentorYou, {'name': name});
  }
  final mentorText =
      context.tr(TranslationKeys.communitySharedMentor, {'name': name});
  return '$mentorText · $members';
}

/// The fellowship's current study on a raised inner block: book icon,
/// "{path} · Lesson N", "n of m" and a gold progress bar.
class FellowshipCurrentStudyRow extends StatelessWidget {
  final CurrentStudyEntity study;

  const FellowshipCurrentStudyRow({super.key, required this.study});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final finished = study.completedAt != null;
    final progressInfo = GroupStudyProgress.of(
      currentGuideIndex: study.currentGuideIndex,
      totalGuides: study.totalGuides,
      completed: finished,
    );
    final lesson = context.tr(TranslationKeys.communitySharedLesson,
        {'number': study.currentGuideIndex + 1});
    final path = study.learningPathTitle?.trim();
    final hasPath = path != null && path.isNotEmpty;
    // A finished path is named on its own; the progress says it is done.
    final title = finished
        ? (hasPath ? path : progressInfo.finishedLabel(context) ?? '')
        : hasPath
            ? '$path · $lesson'
            : lesson;
    final doneLabel = progressInfo.doneLabel(context);
    final progress = progressInfo.fraction;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                    finished
                        ? Icons.check_circle_rounded
                        : Icons.menu_book_outlined,
                    size: 14,
                    color: palette.gold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
              ),
              if (doneLabel != null) ...[
                const SizedBox(width: 10),
                // Natural width, so the path keeps the line; a long
                // translation wraps (never clips) inside the cap.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    doneLabel,
                    textAlign: TextAlign.end,
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: palette.muted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            CommunityProgressBar(value: progress),
          ],
        ],
      ),
    );
  }
}

/// Thin gold progress bar on a faint track.
class CommunityProgressBar extends StatelessWidget {
  /// 0..1.
  final double value;

  const CommunityProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: palette.isDark
            ? Colors.white.withValues(alpha: 0.10)
            : palette.text.withValues(alpha: 0.08),
        valueColor: AlwaysStoppedAnimation<Color>(palette.gold),
      ),
    );
  }
}

/// Short language code chip ("EN", "HI", "ML") on a raised fill.
class FellowshipLanguageChip extends StatelessWidget {
  /// `'en'`, `'hi'` or `'ml'` (anything else is upper-cased as is).
  final String language;

  const FellowshipLanguageChip({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : palette.raised,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        language.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.text,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
