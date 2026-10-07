import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/topic_progress.dart';

/// What the Continue card shows: the path to resume and, when known, the
/// topic the user is on.
class TopicsContinueData {
  final String pathId;
  final String title;

  /// 1-based position of the current topic.
  final int currentTopic;
  final int totalTopics;

  /// Title of the topic to study next, if known.
  final String? nextTopicTitle;

  /// 0–100.
  final int progressPercentage;

  const TopicsContinueData({
    required this.pathId,
    required this.title,
    required this.currentTopic,
    required this.totalTopics,
    required this.progressPercentage,
    this.nextTopicTitle,
  });

  /// Picks the path to continue.
  ///
  /// Prefers the most recent in-progress topic that belongs to a path
  /// ([inProgressTopics], newest first), which also names the next topic.
  /// Otherwise falls back to the furthest-along in-progress path in
  /// [paths]. Returns null when nothing is in progress.
  static TopicsContinueData? resolve({
    required List<InProgressTopic> inProgressTopics,
    required List<LearningPath> paths,
  }) {
    LearningPath? pathById(String id) =>
        paths.where((p) => p.id == id).firstOrNull;

    for (final topic in inProgressTopics) {
      if (!topic.isFromLearningPath) continue;
      final path = pathById(topic.learningPathId!);
      if (path != null && path.isCompleted) continue;
      final total = topic.totalTopicsInPath ?? path?.topicsCount ?? 0;
      if (total <= 0) continue;
      final completed = topic.topicsCompletedInPath ?? path?.topicsCompleted;
      final percent = path?.progressPercentage ??
          (completed != null ? (completed * 100 / total).round() : 0);
      return TopicsContinueData(
        pathId: topic.learningPathId!,
        title: path?.displayTitle ?? topic.learningPathName ?? topic.title,
        currentTopic:
            (topic.positionInPath ?? ((completed ?? 0) + 1)).clamp(1, total),
        totalTopics: total,
        nextTopicTitle: topic.title,
        progressPercentage: percent.clamp(0, 100),
      );
    }

    final inProgress = paths
        .where((p) => p.isInProgress && p.topicsCount > 0)
        .toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    if (inProgress.isEmpty) return null;
    final path = inProgress.first;
    return TopicsContinueData(
      pathId: path.id,
      title: path.displayTitle,
      currentTopic: (path.topicsCompleted + 1).clamp(1, path.topicsCount),
      totalTopics: path.topicsCount,
      progressPercentage: path.progressPercentage.clamp(0, 100),
    );
  }
}

/// "CONTINUE · TOPIC 4 OF 8" card at the top of the Study Topics tab.
class TopicsContinueCard extends StatelessWidget {
  final TopicsContinueData data;
  final VoidCallback onTap;

  const TopicsContinueCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(20);
    final eyebrow = context.tr(TranslationKeys.topicsHubContinueEyebrow, {
      'current': data.currentTopic,
      'total': data.totalTopics,
    }).toUpperCase();

    return Material(
      color: palette.isDark
          ? palette.card.withValues(alpha: 0.82)
          : palette.card.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('topics_continue_card'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: palette.gold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.25,
                ),
              ),
              if (data.nextTopicTitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr(TranslationKeys.topicsHubNextTopic,
                      {'title': data.nextTopicTitle}),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(fontSize: 14, color: palette.muted),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: data.progressPercentage / 100,
                        minHeight: 4,
                        backgroundColor: palette.raised,
                        valueColor: AlwaysStoppedAnimation(palette.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${data.progressPercentage}%',
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small stat tile: gold-tinted icon box, value and label.
class TopicsStatTile extends StatelessWidget {
  final IconData icon;

  /// Big value (e.g. "4 days", "#5"); omitted when unknown.
  final String? value;

  /// Small line under [value]. Without a value it is shown in the value's
  /// bold style instead, so a tile never reads as a lone grey caption.
  final String label;
  final VoidCallback? onTap;

  const TopicsStatTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(18);
    return Material(
      color: palette.isDark
          ? palette.card.withValues(alpha: 0.82)
          : palette.card.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: palette.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value != null) ...[
                      Text(
                        value!,
                        style: AppFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        label,
                        style: AppFonts.inter(
                          fontSize: 12.5,
                          color: palette.muted,
                          height: 1.25,
                        ),
                      ),
                    ] else
                      // One word in every language: shrink rather than
                      // break it across lines on a narrow tile.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: AppFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                            height: 1.25,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Study streak and (when [showLeaderboard]) Leaderboard tiles side by side.
/// Neither shows an XP number: the streak in days and the rank only.
class TopicsStatRow extends StatelessWidget {
  final int? streak;
  final int? rank;
  final bool showLeaderboard;
  final VoidCallback? onLeaderboardTap;

  const TopicsStatRow({
    super.key,
    this.streak,
    this.rank,
    this.showLeaderboard = true,
    this.onLeaderboardTap,
  });

  @override
  Widget build(BuildContext context) {
    final streak = this.streak;
    final rank = this.rank;
    final streakTile = TopicsStatTile(
      key: const Key('topics_streak_tile'),
      icon: Icons.local_fire_department_outlined,
      value: streak == null
          ? null
          : context.tr(
              streak == 1
                  ? TranslationKeys.topicsHubStreakValueOne
                  : TranslationKeys.topicsHubStreakValue,
              {'count': streak},
            ),
      label: context.tr(TranslationKeys.topicsHubStreakLabel),
    );
    if (!showLeaderboard) return streakTile;
    final leaderboardTile = TopicsStatTile(
      key: const Key('topics_leaderboard_tile'),
      icon: Icons.emoji_events_outlined,
      value: rank != null && rank > 0 ? '#$rank' : null,
      label: context.tr(TranslationKeys.topicsHubLeaderboardLabel),
      onTap: onLeaderboardTap,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: streakTile),
          const SizedBox(width: 10),
          Expanded(child: leaderboardTile),
        ],
      ),
    );
  }
}
