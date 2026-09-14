import 'package:equatable/equatable.dart';

/// Mentor view of a fellowship's Discipler daily post: schedule, what posts
/// next, the optional preview, pending actions and recent history.
class DailyPostStatusEntity extends Equatable {
  final DailyPostSettingsEntity settings;

  /// Today's date as the server counts it (`YYYY-MM-DD`).
  final String today;

  final DailyPostHistoryItemEntity? lastPost;
  final bool postedToday;

  /// When the next scheduled post goes out; `null` while daily posts are off.
  final String? nextPostDate;
  final String? nextPostTime;

  final String? pathTitle;
  final int pathTotalLessons;

  /// The next lessons in order; the first is the one that posts next.
  final List<DailyPostLessonEntity> upcoming;

  /// Only present when previews are enabled and one has been generated.
  final DailyPostPreviewEntity? preview;

  /// Latest request of each kind (`preview`, `regenerate`, `post_now`,
  /// `repost`).
  final Map<String, DailyPostRequestEntity> requests;

  final List<DailyPostHistoryItemEntity> history;

  /// How many more times a post can be posted again today.
  final int repostsLeftToday;

  const DailyPostStatusEntity({
    required this.settings,
    required this.today,
    this.lastPost,
    this.postedToday = false,
    this.nextPostDate,
    this.nextPostTime,
    this.pathTitle,
    this.pathTotalLessons = 0,
    this.upcoming = const [],
    this.preview,
    this.requests = const {},
    this.history = const [],
    this.repostsLeftToday = 0,
  });

  /// True while any requested action is still waiting to be processed.
  bool get hasOpenRequest => requests.values.any((r) => r.isOpen);

  DailyPostRequestEntity? request(String kind) => requests[kind];

  /// True while a "post again" is running for this daily post.
  bool isReposting(String dailyPostId) {
    final repost = requests['repost'];
    return repost != null &&
        repost.isOpen &&
        repost.targetDailyPostId == dailyPostId;
  }

  @override
  List<Object?> get props => [
        settings,
        today,
        lastPost,
        postedToday,
        nextPostDate,
        nextPostTime,
        pathTitle,
        pathTotalLessons,
        upcoming,
        preview,
        requests,
        history,
        repostsLeftToday,
      ];
}

class DailyPostSettingsEntity extends Equatable {
  final bool dailyPostOn;
  final int frequencyDays;
  final bool autoAdvance;

  /// IST posting time, `HH:MM`.
  final String time;
  final String? skipDate;
  final String? pausedUntil;
  final bool previewAllowed;
  final bool regenerateAllowed;
  final bool postNowAllowed;

  /// Official groups: no daily caps on new teasers or posting again, and no
  /// limit on how long posts can be paused.
  final bool noLimits;

  /// The posting times a mentor can choose from.
  final List<String> times;

  const DailyPostSettingsEntity({
    required this.dailyPostOn,
    required this.frequencyDays,
    required this.autoAdvance,
    required this.time,
    this.skipDate,
    this.pausedUntil,
    this.previewAllowed = false,
    this.regenerateAllowed = false,
    this.postNowAllowed = false,
    this.noLimits = false,
    this.times = const [],
  });

  @override
  List<Object?> get props => [
        dailyPostOn,
        frequencyDays,
        autoAdvance,
        time,
        skipDate,
        pausedUntil,
        previewAllowed,
        regenerateAllowed,
        postNowAllowed,
        noLimits,
        times,
      ];
}

class DailyPostLessonEntity extends Equatable {
  final String learningPathTopicId;
  final int position;
  final String title;

  const DailyPostLessonEntity({
    required this.learningPathTopicId,
    required this.position,
    required this.title,
  });

  @override
  List<Object?> get props => [learningPathTopicId, position, title];
}

class DailyPostPreviewEntity extends Equatable {
  final String postDate;
  final String topicTitle;
  final String content;
  final String? teaserHook;
  final String? teaserBody;
  final int regenerationsLeft;

  /// False when the preview was made for another lesson or an earlier date;
  /// the scheduled post will not use it.
  final bool isCurrent;

  const DailyPostPreviewEntity({
    required this.postDate,
    required this.topicTitle,
    required this.content,
    this.teaserHook,
    this.teaserBody,
    this.regenerationsLeft = 0,
    this.isCurrent = true,
  });

  @override
  List<Object?> get props => [
        postDate,
        topicTitle,
        content,
        teaserHook,
        teaserBody,
        regenerationsLeft,
        isCurrent,
      ];
}

class DailyPostRequestEntity extends Equatable {
  final String kind;

  /// `pending`, `processing`, `done` or `failed`.
  final String status;
  final String? error;
  final String? processedAt;

  /// For `repost`: the daily post being replaced.
  final String? targetDailyPostId;

  const DailyPostRequestEntity({
    required this.kind,
    required this.status,
    this.error,
    this.processedAt,
    this.targetDailyPostId,
  });

  bool get isOpen => status == 'pending' || status == 'processing';
  bool get isFailed => status == 'failed';

  @override
  List<Object?> get props =>
      [kind, status, error, processedAt, targetDailyPostId];
}

class DailyPostHistoryItemEntity extends Equatable {
  /// `discipler_daily_posts.id`; what "Post again" targets.
  final String? dailyPostId;
  final String postDate;
  final String? postId;
  final String? topicTitle;
  final int completedCount;

  /// True when the post was deleted or removed; it can still be posted again.
  final bool postDeleted;

  const DailyPostHistoryItemEntity({
    this.dailyPostId,
    required this.postDate,
    this.postId,
    this.topicTitle,
    this.completedCount = 0,
    this.postDeleted = false,
  });

  @override
  List<Object?> get props =>
      [dailyPostId, postDate, postId, topicTitle, completedCount, postDeleted];
}
