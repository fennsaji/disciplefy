import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/discipler_activity_entity.dart';
import '../../../domain/repositories/community_repository.dart';
import 'discipler_activity_event.dart';
import 'discipler_activity_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

/// BLoC backing the Discipler activity screen: lists what the Discipler AI
/// helper has drafted, replied, reacted to, or posted in a fellowship, and
/// lets a mentor review drafts or delete rows.
class DisciplerActivityBloc
    extends Bloc<DisciplerActivityEvent, DisciplerActivityState> {
  final CommunityRepository _repository;
  String? _fellowshipId;

  DisciplerActivityBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const DisciplerActivityState()) {
    on<DisciplerActivityLoadRequested>(_onLoadRequested);
    on<DisciplerActivityLoadMoreRequested>(_onLoadMoreRequested);
    on<DisciplerActivityReviewed>(_onReviewed);
    on<DisciplerActivityDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    DisciplerActivityLoadRequested event,
    Emitter<DisciplerActivityState> emit,
  ) async {
    _fellowshipId = event.fellowshipId;
    emit(state.copyWith(
      status: DisciplerActivityStatus.loading,
      kind: event.kind,
      clearKind: event.kind == null,
      clearErrorMessage: true,
    ));

    final result = await _repository.getDisciplerActivity(
      fellowshipId: event.fellowshipId,
      kind: event.kind,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: DisciplerActivityStatus.failure,
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (page) => emit(state.copyWith(
        status: DisciplerActivityStatus.success,
        items: page.items,
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      )),
    );
  }

  Future<void> _onLoadMoreRequested(
    DisciplerActivityLoadMoreRequested event,
    Emitter<DisciplerActivityState> emit,
  ) async {
    final fellowshipId = _fellowshipId;
    if (fellowshipId == null || !state.hasMore || state.cursor == null) {
      return;
    }

    final result = await _repository.getDisciplerActivity(
      fellowshipId: fellowshipId,
      kind: state.kind,
      cursor: state.cursor,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (page) => emit(state.copyWith(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      )),
    );
  }

  Future<void> _onReviewed(
    DisciplerActivityReviewed event,
    Emitter<DisciplerActivityState> emit,
  ) async {
    final result = event.approve
        ? await _repository.approveDisciplerComment(event.commentId)
        : await _repository.discardDisciplerComment(event.commentId);

    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (_) {
        final updated = state.items.map((item) {
          if (item.commentId != event.commentId) return item;
          return DisciplerActivityEntity(
            id: item.id,
            kind: item.kind,
            postId: item.postId,
            commentId: item.commentId,
            reaction: item.reaction,
            language: item.language,
            summary: item.summary,
            reviewedAt: item.reviewedAt,
            createdAt: item.createdAt,
            postContent: item.postContent,
            postType: item.postType,
            topicTitle: item.topicTitle,
            commentContent: item.commentContent,
            commentDeleted: event.approve ? item.commentDeleted : true,
          );
        }).toList();
        emit(state.copyWith(items: updated));
      },
    );
  }

  Future<void> _onDeleteRequested(
    DisciplerActivityDeleteRequested event,
    Emitter<DisciplerActivityState> emit,
  ) async {
    final result = event.postId != null
        ? await _repository.deletePost(event.postId!)
        : event.commentId != null
            ? await _repository.deleteComment(event.commentId!)
            : null;

    if (result == null) return;

    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: ErrorMessageSanitizer.sanitize(failure),
      )),
      (_) => emit(state.copyWith(
        items:
            state.items.where((item) => item.id != event.activityId).toList(),
      )),
    );
  }
}
