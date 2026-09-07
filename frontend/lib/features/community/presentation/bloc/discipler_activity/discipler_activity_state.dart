import 'package:equatable/equatable.dart';

import '../../../domain/entities/discipler_activity_entity.dart';

/// Load lifecycle for [DisciplerActivityBloc].
enum DisciplerActivityStatus { initial, loading, success, failure }

/// Single immutable state for [DisciplerActivityBloc].
class DisciplerActivityState extends Equatable {
  final DisciplerActivityStatus status;
  final List<DisciplerActivityEntity> items;

  /// Active `kind` filter: `null` (all), `'draft'`, `'reply'`, `'react'`, or
  /// `'daily_post'`.
  final String? kind;

  final bool hasMore;
  final String? cursor;
  final String? errorMessage;

  const DisciplerActivityState({
    this.status = DisciplerActivityStatus.initial,
    this.items = const [],
    this.kind,
    this.hasMore = false,
    this.cursor,
    this.errorMessage,
  });

  DisciplerActivityState copyWith({
    DisciplerActivityStatus? status,
    List<DisciplerActivityEntity>? items,
    String? kind,
    bool clearKind = false,
    bool? hasMore,
    String? cursor,
    bool clearCursor = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DisciplerActivityState(
      status: status ?? this.status,
      items: items ?? this.items,
      kind: clearKind ? null : (kind ?? this.kind),
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, items, kind, hasMore, cursor, errorMessage];
}
