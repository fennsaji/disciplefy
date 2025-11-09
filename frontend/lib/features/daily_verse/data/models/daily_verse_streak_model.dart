import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/daily_verse_streak.dart';

part 'daily_verse_streak_model.g.dart';

/// Data model for daily verse streak with JSON serialization
@JsonSerializable()
class DailyVerseStreakModel {
  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(name: 'current_streak')
  final int currentStreak;

  @JsonKey(name: 'longest_streak')
  final int longestStreak;

  @JsonKey(name: 'last_viewed_at')
  final DateTime? lastViewedAt;

  @JsonKey(name: 'total_views')
  final int totalViews;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const DailyVerseStreakModel({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastViewedAt,
    required this.totalViews,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert from JSON
  factory DailyVerseStreakModel.fromJson(Map<String, dynamic> json) =>
      _$DailyVerseStreakModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$DailyVerseStreakModelToJson(this);

  /// Convert to domain entity
  DailyVerseStreak toEntity() {
    return DailyVerseStreak(
      userId: userId,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastViewedAt: lastViewedAt,
      totalViews: totalViews,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Convert from domain entity
  factory DailyVerseStreakModel.fromEntity(DailyVerseStreak entity) {
    return DailyVerseStreakModel(
      userId: entity.userId,
      currentStreak: entity.currentStreak,
      longestStreak: entity.longestStreak,
      lastViewedAt: entity.lastViewedAt,
      totalViews: entity.totalViews,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
