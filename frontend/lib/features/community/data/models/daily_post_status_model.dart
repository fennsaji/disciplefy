import '../../domain/entities/daily_post_status_entity.dart';

/// Parses the `fellowship-study/daily/status` response into a
/// [DailyPostStatusEntity]. Missing optional fields fall back to safe defaults
/// so an older server response never crashes the screen.
class DailyPostStatusModel {
  const DailyPostStatusModel._();

  static DailyPostStatusEntity fromJson(Map<String, dynamic> json) {
    final settings = (json['settings'] as Map<String, dynamic>?) ?? const {};
    final nextPost = json['next_post'] as Map<String, dynamic>?;
    final path = json['path'] as Map<String, dynamic>?;
    final lastPost = json['last_post'] as Map<String, dynamic>?;
    final preview = json['preview'] as Map<String, dynamic>?;
    final requests = (json['requests'] as Map<String, dynamic>?) ?? const {};

    return DailyPostStatusEntity(
      settings: DailyPostSettingsEntity(
        dailyPostOn: settings['daily_post_on'] as bool? ?? false,
        frequencyDays: (settings['frequency_days'] as num?)?.toInt() ?? 1,
        autoAdvance: settings['auto_advance'] as bool? ?? true,
        autoAdvancePath: settings['auto_advance_path'] as bool? ?? true,
        time: settings['time'] as String? ?? '06:30',
        skipDate: settings['skip_date'] as String?,
        pausedUntil: settings['paused_until'] as String?,
        previewAllowed: settings['preview_allowed'] as bool? ?? false,
        regenerateAllowed: settings['regenerate_allowed'] as bool? ?? false,
        postNowAllowed: settings['post_now_allowed'] as bool? ?? false,
        noLimits: settings['no_limits'] as bool? ?? false,
        times:
            ((settings['times'] as List<dynamic>?) ?? const []).cast<String>(),
      ),
      today: json['today'] as String? ?? '',
      lastPost: lastPost == null ? null : _historyItem(lastPost),
      postedToday: json['posted_today'] as bool? ?? false,
      nextPostDate: nextPost?['date'] as String?,
      nextPostTime: nextPost?['time'] as String?,
      pathTitle: path?['title'] as String?,
      pathTotalLessons: (path?['total_lessons'] as num?)?.toInt() ?? 0,
      upcoming: ((json['upcoming'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((l) => DailyPostLessonEntity(
                learningPathTopicId: l['learning_path_topic_id'] as String,
                position: (l['position'] as num?)?.toInt() ?? 0,
                title: l['title'] as String? ?? '',
              ))
          .toList(),
      preview: preview == null
          ? null
          : DailyPostPreviewEntity(
              postDate: preview['post_date'] as String? ?? '',
              topicTitle: preview['topic_title'] as String? ?? '',
              content: preview['content'] as String? ?? '',
              teaserHook: preview['teaser_hook'] as String?,
              teaserBody: preview['teaser_body'] as String?,
              regenerationsLeft:
                  (preview['regenerations_left'] as num?)?.toInt() ?? 0,
              isCurrent: preview['is_current'] as bool? ?? false,
            ),
      requests: {
        for (final entry in requests.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: _request(entry.key, entry.value as Map<String, dynamic>),
      },
      history: ((json['history'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_historyItem)
          .toList(),
      repostsLeftToday: (json['reposts_left_today'] as num?)?.toInt() ?? 0,
    );
  }

  static DailyPostRequestEntity _request(String kind, Map<String, dynamic> r) =>
      DailyPostRequestEntity(
        kind: kind,
        status: r['status'] as String? ?? 'done',
        error: r['error'] as String?,
        processedAt: r['processed_at'] as String?,
        targetDailyPostId: r['target_daily_post_id'] as String?,
        createdAt: r['created_at'] as String?,
      );

  static DailyPostHistoryItemEntity _historyItem(Map<String, dynamic> h) =>
      DailyPostHistoryItemEntity(
        dailyPostId: h['daily_post_id'] as String?,
        postDate: h['post_date'] as String? ?? '',
        postId: h['post_id'] as String?,
        topicTitle: h['topic_title'] as String?,
        completedCount: (h['completed_count'] as num?)?.toInt() ?? 0,
        postDeleted: h['post_deleted'] as bool? ?? false,
      );
}
