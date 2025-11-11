// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_verse_streak_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyVerseStreakModel _$DailyVerseStreakModelFromJson(
        Map<String, dynamic> json) =>
    DailyVerseStreakModel(
      userId: json['user_id'] as String,
      currentStreak: (json['current_streak'] as num).toInt(),
      longestStreak: (json['longest_streak'] as num).toInt(),
      lastViewedAt: json['last_viewed_at'] == null
          ? null
          : DateTime.parse(json['last_viewed_at'] as String),
      totalViews: (json['total_views'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DailyVerseStreakModelToJson(
        DailyVerseStreakModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'current_streak': instance.currentStreak,
      'longest_streak': instance.longestStreak,
      'last_viewed_at': instance.lastViewedAt?.toIso8601String(),
      'total_views': instance.totalViews,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
