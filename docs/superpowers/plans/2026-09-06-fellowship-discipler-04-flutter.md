# Fellowship 1.0.5 — Plan 04: Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 1.0.5 community client: Discipler rendering (AI chip, daily post card, guide chip, drafts), mentions, ask-a-mentor, multiple mentors with promote/demote, mentor Discipler settings, Discipler activity screen, post sharing, Discover defaulting to All, notification routing, and the version bump.

**Architecture:** Clean Architecture per feature: entities → models → datasource → repository → BLoC → widgets. New screens follow the existing `fellowship_*_screen.dart` style (Inter font, `context.app*` colour extensions, `AppLocalizations` hand-written map). New strings are added to all three locale blocks plus a getter. Tests: `bloc_test` + mockito codegen for blocs, `flutter_test` for models and pure helpers.

**Tech Stack:** Flutter 3.x, flutter_bloc, dartz, get_it, go_router, share_plus ^11, mockito 5 + build_runner, bloc_test.

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md` §1, §5, §6, §7, §8. Index: `2026-09-06-fellowship-discipler-00-index.md`. Requires Plans 01–02 deployed locally (`sh scripts/run-android-local.sh` or web).

## Global Constraints

See index. Relevant here:
- Discipler id `00000000-0000-4000-8000-00000000d15c` (constant `kDisciplerUserId`).
- Reactions Discipler may show: existing `_kReactions`; never add `i_prayed` for it.
- Post composer type grid must stay length 4; "To mentors" is a toggle row, not a 5th type.
- Every new string: `'en'` (~line 29+), `'hi'` (~621+), `'ml'` (~1212+) blocks and a getter (~1814+) in `lib/core/localization/app_localizations.dart`. Keys camelCase.
- Every new push `type` needs a `case` in `notification_service.dart` and the web handler.
- After each task: `flutter analyze` clean, `dart format lib/ test/`, tests pass. Mock regeneration: `dart run build_runner build --delete-conflicting-outputs`.

---

### Task 1: Entities and models

**Files:**
- Modify: `lib/features/community/domain/entities/fellowship_entity.dart`, `fellowship_post_entity.dart`, `fellowship_comment_entity.dart`, `fellowship_member_entity.dart`, `public_fellowship_entity.dart`
- Modify: `lib/features/community/data/models/fellowship_model.dart`, `fellowship_post_model.dart`, `fellowship_comment_model.dart`, `fellowship_member_model.dart`, `public_fellowship_model.dart`
- Create: `lib/features/community/domain/entities/discipler_activity_entity.dart`, `lib/features/community/data/models/discipler_activity_model.dart`, `lib/core/constants/discipler.dart`
- Test: `test/features/community/models/community_models_test.dart`

**Interfaces:**
- Produces:
```dart
// lib/core/constants/discipler.dart
const String kDisciplerUserId = '00000000-0000-4000-8000-00000000d15c';
const String kDisciplerHandle = '@Discipler';

// FellowshipPostEntity: + bool toMentors, bool mentionsDiscipler; getter bool get authorIsSystem => authorUserId == kDisciplerUserId; bool get isDaily => postType == 'daily';
// FellowshipCommentEntity: + bool isPendingReview, bool mentionsDiscipler, String? studyGuideId, String? guideTitle, String? guideInputType, String? guideInputValue, String? guideLanguage; getter authorIsSystem
// FellowshipMemberEntity: + bool isOwner (default false); copyWith gains role
// FellowshipMentorEntity { String userId; String displayName; String? avatarUrl }
// FellowshipEntity: + List<FellowshipMentorEntity> mentors, bool isOfficial, disciplerAllowed, dailyPostAllowed, String disciplerReplyMode, disciplerReplyScope, int disciplerReplyDelayMin, bool disciplerReactEnabled, dailyPostOn, bool myDisciplerActivityPush; copyWith for the pref fields
// PublicFellowshipEntity: maxMembers becomes int? ; + bool isOfficial; getter bool get isUnlimited => maxMembers == null
// DisciplerActivityEntity { String id; String kind; String? postId; String? commentId; String? reaction; String? language; String summary; String? reviewedAt; String createdAt; String? postContent; String? postType; String? commentContent; bool commentPending; bool commentDeleted }
```

- [ ] **Step 1: Write the failing model tests**

```dart
// test/features/community/models/community_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/features/community/data/models/discipler_activity_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_comment_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_post_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/public_fellowship_model.dart';

void main() {
  test('post model reads Discipler fields and derives authorIsSystem', () {
    final p = FellowshipPostModel.fromJson({
      'id': 'p', 'fellowship_id': 'f', 'author_user_id': kDisciplerUserId, 'content': 'x',
      'post_type': 'daily', 'reaction_counts': {'amen': 2}, 'is_deleted': false,
      'created_at': '2026-09-06T01:00:00Z', 'author_display_name': 'Discipler',
      'comment_count': 0, 'to_mentors': false, 'mentions_discipler': false,
    }).toEntity();
    expect(p.authorIsSystem, true);
    expect(p.isDaily, true);
    expect(p.toMentors, false);
  });

  test('post model defaults the new booleans when absent', () {
    final p = FellowshipPostModel.fromJson({
      'id': 'p', 'fellowship_id': 'f', 'author_user_id': 'u', 'content': 'x', 'post_type': 'general',
      'reaction_counts': {}, 'is_deleted': false, 'created_at': 'c', 'author_display_name': 'n', 'comment_count': 1,
    }).toEntity();
    expect(p.toMentors, false);
    expect(p.mentionsDiscipler, false);
    expect(p.authorIsSystem, false);
  });

  test('comment model reads pending, mention and guide fields', () {
    final c = FellowshipCommentModel.fromJson({
      'id': 'c', 'post_id': 'p', 'author_user_id': kDisciplerUserId, 'content': 'x', 'is_deleted': false,
      'created_at': 'c', 'author_display_name': 'Discipler', 'is_pending_review': true, 'mentions_discipler': false,
      'study_guide_id': null, 'guide_title': 'Prayer', 'guide_input_type': 'topic', 'guide_input_value': 'prayer', 'guide_language': 'hi',
    }).toEntity();
    expect(c.isPendingReview, true);
    expect(c.authorIsSystem, true);
    expect(c.hasGuide, true);
    expect(c.studyGuideId, null);
  });

  test('public fellowship keeps null max_members as unlimited', () {
    final f = PublicFellowshipModel.fromJson({
      'id': 'f', 'name': 'n', 'language': 'en', 'member_count': 40, 'max_members': null, 'is_official': true,
    }).toEntity();
    expect(f.maxMembers, null);
    expect(f.isUnlimited, true);
    expect(f.isOfficial, true);
  });

  test('fellowship model reads mentors and prefs', () {
    final f = FellowshipModel.fromJson({
      'id': 'f', 'name': 'n', 'member_count': 3, 'user_role': 'mentor', 'joined_at': 'j', 'created_at': 'c',
      'mentors': [{'user_id': 'a', 'display_name': 'Anna', 'avatar_url': null}],
      'is_official': true, 'discipler_allowed': true, 'daily_post_allowed': false,
      'discipler_reply_mode': 'review', 'discipler_reply_scope': 'lessons_only', 'discipler_reply_delay_min': 30,
      'discipler_react_enabled': false, 'daily_post_on': true, 'my_discipler_activity_push': false,
    }).toEntity();
    expect(f.mentors.single.displayName, 'Anna');
    expect(f.disciplerReplyMode, 'review');
    expect(f.disciplerReplyDelayMin, 30);
    expect(f.myDisciplerActivityPush, false);
  });

  test('activity model joins post and comment', () {
    final a = DisciplerActivityModel.fromJson({
      'id': 'a', 'kind': 'draft', 'post_id': 'p', 'comment_id': 'c', 'reaction': null, 'language': 'en',
      'summary': 's', 'reviewed_at': null, 'created_at': 't',
      'post': {'content': 'q?', 'post_type': 'question', 'topic_title': null},
      'comment': {'content': 'ans', 'is_pending_review': true, 'is_deleted': false},
    }).toEntity();
    expect(a.commentPending, true);
    expect(a.postContent, 'q?');
  });
}
```

- [ ] **Step 2: Run** — `flutter test test/features/community/models/community_models_test.dart` → compile errors (missing fields/files).

- [ ] **Step 3: Implement**

`lib/core/constants/discipler.dart`:
```dart
/// Fixed identity of the Discipler AI helper (matches the seeded auth.users row).
const String kDisciplerUserId = '00000000-0000-4000-8000-00000000d15c';
const String kDisciplerHandle = '@Discipler';
```

`fellowship_post_entity.dart`: add fields `final bool toMentors; final bool mentionsDiscipler;` (constructor `this.toMentors = false, this.mentionsDiscipler = false`), getters:
```dart
  bool get authorIsSystem => authorUserId == kDisciplerUserId;
  bool get isDaily => postType == 'daily';
```
Add both to `props`. Add a `copyWith({Map<String,int>? reactionCounts, String? userReaction, bool clearUserReaction = false, int? commentCount})` that copies every field (this replaces the manual rebuild in the bloc later).

`fellowship_post_model.dart` `fromJson`: `toMentors: json['to_mentors'] as bool? ?? false, mentionsDiscipler: json['mentions_discipler'] as bool? ?? false,` and `lessonIndex: (json['lesson_index'] as num?)?.toInt()`. `toEntity` passes them through.

`fellowship_comment_entity.dart`: add `final bool isPendingReview; final bool mentionsDiscipler; final String? studyGuideId; final String? guideTitle; final String? guideInputType; final String? guideInputValue; final String? guideLanguage;` with defaults false/null; getters `authorIsSystem` and `bool get hasGuide => studyGuideId != null || (guideInputValue != null && guideInputType != null);`. Model `fromJson` reads the snake_case keys with `?? false` / `as String?`.

`fellowship_member_entity.dart`: add `final bool isOwner;` (default false); `copyWith({bool? isMuted, int? topicsCompleted, String? role})`. Model reads `is_owner`.

`fellowship_entity.dart`: add
```dart
class FellowshipMentorEntity extends Equatable {
  final String userId; final String displayName; final String? avatarUrl;
  const FellowshipMentorEntity({required this.userId, required this.displayName, this.avatarUrl});
  @override List<Object?> get props => [userId, displayName, avatarUrl];
}
```
and fields `List<FellowshipMentorEntity> mentors = const []`, `bool isOfficial = false, disciplerAllowed = false, dailyPostAllowed = false`, `String disciplerReplyMode = 'auto', disciplerReplyScope = 'all'`, `int disciplerReplyDelayMin = 0`, `bool disciplerReactEnabled = true, dailyPostOn = true, myDisciplerActivityPush = true`; `copyWith` covering the pref fields and `mentors`. Model `fromJson`: `mentors: ((json['mentors'] as List<dynamic>?) ?? []).map((m) => FellowshipMentorEntity(userId: m['user_id'] as String, displayName: m['display_name'] as String? ?? 'Mentor', avatarUrl: m['avatar_url'] as String?)).toList()` and the flags with defaults.

`public_fellowship_entity.dart`: `final int? maxMembers; final bool isOfficial;` `bool get isUnlimited => maxMembers == null;`. Model: `maxMembers: (json['max_members'] as num?)?.toInt(), isOfficial: json['is_official'] as bool? ?? false`.

`discipler_activity_entity.dart` + model as in the interface block (`fromJson` reads nested `post` / `comment` maps with null safety; `commentPending: (json['comment']?['is_pending_review'] as bool?) ?? false`).

- [ ] **Step 4: Fix compile fallout** — `community_tab_screen.dart:1460` `isFull` becomes `final isFull = !fellowship.isUnlimited && fellowship.memberCount >= fellowship.maxMembers!;` (full replacement in Task 6). Run `flutter analyze`.

- [ ] **Step 5: Run tests** → 6 passed. Commit.

```bash
git add lib/core/constants/discipler.dart lib/features/community/domain lib/features/community/data/models test/features/community/models
git commit -m "feat(community): Discipler, mentors and preference fields on entities and models"
```

---

### Task 2: Datasource and repository

**Files:**
- Modify: `lib/features/community/data/datasources/community_remote_datasource.dart`
- Modify: `lib/features/community/domain/repositories/community_repository.dart`, `lib/features/community/data/repositories/community_repository_impl.dart`

**Interfaces:**
- Produces (datasource and repository, repository wraps in `Either<Failure, T>`):
```dart
Future<FellowshipPostModel> createPost({..., bool toMentors = false})
Future<void> createFellowship({..., bool isOfficial = false, bool disciplerAllowed = false, bool dailyPostAllowed = false})
Future<void> updateFellowship({required String fellowshipId, String? name, String? description, int? maxMembers, String? postingPermission,
  bool? isOfficial, bool? disciplerAllowed, bool? dailyPostAllowed, String? disciplerReplyMode, String? disciplerReplyScope,
  int? disciplerReplyDelayMin, bool? disciplerReactEnabled, bool? dailyPostOn, bool? disciplerActivityPush})
Future<void> promoteMember({required String fellowshipId, required String userId})
Future<void> demoteMember({required String fellowshipId, required String userId})
Future<void> approveDisciplerComment(String commentId)
Future<void> discardDisciplerComment(String commentId)
Future<({List<DisciplerActivityModel> items, bool hasMore, String? nextCursor})> getDisciplerActivity({required String fellowshipId, String? kind, String? cursor, int limit = 30})
```
Endpoints: `/functions/v1/fellowship-members/promote`, `/demote`; `/functions/v1/fellowship-comments/approve`, `/discard`; `/functions/v1/fellowship/discipler-activity`.

- [ ] **Step 1: Datasource**

Add endpoint constants:
```dart
  static const String _fellowshipMembersPromoteEndpoint = '/functions/v1/fellowship-members/promote';
  static const String _fellowshipMembersDemoteEndpoint = '/functions/v1/fellowship-members/demote';
  static const String _fellowshipCommentsApproveEndpoint = '/functions/v1/fellowship-comments/approve';
  static const String _fellowshipCommentsDiscardEndpoint = '/functions/v1/fellowship-comments/discard';
  static const String _fellowshipDisciplerActivityEndpoint = '/functions/v1/fellowship/discipler-activity';
```
`createPost`: add `bool toMentors = false` and `'to_mentors': toMentors` to the body. `createFellowship`: add the three flags to the body only when true. `updateFellowship`: extend the `bodyMap` with one `if (x != null) bodyMap['snake_key'] = x;` line per new parameter (`posting_permission, is_official, discipler_allowed, daily_post_allowed, discipler_reply_mode, discipler_reply_scope, discipler_reply_delay_min, discipler_react_enabled, daily_post_on, discipler_activity_push`).

Add a shared POST helper for the four simple actions (transfer/mute already inline; new code may share):
```dart
  Future<void> _postAction(String endpoint, Map<String, dynamic> body, String code, String failMsg) async {
    try {
      final headers = await _httpService.createHeaders();
      final response = await _httpService.post('$_baseUrl$endpoint', headers: headers, body: jsonEncode(body));
      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final err = json['error'];
        throw ServerException(message: err is String ? err : (err is Map ? err['message'] as String? : null) ?? failMsg, code: code);
      }
    } on ServerException { rethrow; } catch (e) { throw ServerException(message: '$failMsg: $e', code: code); }
  }

  @override Future<void> promoteMember({required String fellowshipId, required String userId}) =>
      _postAction(_fellowshipMembersPromoteEndpoint, {'fellowship_id': fellowshipId, 'user_id': userId}, 'FELLOWSHIP_PROMOTE_ERROR', 'Failed to promote member');
  @override Future<void> demoteMember({required String fellowshipId, required String userId}) =>
      _postAction(_fellowshipMembersDemoteEndpoint, {'fellowship_id': fellowshipId, 'user_id': userId}, 'FELLOWSHIP_DEMOTE_ERROR', 'Failed to demote member');
  @override Future<void> approveDisciplerComment(String commentId) =>
      _postAction(_fellowshipCommentsApproveEndpoint, {'comment_id': commentId}, 'DISCIPLER_APPROVE_ERROR', 'Failed to approve reply');
  @override Future<void> discardDisciplerComment(String commentId) =>
      _postAction(_fellowshipCommentsDiscardEndpoint, {'comment_id': commentId}, 'DISCIPLER_DISCARD_ERROR', 'Failed to discard reply');
```
`getDisciplerActivity` copies `discoverFellowships` (query params `fellowship_id, kind, cursor, limit`; parse `data` list into `DisciplerActivityModel`, read top-level `pagination`).

- [ ] **Step 2: Repository interface + impl** — mirror each method with the three-catch template from `updateFellowship`. `getDisciplerActivity` returns `Either<Failure, DisciplerActivityPage>` where `class DisciplerActivityPage { final List<DisciplerActivityEntity> items; final bool hasMore; final String? nextCursor; }` declared next to `DiscoverPage`.

- [ ] **Step 3: Regenerate mocks and run existing tests**

`dart run build_runner build --delete-conflicting-outputs` then `flutter test test/features/community` → green. `flutter analyze` clean.

- [ ] **Step 4: Commit**

```bash
git add lib/features/community/data lib/features/community/domain test/features/community
git commit -m "feat(community): datasource and repository for mentor roles, Discipler prefs, review and activity"
```

---

### Task 3: Feed bloc: Discipler review, ask-a-mentor, entity copy

**Files:**
- Modify: `lib/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart`, `_state.dart`, `_bloc.dart`
- Test: `test/features/community/fellowship_discipler_review_test.dart`

**Interfaces:**
- Produces events: `FellowshipPostCreateRequested` gains `bool toMentors = false`; new `FellowshipDisciplerCommentReviewed({required String commentId, required bool approve})`. State: `comments` updated in place (approved → `isPendingReview:false`; discarded → removed). `_onReactionToggleRequested` uses `post.copyWith(reactionCounts:, userReaction:)`.

- [ ] **Step 1: Write the failing bloc test**

```dart
// test/features/community/fellowship_discipler_review_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'fellowship_discipler_review_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;
  FellowshipCommentEntity draft(String id) => FellowshipCommentEntity(
        id: id, postId: 'p', authorUserId: kDisciplerUserId, content: 'draft', isDeleted: false,
        createdAt: 't', authorDisplayName: 'Discipler', isPendingReview: true);
  final seeded = FellowshipFeedState.initial().copyWith(
      status: FellowshipFeedStatus.success, activePostId: 'p', comments: [draft('c1'), draft('c2')]);
  setUp(() => repository = MockCommunityRepository());

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'approve clears pending on the comment',
    build: () {
      when(repository.approveDisciplerComment('c1')).thenAnswer((_) async => const Right(null));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (b) => b.add(const FellowshipDisciplerCommentReviewed(commentId: 'c1', approve: true)),
    verify: (b) {
      expect(b.state.comments.firstWhere((c) => c.id == 'c1').isPendingReview, false);
      expect(b.state.comments.firstWhere((c) => c.id == 'c2').isPendingReview, true);
    },
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'discard removes the comment',
    build: () {
      when(repository.discardDisciplerComment('c2')).thenAnswer((_) async => const Right(null));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (b) => b.add(const FellowshipDisciplerCommentReviewed(commentId: 'c2', approve: false)),
    verify: (b) => expect(b.state.comments.map((c) => c.id), ['c1']),
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'create post forwards toMentors',
    build: () {
      when(repository.createPost(
        fellowshipId: anyNamed('fellowshipId'), content: anyNamed('content'), postType: anyNamed('postType'),
        topicId: anyNamed('topicId'), topicTitle: anyNamed('topicTitle'), guideTitle: anyNamed('guideTitle'),
        lessonIndex: anyNamed('lessonIndex'), studyGuideId: anyNamed('studyGuideId'), guideInputType: anyNamed('guideInputType'),
        guideLanguage: anyNamed('guideLanguage'), toMentors: true,
      )).thenAnswer((_) async => Left(const ServerFailure(message: 'x')));
      return FellowshipFeedBloc(repository: repository);
    },
    act: (b) => b.add(const FellowshipPostCreateRequested(fellowshipId: 'f', content: 'help?', postType: 'question', toMentors: true)),
    verify: (_) => verify(repository.createPost(
        fellowshipId: 'f', content: 'help?', postType: 'question', topicId: null, topicTitle: null, guideTitle: null,
        lessonIndex: null, studyGuideId: null, guideInputType: null, guideLanguage: null, toMentors: true)).called(1),
  );
}
```
(add `import 'package:disciplefy_bible_study/core/error/failures.dart';`.)

- [ ] **Step 2: Run** — build_runner then `flutter test test/features/community/fellowship_discipler_review_test.dart` → fails (missing event).

- [ ] **Step 3: Implement**

Event:
```dart
class FellowshipDisciplerCommentReviewed extends FellowshipFeedEvent {
  final String commentId; final bool approve;
  const FellowshipDisciplerCommentReviewed({required this.commentId, required this.approve});
  @override List<Object?> get props => [commentId, approve];
}
```
`FellowshipPostCreateRequested`: add `final bool toMentors;` (`this.toMentors = false`) and props. Bloc `_onPostCreateRequested` passes `toMentors: event.toMentors`. Handler:
```dart
  Future<void> _onDisciplerCommentReviewed(FellowshipDisciplerCommentReviewed event, Emitter<FellowshipFeedState> emit) async {
    final result = event.approve
        ? await _repository.approveDisciplerComment(event.commentId)
        : await _repository.discardDisciplerComment(event.commentId);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: ErrorMessageSanitizer.sanitize(failure))),
      (_) {
        final updated = event.approve
            ? state.comments.map((c) => c.id == event.commentId ? c.copyWith(isPendingReview: false) : c).toList()
            : state.comments.where((c) => c.id != event.commentId).toList();
        emit(state.copyWith(comments: updated, clearErrorMessage: true));
      },
    );
  }
```
Add `copyWith({bool? isPendingReview})` to `FellowshipCommentEntity` (Task 1 file). Register `on<FellowshipDisciplerCommentReviewed>(_onDisciplerCommentReviewed);`. Replace the manual rebuild in `_onReactionToggleRequested` with `post.copyWith(reactionCounts: updatedCounts, userReaction: _resolveUserReaction(...), clearUserReaction: _resolveUserReaction(...) == null)`.

- [ ] **Step 4: Run tests** → 3 passed, plus existing `fellowship_block_test.dart`. Commit.

```bash
git add lib/features/community/presentation/bloc/fellowship_feed test/features/community
git commit -m "feat(community): review Discipler drafts and ask-a-mentor in the feed bloc"
```

---

### Task 4: Localized strings for the release

**Files:**
- Modify: `lib/core/localization/app_localizations.dart` (three blocks + getters)

**Interfaces:**
- Produces getters (all `String get x`): `disciplerName` ("Discipler"), `disciplerAiChip` ("AI"), `disciplerFooter` ("Discipler is an AI helper. Mentors review its answers."), `disciplerDraftBadge` ("Draft · mentors only"), `approve`, `discard`, `openStudyGuide`, `postTypeDaily` ("Today's study"), `openFullStudy` ("Open the full study"), `askAMentor`, `toMentorsChip` ("To mentors"), `askMentorsToggle` ("Ask the mentors directly"), `askMentorsHint` ("Mentors get notified. Discipler stays out of this one."), `mentionSheetTitle` ("Mention"), `disciplerMentionSubtitle` ("AI helper · answers in your language"), `mentorLabel` ("Mentor"), `ownerLabel` ("Owner"), `helpersSection` ("Helpers"), `mentorsSection` ("Mentors"), `promoteToMentor`, `demoteToMember`, `officialBadge` ("Official"), `unlimitedMembers` ("Unlimited"), `sharePost`, `sharePostSuffix` ("on Disciplefy"), `fellowshipSettingsTitle`, `disciplerSettingsSection`, `disciplerAllowedByAdmin` ("Allowed by admin"), `disciplerAnswerQuestions`, `disciplerModeOff` ("Off"), `disciplerModeAuto` ("Answer automatically"), `disciplerModeReview` ("Draft for my review"), `disciplerWhichQuestions`, `disciplerScopeAll` ("All questions"), `disciplerScopeLessons` ("Lesson discussions only"), `disciplerWaitFirst` ("Wait for a mentor first"), `disciplerDelayNow` ("Immediately"), `disciplerDelay30` ("30 min"), `disciplerDelay120` ("2 h"), `disciplerDelay720` ("12 h"), `disciplerReactToggle` ("React to posts"), `disciplerDailyToggle` ("Post a daily study"), `disciplerNotifyToggle` ("Notify me about Discipler activity"), `disciplerActivityTitle` ("Discipler activity"), `activityTabAll` ("All"), `activityTabReview` ("Review"), `activityTabReplies` ("Replies"), `activityTabReactions` ("Reactions"), `activityTabDaily` ("Daily"), `activityEmpty` ("Nothing from Discipler yet."), `deleteAction` ("Delete"), `createFellowshipOfficial` ("Official Disciplefy fellowship"), `createFellowshipDisciplerAllowed` ("Allow Discipler replies"), `createFellowshipDailyAllowed` ("Allow daily study post"), `adminOptionsLabel` ("Admin options").

- [ ] **Step 1: Add keys** to `'en'`, `'hi'`, `'ml'` with real translations (Hindi and Malayalam by a fluent speaker; if none is available at implementation time, use the English text in the `hi`/`ml` blocks and open a follow-up, but every key must exist in all three blocks or the app throws).

- [ ] **Step 2: Add getters** in the getters section, one per key following the `postTypePrayer` pattern.

- [ ] **Step 3: Verify** — `flutter analyze`; run the app and switch languages to confirm no `Null check operator` crash on the community tab.

- [ ] **Step 4: Commit**

```bash
git add lib/core/localization/app_localizations.dart
git commit -m "feat(l10n): strings for Discipler, mentors, sharing and fellowship settings"
```

---

### Task 5: Post card and comment tile rendering

**Files:**
- Modify: `lib/features/community/presentation/widgets/fellowship_post_card.dart`
- Create: `lib/features/community/presentation/widgets/discipler_badges.dart`, `lib/features/community/presentation/widgets/daily_post_card.dart`, `lib/features/community/presentation/widgets/study_guide_chip.dart`
- Modify: the comment tile widget used by the comments sheet in `fellowship_feed_tab_screen.dart` (search `class _CommentTile`)
- Test: `test/features/community/widgets/post_card_menu_test.dart`

**Interfaces:**
- Produces widgets: `DisciplerAiChip()`, `DisciplerAvatar({double radius})`, `DisciplerFooterNote()`, `DailyPostCard({required FellowshipPostEntity post, required String fellowshipId, VoidCallback? onCommentTap, VoidCallback? onShareTap})`, `StudyGuideChip({String? studyGuideId, required String title, String? inputType, String? inputValue, String? language})`.
- Pure helper for tests: `List<String> postMenuItems({required FellowshipPostEntity post, required bool isMentor, required bool isAdmin, String? currentUserId})` returning any of `['delete','report','block','share']`.

- [ ] **Step 1: Write the failing test for menu rules**

```dart
// test/features/community/widgets/post_card_menu_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/constants/discipler.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';

FellowshipPostEntity post(String author, {String type = 'general'}) => FellowshipPostEntity(
    id: 'p', fellowshipId: 'f', authorUserId: author, content: 'c', postType: type, reactionCounts: const {},
    isDeleted: false, createdAt: 't', authorDisplayName: author, commentCount: 0);

void main() {
  test('Discipler content: mentors and admins delete, nobody reports or blocks, everyone shares', () {
    expect(postMenuItems(post(kDisciplerUserId), isMentor: true, isAdmin: false, currentUserId: 'u'), ['share', 'delete']);
    expect(postMenuItems(post(kDisciplerUserId), isMentor: false, isAdmin: true, currentUserId: 'u'), ['share', 'delete']);
    expect(postMenuItems(post(kDisciplerUserId), isMentor: false, isAdmin: false, currentUserId: 'u'), ['share']);
  });
  test('member content keeps existing rules plus share', () {
    expect(postMenuItems(post('a'), isMentor: false, isAdmin: false, currentUserId: 'a'), ['share', 'delete']);
    expect(postMenuItems(post('a'), isMentor: false, isAdmin: false, currentUserId: 'b'), ['share', 'report', 'block']);
    expect(postMenuItems(post('a'), isMentor: true, isAdmin: false, currentUserId: 'b'), ['share', 'delete', 'block']);
  });
}
```

- [ ] **Step 2: Run** → fails, `postMenuItems` missing.

- [ ] **Step 3: Implement**

`discipler_badges.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';

class DisciplerAiChip extends StatelessWidget {
  const DisciplerAiChip({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: context.appPrimary, borderRadius: BorderRadius.circular(6)),
        child: Text(AppLocalizations.of(context)!.disciplerAiChip,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
      );
}

class DisciplerAvatar extends StatelessWidget {
  final double radius;
  const DisciplerAvatar({this.radius = 20, super.key});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius, backgroundColor: context.appPrimary,
        child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: radius));
}

class DisciplerFooterNote extends StatelessWidget {
  const DisciplerFooterNote({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(Icons.info_outline_rounded, size: 12, color: context.appTextTertiary),
        const SizedBox(width: 4),
        Expanded(child: Text(AppLocalizations.of(context)!.disciplerFooter,
            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: context.appTextTertiary))),
      ]);
}
```

`study_guide_chip.dart`: an `InkWell` bordered row (book icon, title, chevron) that on tap: if `studyGuideId != null` → `context.push('${AppRoutes.studyGuide}?source=fellowship', extra: {'study_guide': {'id': studyGuideId, 'title': title, 'type': inputType ?? 'topic', 'input_value': inputValue ?? title, 'language': language ?? 'en'}})` else → `context.push('${AppRoutes.studyGuideV2}?input=${Uri.encodeComponent(inputValue ?? title)}&type=${inputType ?? 'topic'}&language=${language ?? 'en'}&source=discipler')`. (`existingGuideData` with only an id is not enough for `StudyGuideScreenV2`; keep the by-id path consistent with `_SharedGuideLink._navigate`, which fetches the full guide first. Reuse that fetch: move `_SharedGuideLink`'s fetch-by-id into a small `Future<Map<String, dynamic>?> fetchSavedGuide(String id)` in `lib/features/community/data/services/saved_guide_fetcher.dart` and call it from both.)

`daily_post_card.dart`: amber card (`AppColors.brandHighlight` light / `Color(0xFF3A3018)` dark), header `DisciplerAvatar` + `Discipler` + `DisciplerAiChip` + `postTypeDaily`, body text rendered from `post.content` (the Rust formatter's plain text; render lines starting with `📖` bold 16, `✝️` in a verse pill, `💬` semibold, and the last line as `openFullStudy` link that navigates like `StudyGuideChip` with `studyGuideId: post.studyGuideId, title: post.guideTitle ?? post.topicTitle ?? '', inputType: 'topic', inputValue: post.topicTitle, language: post.guideLanguage`), footer: reaction button reused from `FellowshipPostCard` (`_ReactionButton` becomes a public `FellowshipReactionButton` in its own file `reaction_button.dart`), comment count, share icon → `onShareTap`.

`fellowship_post_card.dart`:
- Add `final bool isAdmin;` (default false) and `final VoidCallback? onShareTap;`.
- Add the exported helper:
```dart
List<String> postMenuItems({required FellowshipPostEntity post, required bool isMentor, required bool isAdmin, String? currentUserId}) {
  final items = <String>['share'];
  final own = post.authorUserId == currentUserId;
  if (isMentor || isAdmin || own) items.add('delete');
  if (post.authorIsSystem) return items;
  if (!isMentor && !own) items.add('report');
  if (!own) items.add('block');
  return items;
}
```
and build the `PopupMenuButton` items from it (`'share'` → `Icons.share_outlined` + `l10n.sharePost`; `'delete'` label → `l10n.deleteAction`, replacing the hardcoded `'Delete'`).
- In `build`, if `post.isDaily` return `DailyPostCard(...)` early.
- Avatar/name row: when `post.authorIsSystem` use `DisciplerAvatar`, name `l10n.disciplerName`, append `DisciplerAiChip`; card background `context.appPrimary.withAlpha(isDark ? 40 : 18)`; add `DisciplerFooterNote` under the content. Render `@Discipler` and `@Name` tokens in content in `context.appPrimary` w600 via a small `RichText` splitter `mentionSpans(String text, TextStyle base, TextStyle mention)` (regex `(@[A-Za-z][\w.]*)`).
- Add `'daily'` to `_PostTypeLabel` config (`label: l10n.postTypeDaily`, color `AppColors.brandHighlightDark` / light variant) and to `postTypeAccentColor`.
- Add a "To mentors" chip next to the type label when `post.toMentors` (`l10n.toMentorsChip`, `AppColors.brandHighlight` bg, `brandHighlightDark` text).
- Footer: add a share `IconButton` calling `onShareTap` in `_InteractiveFooter`.

Comment tile (`_CommentTile` in `fellowship_feed_tab_screen.dart`): when `comment.authorIsSystem` → `DisciplerAvatar(radius: 16)`, name `disciplerName` + `DisciplerAiChip`, tinted background, `DisciplerFooterNote`; if `comment.hasGuide` show `StudyGuideChip(...)` under the text; if `comment.isPendingReview` show a `disciplerDraftBadge` pill and, when `isMentor`, two buttons `approve` / `discard` dispatching `FellowshipDisciplerCommentReviewed`. Report/block items are hidden for system authors; delete shown for mentors/admins.

- [ ] **Step 4: Run tests and analyze** → `flutter test test/features/community/widgets/post_card_menu_test.dart` 2 passed; `flutter analyze` clean. Visual check in the app: seed a Discipler comment (Plan 02 Task 6) and confirm the chip, tint, footer, and guide chip render.

- [ ] **Step 5: Commit**

```bash
git add lib/features/community/presentation/widgets lib/features/community/presentation/screens/fellowship_feed_tab_screen.dart lib/features/community/data/services test/features/community/widgets
git commit -m "feat(community): Discipler chips, daily post card, guide chip, review controls, share menu"
```

---

### Task 6: Discover defaults to All, official badge, unlimited

**Files:**
- Modify: `lib/features/community/presentation/screens/community_tab_screen.dart` (`:829-845`, `_PublicFellowshipCard :1446+`, `_LanguageFilterChips`)

- [ ] **Step 1: Default filter** — in `_DiscoverTabState.initState` replace the locale lookup with `bloc.add(const DiscoverLoadRequested(language: null));` and delete the `localeCode`/`initialLang` lines. Ensure the "All" chip renders selected when `language == null` (check `_LanguageFilterChips`).

- [ ] **Step 2: Card** — `final isFull = !fellowship.isUnlimited && fellowship.memberCount >= fellowship.maxMembers!;`. Member line: `fellowship.isUnlimited ? '${l10n.unlimitedMembers} · ${fellowship.memberCount}' : '${fellowship.memberCount} / ${fellowship.maxMembers}'`. After the name add `if (fellowship.isOfficial) _OfficialBadge()` (amber pill, `l10n.officialBadge`). Also add the badge to `_FellowshipCard` in My Fellowships using `fellowship.isOfficial`, and a mentors avatar stack (initials of `fellowship.mentors`, max 3, overlapping 12px).

- [ ] **Step 3: Verify** — run the app: Discover opens on All and lists all three languages; the unlimited group shows "Unlimited · N" and a Join button; official groups show the badge. `flutter analyze`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/community/presentation/screens/community_tab_screen.dart
git commit -m "fix(community): Discover defaults to All, unlimited groups never read full, official badge"
```

---

### Task 7: Fellowship home: mentors strip, ask a mentor, share, settings and activity entry

**Files:**
- Modify: `lib/features/community/presentation/screens/fellowship_home_screen.dart` (`_HeroHeader :566-632`, app bar `:448-515`, feed preview)
- Modify: `lib/features/community/presentation/screens/fellowship_feed_tab_screen.dart` (`FellowshipCreatePostSheet`)

**Interfaces:**
- Consumes: `FellowshipEntity.mentors`, `isOfficial`, `disciplerAllowed`; `FellowshipMembersBloc` members (`role == 'mentor'`).
- Produces: `FellowshipCreatePostSheet({required String fellowshipId, bool initialToMentors = false, String initialType = 'general'})`; app bar overflow gains `settings` (mentor) and `disciplerActivity` (mentor, when `disciplerAllowed`), and `share` (all).

- [ ] **Step 1: Hero** — replace the single `'Mentor: ${mentor.displayName}'` row with a `Row` of an avatar stack of all `role == 'mentor'` members (fallback to `fellowship?.mentors`) followed by `l10n.mentorsSection` + names joined by ", ". Add an `OFFICIAL` badge before the member count when `fellowship?.isOfficial == true`. Below, a button row: filled white `ElevatedButton.icon(Icons.forum_outlined, l10n.askAMentor)` opening `FellowshipCreatePostSheet(fellowshipId:, initialToMentors: true, initialType: 'question')` wrapped in `BlocProvider.value(FellowshipFeedBloc)`, and an outlined `Share` button calling `shareFellowshipInvite` (existing invite share from `fellowship_invites_screen.dart:235`, extracted to `lib/features/community/presentation/utils/share_helpers.dart`).

- [ ] **Step 2: App bar menu** — add items: `if (isMentor) 'settings'` → `context.push('/community/$fellowshipId/settings', extra: fellowship)`; `if (isMentor && (fellowship?.disciplerAllowed ?? false)) 'discipler_activity'` → `context.push('/community/$fellowshipId/discipler-activity')`. Keep existing edit/delete/leave. The old `_EditFellowshipSheet` stays for name-only edits until Task 8 replaces the `edit` item with `settings`.

- [ ] **Step 3: Feed preview** — `FellowshipPostCard(... isAdmin: authIsAdmin, onShareTap: () => sharePost(context, post, fellowshipName))` where `authIsAdmin` comes from `context.read<AuthBloc>().state is AuthenticatedState && ....isAdmin`. Sort: posts with `isDaily && createdAt` today first (`List.sort` with a comparator on `isDaily` then `createdAt` desc) in both preview and full feed (`FellowshipFeedTabScreen` list builder).

- [ ] **Step 4: Composer** — add `initialToMentors`, `initialType`; state `bool _toMentors`; a `SwitchListTile`-style row under the grid: title `l10n.askMentorsToggle`, subtitle `l10n.askMentorsHint`; `_submit` passes `toMentors: _toMentors` and forces `postType = 'question'` when on.

- [ ] **Step 5: Verify** — mentors strip shows Anna; Ask a mentor opens the composer with the toggle on; posting creates a post with the "To mentors" chip; `flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/community/presentation
git commit -m "feat(community): mentors strip, ask a mentor, share, settings and activity entries on fellowship home"
```

---

### Task 8: Fellowship settings screen with mentor Discipler preferences

**Files:**
- Create: `lib/features/community/presentation/bloc/fellowship_settings/fellowship_settings_bloc.dart`, `_event.dart`, `_state.dart`
- Create: `lib/features/community/presentation/screens/fellowship_settings_screen.dart`
- Modify: `lib/core/di/injection_container.dart` (register bloc), `lib/core/router/app_router.dart` (route `settings` under `:fellowshipId`), `lib/core/router/app_routes.dart`
- Test: `test/features/community/fellowship_settings_bloc_test.dart`

**Interfaces:**
- Produces:
```dart
// events
class FellowshipSettingsLoaded { final FellowshipEntity fellowship; }
class FellowshipSettingsChanged { final String? name; final String? description; final String? postingPermission;
  final String? disciplerReplyMode; final String? disciplerReplyScope; final int? disciplerReplyDelayMin;
  final bool? disciplerReactEnabled; final bool? dailyPostOn; final bool? disciplerActivityPush; }
class FellowshipSettingsSaveRequested {}
// state
enum FellowshipSettingsStatus { idle, saving, saved, failure }
class FellowshipSettingsState { final FellowshipEntity? original; final FellowshipEntity? draft; final FellowshipSettingsStatus status; final String? errorMessage; bool get isDirty; }
```
Route: `AppRoutes.fellowshipSettings = '/community/:fellowshipId/settings'`, name `fellowship_settings`, `state.extra` is `FellowshipEntity`.

- [ ] **Step 1: Write the failing bloc test**

```dart
// test/features/community/fellowship_settings_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_settings/fellowship_settings_state.dart';
import 'fellowship_settings_bloc_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repo;
  const f = FellowshipEntity(id: 'f', name: 'N', memberCount: 1, userRole: 'mentor', joinedAt: 'j', createdAt: 'c',
      disciplerAllowed: true, disciplerReplyMode: 'auto', disciplerReplyDelayMin: 0);
  setUp(() => repo = MockCommunityRepository());

  blocTest<FellowshipSettingsBloc, FellowshipSettingsState>(
    'saves only changed Discipler fields',
    build: () {
      when(repo.updateFellowship(
        fellowshipId: 'f', name: null, description: null, maxMembers: null, postingPermission: null,
        isOfficial: null, disciplerAllowed: null, dailyPostAllowed: null,
        disciplerReplyMode: 'review', disciplerReplyScope: null, disciplerReplyDelayMin: 30,
        disciplerReactEnabled: null, dailyPostOn: null, disciplerActivityPush: null,
      )).thenAnswer((_) async => const Right(null));
      return FellowshipSettingsBloc(repository: repo);
    },
    act: (b) => b
      ..add(const FellowshipSettingsLoaded(f))
      ..add(const FellowshipSettingsChanged(disciplerReplyMode: 'review', disciplerReplyDelayMin: 30))
      ..add(const FellowshipSettingsSaveRequested()),
    verify: (b) {
      expect(b.state.status, FellowshipSettingsStatus.saved);
      expect(b.state.isDirty, false);
      expect(b.state.original!.disciplerReplyMode, 'review');
    },
  );
}
```

- [ ] **Step 2: Run** → fails (missing bloc).

- [ ] **Step 3: Implement bloc**

```dart
class FellowshipSettingsBloc extends Bloc<FellowshipSettingsEvent, FellowshipSettingsState> {
  final CommunityRepository _repository;
  FellowshipSettingsBloc({required CommunityRepository repository})
      : _repository = repository, super(const FellowshipSettingsState()) {
    on<FellowshipSettingsLoaded>((e, emit) => emit(state.copyWith(original: e.fellowship, draft: e.fellowship, status: FellowshipSettingsStatus.idle)));
    on<FellowshipSettingsChanged>((e, emit) {
      final d = state.draft; if (d == null) return;
      emit(state.copyWith(draft: d.copyWith(
        name: e.name, description: e.description, postingPermission: e.postingPermission,
        disciplerReplyMode: e.disciplerReplyMode, disciplerReplyScope: e.disciplerReplyScope,
        disciplerReplyDelayMin: e.disciplerReplyDelayMin, disciplerReactEnabled: e.disciplerReactEnabled,
        dailyPostOn: e.dailyPostOn, myDisciplerActivityPush: e.disciplerActivityPush,
      )));
    });
    on<FellowshipSettingsSaveRequested>(_onSave);
  }

  Future<void> _onSave(FellowshipSettingsSaveRequested e, Emitter<FellowshipSettingsState> emit) async {
    final o = state.original, d = state.draft;
    if (o == null || d == null) return;
    emit(state.copyWith(status: FellowshipSettingsStatus.saving));
    T? diff<T>(T a, T b) => a == b ? null : b;
    final result = await _repository.updateFellowship(
      fellowshipId: d.id,
      name: diff(o.name, d.name), description: diff(o.description, d.description), maxMembers: null,
      postingPermission: diff(o.postingPermission, d.postingPermission),
      isOfficial: null, disciplerAllowed: null, dailyPostAllowed: null,
      disciplerReplyMode: diff(o.disciplerReplyMode, d.disciplerReplyMode),
      disciplerReplyScope: diff(o.disciplerReplyScope, d.disciplerReplyScope),
      disciplerReplyDelayMin: diff(o.disciplerReplyDelayMin, d.disciplerReplyDelayMin),
      disciplerReactEnabled: diff(o.disciplerReactEnabled, d.disciplerReactEnabled),
      dailyPostOn: diff(o.dailyPostOn, d.dailyPostOn),
      disciplerActivityPush: diff(o.myDisciplerActivityPush, d.myDisciplerActivityPush),
    );
    result.fold(
      (f) => emit(state.copyWith(status: FellowshipSettingsStatus.failure, errorMessage: ErrorMessageSanitizer.sanitize(f))),
      (_) => emit(state.copyWith(status: FellowshipSettingsStatus.saved, original: d)),
    );
  }
}
```
State `isDirty => original != draft` (entities are Equatable; make sure `FellowshipEntity.props` includes the pref fields). `FellowshipEntity.copyWith` must accept `name, description, postingPermission` too.

- [ ] **Step 4: Screen** — `FellowshipSettingsScreen({required String fellowshipId, required FellowshipEntity fellowship})`: `Scaffold` with app bar title `fellowshipSettingsTitle` and a `Save` text button enabled when `isDirty`; body `ListView` with: name `TextFormField`, description, `SegmentedButton` for who-can-post (reuse the create screen's segments), then when `fellowship.disciplerAllowed` a "Discipler" section header with `DisciplerAvatar(radius: 12)` + `disciplerSettingsSection` + green pill `disciplerAllowedByAdmin`, and:
  - `disciplerAnswerQuestions` → `SegmentedButton<String>` values `off/auto/review` labels `disciplerModeOff/Auto/Review`
  - `disciplerWhichQuestions` → `SegmentedButton<String>` `all/lessons_only`
  - `disciplerWaitFirst` → `SegmentedButton<int>` `0/30/120/720`
  - `SwitchListTile` `disciplerReactToggle`, `disciplerDailyToggle` (only when `fellowship.dailyPostAllowed`), `disciplerNotifyToggle`
  Each control dispatches `FellowshipSettingsChanged`. On `saved` show a `SnackBar` and `context.pop(state.original)`; the home screen updates its `fellowship` from the pop result.

- [ ] **Step 5: Wire** — DI `sl.registerFactory<FellowshipSettingsBloc>(() => FellowshipSettingsBloc(repository: sl()));`; router: under the `:fellowshipId` route add `GoRoute(path: 'settings', name: 'fellowship_settings', builder: (context, state) => MaxWidthWrapper(child: BlocProvider(create: (_) => sl<FellowshipSettingsBloc>()..add(FellowshipSettingsLoaded(state.extra as FellowshipEntity)), child: FellowshipSettingsScreen(fellowshipId: state.pathParameters['fellowshipId']!, fellowship: state.extra as FellowshipEntity))))`. Replace the home overflow `edit` item with `settings`.

- [ ] **Step 6: Verify** — build_runner, `flutter test test/features/community/fellowship_settings_bloc_test.dart` → 1 passed; in the app as Anna change mode to review, save, reopen → persisted; as Rahul the entry is hidden.

- [ ] **Step 7: Commit**

```bash
git add lib/features/community/presentation/bloc/fellowship_settings lib/features/community/presentation/screens/fellowship_settings_screen.dart lib/core/di/injection_container.dart lib/core/router test/features/community
git commit -m "feat(community): fellowship settings screen with mentor Discipler preferences"
```

---

### Task 9: Members: mentors section, promote/demote, Discipler helper row

**Files:**
- Modify: `lib/features/community/presentation/bloc/fellowship_members/` (events/bloc), `lib/features/community/presentation/screens/fellowship_members_tab_screen.dart`
- Test: extend `test/features/community/fellowship_members_roles_test.dart` (new)

**Interfaces:**
- Produces events `FellowshipMemberPromoteRequested({required String userId})`, `FellowshipMemberDemoteRequested({required String userId})`; on success the member's `role` flips in state (`copyWith(role:)`).

- [ ] **Step 1: Write the failing bloc test** (same mockito style as Task 3): seed two members, promote one, expect `role == 'mentor'`; demote, expect `'member'`; failure sets sanitized `errorMessage`.

- [ ] **Step 2: Implement bloc handlers** calling `_repository.promoteMember` / `demoteMember` and mapping `members`.

- [ ] **Step 3: Screen** — group members: `mentorsSection` header (owner first, `ownerLabel` badge on `isOwner`, `mentorLabel` badge on the rest), then when `fellowship.disciplerAllowed` a `helpersSection` with one row `DisciplerAvatar` + `disciplerName` + `DisciplerAiChip` + subtitle "AI helper" (no menu), then members. `_MemberAction` gains `promote`, `demote`; menu shows `promote` for members and `demote` for non-owner mentors when the viewer is a mentor or admin; the `remove` item stays hidden for mentors. Owner row has no demote.

- [ ] **Step 4: Verify** — tests pass; in the app promote Rahul → he moves to Mentors with a badge; owner has no demote. `flutter analyze`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/community/presentation/bloc/fellowship_members lib/features/community/presentation/screens/fellowship_members_tab_screen.dart test/features/community
git commit -m "feat(community): mentors section with promote and demote, Discipler helper row"
```

---

### Task 10: Mentions in the composer and comment box

**Files:**
- Create: `lib/features/community/presentation/widgets/mention_sheet.dart`, `lib/features/community/presentation/utils/mention_text.dart`
- Modify: `FellowshipCreatePostSheet` and the comment input in `fellowship_feed_tab_screen.dart`
- Test: `test/features/community/utils/mention_text_test.dart`

**Interfaces:**
- Produces: `class MentionCandidate { final String handle; final String display; final String subtitle; final bool isDiscipler; final String? avatarUrl; }`, `Future<MentionCandidate?> showMentionSheet(BuildContext context, {required bool disciplerAllowed, required List<FellowshipMentorEntity> mentors})`, and pure `MentionInsertion insertMention(String text, int cursor, String handle)` returning the new text and cursor (replaces a trailing partial `@word` at the cursor, else inserts `@Handle ` at the cursor).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/community/utils/mention_text_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mention_text.dart';

void main() {
  test('replaces partial handle at cursor', () {
    final r = insertMention('Is fasting needed? @Disc', 24, '@Discipler');
    expect(r.text, 'Is fasting needed? @Discipler ');
    expect(r.cursor, r.text.length);
  });
  test('inserts at cursor when no partial', () {
    final r = insertMention('Hello world', 5, '@Anna');
    expect(r.text, 'Hello @Anna  world');
  });
  test('typing @ at end triggers', () {
    expect(shouldOpenMentionSheet('hello @', 7), true);
    expect(shouldOpenMentionSheet('a@b.com', 2), false);
  });
}
```

- [ ] **Step 2: Implement** `mention_text.dart`:
```dart
class MentionInsertion { final String text; final int cursor; const MentionInsertion(this.text, this.cursor); }

/// '@' typed at the start or after whitespace opens the sheet.
bool shouldOpenMentionSheet(String text, int cursor) {
  if (cursor < 1 || cursor > text.length || text[cursor - 1] != '@') return false;
  return cursor == 1 || text[cursor - 2].trim().isEmpty;
}

MentionInsertion insertMention(String text, int cursor, String handle) {
  final before = text.substring(0, cursor);
  final after = text.substring(cursor);
  final m = RegExp(r'(^|\s)@[\w.]*$').firstMatch(before);
  final head = m == null ? '$before ' : before.substring(0, m.start) + (m.group(1) ?? '');
  final next = '$head$handle $after';
  return MentionInsertion(next, head.length + handle.length + 1);
}
```
`mention_sheet.dart`: `showModalBottomSheet` listing Discipler first (`DisciplerAvatar`, `disciplerName`, `disciplerMentionSubtitle`, `DisciplerAiChip`) when `disciplerAllowed`, then mentors with `mentorLabel`. Composer: listen to the controller; when `shouldOpenMentionSheet` fires, open the sheet and apply `insertMention`. Also add a leading `@` `IconButton` to the comment input row that opens the sheet directly. The feed bloc state needs `disciplerAllowed` and `mentors`; pass them through `FellowshipFeedInitialized` (add fields `bool disciplerAllowed = false, List<FellowshipMentorEntity> mentors = const []`) from the home screen.

- [ ] **Step 3: Verify** — tests pass; typing `@` in the composer shows the sheet; selecting Discipler inserts `@Discipler `; posting yields `mentions_discipler: true` on the server.

- [ ] **Step 4: Commit**

```bash
git add lib/features/community/presentation test/features/community/utils
git commit -m "feat(community): @mention sheet for Discipler and mentors in posts and comments"
```

---

### Task 11: Share a post and post deep link

**Files:**
- Create: `lib/features/community/presentation/utils/share_helpers.dart`
- Modify: `lib/core/services/deep_link_service.dart` (`_handleUri`), `lib/core/router/app_router.dart` (route `post/:postId` under `:fellowshipId`), `fellowship_feed_tab_screen.dart` (open a single post's comments when `initialPostId` is given)
- Test: `test/features/community/utils/share_helpers_test.dart`

**Interfaces:**
- Produces: `String buildPostShareText({required FellowshipPostEntity post, required String fellowshipName, required String suffix})` and `Future<void> sharePost(BuildContext context, FellowshipPostEntity post, String fellowshipName)` (uses `SharePlus.instance.share(ShareParams(text: …))` per share_plus 11). Link format `https://disciplefy.in/fellowship/<fellowshipId>/post/<postId>`. Deep link routes to `/community/<fellowshipId>/post/<postId>`.

- [ ] **Step 1: Failing test**

```dart
test('share text quotes 200 chars, author, fellowship and link', () {
  final p = FellowshipPostEntity(id: 'p1', fellowshipId: 'f1', authorUserId: 'u', content: 'x' * 300, postType: 'general',
      reactionCounts: const {}, isDeleted: false, createdAt: 't', authorDisplayName: 'Rahul', commentCount: 0);
  final t = buildPostShareText(post: p, fellowshipName: 'Disciplefy Fellowship', suffix: 'on Disciplefy');
  expect(t.startsWith('"${'x' * 200}…"'), true);
  expect(t.contains('— Rahul in Disciplefy Fellowship on Disciplefy'), true);
  expect(t.trim().endsWith('https://disciplefy.in/fellowship/f1/post/p1'), true);
});
```

- [ ] **Step 2: Implement**

```dart
String buildPostShareText({required FellowshipPostEntity post, required String fellowshipName, required String suffix}) {
  final body = post.content.length > 200 ? '${post.content.substring(0, 200)}…' : post.content;
  final author = post.authorIsSystem ? 'Discipler' : post.authorDisplayName;
  return '"$body"\n— $author in $fellowshipName $suffix\nhttps://disciplefy.in/fellowship/${post.fellowshipId}/post/${post.id}';
}

Future<void> sharePost(BuildContext context, FellowshipPostEntity post, String fellowshipName) {
  final text = buildPostShareText(post: post, fellowshipName: fellowshipName, suffix: AppLocalizations.of(context)!.sharePostSuffix);
  return SharePlus.instance.share(ShareParams(text: text));
}
```
Deep link: in `_handleUri` add a branch for `segments[0] == 'fellowship' && segments.length >= 4 && segments[2] == 'post'` with UUID validation on `segments[1]` and `segments[3]` → `_router.go('/community/${segments[1]}/post/${segments[3]}')`. Router: `GoRoute(path: 'post/:postId', name: 'fellowship_post', builder: … FellowshipHomeScreen(fellowshipId:, initialPostId: state.pathParameters['postId']))`; the home screen, when `initialPostId != null`, pushes the full feed and dispatches `FellowshipCommentsOpenRequested(postId: initialPostId)` after the first successful load. Non-members get the existing 403 → show the Discover detail with Join (the feed error state offers "Find this fellowship in Discover" → `context.go('/community')`).
Add the `/fellowship/*/post/*` path to `android/app/src/main/AndroidManifest.xml` intent filter and the AASA file (`api/apple-app-site-association.js`) beside the existing `/fellowship/join/*` entry.

- [ ] **Step 3: Verify** — test passes; tapping Share opens the OS sheet with the text; `adb shell am start -a android.intent.action.VIEW -d "https://disciplefy.in/fellowship/f0000000-0000-0000-0000-000000000001/post/<id>"` opens the thread.

- [ ] **Step 4: Commit**

```bash
git add lib/features/community/presentation/utils/share_helpers.dart lib/core/services/deep_link_service.dart lib/core/router lib/features/community/presentation/screens android/app/src/main/AndroidManifest.xml api/apple-app-site-association.js test/features/community/utils
git commit -m "feat(community): share fellowship posts with deep links"
```

---

### Task 12: Notification routing and the Discipler activity screen

**Files:**
- Modify: `lib/core/services/notification_service.dart` (switch `:702-724`), `lib/core/services/notification_message_handler_web.dart:194-268`
- Create: `lib/features/community/presentation/bloc/discipler_activity/` (bloc/event/state), `lib/features/community/presentation/screens/discipler_activity_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route `discipler-activity`), `lib/core/di/injection_container.dart`
- Test: `test/features/community/discipler_activity_bloc_test.dart`

**Interfaces:**
- Routing: `fellowship_daily_post` → `/feed`; `fellowship_discipler_reply` → `/post/<post_id>` when present else `/feed`; `fellowship_discipler_activity` → `/discipler-activity`. Web handler gets the same fellowship cases as mobile (all of them, closing the drift).
- Bloc: `DisciplerActivityLoadRequested({required String fellowshipId, String? kind})`, `DisciplerActivityLoadMoreRequested()`, `DisciplerActivityReviewed({required String commentId, required bool approve})`, `DisciplerActivityDeleteRequested({required String activityId, String? postId, String? commentId})`; state `{ status, items, kind, hasMore, cursor, errorMessage }`.

- [ ] **Step 1: Failing bloc test** — load returns two items (mock `getDisciplerActivity`), review with approve flips `commentPending` false; delete removes the item (mock `deleteComment` / `deletePost`).

- [ ] **Step 2: Implement bloc** (repository calls `getDisciplerActivity`, `approveDisciplerComment`, `discardDisciplerComment`, `deleteComment`, `deletePost`).

- [ ] **Step 3: Screen** — app bar `disciplerActivityTitle`; a horizontal chip row `activityTabAll/Review/Replies/Reactions/Daily` mapping to `kind` `null/draft/reply/react/daily_post`; banner text; list of cards: `DisciplerAvatar(14)` + kind badge (`DRAFT` amber, `REPLIED` green, `REACTED 🙏` grey, `DAILY STUDY` amber) + language pill + `summary` + optional post content quote + optional comment content in a tinted box; actions: drafts → `approve` / `discard`; replies/daily → `deleteAction`; reacts → `deleteAction` (removes the reaction via `toggleReaction` as the mentor cannot un-react for Discipler, so instead call a new datasource method? No: keep it simple — reactions rows show no delete; spec allows Delete on "any" but a reaction is harmless and the model reply is what matters). Tapping a card opens `/community/<fellowshipId>/post/<postId>`.

- [ ] **Step 4: Routing** — add the three `case`s to `notification_service.dart` and copy the whole fellowship switch into `notification_message_handler_web.dart`. Router: `GoRoute(path: 'discipler-activity', name: 'fellowship_discipler_activity', …)` providing `DisciplerActivityBloc`.

- [ ] **Step 5: Verify** — tests pass; as Anna the screen lists the rows created in Plans 02/03; approve works; run `deno test --allow-read push-type-routing-drift.test.ts` in the backend (still green).

- [ ] **Step 6: Commit**

```bash
git add lib/core/services lib/features/community/presentation/bloc/discipler_activity lib/features/community/presentation/screens/discipler_activity_screen.dart lib/core/router lib/core/di test/features/community
git commit -m "feat(community): Discipler activity screen and push routing for new types"
```

---

### Task 13: Create fellowship admin toggles, feed bloc context, version bump

**Files:**
- Modify: `lib/features/community/presentation/screens/create_fellowship_screen.dart` (`:29-77`, admin section `:385-471`), `lib/features/community/presentation/bloc/fellowship_list/` (`FellowshipCreateRequested` fields)
- Modify: `pubspec.yaml:3`

- [ ] **Step 1: Toggles** — state `bool _isOfficial = false, _disciplerAllowed = false, _dailyPostAllowed = false;` In the admin-only `BlocBuilder` (the one that already renders language + Make Public) add an `adminOptionsLabel` header and three `SwitchListTile`s: `createFellowshipOfficial`; `createFellowshipDisciplerAllowed` and `createFellowshipDailyAllowed` disabled (`onChanged: null`) until `_isOfficial`. Pass them in `FellowshipCreateRequested` → repository `createFellowship(isOfficial:, disciplerAllowed:, dailyPostAllowed:)`.

- [ ] **Step 2: Feed init context** — where `FellowshipFeedInitialized` is dispatched in `fellowship_home_screen.dart`, pass `disciplerAllowed: fellowship?.disciplerAllowed ?? false, mentors: fellowship?.mentors ?? const []` (fields added in Task 10).

- [ ] **Step 3: Version** — `pubspec.yaml`: `version: 1.0.5+5`.

- [ ] **Step 4: Full verification**

```bash
flutter analyze
dart format --set-exit-if-changed lib test
flutter test
```
Expected: no issues, formatted, all tests pass. Manual pass on the emulator as Anna: create an official fellowship with Discipler on; open settings; post a tagged question as Rahul and see the reply arrive (worker from Plan 03 running); Discover shows All by default.

- [ ] **Step 5: Commit**

```bash
git add lib/features/community/presentation/screens/create_fellowship_screen.dart lib/features/community/presentation/bloc lib/features/community/presentation/screens/fellowship_home_screen.dart pubspec.yaml
git commit -m "feat(community): admin Discipler toggles on create fellowship; bump to 1.0.5"
```

---

## Self-Review Notes

- Spec §6 screens: 1 (Task 6 card badges), 2 (Task 6), 3 (Task 7), 4 (Task 5), 5/5a (Tasks 5, 10), 6 (Task 9), 7/8 (Task 12), settings (Task 8), create (Task 13).
- Spec §7 share: Task 11. §8 cleanups: Task 6 (unlimited), Task 12 (web handler).
- Type consistency: `FellowshipMentorEntity`, `DisciplerActivityEntity`, `FellowshipDisciplerCommentReviewed`, `FellowshipSettingsBloc/Event/State`, `postMenuItems`, `insertMention`, `buildPostShareText` used with the same names throughout.
- Deviation noted in Task 12: reaction rows in the activity screen have no Delete; the spec's "Delete (any)" is satisfied for replies, drafts and daily posts. Flag to the user at review.
