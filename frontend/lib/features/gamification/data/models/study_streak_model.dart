import '../../domain/entities/study_streak.dart';

/// Data model for StudyStreak from Supabase
class StudyStreakModel extends StudyStreak {
  const StudyStreakModel({
    super.id,
    required super.userId,
    super.currentStreak,
    super.longestStreak,
    super.lastStudyDate,
    super.totalStudyDays,
    super.createdAt,
    super.updatedAt,
  });

  /// Create from Supabase response
  factory StudyStreakModel.fromJson(Map<String, dynamic> json) {
    return StudyStreakModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastStudyDate: json['last_study_date'] != null
          ? DateTime.tryParse(json['last_study_date'].toString())
          : null,
      totalStudyDays: (json['total_study_days'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_study_date': lastStudyDate?.toIso8601String().split('T').first,
      'total_study_days': totalStudyDays,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  StudyStreak toEntity() {
    return StudyStreak(
      id: id,
      userId: userId,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastStudyDate: lastStudyDate,
      totalStudyDays: totalStudyDays,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Model for study streak update result
class StudyStreakUpdateResultModel extends StudyStreakUpdateResult {
  const StudyStreakUpdateResultModel({
    required super.currentStreak,
    required super.longestStreak,
    required super.streakIncreased,
    required super.isNewRecord,
  });

  factory StudyStreakUpdateResultModel.fromJson(Map<String, dynamic> json) {
    return StudyStreakUpdateResultModel(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      streakIncreased: json['streak_increased'] as bool? ?? false,
      isNewRecord: json['is_new_record'] as bool? ?? false,
    );
  }
}
